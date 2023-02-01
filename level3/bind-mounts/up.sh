#!/usr/bin/env bash

docker run --rm -d \
  --name edge \
  -p 8000:80 \
  --mount type=bind,source="$(pwd)"/config/nginx.conf,target=/etc/nginx/nginx.conf \
  --mount type=bind,source="$(pwd)"/config/app.conf,target=/etc/nginx/conf.d/app.conf \
  --mount type=bind,source="$(pwd)"/content,target=/usr/share/nginx/html \
  nginx:1.23