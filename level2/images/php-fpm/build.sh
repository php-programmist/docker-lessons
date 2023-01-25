#!/usr/bin/env bash

docker build \
    --pull \
    --target fpm-dev\
    -t phpprogrammist/php:8.1-fpm-alpine-dev \
    .

docker build \
    --pull \
    --target fpm-prod\
    -t phpprogrammist/php:8.1-fpm-alpine-prod \
    .
