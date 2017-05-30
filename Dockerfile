FROM debian:8
MAINTAINER Daniel Ripoll <info@danielripoll.es>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Update base image
# Add sources for latest nginx
# Install software requirements
#
ENV IMAGE_PHP_VERSION=7.1
RUN apt-get install wget curl
RUN (echo 'deb http://packages.dotdeb.org/ jessie all'> /etc/apt/sources.d/dotdeb.list)
RUN (echo 'deb-src http://packages.dotdeb.org/ jessie all >> /etc/apt/sources.d/dotdeb.list)
RUN (echo 'deb http://ftp.debian.org/debian jessie-backports main' >> /etc/apt/sources.list)
RUN (echo 'deb http://packages.dotdeb.org jessie-nginx-http2 all' > /etc/apt/sources.list.d/nginx.list)
RUN (echo 'deb-src http://packages.dotdeb.org jessie-nginx-http2 all' >> /etc/apt/sources.list.d/nginx.list)
RUN wget https://www.dotdeb.org/dotdeb.gpg -O \
    /tmp/dotdeb.gpg && \
    apt-key add /tmp/dotdeb.gpg && \
    rm /tmp/dotdeb.gpg


RUN apt-get update && \
    apt-get update && \
    apt-get upgrade -y && \
    BUILD_PACKAGES="supervisor nginx php${IMAGE_PHP_VERSION}-fpm git php${IMAGE_PHP_VERSION}-mysql php-apcu php${IMAGE_PHP_VERSION}-curl php${IMAGE_PHP_VERSION}-gettext php${IMAGE_PHP_VERSION}-imap php${IMAGE_PHP_VERSION}-gmp php${IMAGE_PHP_VERSION}-pear php${IMAGE_PHP_VERSION}-mail php${IMAGE_PHP_VERSION}-net-socket php${IMAGE_PHP_VERSION}-net-smtp php${IMAGE_PHP_VERSION}-auth-sasl php${IMAGE_PHP_VERSION}-gd php${IMAGE_PHP_VERSION}-intl php${IMAGE_PHP_VERSION}-mcrypt php${IMAGE_PHP_VERSION}-memcache php${IMAGE_PHP_VERSION}-sqlite php${IMAGE_PHP_VERSION}-tidy php${IMAGE_PHP_VERSION}-xmlrpc php${IMAGE_PHP_VERSION}-xsl php${IMAGE_PHP_VERSION}-pgsql pwgen php${IMAGE_PHP_VERSION}-cli" && \
    apt-get -y install $BUILD_PACKAGES && \
    apt-get autoremove -y && \
    apt-get clean && \
    apt-get autoclean && \
    echo -n > /var/lib/apt/extended_states && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/man/?? && \
    rm -rf /usr/share/man/??_* && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# tweak nginx config
RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
echo "daemon off;" >> /etc/nginx/nginx.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf

# fix ownership of sock file for php-fpm
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/${IMAGE_PHP_VERSION}/fpm/pool.d/www.conf && \
find /etc/php/${IMAGE_PHP_VERSION}/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \; && \
mkdir /run/php

# mycrypt conf
RUN phpenmod mcrypt

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/* && \
rm -Rf /etc/nginx/sites-available/default && \
mkdir -p /etc/nginx/ssl/

COPY ./nginx.conf.tmpl /etc/nginx/sites-available/default.conf

RUN rm -f /etc/nginx/sites-enabled/default

RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default

# Supervisor Config
COPY ./supervisord.conf /etc/supervisord.conf

# Start Supervisord
COPY ./cmd.sh /
RUN chmod 755 /cmd.sh

# add test PHP file
COPY ./index.php /usr/share/nginx/html/index.php
RUN chown -Rf www-data.www-data /usr/share/nginx/html/

# Expose Ports
EXPOSE 80
CMD ["/bin/bash", "/cmd.sh"]
