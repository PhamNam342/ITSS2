// Đặt lại mật khẩu cho người dùng quên (homelab chưa có email, spec 2.2 / 17.6).
//   docker compose exec api node src/tools/set-password.ts <email>
// In ra mật khẩu tạm ngẫu nhiên → đưa riêng cho người dùng; mọi phiên đăng nhập cũ bị đăng xuất.
import { randomBytes } from "node:crypto";
import { db } from "../db.ts";
import { hashPassword } from "../auth.ts";

const email = process.argv[2]?.trim().toLowerCase();
if (!email) {
  console.error("Cách dùng: node src/tools/set-password.ts <email>");
  process.exit(1);
}
const password = randomBytes(9).toString("base64url"); // 12 ký tự
const { rows } = await db.query("update users set password_hash = $2 where email = $1 returning id",
  [email, await hashPassword(password)]);
if (!rows[0]) {
  console.error(`Không có tài khoản ${email}`);
  process.exit(1);
}
await db.query("delete from sessions where user_id = $1", [rows[0].id]);
console.log(`Mật khẩu tạm của ${email}: ${password}`);
await db.end();
