import Fastify from "fastify";
import cookie from "@fastify/cookie";
import rateLimit from "@fastify/rate-limit";
import fastifyStatic from "@fastify/static";
import { join } from "node:path";
import { db, migrate } from "./db.ts";
import { authRoutes, clientKey } from "./auth.ts";

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

app.get("/api/health", async () => {
  await db.query("select 1");
  return { ok: true };
});
await app.register(authRoutes);

// Flutter Web build. Mặc định "max-age=0" → trình duyệt luôn hỏi lại (ETag), deploy xong thấy bản mới ngay.
await app.register(fastifyStatic, { root: join(import.meta.dirname, "../public") });
app.setNotFoundHandler((req, reply) =>
  req.url.startsWith("/api/") || req.method !== "GET"
    ? reply.code(404).send({ error: "not_found", message: "Không tìm thấy." })
    : reply.sendFile("index.html"), // SPA fallback: F5 ở /community/post/123 không 404
);

await migrate(join(import.meta.dirname, "../migrations"));
await app.listen({ host: "0.0.0.0", port: 8080 });
