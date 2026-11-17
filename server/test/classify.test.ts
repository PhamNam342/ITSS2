import { test } from "node:test";
import assert from "node:assert/strict";
import { KEYWORDS, classify, learnPattern } from "../src/classify.ts";

const ID: Record<string, number> = { food: 1, rent: 2, transport: 3, study: 4, shopping: 5, fun: 6, topup: 7 };
const dict = Object.entries(KEYWORDS).flatMap(([code, ps]) => ps.map((pattern) => ({ pattern, category_id: ID[code] })));
const c = (text: string, rules = []) => classify(text, rules, dict);

test("phân loại theo từ điển, so nguyên token", () => {
  assert.equal(c("THANH TOAN QR HIGHLANDS"), ID.food);
  assert.equal(c("GRAB*TRIP"), ID.transport);
  assert.equal(c("GRAB FOOD 123"), ID.food);            // cụm 2 token thắng "grab"
  assert.equal(c("SHOPEE PAY"), ID.shopping);
  assert.equal(c("Trà sữa Phúc Long"), ID.food);        // có dấu vẫn khớp
  assert.equal(c("COMBO SINH NHAT"), null);             // "com" không khớp "combo"
  assert.equal(c("NGUYEN VAN BE CK"), null);            // "be" đứng riêng không còn trong từ điển
  assert.equal(c("CHUYEN TIEN SUA MAY TINH"), null);
});

test("quy tắc người dùng thắng từ điển", () => {
  const rules = [{ pattern: "sua may tinh", category_id: ID.study }, { pattern: "grab", category_id: ID.fun }];
  assert.equal(c("CHUYEN TIEN SUA MAY TINH", rules as never), ID.study);
  assert.equal(c("GRAB*TRIP", rules as never), ID.fun);
});

test("learnPattern bỏ từ chung chung, mã, số; quá ngắn thì không học", () => {
  assert.equal(learnPattern("THANH TOAN QR TOCOTOCO"), "tocotoco");
  assert.equal(learnPattern("CHUYEN TIEN SUA MAY TINH FT26321123"), "sua may tinh");
  assert.equal(learnPattern("THANH TOAN QR 123456"), null);
  assert.equal(learnPattern("CK BE"), null);
  assert.equal(learnPattern(null), null);
});
