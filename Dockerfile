FROM php:7.2-fpm-stretch

LABEL authors="Julien Neuhart <j.neuhart@thecodingmachine.com>, David Négrier <d.negrier@thecodingmachine.com>"


# |--------------------------------------------------------------------------
# | Main PHP extensions
# |--------------------------------------------------------------------------
# |
# | Installs the main PHP extensions
# |

# Install php extensions
# Shamelessly borrowed from https://github.com/TetraWeb/docker/
RUN buildDeps=" \
        freetds-dev \
        libbz2-dev \
        libc-client-dev \
        libenchant-dev \
        libevent-dev \
        libfreetype6-dev \
        libgmp3-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libldap2-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libpng-dev \
        libpq-dev \
        libpspell-dev \
        librabbitmq-dev \
        libsasl2-dev \
        libsnmp-dev \
        libssl-dev \
        libtidy-dev \
        libxml2-dev \
        libxpm-dev \
        libxslt1-dev \
        libyaml-dev \
        zlib1g-dev \
    " \
    && phpModules=" \
        bcmath bz2 calendar dba enchant exif ftp gd gettext gmp imap intl ldap mbstring mysqli opcache pcntl pdo pdo_dblib pdo_mysql pdo_pgsql pgsql pspell shmop snmp soap sockets sysvmsg sysvsem sysvshm tidy wddx xmlrpc xsl zip xdebug \
    " \
    && sed -i "s/jessie main/jessie main contrib non-free/" /etc/apt/sources.list \
    && apt-get update && apt-get install -y libc-client2007e libenchant1c2a libfreetype6 libjpeg62-turbo libmcrypt4 libpq5 libsybdb5 libx11-6 libxpm4 libxslt1.1 snmp bind9-host cron git nano sudo iproute2 openssh-client procps --no-install-recommends \
    && apt-get install -y $buildDeps --no-install-recommends \
    && docker-php-source extract \
    && cd /usr/src/php/ext/ \
    && curl -L http://xdebug.org/files/xdebug-2.6.0.tgz | tar -zxf - \
    && mv xdebug-2.6.0 xdebug \
    && ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h \
    && ln -s /usr/lib/x86_64-linux-gnu/libldap_r.so /usr/lib/libldap.so \
    && ln -s /usr/lib/x86_64-linux-gnu/libldap_r.a /usr/lib/libldap_r.a \
    && ln -s /usr/lib/x86_64-linux-gnu/libsybdb.a /usr/lib/libsybdb.a \
    && ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/libsybdb.so \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-xpm-dir=/usr/include/ \
    && docker-php-ext-configure imap --with-imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure ldap --with-ldap-sasl \
    && docker-php-ext-install $phpModules \
    && pecl install amqp \
    && pecl install mcrypt-1.0.1 \
    && pecl install igbinary \
    && pecl install memcached \
    && pecl install mongodb \
    && pecl install redis \
    && pecl install apcu \
    && pecl install yaml \
    && pecl install ast \
    && pecl install weakref-beta \
    && pecl install ev \
    && pecl install event \
    && for ext in $phpModules; do \
           rm -f /usr/local/etc/php/conf.d/docker-php-ext-$ext.ini; \
       done \
    && docker-php-source delete \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps \
    && echo 'extension=zip.so' > /usr/local/etc/php/conf.d/generated_conf.ini
# Comments: MCrypt is deprecated and usage is generally discouraged. Provided here for legacy apps only.

# |--------------------------------------------------------------------------
# | User
# |--------------------------------------------------------------------------
# |
# | Define a default user with sudo rights.
# |

RUN useradd -ms /bin/bash docker && adduser docker sudo
# Users in the sudoers group can sudo as root without password.
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# |--------------------------------------------------------------------------
# | Default PHP extensions to be enabled
# |--------------------------------------------------------------------------
ENV PHP_EXTENSION_APCU=1 \
    PHP_EXTENSION_MYSQLI=1 \
    PHP_EXTENSION_OPCACHE=1 \
    PHP_EXTENSION_PDO=1 \
    PHP_EXTENSION_PDO_MYSQL=1 \
    PHP_EXTENSION_REDIS=1 \
    PHP_EXTENSION_ZIP=1 \
    PHP_EXTENSION_SOAP=1

