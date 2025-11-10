---
title: README
author: Todd Wintermute
date: 2023-12-21
---

# toddwint/transfer


## Info

`transfer` docker image for simple lab testing applications.

Docker Hub: <https://hub.docker.com/r/toddwint/transfer>

GitHub: <https://github.com/toddwint/transfer>


## Overview

Docker image providing the following server services: DHCP, FTP, TFTP, HTTP. Services can be disabled individually by passing environment variables at run time.

Pull the docker image from Docker Hub or, optionally, build the docker image from the source files in the `build` directory.

Create and run the container using `docker run` commands, `docker compose` commands, or by downloading and using the files here on github in the directories `run` or `compose`.

**NOTE: A volume named `public` is created the first time the container is started. Upload the files to that folder.**

Manage the container using a web browser. Navigate to the IP address of the container and one of the `HTTPPORT`s.

Upload files to the container via FTP. Username and password are transfer / transfer [APPNAME / APPNAME].

**NOTE: Network interface must be UP i.e. a cable plugged in.**

Example `docker run` and `docker compose` commands as well as sample commands to create the macvlan are below.


## Features

- Ubuntu base image
- Plus:
  - bsdmainutils
  - ftp
  - fzf
  - iproute2
  - iputils-ping
  - isc-dhcp-server
  - python3-minimal
  - rsyslog
  - tftp-hpa
  - tftpd-hpa
  - tmux
  - tzdata
  - vsftpd
  - webfs
  - [ttyd](https://github.com/tsl0922/ttyd)
    - View the terminal in your browser
  - [frontail](https://github.com/mthenw/frontail)
    - View logs in your browser
    - Mark/Highlight logs
    - Pause logs
    - Filter logs
  - [tailon](https://github.com/gvalkov/tailon)
    - View multiple logs and files in your browser
    - User selectable `tail`, `grep`, `sed`, and `awk` commands
    - Filter logs and files
    - Download logs to your computer


## Sample commands to create the `macvlan`

Create the docker macvlan interface.

```bash
docker network create -d macvlan --subnet=192.168.10.0/24 --gateway=192.168.10.254 \
    --aux-address="mgmt_ip=192.168.10.253" -o parent="eth0" \
    --attachable "transfer01"
```

Create a management macvlan interface.

```bash
sudo ip link add "transfer01" link "eth0" type macvlan mode bridge
sudo ip link set "transfer01" up
```

Assign an IP on the management macvlan interface plus add routes to the docker container.

```bash
sudo ip addr add "192.168.10.253/32" dev "transfer01"
sudo ip route add "192.168.10.0/24" dev "transfer01"
```

## Sample `docker run` command

```bash
docker run -dit \
    --name "transfer01" \
    --network "transfer01" \
    --ip "192.168.10.1" \
    -h "transfer01" \
    -v "${PWD}/public:/opt/transfer/public" \
    -p "192.168.10.1:80:80" \
    -p "192.168.10.1:8080:8080" \
    -p "192.168.10.1:8081:8081" \
    -p "192.168.10.1:8082:8082" \
    -p "192.168.10.1:8083:8083" \
    -e TZ="UTC" \
    -e MGMTIP="192.168.10.253" \
    -e GATEWAY="192.168.10.254" \
    -e HUID="1000" \
    -e HGID="1000" \
    -e ENABLE_DHCP="True" \
    -e ENABLE_HTTP="True" \
    -e ENABLE_TFTP="True" \
    -e ENABLE_FTP="True" \
    -e HTTPPORT1="8080" \
    -e HTTPPORT2="8081" \
    -e HTTPPORT3="8082" \
    -e HTTPPORT4="8083" \
    -e HOSTNAME="transfer01" \
    -e APPNAME="transfer" \
    "toddwint/transfer"
```


## Sample `docker compose` (`compose.yaml`) file

```yaml
name: transfer01

services:
  transfer:
    image: toddwint/transfer
    hostname: transfer01
    ports:
        - "192.168.10.1:80:80"
        - "192.168.10.1:8080:8080"
        - "192.168.10.1:8081:8081"
        - "192.168.10.1:8082:8082"
        - "192.168.10.1:8083:8083"
    networks:
        default:
            ipv4_address: 192.168.10.1
    environment:
        - ENABLE_DHCP=True
        - ENABLE_HTTP=True
        - ENABLE_TFTP=True
        - ENABLE_FTP=True
        - HUID=1000
        - HGID=1000
        - HOSTNAME=transfer01
        - TZ=UTC
        - MGMTIP=192.168.10.253
        - GATEWAY=192.168.10.254
        - HTTPPORT1=8080
        - HTTPPORT2=8081
        - HTTPPORT3=8082
        - HTTPPORT4=8083
    volumes:
      - "${PWD}/public:/opt/transfer/public"
    tty: true

networks:
    default:
        name: "transfer01"
        external: true
```
