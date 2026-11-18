-- Người dùng (thay cho auth.users + profiles của Supabase)
create table users (
  id uuid primary key default gen_random_uuid(),
  email text unique check (email = lower(email)), -- null = tài khoản seed (tác giả bài mẫu)
  password_hash text,                    -- 'scrypt$N$r$p$salt$hash'; null = không đăng nhập được
  display_name text,
  anon_alias text not null unique,       -- tên ẩn danh trong cộng đồng, vd "Mèo Mướp #4821"
  role text not null default 'user' check (role in ('user','admin')),
  monthly_income_day int not null default 1 check (monthly_income_day between 1 and 31),
  demo_mode boolean not null default false,     -- bật tab /demo (mục 14)
  exclude_topup boolean not null default false, -- loại 'topup' khỏi tổng chi (mục 11.3)
  created_at timestamptz not null default now()
);

-- Phiên đăng nhập: chỉ lưu SHA-256 của token, token thật nằm trong cookie
create table sessions (
  token_hash bytea primary key,
  user_id uuid not null references users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index on sessions (user_id);

-- Nhóm chi tiêu
create table categories (
  id serial primary key,
  code text unique not null,             -- food, transport, shopping, rent, study, fun, topup, other, income
  name_vi text not null,
  icon text,
  default_essential boolean not null default false
);

-- Ngân sách theo tháng & theo nhóm
create table budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  month date not null check (extract(day from month) = 1),  -- ngày đầu tháng, vd 2026-11-01
  category_id int references categories(id),               -- null = tổng ngân sách tháng
  amount bigint not null check (amount >= 0),
  is_essential boolean not null default false,
  unique nulls not distinct (user_id, month, category_id)  -- chỉ 1 dòng tổng (category_id null) mỗi tháng
);

-- Tài khoản ngân hàng đã liên kết qua SePay
create table bank_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  provider text not null default 'sepay',
  provider_account_id text,              -- id tài khoản phía SePay Bank Hub (đã xác minh với SePay)
  account_number_hmac text,              -- HMAC-SHA256(số TK, ACCOUNT_HASH_SECRET), dùng cho webhook SePay thường
  bank_short_name text,                  -- 'MBBank'
  account_number_masked text,            -- '****6789'
  status text not null default 'active' check (status in ('active','unlinked')),
  linked_at timestamptz not null default now(),
  unique (provider, provider_account_id),
  unique (provider, account_number_hmac),
  check (provider_account_id is not null or account_number_hmac is not null)
);

-- Giao dịch
create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  bank_account_id uuid references bank_accounts(id) on delete set null,
  source text not null check (source in ('sepay','manual','demo')),
  wallet text check (wallet in ('cash','momo','zalopay','other')),  -- chỉ dùng cho source='manual'
  external_id text,                      -- id giao dịch phía SePay (chống trùng)
  direction text not null check (direction in ('in','out')),
  amount bigint not null check (amount > 0),   -- VND, luôn dương
  occurred_at timestamptz not null,
  raw_content text,                      -- nội dung chuyển khoản gốc
  counterparty text,                     -- tên người nhận / cửa hàng (nếu tách được)
  category_id int references categories(id),
  category_confirmed boolean not null default false,  -- user đã xác nhận nhóm chưa
  note text,
  balance_after bigint,                  -- số dư sau giao dịch (từ ngân hàng)
  created_at timestamptz not null default now(),
  unique (source, external_id)           -- manual có external_id null → không đụng nhau
);
create index on transactions (user_id, occurred_at desc);

-- Quy tắc phân loại học từ người dùng
create table merchant_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  pattern text not null check (char_length(pattern) >= 3),  -- cụm token đã chuẩn hoá: 'highlands', 'quan co ba'
  category_id int not null references categories(id),
  hits int not null default 1,
  unique (user_id, pattern)
);

-- Log webhook (debug & audit). Chỉ server đọc; số tài khoản bị che trước khi lưu.
create table webhook_logs (
  id bigserial primary key,
  received_at timestamptz not null default now(),
  payload jsonb not null,
  status text not null default 'received'
    check (status in ('received','ok','duplicate','unknown_account','error')),
  error text
);

-- ===== Cộng đồng "Đồng cảnh ngộ" =====
create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references users(id) on delete cascade,
  difficulty_type text not null check (difficulty_type in ('unexpected_expense','over_budget','income_delay','other')),
  expense_type text check (expense_type in ('medical','device_broken','social','tuition','other')),
  amount_range text check (amount_range in ('<200k','200k-500k','500k-1tr','>1tr')),
  need text not null check (need in ('meal_ideas','budget_adjust','side_job','emotional','other')),
  body text not null check (char_length(body) between 20 and 1000),
  status text not null default 'visible' check (status in ('visible','hidden','removed')),
  created_at timestamptz not null default now()
);

create table solutions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade,  -- null = mẹo chung
  author_id uuid not null references users(id) on delete cascade,
  tag text not null check (tag in ('cheap_meal','adjust_plan','side_job','mindset')),
  body text not null check (char_length(body) between 10 and 1000),
  status text not null default 'visible' check (status in ('visible','hidden','removed')),
  created_at timestamptz not null default now()
);

create table solution_feedback (
  solution_id uuid references solutions(id) on delete cascade,
  user_id uuid references users(id) on delete cascade,
  helpful boolean not null,
  applied_result text check (applied_result in ('worked','partly','not_worked')),
  comment text check (char_length(comment) <= 500),
  created_at timestamptz not null default now(),
  primary key (solution_id, user_id)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id) on delete cascade,
  target_type text not null check (target_type in ('post','solution')),
  target_id uuid not null,
  reason text not null check (reason in ('scam_loan','spam','offensive','personal_info','other')),
  detail text check (char_length(detail) <= 500),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

-- View công khai: KHÔNG có author_id. API cộng đồng chỉ đọc từ 2 view này.
create view public_posts as
  select p.id, u.anon_alias, p.difficulty_type, p.expense_type, p.amount_range,
         p.need, p.body, p.created_at,
         (select count(*) from solutions s where s.post_id = p.id and s.status = 'visible') as solution_count
  from posts p join users u on u.id = p.author_id
  where p.status = 'visible';

create view public_solutions as
  select s.id, s.post_id, u.anon_alias, s.tag, s.body, s.created_at,
         count(*) filter (where f.helpful)                  as helpful_count,
         count(*) filter (where f.applied_result = 'worked') as worked_count
  from solutions s
  join users u on u.id = s.author_id
  left join solution_feedback f on f.solution_id = s.id
  where s.status = 'visible'
  group by s.id, u.anon_alias;

-- Trigger tự ẩn bài khi bị báo cáo nhiều (spec 6.5)
create function auto_hide_on_reports() returns trigger language plpgsql as $$
begin
  if (select count(*) from reports
      where target_type = new.target_type and target_id = new.target_id and status = 'open') >= 3 then
    if new.target_type = 'post' then
      update posts set status = 'hidden' where id = new.target_id and status = 'visible';
    else
      update solutions set status = 'hidden' where id = new.target_id and status = 'visible';
    end if;
  end if;
  return new;
end $$;

create trigger trg_auto_hide after insert on reports
for each row execute function auto_hide_on_reports();
