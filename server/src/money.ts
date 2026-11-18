import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { db } from "./db.ts";
import { requireUser, type User } from "./auth.ts";
import { emit } from "./events.ts";
import {
  TZ, computeSummary, daysLeft, monthOf, quickCheck, shouldSuggest, vnToday, weeklyReview, type BudgetRow,
} from "./budget.ts";
import { KEYWORDS, classify, learnPattern, type Rule } from "./classify.ts";

const TX_COLS =
  "id, source, wallet, direction, amount, occurred_at, raw_content, counterparty, category_id, category_confirmed, note";
const NOT_FOUND = { error: "not_found", message: "Không tìm thấy." };
const idParam = { type: "object", required: ["id"], properties: { id: { type: "string", format: "uuid" } } };
const monthQuery = { type: "object", properties: { month: { type: "string", pattern: "^\\d{4}-(0[1-9]|1[0-2])$" } } };
const money = { type: "integer", minimum: 0, maximum: 1_000_000_000_000 };

// "2026-11" → "2026-11-01"; không truyền → tháng hiện tại theo giờ VN
const monthStart = (m?: string) => `${m ?? monthOf(vnToday())}-01`;

const catIds = new Map<string, number>();
export async function categoryId(code: string): Promise<number> {
  if (!catIds.size) for (const r of (await db.query("select id, code from categories")).rows) catIds.set(r.code, r.id);
  return catIds.get(code)!;
}

let dict: Rule[] | null = null;
async function classifyFor(userId: string, text: string): Promise<number | null> {
  if (!dict) {
    const d: Rule[] = [];
    for (const [code, patterns] of Object.entries(KEYWORDS)) {
      const id = await categoryId(code);
      for (const pattern of patterns) d.push({ pattern, category_id: id });
    }
    dict = d;
  }
  const rules = await db.query("select pattern, category_id from merchant_rules where user_id = $1", [userId]);
  return classify(text, rules.rows, dict);
}

// Tiền vào → "Tiền vào"; khoản chi → tự phân loại, không khớp thì "Khác" + chờ người dùng chọn (spec 9.1)
export async function categorize(userId: string, direction: "in" | "out", text: string) {
  const found = direction === "in" ? await categoryId("income") : await classifyFor(userId, text);
  return { category_id: found ?? (await categoryId("other")), category_confirmed: found !== null };
}

// Không tính vào chi/thu: chuyển giữa tài khoản của mình (luôn), nạp ví (khi user bật exclude_topup)
const NOT_SELF = `category_id is distinct from (select id from categories where code = 'self_transfer')`;
const TOPUP_FILTER = `t.${NOT_SELF}
  and not ($2::boolean and t.category_id is not distinct from (select id from categories where code = 'topup'))`;

// Số liệu Dashboard (spec 9.2), dùng chung cho /api/summary, Đánh giá nhanh và gợi ý sau mỗi khoản chi
async function getSummary(u: User) {
  const today = vnToday();
  const month = monthStart();
  const [budgets, spent, week, pending] = await Promise.all([
    db.query("select category_id, amount, is_essential from budgets where user_id = $1 and month = $2", [u.id, month]),
    db.query(
      `select t.category_id, sum(t.amount)::bigint as spent from transactions t
       where t.user_id = $1 and t.direction = 'out' and ${TOPUP_FILTER}
         and t.occurred_at >= $3::date::timestamp at time zone '${TZ}'
         and t.occurred_at < ($3::date + interval '1 month')::timestamp at time zone '${TZ}'
       group by t.category_id`,
      [u.id, u.exclude_topup, month],
    ),
    db.query(
      `select coalesce(sum(t.amount), 0)::bigint as spent from transactions t
       where t.user_id = $1 and t.direction = 'out' and ${TOPUP_FILTER}
         and t.occurred_at >= date_trunc('week', now() at time zone '${TZ}') at time zone '${TZ}'`,
      [u.id, u.exclude_topup],
    ),
    db.query(
      "select count(*)::int as n from transactions where user_id = $1 and direction = 'out' and not category_confirmed",
      [u.id],
    ),
  ]);
  const spentMap = new Map<number | null, number>(spent.rows.map((r) => [r.category_id, r.spent]));
  return {
    month: monthOf(today),
    ...computeSummary(budgets.rows as BudgetRow[], spentMap, daysLeft(today, u.monthly_income_day)),
    spent_week: week.rows[0].spent as number,
    pending_count: pending.rows[0].n as number,
  };
}

