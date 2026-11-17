import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseVcb } from "../src/vcb.ts";

// Mẫu giả: HTML thật của VCB Digibank, đã thay tên, số tài khoản, số lệnh
const html = readFileSync(new URL("./fixtures/vcb-bien-lai.html", import.meta.url), "utf8");

test("đọc biên lai chuyển tiền VCB", () => {
  assert.deepEqual(parseVcb(html), {
    direction: "out",
    amount: 1_000_000,
    occurred_at: "2026-11-14T17:34:00+07:00",
    ref: "1235679001",
    content: "NGUYEN VAN AN chuyen tien",
    counterparty: "NGUYEN VAN AN",
    self: true,
    account_last4: "0112",
  });
});

test("người hưởng khác tên → không phải chuyển cho mình; có dấu vẫn so đúng", () => {
  assert.equal(parseVcb(html.replace(/(Beneficiary Name[\s\S]*?)NGUYEN VAN AN/, "$1TRAN THI BINH"))!.self, false);
  assert.equal(parseVcb(html.replace(/(Beneficiary Name[\s\S]*?)NGUYEN VAN AN/, "$1Nguyễn Văn An"))!.self, true);
});

test("email khác hoặc thiếu trường → null", () => {
  assert.equal(parseVcb("<p>Mã OTP của bạn là 123456</p>"), null);
  assert.equal(parseVcb(html.replace("1,000,000 VND", "một triệu")), null);
});
