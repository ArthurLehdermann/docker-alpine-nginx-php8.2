FROM php:8.2.35-fpm-alpine3.24

LABEL Maintainer="Arthur Lehdermann <ArthurLehdermann@gmail.com>" \
      Description="A lightweight container with Nginx & PHP 8.2 based on Alpine Linux pt-BR.UTF-8"

# terminal bash
RUN apk add --no-cache bash curl wget vim git nginx supervisor

# composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer self-update

# TimeZone
RUN apk add --no-cache tzdata
RUN cp /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN echo "America/Sao_Paulo" >  /etc/timezone
ENV TZ=America/Sao_Paulo
ENV LANG=pt_BR.UTF-8
ENV LANGUAGE=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

# Add essential PHP extensions
# build-essentials: Dependencies for compiling extensions
# Note: "shadow" is often needed for usermod/groupmod if you do user management, kept from original
RUN apk add --no-cache \
    freetype \
    gettext \
    icu-libs \
    imagemagick \
    libjpeg-turbo \
    libpng \
    libwebp \
    libzip \
    linux-headers \
    shadow \
    mysql-client \
    postgresql-client

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    curl-dev \
    freetype-dev \
    gettext-dev \
    icu-dev \
    imagemagick-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libsodium-dev \
    libwebp-dev \
    libxml2-dev \
    libzip-dev \
    postgresql-dev \
    zlib-dev

# Configure and install core PHP extensions
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install -j$(nproc) \
    bcmath \
    bz2 \
    curl \
    dom \
    exif \
    fileinfo \
    ftp \
    gd \
    gettext \
    intl \
    mysqli \
    opcache \
    pcntl \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    shmop \
    simplexml \
    sockets \
    sodium \
    sysvmsg \
    sysvsem \
    sysvshm \
    xml \
    xmlwriter \
    zip

# Install generic extensions via PECL (Redis)
RUN pecl install redis && docker-php-ext-enable redis

# Install PCOV for code coverage
RUN pecl install pcov && docker-php-ext-enable pcov

# Install Imagick
# Using PECL for better compatibility/stability
RUN pecl install imagick && docker-php-ext-enable imagick

# Cleanup
RUN apk del .build-deps && \
    rm -rf /usr/src/php* /tmp/* /var/tmp/*

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
# PHP 8+ official images use /usr/local/etc/php-fpm.d/
COPY config/fpm-pool.conf /usr/local/etc/php-fpm.d/www.conf

# Configure PHP settings
# PHP 8+ official images use /usr/local/etc/php/conf.d/
COPY config/php.ini /usr/local/etc/php/conf.d/custom.ini

# Boost to vim
ADD .vimrc /root/.vimrc

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create directory for nginx pid if not exists (Alpine nginx package usually does this, but good to ensure)
RUN mkdir -p /run/nginx

# Start supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Healthcheck
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:9000/fpm-ping
