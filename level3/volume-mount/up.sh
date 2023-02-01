#!/usr/bin/env bash

docker run --rm -d \
  --name db \
  -e MYSQL_ROOT_PASSWORD=root \
  --mount type=volume,source=db_volume,target=/var/lib/mysql \
  mysql:8.0