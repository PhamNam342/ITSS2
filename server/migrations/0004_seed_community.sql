-- Nội dung mẫu cho cộng đồng "Đồng cảnh ngộ" (spec 10.4) để không trống khi demo.
-- Tác giả là tài khoản seed: email + password_hash null → không đăng nhập được.
-- Tên ẩn danh dạng #01xx: bộ sinh tên (#1000–#9999) không bao giờ tạo ra → không trùng người dùng thật.
-- Nhóm có thể thay bằng tình huống thật từ Problem Interview.

insert into users (id, email, password_hash, anon_alias) values
  ('00000000-0000-4000-a000-000000000101', null, null, 'Mèo Mướp #0101'),
  ('00000000-0000-4000-a000-000000000102', null, null, 'Cún Con #0102'),
  ('00000000-0000-4000-a000-000000000103', null, null, 'Gấu Trúc #0103'),
  ('00000000-0000-4000-a000-000000000104', null, null, 'Sóc Nâu #0104'),
  ('00000000-0000-4000-a000-000000000105', null, null, 'Thỏ Trắng #0105'),
  ('00000000-0000-4000-a000-000000000106', null, null, 'Cá Heo #0106'),
  ('00000000-0000-4000-a000-000000000107', null, null, 'Chim Sẻ #0107'),
  ('00000000-0000-4000-a000-000000000108', null, null, 'Rùa Con #0108');

