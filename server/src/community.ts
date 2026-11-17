import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import { db } from "./db.ts";
import { requireUser } from "./auth.ts";
import { checkContent } from "./moderation.ts";

// Cộng đồng "Đồng cảnh ngộ" (spec 10). Chỉ đọc qua view public_posts / public_solutions → không response nào có author_id.
const NOT_FOUND = { error: "not_found", message: "Không tìm thấy bài này, có thể đã bị ẩn." };
const idParam = { type: "object", required: ["id"], properties: { id: { type: "string", format: "uuid" } } };
const enumOf = (...v: string[]) => ({ enum: v });
const DIFFICULTY = enumOf("unexpected_expense", "over_budget", "income_delay", "other");
const EXPENSE = enumOf("medical", "device_broken", "social", "tuition", "other");
const AMOUNT = enumOf("<200k", "200k-500k", "500k-1tr", ">1tr");
const NEED = enumOf("meal_ideas", "budget_adjust", "side_job", "emotional", "other");
const TAG = enumOf("cheap_meal", "adjust_plan", "side_job", "mindset");

// Cột giống hệt view public_posts (không có author_id) + status + is_mine (tính ở server, không lộ tác giả).
// Người khác chỉ thấy bài 'visible'; tác giả thấy thêm bài của mình đang tạm ẩn chờ kiểm duyệt (spec 6.4).
const POST_SELECT = `select p.id, u.anon_alias, p.difficulty_type, p.expense_type, p.amount_range, p.need, p.body,
    p.created_at, p.status, (p.author_id = $1) as is_mine,
    (select count(*)::int from solutions s where s.post_id = p.id and s.status = 'visible') as solution_count
  from posts p join users u on u.id = p.author_id
  where (p.status = 'visible' or (p.author_id = $1 and p.status = 'hidden'))`;
const SOLUTION_SELECT = `select v.*, (s.author_id = $1) as is_mine, f.helpful as my_helpful, f.applied_result as my_result
  from public_solutions v join solutions s on s.id = v.id
  left join solution_feedback f on f.solution_id = v.id and f.user_id = $1`;

function blocked(reply: FastifyReply, text: string) {
  const reason = checkContent(text);
  return reason ? reply.code(422).send({ error: "content_blocked", message: reason }) : null;
}

const uid = (req: FastifyRequest) => req.user!.id;

