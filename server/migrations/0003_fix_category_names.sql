-- 0002 từng bị ghi sai encoding (chữ tiếng Việt vỡ) → đặt lại tên + icon cho DB đã tạo
update categories c set name_vi = x.name_vi, icon = x.icon
from (values ('food', 'Ăn uống', '🍜'),
             ('rent', 'Nhà ở & điện nước', '🏠'),
             ('transport', 'Đi lại', '🛵'),
             ('study', 'Học tập', '📚'),
             ('shopping', 'Mua sắm', '🛍️'),
             ('fun', 'Giải trí & bạn bè', '🎉'),
             ('topup', 'Nạp ví điện tử', '📱'),
             ('other', 'Khác', '📦'),
             ('income', 'Tiền vào', '💰'))
     as x(code, name_vi, icon)
where c.code = x.code;