insert into posts (id, author_id, difficulty_type, expense_type, amount_range, need, body, created_at) values
  ('00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000101', 'unexpected_expense', 'device_broken', '>1tr', 'budget_adjust',
   'Laptop hỏng màn hình giữa kỳ thi, sửa hết 1,5 triệu. Tiền tháng này coi như đi một nửa, còn hơn 2 tuần nữa mới có tiền. Mọi người xoay thế nào ạ?', now() - interval '20 days'),
  ('00000000-0000-4000-a000-000000000202', '00000000-0000-4000-a000-000000000102', 'unexpected_expense', 'medical', '200k-500k', 'meal_ideas',
   'Bị sốt mấy hôm, tiền khám với thuốc gần 400k. Giờ mệt không muốn nấu, mà đặt đồ ăn thì tốn quá. Có món nào dễ làm mà rẻ không?', now() - interval '18 days'),
  ('00000000-0000-4000-a000-000000000203', '00000000-0000-4000-a000-000000000103', 'over_budget', 'social', '500k-1tr', 'budget_adjust',
   'Tháng này dồn 2 đám cưới anh chị họ với sinh nhật bạn thân, mất gần 1 triệu. Ngại từ chối nhưng ví thì cạn rồi.', now() - interval '16 days'),
  ('00000000-0000-4000-a000-000000000204', '00000000-0000-4000-a000-000000000104', 'income_delay', 'other', '>1tr', 'emotional',
   'Bố mẹ báo tháng này gửi tiền muộn 10 ngày vì việc nhà. Mình không muốn bố mẹ lo thêm nhưng thật sự hơi hoảng.', now() - interval '15 days'),
  ('00000000-0000-4000-a000-000000000205', '00000000-0000-4000-a000-000000000105', 'unexpected_expense', 'device_broken', '200k-500k', 'budget_adjust',
   'Xe máy thủng săm rồi hỏng bugi trong cùng một tuần, hết 350k. Nhỏ thôi nhưng cộng dồn làm mình bị lệch kế hoạch.', now() - interval '13 days'),
  ('00000000-0000-4000-a000-000000000206', '00000000-0000-4000-a000-000000000106', 'over_budget', 'other', '200k-500k', 'meal_ideas',
   'Mình lỡ đặt đồ ăn online nhiều quá, mới giữa tháng đã vượt ngân sách ăn uống 400k. Có cách nào ăn đủ chất mà rẻ không?', now() - interval '12 days'),
  ('00000000-0000-4000-a000-000000000207', '00000000-0000-4000-a000-000000000107', 'unexpected_expense', 'tuition', '500k-1tr', 'side_job',
   'Phải đóng thêm tiền tài liệu với phí học lại một môn, gần 900k. Muốn tìm việc làm thêm cuối tuần mà không ảnh hưởng học.', now() - interval '11 days'),
  ('00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000108', 'over_budget', 'other', '<200k', 'emotional',
   'Vượt ngân sách có 150k thôi mà cứ thấy mình thất bại, mở app ra là ngại. Có ai từng vậy không?', now() - interval '10 days'),
  ('00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000101', 'unexpected_expense', 'medical', '500k-1tr', 'budget_adjust',
   'Đi nha sĩ trám răng hết 700k, không có bảo hiểm chi trả. Phải cắt bớt khoản nào trước đây?', now() - interval '9 days'),
  ('00000000-0000-4000-a000-000000000210', '00000000-0000-4000-a000-000000000102', 'income_delay', 'other', '500k-1tr', 'side_job',
   'Chỗ làm thêm trả lương chậm 2 tuần. Có bạn nào biết việc trả theo ngày hoặc theo ca không?', now() - interval '8 days'),
  ('00000000-0000-4000-a000-000000000211', '00000000-0000-4000-a000-000000000103', 'unexpected_expense', 'social', '200k-500k', 'budget_adjust',
   'Lớp tổ chức đi chơi cuối kỳ, góp 400k. Không đi thì sợ lạc lõng, đi thì phải nhịn ăn sáng cả tuần.', now() - interval '7 days'),
  ('00000000-0000-4000-a000-000000000212', '00000000-0000-4000-a000-000000000104', 'unexpected_expense', 'device_broken', '>1tr', 'emotional',
   'Rơi vỡ điện thoại, thay màn hình 1,8 triệu. Đang tự trách mình bất cẩn, cũng không dám kể với nhà.', now() - interval '6 days'),
  ('00000000-0000-4000-a000-000000000213', '00000000-0000-4000-a000-000000000105', 'over_budget', 'other', '500k-1tr', 'budget_adjust',
   'Sale cuối tháng mình mua hơi nhiều đồ trên mạng, giờ còn 10 ngày mà chỉ còn 600k. Lên kế hoạch lại thế nào cho đủ?', now() - interval '5 days'),
  ('00000000-0000-4000-a000-000000000214', '00000000-0000-4000-a000-000000000106', 'unexpected_expense', 'other', '<200k', 'meal_ideas',
   'Mất ví, may chỉ có 150k tiền mặt trong đó nhưng phải làm lại thẻ sinh viên. Tuần này cần ăn thật tiết kiệm.', now() - interval '4 days'),
  ('00000000-0000-4000-a000-000000000215', '00000000-0000-4000-a000-000000000107', 'income_delay', 'other', '200k-500k', 'budget_adjust',
   'Học bổng giải ngân chậm 1 tháng so với dự kiến. Mình đã lỡ tính khoản này vào ngân sách rồi.', now() - interval '3 days'),
  ('00000000-0000-4000-a000-000000000216', '00000000-0000-4000-a000-000000000108', 'unexpected_expense', 'medical', '200k-500k', 'emotional',
   'Đau dạ dày phải đi khám, bác sĩ bảo do ăn uống thất thường vì tiết kiệm quá đà. Giờ vừa tốn tiền vừa thấy mình làm sai.', now() - interval '2 days');

