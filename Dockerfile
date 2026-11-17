# 1) Build Flutter Web (cố định phiên bản để mọi máy build ra giống nhau).
# Tự dựng Flutter, chỉ phần web. Image cirruslabs/flutter kèm Android SDK có một lớp
# mà Docker 29.9 / containerd 2.4 không giải nén được ("archive/tar: invalid tar header").
FROM debian:trixie-slim AS web
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 3.44.0 https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:$PATH"
RUN flutter config --no-analytics --no-cli-animations && flutter precache --web
WORKDIR /app
COPY app/pubspec.* ./
RUN flutter pub get
COPY app/ ./
ARG APP_ENV=demo
RUN flutter build web --release --dart-define=APP_ENV=$APP_ENV

# 2) Thư viện Node cho production
FROM node:24-alpine AS deps
WORKDIR /srv
COPY server/package*.json ./
RUN npm ci --omit=dev

# 3) Typecheck + test: đỏ thì build dừng ở đây, container đang chạy không bị đụng tới
FROM node:24-alpine AS test
WORKDIR /srv
COPY server/package*.json ./
RUN npm ci
COPY server/ ./
RUN npm test && touch /srv/.tested

# 4) Image chạy thật
FROM node:24-alpine
WORKDIR /srv
# Bắt buộc BuildKit chạy stage test (stage không ai dùng tới sẽ bị bỏ qua)
COPY --from=test /srv/.tested /srv/.tested
COPY --from=deps /srv/node_modules ./node_modules
COPY server/ ./
COPY --from=web /app/build/web ./public
USER node
EXPOSE 8080
CMD ["node", "src/main.ts"]
