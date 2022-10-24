#!/usr/bin/env bash
source "$(dirname "$(dirname "$(realpath $0)")")"/config.txt
set -x
docker exec -it "$HOSTNAME" bash -c 'tmux kill-session -t "$APPNAME"'
