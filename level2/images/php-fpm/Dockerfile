FROM php:8.1-fpm-alpine as fpm-prod

WORKDIR /opt/project

# Import extension installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

RUN install-php-extensions amqp apcu bcmath intl oauth opcache pdo_pgsql pgsql redis sockets zip @composer

RUN set -xe \
    && apk update \
    && apk add --no-cache \
        postgresql-dev \
        icu-dev \
        # Необходимо для AMQP
        rabbitmq-c \
        # Необходимо для AMQP
        rabbitmq-c-dev \
        # Необходимо для AMQP
        libssh-dev

FROM fpm-prod as fpm-dev
RUN install-php-extensions xdebug
