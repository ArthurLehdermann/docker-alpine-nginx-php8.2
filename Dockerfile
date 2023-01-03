#FROM microsoft/mssql-tools as mssql

#COPY --from=mssql /opt/microsoft/ /opt/microsoft/
#COPY --from=mssql /opt/mssql-tools/ /opt/mssql-tools/
#COPY --from=mssql /usr/lib/libmsodbcsql-13.so /usr/lib/libmsodbcsql-13.so

#RUN set -xe \
#    && apk add --no-cache --virtual .persistent-deps \
#        freetds \
#        unixodbc \
#    && apk add --no-cache --virtual .build-deps \
#        $PHPIZE_DEPS \
#        unixodbc-dev \
#        freetds-dev \
#    && docker-php-source extract \
#    && docker-php-ext-install pdo_dblib \
#    && pecl install \
#        sqlsrv \
#        pdo_sqlsrv \
#    && docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv \
#    && docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv \
#    && docker-php-source delete \
#    && apk del .build-deps

FROM php:8.2.1RC1-fpm-alpine3.17

LABEL Maintainer="Arthur Lehdermann <ArthurLehdermann@gmail.com>" \
      Description="A lightweight container with Nginx & PHP 8.2.1 based on Alpine Linux pt-BR.UTF-8"

# terminal bash
RUN apk add --no-cache bash curl wget vim git composer nginx supervisor

# composer 2
RUN composer self-update
RUN composer self-update --2

# TimeZone
RUN apk add tzdata
RUN cp /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN rm -r /usr/share/zoneinfo/Africa && \
    rm -r /usr/share/zoneinfo/Antarctica && \
    rm -r /usr/share/zoneinfo/Arctic && \
    rm -r /usr/share/zoneinfo/Asia && \
    rm -r /usr/share/zoneinfo/Atlantic && \
    rm -r /usr/share/zoneinfo/Australia && \
    rm -r /usr/share/zoneinfo/Europe  && \
    rm -r /usr/share/zoneinfo/Indian && \
    rm -r /usr/share/zoneinfo/Mexico && \
    rm -r /usr/share/zoneinfo/Pacific && \
    rm -r /usr/share/zoneinfo/Chile && \
    rm -r /usr/share/zoneinfo/Canada
RUN echo "America/Sao_Paulo" >  /etc/timezone
ENV TZ America/Sao_Paulo
ENV LANG pt_BR.UTF-8
ENV LANGUAGE pt_BR.UTF-8
ENV LC_ALL pt_BR.UTF-8

# Add MySQL and Postgres/pgsql support
RUN apk add --no-cache postgresql-client mysql-client
RUN docker-php-ext-install mysqli pdo pdo_mysql && docker-php-ext-enable pdo_mysql
RUN set -ex && apk --no-cache add postgresql-dev && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install pdo_pgsql pgsql && \
    docker-php-ext-enable pdo_pgsql

# Add essential PHP extensions
RUN apk add --no-cache msmtp perl procps shadow freetype icu libmcrypt-dev libpng-dev \
     icu-dev icu-libs zlib-dev g++ make automake autoconf libzip libpng libjpeg-turbo \
     libwebp libcurl curl-dev libxml2-dev libzip-dev libpng-dev libwebp-dev libjpeg-turbo-dev \
     freetype-dev icu-dev gettext-dev

RUN apk add --no-cache php81-bcmath php81-bz2 php81-dom php81-exif php81-fileinfo php81-ftp php81-gd php81-gettext \
    php81-intl php81-opcache php81-pdo php81-pdo_mysql php81-pdo_pgsql php81-shmop php81-simplexml php81-session \
    php81-sockets php81-sysvmsg php81-sysvsem php81-sysvshm php81-tokenizer php81-xml php81-xmlwriter

RUN apk add --no-cache --virtual build-essentials && \
    docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install bcmath bz2 curl dom exif fileinfo ftp gd gettext intl opcache phar \
      pdo pdo_mysql pdo_pgsql shmop simplexml sockets sysvmsg sysvsem sysvshm xml xmlwriter zip && \
    docker-php-ext-enable bcmath bz2 curl dom exif fileinfo ftp gd gettext intl opcache phar \
      pdo pdo_mysql pdo_pgsql shmop simplexml sockets sysvmsg sysvsem sysvshm xml xmlwriter zip

# install imagick
# use github version for now until release from https://pecl.php.net/get/imagick is ready for PHP 8
# ref: https://github.com/Imagick/imagick/issues/358
RUN mkdir -p /usr/src/php/ext/imagick && \
    curl -fsSL https://github.com/Imagick/imagick/archive/06116aa24b76edaf6b1693198f79e6c295eda8a9.tar.gz | tar xvz -C "/usr/src/php/ext/imagick" --strip 1

# Remove the build deps and clean out directories that don't need to be part of the image
RUN apk del build-essentials && rm -rf /usr/src/php* && rm -rf /tmp/* /var/tmp/*

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf
# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/my_custom.ini

# Boost to vim
ADD .vimrc /root/.vimrc

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:9000/fpm-ping
