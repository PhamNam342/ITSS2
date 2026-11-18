import { containsRun, tokens } from "./classify.ts";

// Bộ lọc nội dung cộng đồng (spec 10.2). Chạy ở server: client có thể bỏ qua, server thì không.
const LOAN = ["vay nhanh", "vay online", "vay tien nhanh", "app vay", "boc ho", "giai ngan", "khong tham dinh",
  "khong the chap", "lai suat thap", "ho tro vay", "cam do"].map(tokens);

const LINK = /(https?:\/\/|www\.|\b[a-z0-9-]+\.(com|vn|net|org|io|me|xyz|top|info|site|link|online|shop|app)\b|t\.me\/|zalo\.me\/)/i;

/** null = cho đăng; có chuỗi = lý do bị chặn (câu nhẹ nhàng hiện cho người dùng) */
export function checkContent(text: string): string | null {
  // gộp số bị chia bởi dấu cách / chấm / gạch: "09 12.345 678" → "0912345678"
  const digits = text.replace(/(\d)[\s.\-]+(?=\d)/g, "$1");
  if (/\d{9,}/.test(digits))
    return "Bài có số điện thoại hoặc số tài khoản. Để giữ an toàn cho bạn, bỏ phần đó đi nhé.";
  if (LINK.test(text)) return "Cộng đồng chưa cho phép gắn đường link. Bạn kể bằng lời giúp mình nhé.";
  const t = tokens(text);
  if (LOAN.some((k) => containsRun(t, k)))
    return "Nội dung giống quảng cáo vay tiền. Cộng đồng không cho đăng để tránh lừa đảo.";
  return null;
}
