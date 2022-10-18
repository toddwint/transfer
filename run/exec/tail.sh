#!/usr/bin/env bash
APPNAME=transfer
source "$(dirname "$(dirname "$(realpath $0)")")"/config.txt
docker exec -it -w /opt/"$APPNAME"/scripts "$HOSTNAME" ./tail.sh
