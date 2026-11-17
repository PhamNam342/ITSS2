// Phân loại giao dịch tự động (spec 9.1). Hàm thuần → test được không cần DB.

/** "THANH TOÁN QR Highlands*Coffee" → ["thanh","toan","qr","highlands","coffee"] */
export function tokens(s: string): string[] {
  return s.normalize("NFD").replace(/\p{M}/gu, "")
    .replace(/đ/g, "d").replace(/Đ/g, "D").toLowerCase()
    .split(/[^a-z0-9]+/).filter(Boolean);
}

/** Cụm token của pattern xuất hiện liên tiếp, nguyên vẹn trong nội dung */
function containsRun(hay: string[], needle: string[]): boolean {
  outer: for (let i = 0; i + needle.length <= hay.length; i++) {
    for (let j = 0; j < needle.length; j++) if (hay[i + j] !== needle[j]) continue outer;
    return true;
  }
  return false;
}

export type Rule = { pattern: string; category_id: number };

/** Ưu tiên: quy tắc người dùng → từ điển chung. Trong mỗi nguồn, cụm nhiều token hơn thắng. Không khớp → null. */
export function classify(text: string, userRules: Rule[], dictionary: Rule[]): number | null {
  const hay = tokens(text);
  for (const source of [userRules, dictionary]) {
    let best: { n: number; len: number; id: number } | null = null;
    for (const r of source) {
      const needle = tokens(r.pattern);
      if (needle.length === 0 || !containsRun(hay, needle)) continue;
      if (!best || needle.length > best.n || (needle.length === best.n && r.pattern.length > best.len))
        best = { n: needle.length, len: r.pattern.length, id: r.category_id };
    }
    if (best) return best.id;
  }
  return null;
}

// ponytail: từ điển hard-code + so token, đủ cho đồ án. Phân loại sai nhiều thì thêm pattern, chưa cần ML.
export const KEYWORDS: Record<string, string[]> = {
  food: ["highlands", "phuc long", "tra sua", "tocotoco", "com tam", "com ga", "quan com", "pho", "bun", "banh mi",
    "grabfood", "grab food", "shopeefood", "shopee food", "baemin", "circle k", "winmart", "bach hoa xanh"],
  transport: ["grab", "be bike", "be car", "xanh sm", "gojek", "xang", "petrolimex", "gui xe"],
  shopping: ["shopee", "lazada", "tiki", "tiktok shop"],
  rent: ["tien nha", "tien phong", "tien dien", "tien nuoc", "wifi", "internet"],
  study: ["hoc phi", "sach", "photo", "in tai lieu"],
  fun: ["cgv", "lotte cinema", "karaoke", "steam", "garena"],
  topup: ["nap momo", "momo", "zalopay", "nap vi"],
};

const STOP = new Set(["thanh", "toan", "qr", "chuyen", "tien", "ck", "tt", "gd", "giao", "dich", "nd", "noi", "dung"]);

/** Pattern để học khi người dùng tự đổi nhóm: bỏ từ chung chung, mã tham chiếu, số. Quá ngắn → null (không học). */
export function learnPattern(text: string | null): string | null {
  if (!text) return null;
  const kept = tokens(text).filter((t) => !STOP.has(t) && !/^\d+$/.test(t) && !/^ft\d/.test(t)).slice(0, 6);
  const p = kept.join(" ");
  return p.length >= 3 ? p : null;
}
