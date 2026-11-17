import { createHash, randomBytes, randomInt, scrypt, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import { db } from "./db.ts";

// ===== Mật khẩu: scrypt$N$r$p$salt$hash (spec 15) =====
const scryptAsync = promisify(scrypt) as (
  pw: string, salt: Buffer, len: number, opt: { N: number; r: number; p: number },
) => Promise<Buffer>;
const N = 16384, R = 8, P = 1, LEN = 64;

export async function hashPassword(pw: string): Promise<string> {
  const salt = randomBytes(16);
  const h = await scryptAsync(pw, salt, LEN, { N, r: R, p: P });
  return `scrypt$${N}$${R}$${P}$${salt.toString("base64")}$${h.toString("base64")}`;
}

// Hash giả để email không tồn tại vẫn tốn thời gian như email có thật (không dò được email qua thời gian phản hồi).
const DUMMY = `scrypt$${N}$${R}$${P}$${Buffer.alloc(16).toString("base64")}$${Buffer.alloc(LEN).toString("base64")}`;

export async function verifyPassword(pw: string, stored: string | null): Promise<boolean> {
  const [algo, n, r, p, salt, hash] = (stored ?? DUMMY).split("$");
  if (algo !== "scrypt") return false;
  const expected = Buffer.from(hash, "base64");
  const got = await scryptAsync(pw, Buffer.from(salt, "base64"), expected.length, { N: +n, r: +r, p: +p });
  return timingSafeEqual(got, expected) && stored !== null;
}

// ===== Phiên: token 32 byte trong cookie, DB chỉ giữ SHA-256 =====
const DAYS = 30;
const sha256 = (s: string) => createHash("sha256").update(s).digest();

async function newSession(userId: string): Promise<string> {
  const token = randomBytes(32).toString("base64url");
  await db.query(
    `insert into sessions (token_hash, user_id, expires_at) values ($1, $2, now() + interval '${DAYS} days')`,
    [sha256(token), userId],
  );
  return token;
}

export type User = {
  id: string; email: string; display_name: string | null; anon_alias: string; role: "user" | "admin";
  monthly_income_day: number; demo_mode: boolean; exclude_topup: boolean;
};
const USER_COLS = "u.id, u.email, u.display_name, u.anon_alias, u.role, u.monthly_income_day, u.demo_mode, u.exclude_topup";

// Trả user của phiên còn hạn và gia hạn trượt thêm 30 ngày.
async function sessionUser(token: string): Promise<User | null> {
  const { rows } = await db.query(
    `with s as (
       update sessions set expires_at = now() + interval '${DAYS} days'
       where token_hash = $1 and expires_at > now() returning user_id)
     select ${USER_COLS} from users u join s on s.user_id = u.id`,
    [sha256(token)],
  );
  return rows[0] ?? null;
}

declare module "fastify" {
  interface FastifyRequest { user: User | null }
}

// preHandler cho route cần đăng nhập
export async function requireUser(req: FastifyRequest, reply: FastifyReply) {
  const sid = req.cookies.sid;
  req.user = sid ? await sessionUser(sid) : null;
  if (!req.user) return reply.code(401).send({ error: "unauthorized", message: "Bạn cần đăng nhập lại nhé." });
}

// ===== Khoá rate-limit theo IP thật =====
// IPv6: mỗi nhà được cả dải /64 → gộp theo /64, nếu không đổi địa chỉ là lách được giới hạn.
export function clientKey(ip: string): string {
  if (!ip.includes(":") || ip.includes(".")) return ip; // IPv4 (kể cả dạng ::ffff:1.2.3.4)
  const [head, tail = ""] = ip.toLowerCase().split("::");
  const h = head ? head.split(":") : [];
  const t = tail ? tail.split(":") : [];
  const full = [...h, ...Array(8 - h.length - t.length).fill("0"), ...t];
  return full.slice(0, 4).map((x) => x.replace(/^0+(?=.)/, "")).join(":") + "::/64";
}

// ===== Tên ẩn danh: "Mèo Mướp #4821" =====
const ANIMALS = ["Mèo Mướp", "Cún Con", "Gấu Trúc", "Sóc Nâu", "Thỏ Trắng", "Cá Heo", "Chim Sẻ", "Rùa Con", "Hươu Sao", "Cáo Nhỏ"];
const randomAlias = () => `${ANIMALS[randomInt(ANIMALS.length)]} #${randomInt(1000, 10000)}`;

export async function authRoutes(app: FastifyInstance) {
  app.decorateRequest("user", null);
  const dev = process.env.NODE_ENV === "development";
  const setSid = (reply: FastifyReply, token: string) =>
    reply.setCookie("sid", token, {
      httpOnly: true, sameSite: "lax", secure: !dev, path: "/", maxAge: DAYS * 24 * 3600,
    });
  const limited = { rateLimit: { max: 10, timeWindow: "1 minute" } };

  app.post<{ Body: { email: string; password: string; display_name?: string } }>("/api/auth/register", {
    config: limited,
    schema: {
      body: {
        type: "object", required: ["email", "password"], additionalProperties: false,
        properties: {
          email: { type: "string", format: "email", maxLength: 254 },
          password: { type: "string", minLength: 8, maxLength: 200 },
          display_name: { type: "string", minLength: 1, maxLength: 50 },
        },
      },
    },
  }, async (req, reply) => {
    const email = req.body.email.trim().toLowerCase();
    const hash = await hashPassword(req.body.password);
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        const { rows } = await db.query(
          "insert into users (email, password_hash, display_name, anon_alias) values ($1, $2, $3, $4) returning id",
          [email, hash, req.body.display_name ?? null, randomAlias()],
        );
        setSid(reply, await newSession(rows[0].id));
        return reply.code(201).send({ ok: true });
      } catch (e) {
        const err = e as { code?: string; constraint?: string };
        if (err.code !== "23505") throw e;
        if (err.constraint === "users_email_key")
          return reply.code(409).send({ error: "email_taken", message: "Email này đã được dùng để đăng ký rồi." });
        // trùng anon_alias → thử tên khác
      }
    }
    throw new Error("không sinh được anon_alias");
  });

  app.post<{ Body: { email: string; password: string } }>("/api/auth/login", {
    config: limited,
    schema: {
      body: {
        type: "object", required: ["email", "password"],
        properties: { email: { type: "string", maxLength: 254 }, password: { type: "string", maxLength: 200 } },
      },
    },
  }, async (req, reply) => {
    const { rows } = await db.query("select id, password_hash from users where email = $1", [
      req.body.email.trim().toLowerCase(),
    ]);
    if (!(await verifyPassword(req.body.password, rows[0]?.password_hash ?? null)))
      return reply.code(401).send({ error: "invalid_credentials", message: "Email hoặc mật khẩu chưa đúng." });
    await db.query("delete from sessions where expires_at < now()");
    setSid(reply, await newSession(rows[0].id));
    return { ok: true };
  });

  app.post("/api/auth/logout", async (req, reply) => {
    if (req.cookies.sid) await db.query("delete from sessions where token_hash = $1", [sha256(req.cookies.sid)]);
    reply.clearCookie("sid", { path: "/" });
    return { ok: true };
  });

  app.get("/api/me", { preHandler: requireUser }, async (req) => req.user);

  // Chỉ các cột này; role không bao giờ sửa được qua API (spec 6.4)
  app.patch<{ Body: { display_name?: string | null; monthly_income_day?: number; demo_mode?: boolean; exclude_topup?: boolean } }>(
    "/api/me", {
      preHandler: requireUser,
      schema: {
        body: {
          type: "object", additionalProperties: false, minProperties: 1,
          properties: {
            display_name: { type: ["string", "null"], maxLength: 50 },
            monthly_income_day: { type: "integer", minimum: 1, maximum: 31 },
            demo_mode: { type: "boolean" },
            exclude_topup: { type: "boolean" },
          },
        },
      },
    }, async (req) => {
      const b = req.body;
      const { rows } = await db.query(
        `update users u set
           display_name = case when $2 then $3 else display_name end,
           monthly_income_day = coalesce($4, monthly_income_day),
           demo_mode = coalesce($5, demo_mode),
           exclude_topup = coalesce($6, exclude_topup)
         where id = $1 returning ${USER_COLS}`,
        [req.user!.id, "display_name" in b, b.display_name ?? null, b.monthly_income_day ?? null,
         b.demo_mode ?? null, b.exclude_topup ?? null],
      );
      return rows[0];
    });
}