export type NewTx = {
  source: "manual" | "demo" | "sepay" | "email"; direction: "in" | "out"; amount: number; category_id: number;
  category_confirmed: boolean; wallet?: string | null; external_id?: string | null;
  raw_content?: string | null; note?: string | null; occurred_at?: string | null;
  bank_account_id?: string | null; counterparty?: string | null; balance_after?: number | null;
};

// Chung cho nhập tay, demo, webhook SePay và email → demo giống hệt giao dịch thật.
// Trả null nếu giao dịch ngân hàng đã có (webhook gửi lại).
export async function addTx(u: User, t: NewTx) {
  const { rows } = await db.query(
    `insert into transactions (user_id, source, wallet, external_id, direction, amount, occurred_at,
       raw_content, category_id, category_confirmed, note, bank_account_id, counterparty, balance_after)
     values ($1, $2, $3, $4, $5, $6, coalesce($7::timestamptz, now()), $8, $9, $10, $11, $12, $13, $14)
     on conflict (source, external_id) do nothing
     returning ${TX_COLS}`,
    [u.id, t.source, t.wallet ?? null, t.external_id ?? null, t.direction, t.amount, t.occurred_at ?? null,
     t.raw_content ?? null, t.category_id, t.category_confirmed, t.note ?? null,
     t.bank_account_id ?? null, t.counterparty ?? null, t.balance_after ?? null],
  );
  let tx = rows[0];
  if (!tx) return null;
  const self = await categoryId("self_transfer");
  if (t.bank_account_id) {
    // Chuyển giữa 2 tài khoản đã liên kết của mình (VCB → MB): khoản ngược chiều, cùng số tiền, lệch ≤ 15 phút
    // → cả hai thành self_transfer, không tính chi/thu. MB hay VCB báo về trước cũng ghép được.
    // Khoản kia có thể đã là self_transfer (email VCB cùng tên người chuyển/hưởng) → vẫn ghép.
    // ponytail: ghép theo số tiền + thời gian, có thể nhầm nếu đúng lúc có khoản vào/ra cùng số tiền với người khác
    // → người dùng tự đổi nhóm. Cần chính xác hơn thì so thêm số tài khoản người hưởng.
    const paired = await db.query(
      `with peer as (
         update transactions set category_id = $1, category_confirmed = true
         where id = (
           select id from transactions
           where user_id = $2 and bank_account_id is not null and bank_account_id <> $3
             and direction <> $4 and amount = $5
             and abs(extract(epoch from occurred_at - $6::timestamptz)) <= 900
           order by abs(extract(epoch from occurred_at - $6::timestamptz)) limit 1)
         returning id)
       update transactions set category_id = $1, category_confirmed = true
       where id = $7 and exists (select 1 from peer)
       returning ${TX_COLS}`,
      [self, u.id, t.bank_account_id, tx.direction, tx.amount, tx.occurred_at, tx.id],
    );
    if (paired.rows[0]) tx = paired.rows[0];
  }
  emit(u.id, "transaction.created", tx);
  if (tx.direction === "out" && tx.category_id !== self) {
    // Khoản chi lớn / bất thường / vừa làm vượt ngân sách → gợi ý Đánh giá nhanh (spec 9.3)
    const [s, avg] = await Promise.all([
      getSummary(u),
      db.query(
        `select avg(amount)::float8 as avg, count(*)::int as n from transactions
         where user_id = $1 and direction = 'out' and id <> $2 and ${NOT_SELF}`,
        [u.id, tx.id],
      ),
    ]);
    const counted = !(u.exclude_topup && tx.category_id === (await categoryId("topup")));
    const reason = shouldSuggest(tx.amount, s, avg.rows[0].avg, avg.rows[0].n, counted);
    if (reason) emit(u.id, "quick_check.suggested", { reason, transaction_id: tx.id });
  }
  return tx;
}

