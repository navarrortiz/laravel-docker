FROM phpearth/php:7.2-nginx

RUN apk add --no-cache  php7.2-dev gcc g++ php7.2-pdo_pgsql redis

RUN apk add --no-cache $PHPIZE_DEPS
#RUN pecl channel-update pecl.php.net
RUN pecl install xdebug
RUN docker-php-ext-enable xdebug
