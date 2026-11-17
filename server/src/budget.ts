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

export type Summary = ReturnType<typeof computeSummary>;

/**
 * Đánh giá nhanh (spec 9.3). "Số tiền hiện có": số dư ngân hàng mới nhất nếu có, không thì
 * thu − chi trong tháng, không có khoản thu nào thì lấy phần ngân sách còn lại.
 */
export function quickCheck(s: Summary, balance: number | null, incomeMonth: number) {
  const [current, basis] =
    balance !== null ? [balance, "bank"] as const
    : incomeMonth > 0 ? [incomeMonth - s.spent_month, "month"] as const
    : [s.remaining_month, "budget"] as const;
  const available = current - s.essential_left;
  const perDay = Math.floor(available / s.days_left);
  return {
    current, basis,
    essential_left: s.essential_left,
    available,
    days_left: s.days_left,
    per_day: Math.max(0, perDay),
    level: available <= 0 ? "support" : perDay >= 50_000 ? "light" : "medium",
    // Nhóm "có thể điều chỉnh" còn dư → slider giảm (spec 9.3)
    adjustable: s.categories.filter((c) => !c.is_essential && c.budget > 0 && c.remaining > 0),
  };
}

/** "2026-11-16" + 7 → "2026-11-23" */
export const addDays = (ymd: string, n: number) =>
  new Date(Date.parse(`${ymd}T00:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);

export type WeekRow = { week: string; category_id: number | null; spent: number };

/**
 * Tổng kết tuần trước (spec 11.4) – tính thẳng từ giao dịch, không cron, không bảng lưu.
 * thisWeek: thứ Hai tuần hiện tại (giờ VN). monthBudget: "2026-11" → tổng ngân sách tháng.
 * classified: số lần người dùng tự chọn nhóm (tổng hits của merchant_rules).
 */
export function weeklyReview(o: {
  thisWeek: string; rows: WeekRow[]; monthBudget: Map<string, number>; classified: number; names: Map<number, string>;
}) {
  const last = addDays(o.thisWeek, -7), prev = addDays(o.thisWeek, -14);
  const total = (w: string) => o.rows.filter((r) => r.week === w).reduce((a, r) => a + r.spent, 0);
  const within = (w: string) => {
    const b = o.monthBudget.get(w.slice(0, 7));
    const [y, m] = w.split("-").map(Number);
    return b === undefined ? null : total(w) <= (b * 7) / daysInMonth(y, m); // ngân sách tháng chia theo tuần
  };
  let streak = 0;
  for (let w = last; streak < 52 && within(w) === true; w = addDays(w, -7)) streak++;

  const ids = new Set(o.rows.filter((r) => r.week === last || r.week === prev).map((r) => r.category_id));
  const sumOf = (w: string, id: number | null) =>
    o.rows.filter((r) => r.week === w && r.category_id === id).reduce((a, r) => a + r.spent, 0);
  const categories = [...ids].map((id) => ({ category_id: id, spent: sumOf(last, id), prev: sumOf(prev, id) }))
    .sort((a, b) => b.spent - a.spent);

  // Chỉ điểm tích cực, không chê, không số âm (spec 11.4, 13)
  const highlights: string[] = [];
  for (const c of categories
    .filter((c) => c.category_id !== null && c.prev > 0 && c.spent < c.prev * 0.9)
    .map((c) => ({ ...c, pct: Math.round(((c.prev - c.spent) / c.prev) * 100) }))
    .sort((a, b) => b.pct - a.pct).slice(0, 2))
    highlights.push(`Tuần qua bạn chi ${o.names.get(c.category_id!) ?? "một nhóm"} ít hơn tuần trước đó ${c.pct}%.`);
  const t = total(last), p = total(prev);
  if (p > 0 && t < p) highlights.push(`Tổng chi tuần qua ít hơn tuần trước đó ${Math.round(((p - t) / p) * 100)}%.`);
  if (streak > 0) highlights.push(`Bạn giữ trong ngân sách ${streak} tuần liên tiếp 🌱`);
  if (o.classified > 0) highlights.push(`Bạn đã tự phân loại ${o.classified} khoản – app hiểu bạn hơn rồi.`);
  if (within(last) === false || highlights.length === 0)
    highlights.push("Tuần qua hơi nhiều khoản phát sinh. Tuần mới, bắt đầu lại nhẹ nhàng nhé.");

  const badge = (code: string, label: string, earned: boolean) => ({ code, label, earned });
  return {
    week_start: last, week_end: addDays(last, 6),
    total_out: t, prev_total_out: p, within_budget: within(last), streak_weeks: streak,
    categories, highlights,
    badges: [
      badge("streak_1", "1 tuần trong ngân sách", streak >= 1),
      badge("streak_4", "4 tuần trong ngân sách", streak >= 4),
      badge("streak_8", "8 tuần trong ngân sách", streak >= 8),
      badge("classified_10", "Tự phân loại 10 khoản", o.classified >= 10),
      badge("classified_50", "Tự phân loại 50 khoản", o.classified >= 50),
    ],
  };
}

/** Có nên gợi ý mở Đánh giá nhanh sau một khoản chi không (spec 9.3) */
export function shouldSuggest(
  amount: number, s: Summary, avgOut: number | null, countOut: number, counted: boolean,
): "big_expense" | "unusual" | "over_budget" | null {
  if (s.budget_total > 0 && amount >= 0.2 * s.budget_total) return "big_expense";
  if (countOut >= 5 && avgOut !== null && amount >= 3 * avgOut) return "unusual";
  if (counted && s.budget_total > 0 && s.remaining_month < 0 && s.remaining_month + amount >= 0) return "over_budget";
  return null;
}

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
