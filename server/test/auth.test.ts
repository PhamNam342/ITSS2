import { test } from "node:test";
import assert from "node:assert/strict";
import { clientKey, hashPassword, verifyPassword } from "../src/auth.ts";

test("rate-limit: IPv6 cùng dải /64 chung một khoá, IPv4 giữ nguyên", () => {
  const a = clientKey("2001:db8:6371:3f2:a1b2:c3d4:e5f6:1");
  assert.equal(a, "2001:db8:6371:3f2::/64");
  assert.equal(clientKey("2001:0db8:6371:03f2::99"), a);       // viết tắt / có số 0 đầu
  assert.notEqual(clientKey("2001:db8:6371:3f3::1"), a);       // dải /64 khác
  assert.equal(clientKey("2001:db8::1"), "2001:db8:0:0::/64");
  assert.equal(clientKey("203.0.113.7"), "203.0.113.7");
  assert.equal(clientKey("::ffff:172.18.0.1"), "::ffff:172.18.0.1");
});

test("mật khẩu: đúng thì qua, sai hoặc user không có mật khẩu thì không", async () => {
  const h = await hashPassword("matkhau123");
  assert.match(h, /^scrypt\$16384\$8\$1\$/);
  assert.equal(await verifyPassword("matkhau123", h), true);
  assert.equal(await verifyPassword("matkhau124", h), false);
  assert.equal(await verifyPassword("matkhau123", null), false);
});
