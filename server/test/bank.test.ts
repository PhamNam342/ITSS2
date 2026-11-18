import { test } from "node:test";
import assert from "node:assert/strict";
import { fromSepay } from "../src/bank.ts";

// Payload mẫu theo tài liệu SePay (developer.sepay.vn → Webhooks → Tích hợp)
const p = {
  id: 92704, gateway: "MBBank", transactionDate: "2026-11-14 17:30:05", accountNumber: "0123456789",
  content: "NGUYEN VAN AN chuyen tien", transferType: "in" as const, transferAmount: 1_000_000, accumulated: 5_250_000,
};

test("SePay → giao dịch: giờ VN, id gắn liên kết, số dư", () => {
  assert.deepEqual(fromSepay(p, "L1"), {
    direction: "in", amount: 1_000_000, occurred_at: "2026-11-14T17:30:05+07:00",
    external_id: "L1:92704", bank_account_id: "L1", balance_after: 5_250_000, raw_content: "NGUYEN VAN AN chuyen tien",
  });
  assert.equal(new Date(fromSepay(p, "L1").occurred_at).toISOString(), "2026-11-14T10:30:05.000Z");
});

test("SePay: không có số dư (0) → null; nội dung null → chuỗi rỗng", () => {
  const t = fromSepay({ ...p, transferType: "out", accumulated: 0, content: null }, "L2");
  assert.equal(t.direction, "out");
  assert.equal(t.balance_after, null);
  assert.equal(t.raw_content, "");
  assert.equal(t.external_id, "L2:92704");
});
