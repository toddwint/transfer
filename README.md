# toddwint/transfer

## Info

`transfer` docker image for simple lab testing applications.

Docker Hub: <https://hub.docker.com/r/toddwint/transfer>

GitHub: <https://github.com/toddwint/transfer>


## Features

- Ubuntu base image
- Plus:
  - ftp
  - isc-dhcp-server
  - rsyslog
  - tftp
  - tftpd-hpa
  - vsftpd
  - webfs
  - tmux
  - python3-minimal
  - iproute2
  - tzdata
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


## Sample `config.txt` file

```
# To get a list of timezones view the files in `/usr/share/zoneinfo`
TZ=UTC

# The interface on which to set the IP. Run `ip -br a` to see a list
INTERFACE=eth0

# The IP address that will be set on the docker container
# The first 2 and last 2 IPs in the subnet are available for use.
IPADDR=192.168.10.1

# The IP address that will be set on the host to manage the docker container
# The first 2 and last 2 IPs in the subnet are available for use.
MGMTIP=192.168.10.253

# The IP subnet in the form subnet/cidr
SUBNET=192.168.10.0/24

# The IP of the gateway. 
# Don't leave blank. Enter a valid ip from the subnet range
# The first 2 and last 2 IPs in the subnet are available for use.
GATEWAY=192.168.10.254

# Set to False to disable any of the following services
# If left blank, the default is True
ENABLE_DHCP=True
ENABLE_HTTP=True
ENABLE_TFTP=True
ENABLE_FTP=True

# The ports for web management access of the docker container.
# ttyd tail, ttyd tmux, frontail, and tmux respectively
HTTPPORT1=8080
HTTPPORT2=8081
HTTPPORT3=8082
HTTPPORT4=8083

# The hostname of the instance of the docker container
HOSTNAME=transfersrvr01
```


## Sample docker run script

```
#!/usr/bin/env bash
REPO=toddwint
APPNAME=transfer
HUID=$(id -u)
HGID=$(id -g)
source "$(dirname "$(realpath $0)")"/config.txt

# Make the macvlan needed to listen on ports
# Set the IP on the host and add a route to the container
docker network create -d macvlan --subnet="$SUBNET" --gateway="$GATEWAY" \
  --aux-address="mgmt_ip=$MGMTIP" -o parent="$INTERFACE" \
  "$HOSTNAME"
sudo ip link add "$HOSTNAME" link "$INTERFACE" type macvlan mode bridge
sudo ip addr add "$MGMTIP"/32 dev "$HOSTNAME"
sudo ip link set "$HOSTNAME" up
sudo ip route add "$IPADDR"/32 dev "$HOSTNAME"

# Create the docker container
docker run -dit \
    --name "$HOSTNAME" \
    --net="$HOSTNAME" \
    --ip $IPADDR \
    -h "$HOSTNAME" \
    ` # Volume can be changed to another folder. For Example: ` \
    ` # -v /home/"$USER"/Desktop/captures:/opt/"$APPNAME"/scripts/captures \ ` \
    -v "$(dirname "$(realpath $0)")"/public:/opt/"$APPNAME"/public \
    -p "$IPADDR":"$HTTPPORT1":"$HTTPPORT1" \
    -p "$IPADDR":"$HTTPPORT2":"$HTTPPORT2" \
    -p "$IPADDR":"$HTTPPORT3":"$HTTPPORT3" \
    -p "$IPADDR":"$HTTPPORT4":"$HTTPPORT4" \
    -e TZ="$TZ" \
    -e HUID="$HUID" \
    -e HGID="$HGID" \
    -e ENABLE_DHCP="$ENABLE_DHCP" \
    -e ENABLE_HTTP="$ENABLE_HTTP" \
    -e ENABLE_TFTP="$ENABLE_TFTP" \
    -e ENABLE_FTP="$ENABLE_FTP" \
    -e HTTPPORT1="$HTTPPORT1" \
    -e HTTPPORT2="$HTTPPORT2" \
    -e HTTPPORT3="$HTTPPORT3" \
    -e HTTPPORT4="$HTTPPORT4" \
    -e HOSTNAME="$HOSTNAME" \
    -e APPNAME="$APPNAME" \
    `# --cap-add=NET_ADMIN \ ` \
    ${REPO}/${APPNAME}
```


## Login page

Open the `webadmin.html` file.

- Or just type in your browser: 
  - `http://<ip_address>:<port1>` or
  - `http://<ip_address>:<port2>` or
  - `http://<ip_address>:<port3>`
  - `http://<ip_address>:<port4>`
