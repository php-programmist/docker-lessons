FROM php:8.1-cli-alpine
# Import extension installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

RUN install-php-extensions amqp apcu bcmath intl oauth opcache pdo_pgsql pgsql redis sockets zip @composer
