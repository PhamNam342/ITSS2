import Fastify from "fastify";
import cookie from "@fastify/cookie";
import rateLimit from "@fastify/rate-limit";
import fastifyStatic from "@fastify/static";
import { join } from "node:path";
import { db, migrate } from "./db.ts";
import { authRoutes, clientKey } from "./auth.ts";
import { eventRoutes } from "./events.ts";
import { moneyRoutes } from "./money.ts";
import { communityRoutes } from "./community.ts";

const dev = process.env.NODE_ENV === "development";
const app = Fastify({ logger: true });

app.removeContentTypeParser("text/plain"); // chỉ nhận JSON (spec 7, chống CSRF)
await app.register(cookie);
await app.register(rateLimit, {
  global: false,
  // Sau cloudflared mọi request đều từ 127.0.0.1 → đếm theo IP thật Cloudflare gửi kèm (spec 15)
  keyGenerator: (req) => clientKey((req.headers["cf-connecting-ip"] as string | undefined) ?? req.ip),
});

// Dev: cho `flutter run -d chrome` (khác cổng = khác origin) gọi API kèm cookie
if (dev) {
  app.addHook("onRequest", async (req, reply) => {
    const origin = req.headers.origin;
    if (!origin || !/^http:\/\/localhost:\d+$/.test(origin)) return;
    reply
      .header("access-control-allow-origin", origin)
      .header("access-control-allow-credentials", "true")
      .header("access-control-allow-headers", "content-type")
      .header("access-control-allow-methods", "GET,POST,PUT,PATCH,DELETE");
    if (req.method === "OPTIONS") return reply.code(204).send();
  });
}

app.addHook("onSend", async (req, reply) => {
  if (req.url.startsWith("/api/")) reply.header("cache-control", "no-store");
});

// Dữ liệu sai (schema, khoá ngoại, trùng, check constraint, uuid hỏng) → 400 với câu dễ hiểu
const BAD_DATA = new Set(["23503", "23505", "23514", "22P02"]);
app.setErrorHandler((err: { validation?: unknown; code?: string; statusCode?: number }, req, reply) => {
  if (err.validation || BAD_DATA.has(err.code ?? ""))
    return reply.code(400).send({ error: "bad_request", message: "Dữ liệu chưa hợp lệ, bạn kiểm tra lại nhé." });
  if (err.statusCode && err.statusCode < 500) return reply.send(err);
  req.log.error(err);
  return reply.code(500).send({ error: "server_error", message: "Có lỗi ở máy chủ, bạn thử lại sau nhé." });
});

app.get("/api/health", async () => {
  await db.query("select 1");
  return { ok: true };
});
await app.register(authRoutes);
await app.register(moneyRoutes);
await app.register(communityRoutes);
await app.register(eventRoutes);

// Flutter Web build. Mặc định "max-age=0" → trình duyệt luôn hỏi lại (ETag), deploy xong thấy bản mới ngay.
await app.register(fastifyStatic, { root: join(import.meta.dirname, "../public") });
app.setNotFoundHandler((req, reply) =>
  req.url.startsWith("/api/") || req.method !== "GET"
    ? reply.code(404).send({ error: "not_found", message: "Không tìm thấy." })
    : reply.sendFile("index.html"), // SPA fallback: F5 ở /community/post/123 không 404
);

await migrate(join(import.meta.dirname, "../migrations"));
await app.listen({ host: "0.0.0.0", port: 8080 });
