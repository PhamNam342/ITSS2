import { test } from "node:test";
import assert from "node:assert/strict";
import { computeSummary, daysLeft, quickCheck, shouldSuggest, vnToday } from "../src/budget.ts";

test("quickCheck: 3 mức và nguồn số tiền hiện có", () => {
  const budgets = [
    { category_id: null, amount: 4_000_000, is_essential: false },
    { category_id: 1, amount: 2_000_000, is_essential: true },
    { category_id: 5, amount: 500_000, is_essential: false },
  ];
  const s = computeSummary(budgets, new Map([[1, 1_000_000], [5, 200_000]]), 10); // essential_left = 1.000.000
  assert.equal(quickCheck(s, 3_000_000, 0).level, "light");                       // (3tr − 1tr)/10 = 200k/ngày
  assert.equal(quickCheck(s, 1_300_000, 0).level, "medium");                       // 30k/ngày
  assert.equal(quickCheck(s, 900_000, 0).level, "support");                        // không đủ cho khoản cần thiết
  const fromMonth = quickCheck(s, null, 5_000_000);
  assert.deepEqual([fromMonth.basis, fromMonth.current], ["month", 3_800_000]);    // 5tr − 1,2tr đã chi
  const fromBudget = quickCheck(s, null, 0);
  assert.deepEqual([fromBudget.basis, fromBudget.current], ["budget", 2_800_000]);
  assert.deepEqual(fromBudget.adjustable.map((c) => c.category_id), [5]);          // chỉ nhóm không cần thiết
  assert.equal(quickCheck(s, 900_000, 0).per_day, 0);                             // không hiện số âm
});

test("shouldSuggest: khoản lớn, bất thường, vừa vượt ngân sách", () => {
  const budgets = [{ category_id: null, amount: 3_000_000, is_essential: false }];
  const ok = computeSummary(budgets, new Map([[1, 1_000_000]]), 10);
  assert.equal(shouldSuggest(600_000, ok, 50_000, 10, true), "big_expense");      // ≥ 20% ngân sách tháng
  assert.equal(shouldSuggest(200_000, ok, 50_000, 10, true), "unusual");          // ≥ 3× trung bình
  assert.equal(shouldSuggest(200_000, ok, 50_000, 3, true), null);                // < 5 giao dịch: chưa xét
  const over = computeSummary(budgets, new Map([[1, 3_100_000]]), 10);
  assert.equal(shouldSuggest(150_000, over, 500_000, 10, true), "over_budget");   // khoản này làm vượt
  assert.equal(shouldSuggest(50_000, over, 500_000, 10, true), null);             // đã vượt từ trước
});

test("vnToday: 23:30 ngày 30/11 giờ VN vẫn là tháng 11, 00:30 đã sang 1/12", () => {
  assert.deepEqual(vnToday(new Date("2026-11-30T16:30:00Z")), { y: 2026, m: 11, d: 30 });
  assert.deepEqual(vnToday(new Date("2026-11-30T17:30:00Z")), { y: 2026, m: 12, d: 1 });
});

test("daysLeft: tới ngày nhận tiền kế tiếp, không bao giờ 0", () => {
  assert.equal(daysLeft({ y: 2026, m: 11, d: 17 }, 1), 14);    // → 1/12
  assert.equal(daysLeft({ y: 2026, m: 11, d: 17 }, 17), 30);   // hôm nay nhận tiền → 17/12
  assert.equal(daysLeft({ y: 2026, m: 11, d: 17 }, 31), 13);   // tháng 11 chỉ có 30 ngày → 30/11
  assert.equal(daysLeft({ y: 2026, m: 11, d: 30 }, 31), 31);   // → 31/12
  assert.equal(daysLeft({ y: 2026, m: 12, d: 31 }, 5), 5);     // qua năm → 5/1/2027
  assert.equal(daysLeft({ y: 2027, m: 2, d: 27 }, 30), 1);     // tháng 2 → 28/2
});

test("computeSummary: an toàn mỗi ngày trừ phần cần thiết còn lại", () => {
  const budgets = [
    { category_id: null, amount: 3_000_000, is_essential: false },
    { category_id: 1, amount: 1_500_000, is_essential: true },   // ăn uống
    { category_id: 5, amount: 500_000, is_essential: false },    // mua sắm
  ];
  const s = computeSummary(budgets, new Map([[1, 500_000], [5, 700_000], [8, 100_000]]), 10);
  assert.equal(s.spent_month, 1_300_000);
  assert.equal(s.remaining_month, 1_700_000);
  assert.equal(s.essential_left, 1_000_000);
  assert.equal(s.safe_per_day, 70_000);                          // (1.700.000 − 1.000.000) / 10
  assert.deepEqual(s.categories.map((c) => c.category_id), [1, 5, 8]); // nhóm chưa đặt ngân sách vẫn hiện
  assert.equal(s.categories[1].remaining, -200_000);

  const over = computeSummary(budgets, new Map([[5, 3_500_000]]), 10);
  assert.equal(over.safe_per_day, 0);                            // vượt ngân sách → 0, không âm
});
