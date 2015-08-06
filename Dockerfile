#
# link:
# https://github.com/ngineered/nginx-php-fpm
# https://github.com/fideloper/docker-nginx-php
# https://github.com/ishakuta/docker-nginx-php5
#
FROM ubuntu:14.04
MAINTAINER gaoermai

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Surpress Upstart errors/warning
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Update base image
# Add sources for latest nginx
# Install software requirements
RUN apt-get update && \
  apt-get install -y software-properties-common && \
  nginx=stable && \
  add-apt-repository ppa:nginx/$nginx && \
  apt-get update && \
  apt-get upgrade -y && \
  BUILD_PACKAGES="supervisor nginx php5-fpm git php5-mysql php5-mysql php-apc php5-curl php5-gd php5-intl php5-mcrypt php5-memcache php5-sqlite php5-tidy php5-xmlrpc php5-xsl php5-pgsql php5-mongo php-gettext php5-dev libpcre3-dev pwgen" && \
  apt-get -y install $BUILD_PACKAGES

# tweak nginx config
RUN sed -i -e"s/worker_processes  1/worker_processes 5/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf && \
sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf && \
echo "daemon off;" >> /etc/nginx/nginx.conf

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/* && \
rm -Rf /etc/nginx/sites-available/default && \
mkdir -p /etc/nginx/ssl/
ADD ./nginx-site.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i "s/;date.timezone =.*/date.timezone = Asia\/Shanghai/" /etc/php5/fpm/php.ini

# fix ownership of sock file for php-fpm
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/fpm/pool.d/www.conf && \
find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# tweak php-cli config
RUN sed -i "s/;date.timezone =.*/date.timezone = Asia\/Shanghai/" /etc/php5/cli/php.ini

# install php-yaf framewrok
RUN pecl install yaf
ADD ./yaf.ini /etc/php5/mods-available/yaf.ini
RUN ln -s /etc/php5/mods-available/yaf.ini /etc/php5/fpm/conf.d/20-yaf.ini
RUN ln -s /etc/php5/mods-available/yaf.ini /etc/php5/cli/conf.d/20-yaf.ini

# install composer and phpunit
RUN curl -sS https://getcomposer.org/installer | php && \
  mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer && \
  mkdir /root/.composer/
ADD composer.json /root/.composer/composer.json
RUN cd /root/.composer && \
  /usr/local/bin/composer install && \
  rm -rf /root/.composer/cache/* && \
  echo "export PATH=$PATH:/root/.composer/vendor/bin:" >> /root/.bashrc

# Add git commands to allow container updating
ADD ./git-pull /usr/bin/git-pull
ADD ./git-push /usr/bin/git-push
RUN chmod 755 /usr/bin/git-pull && chmod 755 /usr/bin/git-push

# Supervisor Config
ADD ./supervisord.conf /etc/supervisord.conf

# Start Supervisord
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# Setup Volume
VOLUME ["/data/webroot"]

# add test PHP file
ADD ./index.php /data/webroot/index.php
RUN chown -Rf www-data.www-data /data/webroot/

# Expose Ports
EXPOSE 443
EXPOSE 80

# cleanup
RUN apt-get remove --purge -y software-properties-common && \
  apt-get autoremove -y && \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /usr/share/man/?? && \
  rm -rf /usr/share/man/??_* && \
  rm -rf /var/lib/apt/lists/* && \
  echo -n > /var/lib/apt/extended_states && \
  rm -rf /tmp/* /var/tmp/*

CMD ["/bin/bash", "/start.sh"]
