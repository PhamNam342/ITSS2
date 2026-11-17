import { test } from "node:test";
import assert from "node:assert/strict";
import { hashPassword, verifyPassword } from "../src/auth.ts";

test("mật khẩu: đúng thì qua, sai hoặc user không có mật khẩu thì không", async () => {
  const h = await hashPassword("matkhau123");
  assert.match(h, /^scrypt\$16384\$8\$1\$/);
  assert.equal(await verifyPassword("matkhau123", h), true);
  assert.equal(await verifyPassword("matkhau124", h), false);
  assert.equal(await verifyPassword("matkhau123", null), false);
});
