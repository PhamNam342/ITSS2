import pg from "pg";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";

export const db = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 10 });

// Chạy các file migrations/*.sql chưa chạy, theo thứ tự tên, mỗi file một transaction (spec 6.6).
// ponytail: chỉ đúng với 1 instance api; nhiều instance thì bọc bằng pg_advisory_lock.
export async function migrate(dir: string) {
  await db.query(
    "create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())",
  );
  const done = new Set((await db.query("select name from schema_migrations")).rows.map((r) => r.name));
  const files = (await readdir(dir)).filter((f) => f.endsWith(".sql")).sort();
  for (const f of files) {
    if (done.has(f)) continue;
    const sql = await readFile(join(dir, f), "utf8");
    const c = await db.connect();
    try {
      await c.query("begin");
      await c.query(sql);
      await c.query("insert into schema_migrations (name) values ($1)", [f]);
      await c.query("commit");
    } catch (e) {
      await c.query("rollback");
      throw new Error(`migration ${f} lỗi: ${(e as Error).message}`);
    } finally {
      c.release();
    }
  }
}
