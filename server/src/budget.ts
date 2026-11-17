// Tính ngân sách (spec 9.2). Hàm thuần, không đụng DB → test được không cần Postgres.
export const TZ = "Asia/Ho_Chi_Minh";

export type Ymd = { y: number; m: number; d: number };

/** Ngày hiện tại theo giờ Việt Nam (không phụ thuộc TZ của máy chạy). */
export function vnToday(now = new Date()): Ymd {
  const [y, m, d] = now.toLocaleDateString("en-CA", { timeZone: TZ }).split("-").map(Number);
  return { y, m, d };
}

/** "2026-11" */
export const monthOf = (t: Ymd) => `${t.y}-${String(t.m).padStart(2, "0")}`;

const daysInMonth = (y: number, m: number) => new Date(Date.UTC(y, m, 0)).getUTCDate();
const dayNumber = (y: number, m: number, d: number) => Date.UTC(y, m - 1, d) / 86_400_000;

/** Số ngày từ hôm nay tới ngày nhận tiền kế tiếp, tối thiểu 1 (không bao giờ chia cho 0). */
export function daysLeft(today: Ymd, incomeDay: number): number {
  const payThisMonth = Math.min(incomeDay, daysInMonth(today.y, today.m));
  let { y, m } = today;
  if (today.d >= payThisMonth) { // hôm nay hoặc đã qua ngày nhận tiền → kỳ sau
    m += 1;
    if (m === 13) { m = 1; y += 1; }
  }
  const next = dayNumber(y, m, Math.min(incomeDay, daysInMonth(y, m)));
  return Math.max(1, next - dayNumber(today.y, today.m, today.d));
}

export type BudgetRow = { category_id: number | null; amount: number; is_essential: boolean };

/** spent: category_id → tổng chi trong tháng (đã loại topup nếu user bật). */
export function computeSummary(budgets: BudgetRow[], spent: Map<number | null, number>, days: number) {
  const total = budgets.find((b) => b.category_id === null)?.amount ?? 0;
  const spentMonth = [...spent.values()].reduce((a, b) => a + b, 0);
  const ids = new Set<number>();
  for (const b of budgets) if (b.category_id !== null) ids.add(b.category_id);
  for (const id of spent.keys()) if (id !== null) ids.add(id);
  const categories = [...ids].sort((a, b) => a - b).map((id) => {
    const b = budgets.find((x) => x.category_id === id);
    const s = spent.get(id) ?? 0;
    const budget = b?.amount ?? 0;
    return { category_id: id, budget, spent: s, remaining: budget - s, is_essential: b?.is_essential ?? false };
  });
  const essentialLeft = categories
    .filter((c) => c.is_essential)
    .reduce((a, c) => a + Math.max(0, c.remaining), 0);
  const remaining = total - spentMonth;
  return {
    budget_total: total,
    spent_month: spentMonth,
    remaining_month: remaining,
    essential_left: essentialLeft,
    days_left: days,
    safe_per_day: Math.floor(Math.max(0, remaining - essentialLeft) / days),
    categories,
  };
}
