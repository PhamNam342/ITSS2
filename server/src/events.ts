import type { OutgoingHttpHeaders, ServerResponse } from "node:http";
import type { FastifyInstance } from "fastify";
import { requireUser } from "./auth.ts";

// SSE (spec 7.3). ponytail: chỉ đúng với 1 instance api; nhiều instance → Postgres LISTEN/NOTIFY.
const clients = new Map<string, Set<ServerResponse>>();

export function emit(userId: string, event: string, data: unknown) {
  for (const res of clients.get(userId) ?? []) res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

export async function eventRoutes(app: FastifyInstance) {
  app.get("/api/events", { preHandler: requireUser }, (req, reply) => {
    const userId = req.user!.id;
    reply.hijack(); // tự ghi stream, Fastify không đóng response
    const res = reply.raw;
    res.writeHead(200, {
      ...(reply.getHeaders() as OutgoingHttpHeaders), // giữ header CORS của môi trường dev
      "content-type": "text/event-stream",
      "cache-control": "no-store",
      connection: "keep-alive",
    });
    res.write(": connected\n\n");
    const set = clients.get(userId) ?? new Set();
    clients.set(userId, set.add(res));
    const ping = setInterval(() => res.write(": ping\n\n"), 30_000); // Cloudflare cắt kết nối rảnh ~100s
    req.raw.on("close", () => {
      clearInterval(ping);
      set.delete(res);
      if (set.size === 0) clients.delete(userId);
    });
  });
}
