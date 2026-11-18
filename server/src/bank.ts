// Sprint 5: lấy giao dịch ngân hàng thật về app.
//   A. MB qua SePay: mỗi người dùng tự tạo webhook trên SePay, dán URL + API key app cấp.
//   B. Vietcombank qua email: Gmail chuyển tiếp biên lai → Cloudflare Email Worker → /api/webhooks/email.
// Cả hai đi qua addTx như nhập tay/demo (phân loại, SSE, gợi ý Đánh giá nhanh).
import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import type { FastifyInstance } from "fastify";
import PostalMime from "postal-mime";
import { db } from "./db.ts";
import { USER_COLS, requireUser, type User } from "./auth.ts";
import { addTx, categorize, categoryId } from "./money.ts";
import { parseVcb } from "./vcb.ts";

type Provider = "sepay" | "vcb_email";

export type SepayPayload = {
  id: number; gateway?: string | null; transactionDate: string; accountNumber?: string | null;
  content?: string | null; transferType: "in" | "out"; transferAmount: number; accumulated?: number | null;
};

const sha256 = (s: string) => createHash("sha256").update(s).digest("hex");
const mask = (acc?: string | null) => (acc ? "****" + acc.replace(/\D/g, "").slice(-4) : null);

/** Payload SePay → giao dịch. external_id gắn id liên kết: người khác không chặn được giao dịch của mình bằng id trùng */
export function fromSepay(p: SepayPayload, linkId: string) {
  return {
    direction: p.transferType,
    amount: p.transferAmount,
    occurred_at: p.transactionDate.replace(" ", "T") + "+07:00", // SePay gửi giờ VN, không kèm múi giờ
    external_id: `${linkId}:${p.id}`,
    bank_account_id: linkId,
    balance_after: p.accumulated || null, // 0 = ngân hàng không gửi số dư
    raw_content: p.content ?? "",
  };
}

/** Key SePay / token địa chỉ email → liên kết đang hoạt động + chủ của nó */
async function linkByKey(provider: Provider, secret: string): Promise<{ id: string; user: User } | null> {
  const { rows } = await db.query(
    `select a.id as link_id, ${USER_COLS} from bank_accounts a join users u on u.id = a.user_id
     where a.provider = $1 and a.webhook_key_hash = $2 and a.status = 'active'`,
    [provider, sha256(secret)],
  );
  if (!rows[0]) return null;
  const { link_id, ...user } = rows[0];
  return { id: link_id, user };
}

const log = (payload: object, status: string, error: string | null = null) =>
  db.query("insert into webhook_logs (payload, status, error) values ($1, $2, $3)", [payload, status, error]);

const touch = (id: string, bank: string | null | undefined, masked: string | null) =>
  db.query(
    `update bank_accounts set last_webhook_at = now(),
       bank_short_name = coalesce(bank_short_name, $2), account_number_masked = coalesce(account_number_masked, $3)
     where id = $1`,
    [id, bank ?? null, masked],
  );

