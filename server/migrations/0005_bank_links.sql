-- Sprint 5: mỗi dòng bank_accounts là một liên kết của người dùng
--   'sepay'     : webhook SePay riêng của người dùng, xác thực bằng API key (Authorization: Apikey <key>)
--   'vcb_email' : email biên lai Vietcombank chuyển tiếp tới <token>@<mail-domain>
-- Server chỉ lưu sha256 của key/token.
alter table bank_accounts add column webhook_key_hash text unique;
alter table bank_accounts add column last_webhook_at timestamptz;
alter table bank_accounts add column gmail_confirm text;   -- mã xác nhận chuyển tiếp của Gmail, hiện cho người dùng
alter table bank_accounts add constraint bank_accounts_provider_check check (provider in ('sepay', 'vcb_email'));
alter table bank_accounts drop constraint bank_accounts_check;
alter table bank_accounts add constraint bank_accounts_check
  check (provider_account_id is not null or account_number_hmac is not null or webhook_key_hash is not null);

alter table transactions drop constraint transactions_source_check;
alter table transactions add constraint transactions_source_check check (source in ('sepay', 'email', 'manual', 'demo'));

-- Chuyển giữa các tài khoản của chính mình: không tính là chi hay thu
insert into categories (code, name_vi, icon, default_essential)
values ('self_transfer', 'Chuyển giữa tài khoản của mình', '🔁', false)
on conflict (code) do nothing;
