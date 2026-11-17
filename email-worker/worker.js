// Cloudflare Email Worker (spec 8.5): nhận email biên lai Vietcombank mà Gmail của người dùng chuyển tiếp tới
// <token>@<mail-domain>, gửi nguyên văn MIME về server. Không chứa logic, server tự đọc và kiểm tra.
// Dán vào Workers & Pages → Create → Worker → Edit code. Biến (Settings → Variables and Secrets):
//   WEBHOOK_URL          = https://<domain>/api/webhooks/email
//   EMAIL_WEBHOOK_SECRET = (secret) cùng giá trị với EMAIL_WEBHOOK_SECRET trong .env của server
export default {
  async email(message, env) {
    // Chỉ nhận địa chỉ app cấp (32 ký tự hex); thư rác tới địa chỉ khác bị từ chối
    if (!/^[0-9a-f]{32}@/i.test(message.to) || message.rawSize > 1_000_000) {
      message.setReject("Unknown address");
      return;
    }
    const r = await fetch(env.WEBHOOK_URL, {
      method: "POST",
      body: message.raw,
      headers: {
        authorization: `Bearer ${env.EMAIL_WEBHOOK_SECRET}`,
        "content-type": "message/rfc822",
        "x-rcpt-to": message.to,
      },
    });
    if (!r.ok) throw new Error(`webhook ${r.status}`); // server lỗi/đang deploy → báo lỗi trong log Worker
  },
};
