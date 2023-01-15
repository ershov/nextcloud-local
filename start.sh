#!/bin/bash

set -exo pipefail
/etc/init.d/mariadb start
/etc/init.d/redis-server start
/etc/init.d/apache2 start
/etc/init.d/cron start
#/elasticsearch-start.sh

if [[ -z "$1" ]]; then
    while true; do sleep 9999999999; done
else
    exec "$@"
fi
