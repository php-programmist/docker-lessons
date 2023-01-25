# 1. Install dependencies only when needed
FROM node:18.0-alpine AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat

WORKDIR /opt/project
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# 2. Rebuild the source code only when needed
FROM node:18.0-alpine AS builder
WORKDIR /opt/project
COPY --from=deps /opt/project/node_modules ./node_modules
COPY . .
RUN yarn build

# 3. Production image, copy all the files and run next
FROM nginx:1.23-alpine AS runner
WORKDIR /usr/share/nginx/html

ENV NODE_ENV=production

COPY --from=builder /opt/project/build /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/conf.d

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]