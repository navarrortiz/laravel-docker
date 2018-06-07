FROM phpearth/php:7.2-nginx

RUN apk add --no-cache php7.2-pdo_pgsql redis xdebug

RUN apk add --no-cache $PHPIZE_DEPS \
    && pecl install xdebug-2.5.0 \
    && docker-php-ext-enable xdebug

