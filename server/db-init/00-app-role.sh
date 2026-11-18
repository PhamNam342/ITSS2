#!/bin/sh
set -e
psql -v ON_ERROR_STOP=1 -U postgres -d antam -v pw="$APP_DB_PASSWORD" <<'SQL'
create role antam_app login password :'pw';
alter database antam owner to antam_app;
alter schema public owner to antam_app;   -- từ PG15 role thường không được tạo bảng trong public
SQL
