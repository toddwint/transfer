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

# Create the webadmin html file from template
htmltemplate="$(dirname "$(realpath $0)")"/webadmin.html.template
htmlfile="$(dirname "$(realpath $0)")"/webadmin.html
cp "$htmltemplate" "$htmlfile"
sed -Ei 's/(Launch page for webadmin)/\1 - '"$HOSTNAME"'/g' "$htmlfile"
sed -Ei 's/\bIPADDR:HTTPPORT1\b/'"$IPADDR"':'"$HTTPPORT1"'/g' "$htmlfile"
sed -Ei 's/\bIPADDR:HTTPPORT2\b/'"$IPADDR"':'"$HTTPPORT2"'/g' "$htmlfile"
sed -Ei 's/\bIPADDR:HTTPPORT3\b/'"$IPADDR"':'"$HTTPPORT3"'/g' "$htmlfile"
sed -Ei 's/\bIPADDR:HTTPPORT4\b/'"$IPADDR"':'"$HTTPPORT4"'/g' "$htmlfile"

# Give the user instructions and offer to launch webadmin page
echo 'Open webadmin.html to use this application (`firefox webadmin.html &`)'
read -rp 'Would you like me to open that now? [Y/n]: ' answer
if [ -z ${answer} ]; then answer='y'; fi
if [[ ${answer,,} =~ ^y ]] 
then
    firefox "$htmlfile" &
fi