export async function communityRoutes(app: FastifyInstance) {
  app.addHook("preHandler", requireUser);

  app.get<{ Querystring: { difficulty_type?: string; amount_range?: string; need?: string; mine?: boolean; before?: string } }>(
    "/api/community/posts", {
      schema: {
        querystring: {
          type: "object",
          properties: {
            difficulty_type: DIFFICULTY, amount_range: AMOUNT, need: NEED, mine: { type: "boolean" },
            before: { type: "string", format: "date-time" },
          },
        },
      },
    }, async (req) => {
      const q = req.query;
      return (await db.query(
        `${POST_SELECT}
           and ($2::text is null or p.difficulty_type = $2) and ($3::text is null or p.amount_range = $3)
           and ($4::text is null or p.need = $4) and (not $5 or p.author_id = $1)
           and ($6::timestamptz is null or p.created_at < $6)
         order by p.created_at desc limit 30`,
        [uid(req), q.difficulty_type ?? null, q.amount_range ?? null, q.need ?? null, q.mine ?? false, q.before ?? null],
      )).rows;
    });

  app.get<{ Params: { id: string } }>("/api/community/posts/:id", { schema: { params: idParam } }, async (req, reply) => {
    const [post, solutions] = await Promise.all([
      db.query(`${POST_SELECT} and p.id = $2`, [uid(req), req.params.id]),
      db.query(`${SOLUTION_SELECT} where v.post_id = $2 order by v.helpful_count desc, v.created_at`, [uid(req), req.params.id]),
    ]);
    return post.rows[0] ? { ...post.rows[0], solutions: solutions.rows } : reply.code(404).send(NOT_FOUND);
  });

  app.post<{ Body: { difficulty_type: string; expense_type?: string; amount_range?: string; need: string; body: string } }>(
    "/api/community/posts", {
      schema: {
        body: {
          type: "object", required: ["difficulty_type", "need", "body"], additionalProperties: false,
          properties: {
            difficulty_type: DIFFICULTY, expense_type: EXPENSE, amount_range: AMOUNT, need: NEED,
            body: { type: "string", minLength: 20, maxLength: 1000 },
          },
        },
      },
    }, async (req, reply) => {
      const b = req.body;
      if (blocked(reply, b.body)) return reply;
      const { rows } = await db.query(
        `insert into posts (author_id, difficulty_type, expense_type, amount_range, need, body)
         values ($1, $2, $3, $4, $5, $6) returning id`,
        [uid(req), b.difficulty_type, b.expense_type ?? null, b.amount_range ?? null, b.need, b.body.trim()],
      );
      return reply.code(201).send(rows[0]);
    });

  // Tác giả chỉ sửa được nội dung; trạng thái (ẩn/gỡ) chỉ admin đổi (spec 6.4)
  app.patch<{ Params: { id: string }; Body: { body: string } }>("/api/community/posts/:id", {
    schema: {
      params: idParam,
      body: { type: "object", required: ["body"], properties: { body: { type: "string", minLength: 20, maxLength: 1000 } } },
    },
  }, async (req, reply) => {
    if (blocked(reply, req.body.body)) return reply;
    const { rowCount } = await db.query("update posts set body = $3 where id = $1 and author_id = $2",
      [req.params.id, uid(req), req.body.body.trim()]);
    return rowCount ? { ok: true } : reply.code(404).send(NOT_FOUND);
  });

  app.delete<{ Params: { id: string } }>("/api/community/posts/:id", { schema: { params: idParam } }, async (req, reply) => {
    const { rowCount } = await db.query("delete from posts where id = $1 and author_id = $2", [req.params.id, uid(req)]);
    return rowCount ? { ok: true } : reply.code(404).send(NOT_FOUND);
  });

  app.post<{ Body: { post_id?: string | null; tag: string; body: string } }>("/api/community/solutions", {
    schema: {
      body: {
        type: "object", required: ["tag", "body"], additionalProperties: false,
        properties: {
          post_id: { type: ["string", "null"], format: "uuid" }, tag: TAG,
          body: { type: "string", minLength: 10, maxLength: 1000 },
        },
      },
    },
  }, async (req, reply) => {
    const b = req.body;
    if (blocked(reply, b.body)) return reply;
    // chỉ trả lời được bài đang hiển thị
    const { rows } = await db.query(
      `insert into solutions (post_id, author_id, tag, body)
       select $1, $2, $3, $4 where $1::uuid is null or exists (select 1 from public_posts where id = $1)
       returning id`,
      [b.post_id ?? null, uid(req), b.tag, b.body.trim()],
    );
    return rows[0] ? reply.code(201).send(rows[0]) : reply.code(404).send(NOT_FOUND);
  });

  app.get("/api/community/tips", async (req) =>
    (await db.query(`${SOLUTION_SELECT} where v.post_id is null order by v.helpful_count desc, v.created_at desc limit 30`,
      [uid(req)])).rows);

  app.put<{ Params: { id: string }; Body: { helpful: boolean; applied_result?: string | null; comment?: string | null } }>(
    "/api/community/solutions/:id/feedback", {
      schema: {
        params: idParam,
        body: {
          type: "object", required: ["helpful"], additionalProperties: false,
          properties: {
            helpful: { type: "boolean" },
            applied_result: { anyOf: [enumOf("worked", "partly", "not_worked"), { type: "null" }] },
            comment: { type: ["string", "null"], maxLength: 500 },
          },
        },
      },
    }, async (req, reply) => {
      const b = req.body;
      const { rowCount } = await db.query(
        `insert into solution_feedback (solution_id, user_id, helpful, applied_result, comment)
         select $1, $2, $3, $4, $5 where exists (select 1 from public_solutions where id = $1)
         on conflict (solution_id, user_id) do update set helpful = excluded.helpful,
           applied_result = coalesce(excluded.applied_result, solution_feedback.applied_result),
           comment = coalesce(excluded.comment, solution_feedback.comment)`,
        [req.params.id, uid(req), b.helpful, b.applied_result ?? null, b.comment ?? null],
      );
      return rowCount ? { ok: true } : reply.code(404).send(NOT_FOUND);
    });

  app.post<{ Body: { target_type: "post" | "solution"; target_id: string; reason: string; detail?: string } }>(
    "/api/community/reports", {
      schema: {
        body: {
          type: "object", required: ["target_type", "target_id", "reason"], additionalProperties: false,
          properties: {
            target_type: enumOf("post", "solution"), target_id: { type: "string", format: "uuid" },
            reason: enumOf("scam_loan", "spam", "offensive", "personal_info", "other"),
            detail: { type: "string", maxLength: 500 },
          },
        },
      },
    }, async (req, reply) => {
      const b = req.body;
      const table = b.target_type === "post" ? "posts" : "solutions";
      const exists = await db.query(`select 1 from ${table} where id = $1`, [b.target_id]);
      if (!exists.rowCount) return reply.code(404).send(NOT_FOUND);
      // trùng (đã báo cáo rồi) → vẫn 200, không báo lỗi. ≥ 3 báo cáo mở → trigger tự ẩn (spec 6.5)
      await db.query(
        `insert into reports (reporter_id, target_type, target_id, reason, detail) values ($1, $2, $3, $4, $5)
         on conflict (reporter_id, target_type, target_id) do nothing`,
        [uid(req), b.target_type, b.target_id, b.reason, b.detail ?? null],
      );
      return { ok: true };
    });

  // ===== Kiểm duyệt (spec 10.3) =====
  const requireAdmin = async (req: FastifyRequest, reply: FastifyReply) => {
    if (req.user?.role !== "admin") return reply.code(403).send({ error: "forbidden", message: "Chỉ người kiểm duyệt mới vào được." });
  };

  app.get("/api/admin/reports", { preHandler: requireAdmin }, async () =>
    (await db.query(
      `select r.target_type, r.target_id, count(*)::int as reports, array_agg(distinct r.reason) as reasons,
              max(r.created_at) as last_at, coalesce(p.body, s.body) as body, coalesce(p.status, s.status) as status
       from reports r
       left join posts p on r.target_type = 'post' and p.id = r.target_id
       left join solutions s on r.target_type = 'solution' and s.id = r.target_id
       where r.status = 'open'
       group by r.target_type, r.target_id, p.body, s.body, p.status, s.status
       order by count(*) desc, max(r.created_at) desc`,
    )).rows);

  app.post<{ Params: { type: "post" | "solution"; id: string; action: "restore" | "remove" } }>(
    "/api/admin/:type/:id/:action", {
      preHandler: requireAdmin,
      schema: {
        params: {
          type: "object", required: ["type", "id", "action"],
          properties: { type: enumOf("post", "solution"), id: { type: "string", format: "uuid" }, action: enumOf("restore", "remove") },
        },
      },
    }, async (req, reply) => {
      const { type, id, action } = req.params;
      const table = type === "post" ? "posts" : "solutions";
      const c = await db.connect();
      try {
        await c.query("begin");
        const { rowCount } = await c.query(`update ${table} set status = $2 where id = $1`,
          [id, action === "restore" ? "visible" : "removed"]);
        // Khôi phục → đóng các báo cáo cũ, nếu không báo cáo kế tiếp sẽ ẩn bài lại ngay (spec 6.5)
        await c.query("update reports set status = $3 where target_type = $1 and target_id = $2 and status = 'open'",
          [type, id, action === "restore" ? "dismissed" : "resolved"]);
        await c.query("commit");
        return rowCount ? { ok: true } : reply.code(404).send(NOT_FOUND);
      } catch (e) {
        await c.query("rollback");
        throw e;
      } finally {
        c.release();
      }
    });
}