export async function bankRoutes(app: FastifyInstance) {
  const hookLimit = { rateLimit: { max: 120, timeWindow: "1 minute" } };

  // ===== A. Webhook SePay =====
  app.post<{ Body: SepayPayload }>("/api/webhooks/sepay", {
    config: hookLimit,
    schema: {
      body: {
        type: "object", required: ["id", "transactionDate", "transferType", "transferAmount"],
        properties: {
          id: { type: "integer" },
          gateway: { type: ["string", "null"] },
          transactionDate: { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$" },
          accountNumber: { type: ["string", "null"] },
          content: { type: ["string", "null"] },
          transferType: { enum: ["in", "out"] },
          transferAmount: { type: "integer", minimum: 1 },
          accumulated: { type: ["integer", "null"] },
        },
      },
    },
  }, async (req, reply) => {
    const key = /^apikey\s+(\S+)$/i.exec(req.headers.authorization ?? "")?.[1];
    const link = key ? await linkByKey("sepay", key) : null;
    if (!link) return reply.code(401).send({ success: false });
    const p = req.body;
    const logged = { ...p, accountNumber: mask(p.accountNumber) };
    try {
      const t = fromSepay(p, link.id);
      const tx = await addTx(link.user, { source: "sepay", ...t, ...(await categorize(link.user.id, t.direction, t.raw_content)) });
      await touch(link.id, p.gateway, mask(p.accountNumber));
      await log(logged, tx ? "ok" : "duplicate");
      return { success: true };
    } catch (e) {
      req.log.error(e);
      await log(logged, "error", String(e)).catch(() => {});
      return reply.code(500).send({ success: false }); // SePay gửi lại; unique(source, external_id) chống trùng
    }
  });

  // ===== B. Email chuyển tiếp (Cloudflare Email Worker gửi nguyên văn MIME) =====
  app.addContentTypeParser("message/rfc822", { parseAs: "buffer", bodyLimit: 1_048_576 }, (_req, body, done) =>
    done(null, body));

  app.post<{ Body: Buffer }>("/api/webhooks/email", { config: hookLimit }, async (req, reply) => {
    const secret = process.env.EMAIL_WEBHOOK_SECRET;
    if (!secret) return reply.code(503).send({ error: "email_off" }); // chưa cấu hình → tắt hẳn, không so với chuỗi rỗng
    const got = /^bearer\s+(\S+)$/i.exec(req.headers.authorization ?? "")?.[1] ?? "";
    const h = (s: string) => createHash("sha256").update(s).digest(); // cùng độ dài cho timingSafeEqual
    if (!timingSafeEqual(h(got), h(secret))) return reply.code(401).send({ error: "unauthorized" });
    if (!Buffer.isBuffer(req.body)) return reply.code(415).send({ error: "unsupported_media_type" });

    const mail = await PostalMime.parse(req.body);
    const from = (mail.from?.address ?? "").toLowerCase();
    const meta = { from, subject: mail.subject ?? null, message_id: mail.messageId ?? null }; // không lưu thân thư
    const token = String(req.headers["x-rcpt-to"] ?? "").toLowerCase().split("@")[0];
    const link = /^[0-9a-f]{32}$/.test(token) ? await linkByKey("vcb_email", token) : null;
    if (!link) {
      await log(meta, "unknown_account");
      return { ok: true };
    }
    // Gmail gửi thư xác nhận khi thêm địa chỉ chuyển tiếp → hiện mã trong app để người dùng nhập vào Gmail
    if (from === "forwarding-noreply@google.com") {
      const code = /#(\d+)/.exec(mail.subject ?? "")?.[1] ?? mail.subject ?? null;
      await db.query("update bank_accounts set gmail_confirm = $2 where id = $1", [link.id, code]);
      return { ok: true };
    }
    // ponytail: tin vào địa chỉ bí mật (token 128 bit) + tên miền người gửi, không tự kiểm DKIM.
    // Địa chỉ lộ thì người dùng huỷ liên kết, tạo lại; cần chặt hơn thì kiểm DKIM d=info.vietcombank.com.vn (mailauth).
    if (!/[@.]vietcombank\.com\.vn$/.test(from)) return { ok: true };
    try {
      const v = parseVcb(mail.html ?? "");
      if (!v) {
        await log(meta, "error", "không đọc được email");
        return { ok: true }; // mẫu lạ: gửi lại cũng không đọc được
      }
      const cat = v.self
        ? { category_id: await categoryId("self_transfer"), category_confirmed: true }
        : await categorize(link.user.id, v.direction, `${v.counterparty ?? ""} ${v.content}`);
      const tx = await addTx(link.user, {
        source: "email", direction: v.direction, amount: v.amount, occurred_at: v.occurred_at,
        external_id: `${link.id}:${v.ref}`, bank_account_id: link.id,
        raw_content: v.content, counterparty: v.counterparty, ...cat,
      });
      await touch(link.id, "Vietcombank", v.account_last4 && "****" + v.account_last4);
      await log(meta, tx ? "ok" : "duplicate");
      return { ok: true };
    } catch (e) {
      req.log.error(e);
      await log(meta, "error", String(e)).catch(() => {});
      return reply.code(500).send({ ok: false });
    }
  });

  // ===== Quản lý liên kết (cần đăng nhập) =====
  const auth = { preHandler: requireUser };

  app.get("/api/bank-links", auth, async (req) =>
    (await db.query(
      `select id, provider, bank_short_name, account_number_masked, linked_at, last_webhook_at, gmail_confirm
       from bank_accounts where user_id = $1 and status = 'active' order by linked_at`,
      [req.user!.id],
    )).rows);

  app.post<{ Body: { provider: Provider } }>("/api/bank-links", {
    ...auth,
    schema: {
      body: {
        type: "object", required: ["provider"], additionalProperties: false,
        properties: { provider: { enum: ["sepay", "vcb_email"] } },
      },
    },
  }, async (req, reply) => {
    const { provider } = req.body;
    const mailDomain = process.env.MAIL_DOMAIN;
    if (provider === "vcb_email" && !mailDomain)
      return reply.code(503).send({ error: "email_off", message: "Máy chủ chưa bật nhận email." });
    const secret = randomBytes(16).toString("hex"); // hex chữ thường: hợp cả form SePay lẫn địa chỉ email
    const { rows } = await db.query(
      `insert into bank_accounts (user_id, provider, webhook_key_hash, bank_short_name)
       select $1, $2, $3, $4
       where (select count(*) from bank_accounts where user_id = $1 and status = 'active') < 3
       returning id`,
      [req.user!.id, provider, sha256(secret), provider === "vcb_email" ? "Vietcombank" : null],
    );
    if (!rows[0])
      return reply.code(409).send({ error: "too_many", message: "Bạn đã có 3 liên kết, huỷ bớt một cái trước nhé." });
    // Key/địa chỉ chỉ trả đúng lần này (DB chỉ giữ sha256)
    return reply.code(201).send(provider === "sepay"
      ? { id: rows[0].id, webhook_url: `${process.env.PUBLIC_URL || `${req.protocol}://${req.host}`}/api/webhooks/sepay`, api_key: secret }
      : { id: rows[0].id, address: `${secret}@${mailDomain}` });
  });

  app.delete<{ Params: { id: string } }>("/api/bank-links/:id", {
    ...auth,
    schema: { params: { type: "object", required: ["id"], properties: { id: { type: "string", format: "uuid" } } } },
  }, async (req, reply) => {
    const { rowCount } = await db.query(
      "update bank_accounts set status = 'unlinked' where id = $1 and user_id = $2 and status = 'active'",
      [req.params.id, req.user!.id],
    );
    return rowCount ? { ok: true } : reply.code(404).send({ error: "not_found", message: "Không tìm thấy." });
  });
}
