import { test } from "node:test";
import assert from "node:assert/strict";
import { checkContent } from "../src/moderation.ts";

test("bộ lọc chặn số điện thoại, số tài khoản, link, quảng cáo vay", () => {
  assert.ok(checkContent("Ai cần thì gọi mình 0912 345 678 nhé các bạn"));
  assert.ok(checkContent("Chuyển khoản vào 1903.6688.123 giúp mình"));
  assert.ok(checkContent("Xem thêm ở https://example.com mấy bạn ơi"));
  assert.ok(checkContent("Vào trang vaytien.xyz là có ngay"));
  assert.ok(checkContent("Bên mình hỗ trợ VAY ONLINE giải ngân trong ngày"));
  assert.ok(checkContent("Bốc họ lãi suất thấp, không thẩm định"));
});

test("bộ lọc không chặn bài bình thường", () => {
  assert.equal(checkContent("Tháng này xe hỏng mất 800k, mình nấu cơm mang đi học 2 tuần thì ổn lại."), null);
  assert.equal(checkContent("Mình làm thêm ở quán cà phê 4 buổi/tuần, mỗi buổi 25k/giờ."), null);
  assert.equal(checkContent("Năm 2026 mình học năm 3, tiền nhà 1.500.000đ/tháng"), null); // số tiền có dấu chấm không phải SĐT
});
