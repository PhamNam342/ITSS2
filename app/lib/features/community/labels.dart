// Nhãn tiếng Việt cho các mã của cộng đồng (khớp check constraint trong 0001_schema.sql)
const difficultyLabels = {
  'unexpected_expense': 'Khoản chi bất ngờ',
  'over_budget': 'Vượt ngân sách',
  'income_delay': 'Tiền về chậm',
  'other': 'Khó khăn khác',
};

const expenseLabels = {
  'medical': 'Ốm đau, thuốc men',
  'device_broken': 'Hỏng xe / điện thoại / laptop',
  'social': 'Cưới hỏi, sinh nhật, bạn bè',
  'tuition': 'Học phí, tài liệu',
  'other': 'Khác',
};

const amountLabels = {
  '<200k': 'Dưới 200k',
  '200k-500k': '200k – 500k',
  '500k-1tr': '500k – 1 triệu',
  '>1tr': 'Trên 1 triệu',
};

const needLabels = {
  'meal_ideas': 'Gợi ý bữa ăn tiết kiệm',
  'budget_adjust': 'Cách chỉnh chi tiêu',
  'side_job': 'Việc làm thêm',
  'emotional': 'Cần được động viên',
  'other': 'Khác',
};

const tagLabels = {
  'cheap_meal': '🍚 Bữa ăn tiết kiệm',
  'adjust_plan': '📝 Điều chỉnh chi tiêu',
  'side_job': '💼 Làm thêm',
  'mindset': '💛 Tinh thần',
};

const reportLabels = {
  'scam_loan': 'Quảng cáo vay / lừa đảo',
  'spam': 'Spam',
  'offensive': 'Xúc phạm, gây tổn thương',
  'personal_info': 'Lộ thông tin cá nhân',
  'other': 'Lý do khác',
};