insert into solutions (id, post_id, author_id, tag, body, created_at) values
  -- Trả lời các tình huống
  ('00000000-0000-4000-a000-000000000301', '00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000103', 'adjust_plan',
   'Mình chia số còn lại cho số ngày, tách riêng tiền ăn ra trước. Mua sắm với giải trí để 0 trong 2 tuần, qua kỳ thi rồi tính tiếp.', now() - interval '19 days'),
  ('00000000-0000-4000-a000-000000000302', '00000000-0000-4000-a000-000000000201', '00000000-0000-4000-a000-000000000105', 'mindset',
   'Laptop là đồ học tập, sửa là chi đúng chỗ rồi, đừng tự trách nhé. Tháng sau để riêng 100k/tháng làm quỹ sửa đồ.', now() - interval '19 days'),
  ('00000000-0000-4000-a000-000000000303', '00000000-0000-4000-a000-000000000202', '00000000-0000-4000-a000-000000000106', 'cheap_meal',
   'Cháo gà nấu nồi cơm điện: 1 lạng gạo + 1 bát thịt gà xé, đổ nhiều nước, bấm nấu 2 lần. Ăn được 3 bữa, tầm 40k.', now() - interval '17 days'),
  ('00000000-0000-4000-a000-000000000304', '00000000-0000-4000-a000-000000000202', '00000000-0000-4000-a000-000000000108', 'cheap_meal',
   'Trứng hấp với cơm nóng + rau cải luộc, 15 phút là xong, mỗi bữa chưa tới 15k mà dễ ăn khi ốm.', now() - interval '17 days'),
  ('00000000-0000-4000-a000-000000000305', '00000000-0000-4000-a000-000000000203', '00000000-0000-4000-a000-000000000101', 'adjust_plan',
   'Mình đặt mức mừng cố định cho từng kiểu quan hệ ngay từ đầu năm, và báo trước với bạn thân là tặng quà tự làm. Không ai trách cả.', now() - interval '15 days'),
  ('00000000-0000-4000-a000-000000000306', '00000000-0000-4000-a000-000000000204', '00000000-0000-4000-a000-000000000107', 'mindset',
   'Mình từng y hệt. Viết ra 10 ngày đó cần chi những gì thật sự, thường ít hơn mình nghĩ. Hỏi bạn cùng phòng góp nấu chung cũng đỡ lắm.', now() - interval '14 days'),
  ('00000000-0000-4000-a000-000000000307', '00000000-0000-4000-a000-000000000204', '00000000-0000-4000-a000-000000000102', 'adjust_plan',
   'Ưu tiên theo thứ tự: tiền nhà, ăn, đi lại. Khoản nào lùi được (cắt tóc, mua đồ) thì ghi lại để tháng sau làm.', now() - interval '14 days'),
  ('00000000-0000-4000-a000-000000000308', '00000000-0000-4000-a000-000000000206', '00000000-0000-4000-a000-000000000104', 'cheap_meal',
   'Đi chợ 1 lần cho 3 ngày: 1 vỉ trứng, 3 lạng thịt, rau, đậu phụ. Nấu cơm sáng mang theo, tối về nấu nhanh. Mình hết khoảng 150k/3 ngày.', now() - interval '11 days'),
  ('00000000-0000-4000-a000-000000000309', '00000000-0000-4000-a000-000000000207', '00000000-0000-4000-a000-000000000106', 'side_job',
   'Gia sư cấp 2 cuối tuần là hợp nhất, 2 buổi đã được 300–400k. Hỏi phòng công tác sinh viên của trường hay có danh sách tin tuyển chính thống.', now() - interval '10 days'),
  ('00000000-0000-4000-a000-000000000310', '00000000-0000-4000-a000-000000000207', '00000000-0000-4000-a000-000000000103', 'side_job',
   'Phụ quầy sự kiện cuối tuần trả theo ca. Nhớ chỉ nhận việc có hợp đồng hoặc qua trường, đừng đóng phí "giữ chỗ" cho ai.', now() - interval '10 days'),
  ('00000000-0000-4000-a000-000000000311', '00000000-0000-4000-a000-000000000208', '00000000-0000-4000-a000-000000000105', 'mindset',
   'Vượt 150k nghĩa là bạn vẫn giữ được phần lớn kế hoạch đó. Mình coi ngân sách là la bàn, không phải bài kiểm tra.', now() - interval '9 days'),
  ('00000000-0000-4000-a000-000000000312', '00000000-0000-4000-a000-000000000209', '00000000-0000-4000-a000-000000000104', 'adjust_plan',
   'Hỏi trường xem bảo hiểm y tế sinh viên có hoàn một phần không. Phần còn lại mình cắt mục giải trí trước vì dễ lùi nhất.', now() - interval '8 days'),
  ('00000000-0000-4000-a000-000000000313', '00000000-0000-4000-a000-000000000211', '00000000-0000-4000-a000-000000000108', 'adjust_plan',
   'Mình nói thật với lớp trưởng là tháng này chật, xin góp một nửa và phụ việc chuẩn bị. Bạn ấy đồng ý luôn.', now() - interval '6 days'),
  ('00000000-0000-4000-a000-000000000314', '00000000-0000-4000-a000-000000000212', '00000000-0000-4000-a000-000000000101', 'mindset',
   'Ai cũng từng làm rơi điện thoại. Nếu kể với nhà, nói kèm kế hoạch bạn tự xoay thế nào, bố mẹ thường yên tâm hơn là giận.', now() - interval '5 days'),
  ('00000000-0000-4000-a000-000000000315', '00000000-0000-4000-a000-000000000213', '00000000-0000-4000-a000-000000000107', 'adjust_plan',
   '600k / 10 ngày = 60k/ngày. Mình chia 45k ăn + 15k dự phòng, đồ đã mua mà chưa dùng thì xem có trả lại được không.', now() - interval '4 days'),
  ('00000000-0000-4000-a000-000000000316', '00000000-0000-4000-a000-000000000214', '00000000-0000-4000-a000-000000000102', 'cheap_meal',
   'Mì trứng thêm rau, cơm rang trứng, đậu phụ sốt cà chua: 3 món xoay vòng, mỗi bữa 10–15k.', now() - interval '3 days'),
  ('00000000-0000-4000-a000-000000000317', '00000000-0000-4000-a000-000000000216', '00000000-0000-4000-a000-000000000106', 'mindset',
   'Tiết kiệm mà bỏ bữa thì không đáng. Mình đặt mức tối thiểu cho ăn uống trước, phần còn lại mới chia cho thứ khác.', now() - interval '1 day'),
  -- Mẹo chung (post_id null) – mục "Mẹo được nhiều bạn thấy hữu ích"
  ('00000000-0000-4000-a000-000000000351', null, '00000000-0000-4000-a000-000000000103', 'adjust_plan',
   'Ngày nhận tiền, chuyển ngay tiền nhà và tiền ăn sang một chỗ riêng. Phần còn lại mới là tiền tiêu linh hoạt.', now() - interval '25 days'),
  ('00000000-0000-4000-a000-000000000352', null, '00000000-0000-4000-a000-000000000105', 'cheap_meal',
   'Nấu cơm buổi tối dư một hộp mang đi học trưa hôm sau, mỗi tuần tiết kiệm được 150–200k.', now() - interval '24 days'),
  ('00000000-0000-4000-a000-000000000353', null, '00000000-0000-4000-a000-000000000101', 'mindset',
   'Trước khi mua gì trên 200k, để trong giỏ hàng 24 giờ. Một nửa số lần mình không còn muốn mua nữa.', now() - interval '23 days'),
  ('00000000-0000-4000-a000-000000000354', null, '00000000-0000-4000-a000-000000000107', 'adjust_plan',
   'Mỗi tháng để riêng 5–10% làm quỹ "chuyện bất ngờ". Không dùng thì cuối kỳ thưởng cho mình một bữa ngon.', now() - interval '22 days'),
  ('00000000-0000-4000-a000-000000000355', null, '00000000-0000-4000-a000-000000000108', 'side_job',
   'Việc làm thêm chính thống thì không bao giờ bắt đóng phí trước. Ai đòi cọc, phí đồng phục hay "phí hồ sơ" là nên tránh.', now() - interval '21 days'),
  ('00000000-0000-4000-a000-000000000356', null, '00000000-0000-4000-a000-000000000104', 'mindset',
   'Chi vượt một tuần không sao. Tuần mới, bắt đầu lại nhẹ nhàng – điều quan trọng là mình vẫn đang theo dõi.', now() - interval '20 days');

-- Một ít lượt "hữu ích" / "đã thử" từ tài khoản seed để có thứ tự hiển thị
insert into solution_feedback (solution_id, user_id, helpful, applied_result)
select s.id, u.id, true, case when (u.n + s.n) % 3 = 0 then 'worked' end
from (select id, row_number() over (order by id) as n from solutions where author_id::text like '00000000-0000-4000-a000-0000000001%') s
cross join (select id, row_number() over (order by id) as n from users where email is null and password_hash is null) u
where (u.n * 7 + s.n * 3) % 5 < 2
on conflict do nothing;
