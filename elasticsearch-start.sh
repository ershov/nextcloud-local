#!/bin/bash

sudo -u elasticsearch -g elasticsearch bash -c '
ES_HOME=/usr/share/elasticsearch
ES_PATH_CONF=/etc/elasticsearch
PID_DIR=/var/run/elasticsearch
ES_SD_NOTIFY=true
. /etc/default/elasticsearch
export ES_HOME
export ES_PATH_CONF
export PID_DIR
export ES_SD_NOTIFY
exec /usr/share/elasticsearch/bin/systemd-entrypoint -p ${PID_DIR}/elasticsearch.pid -d
'

