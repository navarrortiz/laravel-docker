FROM phpearth/php:7.2-nginx

RUN apk add --no-cache php7.2-pdo_pgsql redis xdebug

