# syntax=docker/dockerfile:1

# Run with DOCKER_BUILDKIT=1 # BUILDKIT_PROGRESS=plain

FROM scratch
RUN <<EOF :
ERROR-----Must-run-with-----DOCKER_BUILDKIT=1
EOF

# https://docs.nextcloud.com/server/22/admin_manual/installation/example_ubuntu.html

FROM ubuntu AS build_nextcloud
SHELL ["/bin/bash", "-c"]

RUN echo Using database: ${database:-mysql}

# Packeges
RUN set -uexo pipefail; apt update -y; \
  DEBIAN_FRONTEND=noninteractive apt install -y \
  apache2 mariadb-server libapache2-mod-php \
  php-gd php-curl php-mbstring php-intl \
  php-gmp php-bcmath php-imagick php-xml php-zip \
  libmagickcore-6.q16-6-extra \
  php-mysql \
  redis-server php-redis \
  curl sudo netcat-openbsd \
  cron \
  ; rm -rf /var/lib/apt/lists/*

# Set up mysql
COPY mysql-init.sql /
RUN set -uexo pipefail; /etc/init.d/mariadb start; mysql < /mysql-init.sql

# Download nextcloud
RUN set -uexo pipefail; \
  mkdir -p /var/www/nextcloud; \
  chown -R www-data:www-data /var/www/nextcloud
USER www-data:www-data
RUN curl -sL https://download.nextcloud.com/server/releases/latest.tar.bz2 | tar jxf - -C /var/www/nextcloud --strip-components=1
USER 0:0

# https://docs.nextcloud.com/server/22/admin_manual/installation/source_installation.html#apache-configuration-label

# Enable nextcloud site
COPY nextcloud.conf /etc/apache2/sites-available/nextcloud.conf
RUN set -uexo pipefail; \
  a2ensite nextcloud.conf; \
  a2enmod rewrite; \
  a2enmod headers; \
  a2enmod env; \
  a2enmod dir; \
  a2enmod mime; \
  a2enmod setenvif; \
  :

# Enable SSL
#RUN set -uexo pipefail; \
#  a2enmod ssl; \
#  a2ensite default-ssl; \
#  #service apache2 reload

# Configure nextcloud

RUN set -uexo pipefail; \
  perl -np -i -E 'for $k ( \
    [memory_limit => "512M"], \
    [upload_max_filesize => "20M"], \
    [max_file_uploads => "100"], \
  ) { s{^\s*$k->[0]\s*=.*$}{$k->[0] = $k->[1]}; } ' etc/php/8.1/apache2/php.ini; \
  :

# https://docs.nextcloud.com/server/22/admin_manual/installation/command_line_installation.html

# Install nextcloud
RUN set -uexo pipefail; \
  /etc/init.d/mariadb start; \
  php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud"  --database-user "root" --database-pass "" --admin-user "admin" --admin-pass "admin"; \
  find /var/www/nextcloud -user 0 -ls -exec chown www-data:www-data '{}' \; ; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ maintenance:update:htaccess; \
  sudo -u www-data -g www-data perl -np -i -E '/\$CONFIG/ and $_ .= qq{  "trusted_domains" => array(0=>"*"),\n}' /var/www/nextcloud/config/config.php; \
  sudo -u www-data -g www-data perl -np -i -E '$_ .= "return true;  // PATCH\n" if /\Qfunction isTrustedDomain(/' /var/www/nextcloud/lib/private/Security/TrustedDomainHelper.php; \
  sudo -u www-data -g www-data perl -np -i -E '$_ .= "return [];  // PATCH\n" if /\Qfunction checkDataDirectoryPermissions(/' /var/www/nextcloud/lib/private/legacy/OC_Util.php; \
  echo "ALTER USER 'oc_admin'@'localhost' IDENTIFIED BY 'nextcloud'" | mysql; \
  sudo -u www-data -g www-data perl -np -i -E 's{^\s*[\x27"](dbpassword)[\x27"]\s*=>.*$}{"$1" => "nextcloud",}' /var/www/nextcloud/config/config.php; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ config:app:set password_policy minLength --value=3; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ config:app:set password_policy enforceHaveIBeenPwned --value=0; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ config:app:set files_scripts php_interpreter --value=true; \
  :

# Configure Redis cache
RUN set -uexo pipefail; \
  /etc/init.d/mariadb start; \
  /etc/init.d/redis-server start; \
  sudo -u www-data -g www-data perl -np -i -E '/\$CONFIG/ and $_ .= qq{"memcache.distributed" => "\x5cOC\x5cMemcache\x5cRedis",\n"memcache.local" => "\x5cOC\x5cMemcache\x5cRedis",\n"memcache.locking" => "\x5cOC\x5cMemcache\x5cRedis",\n"redis" => array("host" => "localhost", "port" => 6379),\n}' /var/www/nextcloud/config/config.php; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ db:add-missing-indices; \
  :

# Install apps
RUN set -uexo pipefail; \
  /etc/init.d/mariadb start; \
  /etc/init.d/redis-server start; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install theming_customcss; \
  #sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install side_menu; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_archive; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install workflow_media_converter; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install camerarawpreviews; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_scripts; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install groupfolders; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_linkeditor; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install metadata; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install integration_youtube; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install audioplayer; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install memories; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install music; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_photospheres; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install maps; \
  #sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install spreed; \
  mkdir -p /mnt/data; \
  chmod 777 /mnt/data; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_external || true; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:enable files_external; \
  sudo -u www-data -g www-data php /var/www/nextcloud/occ files_external:create data local null::null -c datadir=/mnt/data; \
  :
##RUN set -uexo pipefail; \
##  /etc/init.d/mariadb start; \
##  /etc/init.d/redis-server start; \
##  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install recognize; \
##  :
####RUN set -uexo pipefail; \
####  /etc/init.d/mariadb start; \
####  /etc/init.d/redis-server start; \
####  set -ex; apt update -y; DEBIAN_FRONTEND=noninteractive apt install -y php-pear php-dev; rm -rf /var/lib/apt/lists/*; pecl install inotify; \
####  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_inotify; \
####  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install facerecognition; \
####  :
USER www-data:www-data
USER 0:0

# sudo -u www-data php /var/www/nextcloud/occ files:scan --all

################################################################################
#### Install Elasticsearch {
###
###RUN set -uexo pipefail; \
###  /etc/init.d/mariadb start; \
###  /etc/init.d/redis-server start; \
###  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install fulltextsearch; \
###  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install fulltextsearch_elasticsearch; \
###  sudo -u www-data -g www-data php /var/www/nextcloud/occ app:install files_fulltextsearch; \
###  :
###
#### https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html
#### https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
#### https://github.com/nextcloud/vm/blob/master/apps/fulltextsearch.sh
###RUN set -uexo pipefail; \
###  cd /tmp; \
###  curl -sLO https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.6.0-amd64.deb; \
###  curl -sLO https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.6.0-amd64.deb.sha512; \
###  shasum -a 512 -c elasticsearch-8.6.0-amd64.deb.sha512; \
###  dpkg -i elasticsearch-8.6.0-amd64.deb; \
###  rm elasticsearch-8.6.0-amd64.deb elasticsearch-8.6.0-amd64.deb.sha512; \
###  mkdir -p /var/run/elasticsearch; \
###  chown elasticsearch:elasticsearch /var/run/elasticsearch; \
###  :
###COPY elasticsearch-start.sh elasticsearch-stop.sh /
###RUN set -uexo pipefail; \
###  /elasticsearch-start.sh; \
###  /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -f -b | perl -nE 'print $1 if /^New value: (.*)$/' > /elastic-pwd; \
###  { echo nextcloud; echo nextcloud; } | /usr/share/elasticsearch/bin/elasticsearch-users useradd nextcloud; \
###  /etc/init.d/mariadb start; \
###  /etc/init.d/redis-server start; \
###  sudo -u www-data -g www-data php /var/www/nextcloud/occ fulltextsearch:configure '{"search_platform":"OCA\\FullTextSearch_Elasticsearch\\Platform\\ElasticSearchPlatform", "app_navigation": "1"}'; \
###  sudo -u www-data php /var/www/nextcloud/occ fulltextsearch_elasticsearch:configure '{"elastic_host": "http://nextcloud:nextcloud@127.0.0.1:9200/", "elastic_index": "nextcloud"}'; \
###  sudo -u www-data php /var/www/nextcloud/occ files_fulltextsearch:configure '{"files_local": "1", "files_external": "1", "files_group_folders": "1", "files_size": "20", "files_office": "1", "files_pdf": "1", "files_zip": "0", "files_image": "1", "files_audio": "1"}'; \
###  sudo -u www-data php /var/www/nextcloud/occ fulltextsearch:check; \
###  #sudo -u www-data php /var/www/nextcloud/occ fulltextsearch:test; \
###  :
###
#### }
################################################################################

# Set up cron
RUN crontab -u www-data - <<_END
SHELL=/bin/bash
*/5 * * * * php -f /var/www/nextcloud/cron.php >& /dev/null
*/5 * * * * php /var/www/nextcloud/occ files:scan -p /admin/files/data/ --unscanned -n >& /dev/null
15 4 * * * php /var/www/nextcloud/occ files:scan -p /admin/files/data/ -n >& /dev/null
15 3 * * * php /var/www/nextcloud/occ memories:index >& /dev/null
15 2 * * * php /var/www/nextcloud/occ music:scan --all >& /dev/null
_END

# Finalize
VOLUME /var/lib/mysql /var/log /mnt/data /var/www/nextcloud/data
EXPOSE 80/tcp
COPY start.sh /

FROM build_nextcloud AS nextcloud

CMD ["/bin/bash", "-c", "while true; do sleep 99999; done"]
ENTRYPOINT ["/start.sh"]
HEALTHCHECK CMD /healthcheck.sh

