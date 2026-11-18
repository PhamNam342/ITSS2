// Đọc email "Biên lai chuyển tiền qua tài khoản" của VCB Digibank (Sprint 5, đường B). Hàm thuần → test không cần DB.
// Mỗi trường trong email là 3 dòng: nhãn tiếng Việt, nhãn tiếng Anh, giá trị.
import { tokens } from "./classify.ts";

export type VcbTx = {
  direction: "out"; amount: number; occurred_at: string; ref: string;
  content: string; counterparty: string | null; self: boolean; account_last4: string | null;
};

const ENTITIES: Record<string, string> = { nbsp: " ", amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" };

/** HTML → các dòng chữ (mỗi ô bảng / đoạn một dòng) */
export function htmlLines(html: string): string[] {
  return html
    .replace(/<(style|script|head)[\s\S]*?<\/\1>/gi, " ")
    .replace(/\s+/g, " ")
    .replace(/<(br|\/?(tr|td|th|p|div|h\d|li|table))\b[^>]*>/gi, "\n")
    .replace(/<[^>]+>/g, " ")
    .replace(/&(#x?[0-9a-f]+|\w+);/gi, (m, e: string) =>
      e[0] === "#" ? String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : +e.slice(1))
        : ENTITIES[e.toLowerCase()] ?? m)
    .split("\n").map((s) => s.replace(/\s+/g, " ").trim()).filter(Boolean);
}

export function parseVcb(html: string): VcbTx | null {
  const lines = htmlLines(html);
  if (!lines.includes("Biên lai chuyển tiền qua tài khoản")) return null;
  const field = (label: string) => {
    const i = lines.indexOf(label);
    return i >= 0 ? lines[i + 2] ?? null : null;
  };
  const amount = field("Số tiền")?.match(/^(\d{1,3}(?:,\d{3})*) VND$/);   // "1,000,000 VND"
  const at = field("Ngày, giờ giao dịch")?.match(/(\d{1,2}):(\d{2})(?::(\d{2}))?.*?(\d{1,2})\/(\d{1,2})\/(\d{4})/);
  const ref = field("Số lệnh giao dịch");
  if (!amount || !at || !ref) return null;
  const p2 = (s: string | undefined) => (s ?? "0").padStart(2, "0");
  const from = field("Tên người chuyển tiền"), to = field("Tên người hưởng");
  return {
    direction: "out",
    amount: Number(amount[1].replaceAll(",", "")),
    occurred_at: `${at[6]}-${p2(at[5])}-${p2(at[4])}T${p2(at[1])}:${at[2]}:${p2(at[3])}+07:00`,
    ref,
    content: field("Nội dung chuyển tiền") ?? "",
    counterparty: to,
    // Cùng tên (bỏ dấu, không phân biệt hoa thường) → chuyển cho chính mình
    self: !!from && !!to && tokens(from).join(" ") === tokens(to).join(" "),
    account_last4: field("Tài khoản nguồn")?.replace(/\D/g, "").slice(-4) || null,
  };
}