# |--------------------------------------------------------------------------
# | Default php.ini file
# |--------------------------------------------------------------------------
# |
# | Let's download php.ini for prod and development
# |

ADD https://raw.githubusercontent.com/php/php-src/php-${PHP_VERSION}/php.ini-production /usr/local/etc/php/php.ini-production
ADD https://raw.githubusercontent.com/php/php-src/php-${PHP_VERSION}/php.ini-development /usr/local/etc/php/php.ini-development
RUN chmod 644 /usr/local/etc/php/php.ini-*
ENV TEMPLATE_PHP_INI=development

# |--------------------------------------------------------------------------
# | Composer
# |--------------------------------------------------------------------------
# |
# | Installs Composer to easily manage your PHP dependencies.
# |

#ENV COMPOSER_ALLOW_SUPERUSER 1

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=real_composer &&\
    chmod +x /usr/local/bin/real_composer

COPY utils/generate_conf.php /usr/local/bin/generate_conf.php
COPY utils/composer_proxy.sh /usr/local/bin/composer


# |--------------------------------------------------------------------------
# | prestissimo
# |--------------------------------------------------------------------------
# |
# | Installs Prestissimo to improve Composer download performance.
# |

USER docker
RUN composer global require hirak/prestissimo
USER root


# |--------------------------------------------------------------------------
# | NodeJS
# |--------------------------------------------------------------------------
# |
# | Installs NodeJS and npm. The later will allow you to easily manage
# | your frontend dependencies.
# |

RUN apt-get update &&\
    apt-get install -y --no-install-recommends gnupg &&\
    curl -sL https://deb.nodesource.com/setup_8.x | bash - &&\
    apt-get update &&\
    apt-get install -y --no-install-recommends nodejs

# |--------------------------------------------------------------------------
# | yarn
# |--------------------------------------------------------------------------
# |
# | Installs yarn. It provides some nice improvements over npm.
# |

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list &&\
    apt-get update &&\
    apt-get install -y --no-install-recommends yarn

# |--------------------------------------------------------------------------
# | PATH updating
# |--------------------------------------------------------------------------
# |
# | Let's add ./node_modules/.bin to the PATH (utility function to use NPM bin easily)
# |
ENV PATH="$PATH:./node_modules/.bin"
RUN sed -i 's#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:./node_modules/.bin#g' /etc/sudoers






RUN chown docker:docker /var/www/html


# |--------------------------------------------------------------------------
# | PATH updating
# |--------------------------------------------------------------------------
# |
# | Let's add ./vendor/bin to the PATH (utility function to use Composer bin easily)
# |
ENV PATH="$PATH:./vendor/bin:~/.composer/vendor/bin"
RUN sed -i 's#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin#/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:./vendor/bin:~/.composer/vendor/bin#g' /etc/sudoers

USER docker
# |--------------------------------------------------------------------------
# | SSH client
# |--------------------------------------------------------------------------
# |
# | Let's set-up the SSH client (for connections to private git repositories)
# | We create an empty known_host file and we launch the ssh-agent
# |

RUN mkdir ~/.ssh && touch ~/.ssh/known_hosts && chmod 644 ~/.ssh/known_hosts && eval $(ssh-agent -s)


# |--------------------------------------------------------------------------
# | .bashrc updating
# |--------------------------------------------------------------------------
# |
# | Let's update the .bashrc to add nice aliases
# |

RUN composer global require bamarni/symfony-console-autocomplete

RUN echo 'eval "$(symfony-autocomplete)"' > ~/.bash_profile

RUN { \
        echo "alias ls='ls --color=auto'"; \
        echo "alias ll='ls --color=auto -alF'"; \
        echo "alias la='ls --color=auto -A'"; \
        echo "alias l='ls --color=auto -CF'"; \
    } >> ~/.bashrc

USER root

# |--------------------------------------------------------------------------
# | Entrypoint
# |--------------------------------------------------------------------------
# |
# | Defines the entrypoint.
# |

ENV IMAGE_VARIANT=fpm

# Add Tini (to be able to stop the container with ctrl-c.
# See: https://github.com/krallin/tini
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

COPY utils/generate_cron.php /usr/local/bin/generate_cron.php
COPY utils/startup_commands.php /usr/local/bin/startup_commands.php

COPY utils/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY utils/docker-entrypoint-as-root.sh /usr/local/bin/docker-entrypoint-as-root.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]




USER docker