export async function moneyRoutes(app: FastifyInstance) {
  app.addHook("preHandler", requireUser); // mọi route trong file này cần đăng nhập
  const uid = (req: { user: User | null }) => req.user!.id;

  app.get("/api/categories", async () =>
    (await db.query("select id, code, name_vi, icon, default_essential from categories order by id")).rows);

  // ===== Ngân sách =====
  app.get<{ Querystring: { month?: string } }>("/api/budgets", { schema: { querystring: monthQuery } }, async (req) =>
    (await db.query(
      "select category_id, amount, is_essential from budgets where user_id = $1 and month = $2 order by category_id nulls first",
      [uid(req), monthStart(req.query.month)],
    )).rows);

  app.put<{
    Querystring: { month?: string };
    Body: { total: number; categories: { category_id: number; amount: number; is_essential: boolean }[] };
  }>("/api/budgets", {
    schema: {
      querystring: monthQuery,
      body: {
        type: "object", required: ["total", "categories"],
        properties: {
          total: money,
          categories: {
            type: "array", maxItems: 50,
            items: {
              type: "object", required: ["category_id", "amount", "is_essential"],
              properties: { category_id: { type: "integer" }, amount: money, is_essential: { type: "boolean" } },
            },
          },
        },
      },
    },
  }, async (req) => {
    const rows = [{ category_id: null, amount: req.body.total, is_essential: false }, ...req.body.categories];
    const c = await db.connect();
    try { // thay toàn bộ ngân sách của tháng trong 1 transaction
      await c.query("begin");
      await c.query("delete from budgets where user_id = $1 and month = $2", [uid(req), monthStart(req.query.month)]);
      await c.query(
        `insert into budgets (user_id, month, category_id, amount, is_essential)
         select $1, $2, x.category_id, x.amount, x.is_essential
         from jsonb_to_recordset($3::jsonb) as x(category_id int, amount bigint, is_essential boolean)`,
        [uid(req), monthStart(req.query.month), JSON.stringify(rows)],
      );
      await c.query("commit");
    } catch (e) {
      await c.query("rollback");
      throw e;
    } finally {
      c.release();
    }
    return { ok: true };
  });

  // ===== Giao dịch =====
  app.get<{ Querystring: { from?: string; category_id?: number; before?: string; limit: number } }>("/api/transactions", {
    schema: {
      querystring: {
        type: "object",
        properties: {
          from: { type: "string", format: "date" },          // ngày (giờ VN)
          category_id: { type: "integer" },
          before: { type: "string", format: "date-time" },   // con trỏ phân trang = occurred_at dòng cuối
          limit: { type: "integer", minimum: 1, maximum: 100, default: 50 },
        },
      },
    },
  }, async (req) => {
    const q = req.query;
    // ponytail: con trỏ chỉ theo occurred_at, 2 giao dịch trùng đúng thời điểm ở mép trang có thể bị sót
    return (await db.query(
      `select ${TX_COLS} from transactions
       where user_id = $1
         and ($2::date is null or occurred_at >= $2::date::timestamp at time zone '${TZ}')
         and ($3::int is null or category_id = $3)
         and ($4::timestamptz is null or occurred_at < $4)
       order by occurred_at desc limit $5`,
      [uid(req), q.from ?? null, q.category_id ?? null, q.before ?? null, q.limit],
    )).rows;
  });

  app.post<{ Body: { direction: "in" | "out"; amount: number; category_id: number; wallet: string; note?: string; occurred_at?: string } }>(
    "/api/transactions", {
      schema: {
        body: {
          type: "object", required: ["amount", "category_id"], additionalProperties: false,
          properties: {
            direction: { enum: ["in", "out"], default: "out" },
            amount: { ...money, minimum: 1 },
            category_id: { type: "integer" },
            wallet: { enum: ["cash", "momo", "zalopay", "other"], default: "cash" },
            note: { type: "string", maxLength: 200 },
            occurred_at: { type: "string", format: "date-time" },
          },
        },
      },
    }, async (req, reply) => {
      const b = req.body; // source luôn là 'manual': client không giả được giao dịch ngân hàng
      return reply.code(201).send(await addTx(req.user!, { ...b, source: "manual", category_confirmed: true }));
    });

  app.patch<{ Params: { id: string }; Body: { category_id?: number; note?: string | null } }>("/api/transactions/:id", {
    schema: {
      params: idParam,
      body: {
        type: "object", additionalProperties: false, minProperties: 1,
        properties: { category_id: { type: "integer" }, note: { type: ["string", "null"], maxLength: 200 } },
      },
    },
  }, async (req, reply) => {
    const b = req.body;
    const { rows } = await db.query(
      `update transactions set
         category_id = coalesce($3, category_id),
         category_confirmed = category_confirmed or $3 is not null,
         note = case when $4 then $5 else note end
       where id = $1 and user_id = $2 returning ${TX_COLS}`,
      [req.params.id, uid(req), b.category_id ?? null, "note" in b, b.note ?? null],
    );
    if (!rows[0]) return reply.code(404).send(NOT_FOUND);
    // Người dùng tự chọn nhóm → học quy tắc, lần sau giao dịch tương tự tự vào nhóm này (spec 9.1)
    const pattern = b.category_id != null ? learnPattern(rows[0].counterparty ?? rows[0].raw_content) : null;
    if (pattern)
      await db.query(
        `insert into merchant_rules (user_id, pattern, category_id) values ($1, $2, $3)
         on conflict (user_id, pattern) do update set category_id = excluded.category_id, hits = merchant_rules.hits + 1`,
        [uid(req), pattern, b.category_id],
      );
    return rows[0];
  });

  app.delete<{ Params: { id: string } }>("/api/transactions/:id", { schema: { params: idParam } }, async (req, reply) => {
    const { rowCount } = await db.query("delete from transactions where id = $1 and user_id = $2", [req.params.id, uid(req)]);
    return rowCount ? { ok: true } : reply.code(404).send(NOT_FOUND);
  });

  app.delete("/api/transactions", async (req) => {
    const { rowCount } = await db.query("delete from transactions where user_id = $1", [uid(req)]);
    return { deleted: rowCount };
  });

  // ===== Tổng hợp cho Dashboard (spec 9.2) =====
  app.get("/api/summary", async (req) => getSummary(req.user!));

  // ===== Đánh giá nhanh (spec 9.3) =====
  app.get("/api/quick-check", async (req) => {
    const u = req.user!;
    const [s, bal, inc] = await Promise.all([
      getSummary(u),
      // Số dư = tổng số dư mới nhất của từng tài khoản còn liên kết (MB + VCB), null nếu chưa có
      db.query(
        `select sum(b)::bigint as balance_after from (
           select distinct on (t.bank_account_id) t.balance_after as b from transactions t
           join bank_accounts a on a.id = t.bank_account_id and a.status = 'active'
           where t.user_id = $1 and t.balance_after is not null
           order by t.bank_account_id, t.occurred_at desc) x`,
        [u.id],
      ),
      db.query(
        `select coalesce(sum(amount), 0)::bigint as v from transactions
         where user_id = $1 and direction = 'in' and ${NOT_SELF}
           and occurred_at >= $2::date::timestamp at time zone '${TZ}'`,
        [u.id, monthStart()],
      ),
    ]);
    return quickCheck(s, bal.rows[0]?.balance_after ?? null, inc.rows[0].v);
  });

  // ===== Tổng kết tuần (spec 11.4): tính khi mở, 13 tuần gần nhất đủ cho streak + huy hiệu 8 tuần =====
  app.get("/api/review/weekly", async (req) => {
    const u = req.user!;
    const WEEK = `date_trunc('week', now() at time zone '${TZ}')`;
    const [w, rows, budgets, classified, cats] = await Promise.all([
      db.query(`select ${WEEK}::date::text as w`),
      db.query(
        `select date_trunc('week', t.occurred_at at time zone '${TZ}')::date::text as week, t.category_id,
                sum(t.amount)::bigint as spent
         from transactions t
         where t.user_id = $1 and t.direction = 'out' and ${TOPUP_FILTER}
           and t.occurred_at >= (${WEEK} - interval '13 weeks') at time zone '${TZ}'
         group by 1, 2`,
        [u.id, u.exclude_topup],
      ),
      db.query("select to_char(month, 'YYYY-MM') as m, amount from budgets where user_id = $1 and category_id is null", [u.id]),
      db.query("select coalesce(sum(hits), 0)::int as n from merchant_rules where user_id = $1", [u.id]),
      db.query("select id, name_vi from categories"),
    ]);
    return weeklyReview({
      thisWeek: w.rows[0].w,
      rows: rows.rows,
      monthBudget: new Map(budgets.rows.map((r) => [r.m, r.amount])),
      classified: classified.rows[0].n,
      names: new Map(cats.rows.map((r) => [r.id, r.name_vi])),
    });
  });

  // ===== Chế độ Demo (spec 14) =====
  const demoOk = (u: User) => process.env.APP_ENV === "demo" && u.demo_mode;
  const DEMO_OFF = { error: "demo_off", message: "Bật Chế độ Demo trong Cài đặt trước nhé." };

  app.post<{ Body: { direction: "in" | "out"; amount: number; content: string } }>("/api/demo/transactions", {
    schema: {
      body: {
        type: "object", required: ["direction", "amount", "content"],
        properties: {
          direction: { enum: ["in", "out"] },
          amount: { ...money, minimum: 1 },
          content: { type: "string", minLength: 1, maxLength: 200 },
        },
      },
    },
  }, async (req, reply) => {
    if (!demoOk(req.user!)) return reply.code(403).send(DEMO_OFF);
    const b = req.body;
    return reply.code(201).send(await addTx(req.user!, {
      source: "demo", external_id: randomUUID(), direction: b.direction, amount: b.amount, raw_content: b.content,
      ...(await categorize(uid(req), b.direction, b.content)),
    }));
  });

  app.post("/api/demo/seed", async (req, reply) => {
    if (!demoOk(req.user!)) return reply.code(403).send(DEMO_OFF);
    const items: { code: string; content: string; amount: number; days: number; hours: number; dir: string }[] = [];
    for (let d = 1; d <= 14; d++) {
      const a = SEED[d % 5], b = SEED[5 + (d * 3) % (SEED.length - 5)];
      items.push({ code: a[0], content: a[1], amount: a[2], days: d, hours: 5, dir: "out" });
      if (d % 2 === 0 || d % 3 === 0) items.push({ code: b[0], content: b[1], amount: b[2], days: d, hours: 11, dir: "out" });
    }
    // Khoản thu nằm trong tháng hiện tại để Đánh giá nhanh tính được "thu − chi trong tháng"
    const incomeDays = Math.max(0, Math.min(13, vnToday().d - 1));
    items.push({ code: "income", content: "BO ME GUI TIEN THANG", amount: 4_000_000, days: incomeDays, hours: 2, dir: "in" });
    items.push({ code: "income", content: "LUONG LAM THEM QUAN CAFE", amount: 1_500_000, days: Math.floor(incomeDays / 2), hours: 3, dir: "in" });
    const { rowCount } = await db.query(
      `insert into transactions (user_id, source, external_id, direction, amount, occurred_at, raw_content, category_id, category_confirmed)
       select $1, 'demo', gen_random_uuid()::text, x.dir, x.amount, now() - make_interval(days => x.days, hours => x.hours),
              x.content, c.id, true
       from jsonb_to_recordset($2::jsonb) as x(code text, content text, amount bigint, days int, hours int, dir text)
       join categories c on c.code = x.code`,
      [uid(req), JSON.stringify(items)],
    );
    // Chưa có ngân sách tháng này → đặt ngân sách mẫu để Dashboard có số
    await db.query(
      `insert into budgets (user_id, month, category_id, amount, is_essential)
       select $1, $2, c.id, x.amount, x.essential
       from (values (null, 4000000, false), ('food', 1800000, true), ('rent', 1000000, true), ('transport', 400000, true),
                    ('study', 200000, true), ('shopping', 300000, false), ('fun', 300000, false)) as x(code, amount, essential)
       left join categories c on c.code = x.code
       where not exists (select 1 from budgets where user_id = $1 and month = $2)`,
      [uid(req), monthStart()],
    );
    return { inserted: rowCount };
  });

  app.delete("/api/demo/transactions", async (req) => {
    const { rowCount } = await db.query("delete from transactions where user_id = $1 and source = 'demo'", [uid(req)]);
    return { deleted: rowCount };
  });
}

// [nhóm, nội dung chuyển khoản, số tiền] — 5 dòng đầu là ăn uống
const SEED = [
  ["food", "THANH TOAN QR TOCOTOCO", 35000],
  ["food", "COM TAM SUON BI CHA", 40000],
  ["food", "GRABFOOD ORDER", 65000],
  ["food", "HIGHLANDS COFFEE", 45000],
  ["food", "BANH MI HUYNH HOA", 25000],
  ["transport", "GRAB*TRIP", 42000],
  ["transport", "XANG PETROLIMEX", 60000],
  ["shopping", "SHOPEE PAY", 159000],
  ["fun", "CGV CINEMA", 90000],
  ["study", "PHOTO TAI LIEU", 15000],
] as const;
