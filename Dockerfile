FROM alpine
MAINTAINER Shing.L <icodex@msn.com>

## Mysql
RUN addgroup -S mysql \
    && adduser -S mysql -G mysql \
    && apk update \
    && apk add --update bash vim vimdiff ca-certificates supervisor wget git mysql \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /var/log/supervisor \
    && chmod -R 777 /var/log/supervisor

RUN awk '{ print } $1 ~ /\[mysqld\]/ && c == 0 { c = 1; print "skip-host-cache\nskip-name-resolve\nlower_case_table_names=1"}' /etc/mysql/my.cnf > /tmp/my.cnf \
    && mv /tmp/my.cnf /etc/mysql/my.cnf \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld \
    && chmod -R 777 /run/mysqld

RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

# php7-fpm
RUN apk update \
    && apk add php7-intl php7-openssl php7-dba php7-sqlite3 php7-pear \
	php7-tokenizer php7-phpdbg php7-gmp php7-pdo_mysql php7-pcntl \
	php7-common php7-xsl php7-fpm php7-imagick php7-mysqlnd \
	php7-enchant php7-pspell php7-redis php7-snmp php7-fileinfo \
	php7-mbstring php7-dev php7-xmlrpc php7-embed php7-xmlreader \
	php7-pdo_sqlite php7-exif php7-opcache php7-ldap php7-posix \
	php7-session php7-gd php7-gettext php7-json php7-xml php7-iconv \
	php7-sysvshm php7-curl php7-shmop php7-odbc php7-phar php7-pdo_pgsql \
	php7-imap php7-pdo_dblib php7-pgsql php7-zip php7-cgi php7-ctype \
	php7-mcrypt php7-wddx php7-bcmath php7-calendar php7-tidy php7-dom \
	php7-sockets php7-memcached php7-soap php7-sysvmsg php7-zlib \
	php7-imagick-dev php7-ftp php7-sysvsem php7-pdo php7-bz2 php7-mysqli \
	php7-simplexml php7-xmlwriter \
    && rm -f /var/cache/apk/* \
	&& mkdir -p /run/php-fpm \
	&& chown -R nobody:nobody /run/php-fpm \
	&& chmod -R 777 /run/php-fpm \
	&& echo "Success"

RUN mv /etc/php7/php-fpm.conf /etc/php7/php-fpm.conf.origin
ADD ./php-fpm.conf /etc/php7/

RUN mv /etc/php7/php-fpm.d/www.conf /etc/php7/php-fpm.d/www.conf.origin
ADD ./www.conf /etc/php7/php-fpm.d/

RUN sed -i'' 's#^\(open_basedir.*$\)#;\1#g' /etc/php7/php.ini
RUN sed -i'' 's#^;\(opcache.enable=\).*$#\11#g' /etc/php7/php.ini
RUN sed -i'' 's#^;\(opcache.enable_cli=\).*$#\11#g' /etc/php7/php.ini
RUN sed -i'' 's#^\(post_max_size = \).*$#\150M#g' /etc/php7/php.ini
RUN sed -i'' 's#^\(upload_max_filesize = \).*$#\150M#g' /etc/php7/php.ini
RUN sed -i'' 's#^\(short_open_tag = \).*$#\1On#g' /etc/php7/php.ini
RUN sed -i'' 's#^\(max_execution_time = \).*$#\1300#g' /etc/php7/php.ini
RUN sed -i'' 's#^;\(error_log = \).*\.log$#\1/var/log/php7/php_errors.log#g' /etc/php7/php.ini


# apache2
RUN apk --update add apache2 apache2-proxy apache-mod-fcgid apache2-ssl apache2-http2 apache2-lua apache2-utils curl \
    && rm -f /var/cache/apk/* \
    && mkdir -p /run/apache2 \
    && chown -R apache:apache /run/apache2 \
    && chmod -R 777 /run/apache2 \
	&& curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && mkdir -p /app && chown -R apache:apache /app \
    && echo "Success"

RUN sed -i'' 's:^#\(LoadModule deflate_module.*$\):\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^#\(LoadModule mpm_event_module.*$\):\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^\(LoadModule mpm_prefork_module.*$\):#\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^#\(LoadModule rewrite_module.*$\):\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^#\(LoadModule slotmem_shm_module.*$\):\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^#\(LoadModule slotmem_plain_module.*$\):\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's:^#\(ServerName www.example.com\).*$:\1:g' /etc/apache2/httpd.conf
RUN sed -i'' 's#\(AllowOverride\).*#\1 All#' /etc/apache2/httpd.conf
RUN sed -i'' 's#^\(DocumentRoot\).*$#\1 /app#g' /etc/apache2/httpd.conf
RUN sed -i'' 's#^\(<Directory \).*htdocs">$#\1 "/app">#g' /etc/apache2/httpd.conf
RUN sed -i'' 's#\(ScriptAlias /cgi-bin/\).*\>$#\1 "/app/cgi-bin/">#g' /etc/apache2/httpd.conf
RUN sed -i'' 's#^\(<Directory \).*cgi-bin">$#\1 "/app/cgi-bin/">#g' /etc/apache2/httpd.conf

RUN sed -i'' 's:^\(LoadModule authn_file_module.*$\):# PHP-FPM default settings\nInclude /etc/apache2/conf.d/httpd-php.conf\n# PhpMyAdmin settings\nInclude /etc/apache2/conf.d/phpmyadmin.conf\n\1:g' /etc/apache2/httpd.conf

ADD ./httpd-php.conf /etc/apache2/conf.d/
ADD ./phpmyadmin.conf /etc/apache2/conf.d/


# redis & memcached
RUN apk apk update \
    && apk add --update redis memcached \
    && rm -f /var/cache/apk/* \
    && chown redis:redis /etc/redis.conf \
    && mkdir -p /var/log/redis \
    && chown -R redis:redis /var/log/redis \
    && chmod -R 777 /var/log/redis


RUN sed -i'' 's#^\(daemonize\).*yes$#\1 no#g' /etc/redis.conf

# supervisor
RUN mkdir -p /etc/supervisor.d
ADD ./init.ini /etc/supervisor.d/

# phpmyadmin
RUN mkdir -p /var/www/html \
	&& cd /var/www/html \
	&& wget "https://files.phpmyadmin.net/phpMyAdmin/4.7.4/phpMyAdmin-4.7.4-all-languages.tar.gz" -O - |tar -zxvf - \
	&& mv phpMyAdmin-4.7.4-all-languages/ phpMyAdmin \
	&& chown -R apache:apache /var/www/html

RUN find /var/log/ -type f -exec rm -f {} \;

# PORT
EXPOSE 80
EXPOSE 22

# VOLUME
VOLUME /app

CMD ["supervisord", "-n"]
