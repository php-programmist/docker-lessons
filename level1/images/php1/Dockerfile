FROM php:8.1-fpm-alpine

RUN set -xe \
    && apk update \
    && apk add --no-cache \
        postgresql-dev \
        icu-dev \
        # Необходимо для imagick
        imagemagick \
        imagemagick-dev \
        libgomp \
        # Необходимо для AMQP
        rabbitmq-c \
        # Необходимо для AMQP
        rabbitmq-c-dev \
        # Необходимо для AMQP
        libssh-dev \
    && docker-php-ext-install \
        # Необходимо для AMQP
        bcmath \
        # Необходимо для AMQP
        sockets \
        intl \
        pdo_pgsql \
        pgsql

RUN  apk add --no-cache --virtual .redis-deps ${PHPIZE_DEPS} \
    && pecl install -o -f redis-5.3.4 \
    && pecl install amqp-1.11.0beta \
    && pecl install -o -f imagick \
    && docker-php-ext-enable \
        redis \
        opcache \
        amqp \
        imagick \
    && apk del ${PHPIZE_DEPS} .redis-deps

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --version 2.0.12 \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer