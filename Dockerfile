# 1) Build Flutter Web (cố định phiên bản để mọi máy build ra giống nhau)
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS web
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
