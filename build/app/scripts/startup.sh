#!/usr/bin/env bash

## Run the commands to make it all work
ln -fs /usr/share/zoneinfo/$TZ /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

echo $HOSTNAME > /etc/hostname

# Extract compressed binaries and move binaries to bin
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    # Unzip frontail and tailon
    gunzip /usr/local/bin/frontail.gz
    gunzip /usr/local/bin/tailon.gz

    # Copy python scripts to /usr/local/bin and make executable
    cp /opt/"$APPNAME"/scripts/ipcalc.py /usr/local/bin
    chmod 755 /usr/local/bin/ipcalc.py
fi

# Link scripts to debug folder as needed
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    ln -s /opt/"$APPNAME"/scripts/tail.sh /opt/"$APPNAME"/debug
    ln -s /opt/"$APPNAME"/scripts/tmux.sh /opt/"$APPNAME"/debug
fi

# Disable rsyslog kernel logs and start rsyslogd
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    sed -Ei '/imklog/s/^([^#])/#\1/' /etc/rsyslog.conf
    sed -Ei '/immark/s/^#//' /etc/rsyslog.conf
    rm -rf /var/log/syslog
else 
    truncate -s 0 /var/log/syslog
fi

# Sometimes rsyslog does not start, so start it and then try again
service rsyslog start
if [ -z $(pidof rsyslogd) ]; then 
    echo 'rsyslog not running'
    service rsyslog start
else 
    echo 'rsyslog is running' 
fi

# Link the log to the app log. Create/clear other log files.
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    mkdir -p /opt/"$APPNAME"/logs
    ln -s /var/log/syslog /opt/"$APPNAME"/logs/"$APPNAME".log
    touch /opt/"$APPNAME"/logs/vsftpd_xfers.log
    #touch /opt/"$APPNAME"/logs/webfsd.log
    #chown www-data:www-data /opt/"$APPNAME"/logs/webfsd.log
else
    truncate -s 0 /opt/"$APPNAME"/logs/vsftpd_xfers.log
    #truncate -s 0 /opt/"$APPNAME"/logs/webfsd.log
fi

# Print first message to either the app log file or syslog
#echo "$(date -Is) [Start of $APPNAME log file]" >> /opt/"$APPNAME"/logs/"$APPNAME".log
logger "[Start of $APPNAME log file]"

# Check if `public` subfolder exists. If non-existing, create it .
# Checking for a file inside the folder because if the folder
#  is mounted as a volume it will already exists when docker starts.
# Also change permissions
if [ ! -e "/opt/$APPNAME/public/.exists" ]
then
    mkdir -p /opt/"$APPNAME"/public
    touch /opt/"$APPNAME"/public/.exists
    echo '`public` folder created'
    chown -R "${HUID}":"${HGID}" /opt/"$APPNAME"/public
fi

if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    # Get IP and subnet information and save to env variables
    # Using python script `ipcalc.py` (adds ~1.6 KB to docker image)
    ipcalc.py $(ip addr show eth0 | mawk '/ inet / {print $2}') > /opt/"$APPNAME"/configs/ipcalc.txt
    IP=$(ip addr show eth0 | mawk '/ inet / {print $2}' | mawk -F/ '{print $1}')
    SUBNET=$(mawk '/Network:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    NETMASK=$(mawk '/Netmask:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    NETMASKBITS=$(mawk '/Netmask_Bits:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    NETWORK=$(mawk '/Network:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    NETWORKADDR=$(mawk '/Network_Addr:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    HOSTMIN=$(mawk '/Host_Min:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    HOSTMAX=$(mawk '/Host_Max:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    BROADCAST=$(mawk '/Broadcast:/ {print $2}' /opt/"$APPNAME"/configs/ipcalc.txt)
    DHCPSTART=$(python3 -c "import ipaddress; print(ipaddress.ip_address('$HOSTMIN') + 2)")
    DHCPEND=$(python3 -c "import ipaddress; print(ipaddress.ip_address('$HOSTMAX') - 2)")
    IPSTART=$(python3 -c "import ipaddress; print(ipaddress.ip_address('$HOSTMIN') + 0)")
    if [ -z "$MGMTIP" ]; then
        MGMTIP=$(python3 -c "import ipaddress; print(ipaddress.ip_address('$HOSTMAX') - 1)")
    fi
    if [ -z "$GATEWAY" ]; then
        GATEWAY=$(python3 -c "import ipaddress; print(ipaddress.ip_address('$HOSTMAX') - 0)")
    fi
    export IP
    export NETMASK
    export NETMASKBITS
    export NETWORK
    export NETWORKADDR
    export HOSTMIN
    export HOSTMAX
    export BROADCAST
    export DHCPSTART
    export DHCPEND
    export IPSTART
    export MGMTIP
    export GATEWAY
fi

if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    # Make copies of template files
    cp /opt/"$APPNAME"/configs/dhcpd.conf.template /opt/"$APPNAME"/configs/dhcpd.conf
    cp /opt/"$APPNAME"/configs/vsftpd.conf.template /opt/"$APPNAME"/configs/vsftpd.conf
    cp /opt/"$APPNAME"/configs/tftpd-hpa.template /opt/"$APPNAME"/configs/tftpd-hpa
    cp /opt/"$APPNAME"/configs/webfsd.conf.template /opt/"$APPNAME"/configs/webfsd.conf

    # Configure isc-dhcp-server interfaces on which to listen
    sed -Ei 's/INTERFACESv4=""/INTERFACESv4="eth0"/' /etc/default/isc-dhcp-server
    sed -Ei 's/INTERFACESv6=""/#INTERFACESv6=""/' /etc/default/isc-dhcp-server

    # isc-dhcp-server template modifications
    sed -Ei 's/^(subnet) 192.168.10.0 (netmask).*/\1 '"$NETWORKADDR"' \2 '"$NETMASK"' {/' /opt/"$APPNAME"/configs/dhcpd.conf
    sed -Ei 's/^(\s+range).*/\1 '"$DHCPSTART"' '"$DHCPEND"';/' /opt/"$APPNAME"/configs/dhcpd.conf
    sed -Ei 's/^(\s+option subnet-mask).*/\1 '"$NETMASK"';/' /opt/"$APPNAME"/configs/dhcpd.conf
    sed -Ei 's/^(\s+option broadcast-address).*/\1 '"$BROADCAST"';/' /opt/"$APPNAME"/configs/dhcpd.conf
    sed -Ei 's/^(\s+option (routers|domain-name-servers)) [0-9.]+;/\1 '"$IP"';/' /opt/"$APPNAME"/configs/dhcpd.conf
    sed -Ei 's/^([# ]+option (tftp-server-name)) "[0-9.]+";/\1 "'"$IP"'";/' /opt/"$APPNAME"/configs/dhcpd.conf

    # vsftpd template modifications
    sed -Ei 's#^((anon|local)_root=).*#\1/opt/'"$APPNAME"'/public#' /opt/"$APPNAME"/configs/vsftpd.conf
    sed -Ei 's#^(xferlog_file=).*#\1/opt/'"$APPNAME"'/logs/vsftpd_xfers.log#' /opt/"$APPNAME"/configs/vsftpd.conf

    # tftpd-hpa template modifications
    sed -Ei 's#^(TFTP_DIRECTORY).*#\1="/opt/'"$APPNAME"'/public"#' /opt/"$APPNAME"/configs/tftpd-hpa

    # webfsd template modifications
    sed -Ei '/^web_root=/c web_root="/opt/'"$APPNAME"'/public"' /opt/"$APPNAME"/configs/webfsd.conf
    #sed -Ei '/^web_accesslog=/c web_accesslog="/opt/'"$APPNAME"'/logs/webfsd.log"' /opt/"$APPNAME"/configs/webfsd.conf

    # Copy templates to configuration locations
    cp /opt/"$APPNAME"/configs/dhcpd.conf /etc/dhcp/dhcpd.conf
    cp /opt/"$APPNAME"/configs/vsftpd.conf /etc/vsftpd.conf
    cp /opt/"$APPNAME"/configs/tftpd-hpa /etc/default/tftpd-hpa
    cp /opt/"$APPNAME"/configs/webfsd.conf /etc/webfsd.conf
fi

# Remove service pid(s) if it exists.
rm -rf /var/run/dhcpd.pid
rm -rf /var/run/webfs/webfsd.pid

# Start services
if [ -z $ENABLE_FTP ]; then $ENABLE_FTP='t'; fi
if [[ ${ENABLE_FTP,,} =~ ^t ]] 
then
    service vsftpd start
fi
if [ -z $ENABLE_TFTP ]; then $ENABLE_TFTP='t'; fi
if [[ ${ENABLE_TFTP,,} =~ ^t ]] 
then
    service tftpd-hpa start
fi
if [ -z $ENABLE_HTTP ]; then $ENABLE_HTTP='t'; fi
if [[ ${ENABLE_HTTP,,} =~ ^t ]] 
then
    service webfs start
fi
if [ -z $ENABLE_DHCP ]; then $ENABLE_DHCP='t'; fi
if [[ ${ENABLE_DHCP,,} =~ ^t ]] 
then
    service isc-dhcp-server start
fi

# Start web interface
NLINES=1000
cp /opt/"$APPNAME"/configs/tmux.conf /root/.tmux.conf
sed -Ei 's/tail -n 500/tail -n '"$NLINES"'/' /opt/"$APPNAME"/scripts/tail.sh
# ttyd tail with color and read only
nohup ttyd -p "$HTTPPORT1" -R -t titleFixed="${APPNAME}.log" -t fontSize=16 -t 'theme={"foreground":"black","background":"white", "selection":"red"}' /opt/"$APPNAME"/scripts/tail.sh >> /opt/"$APPNAME"/logs/ttyd1.log 2>&1 &
# ttyd tail without color and read only
#nohup ttyd -p "$HTTPPORT1" -R -t titleFixed="${APPNAME}.log" -T xterm-mono -t fontSize=16 -t 'theme={"foreground":"black","background":"white", "selection":"red"}' /opt/"$APPNAME"/scripts/tail.sh >> /opt/"$APPNAME"/logs/ttyd1.log 2>&1 &
sed -Ei 's/tail -n 500/tail -n '"$NLINES"'/' /opt/"$APPNAME"/scripts/tmux.sh
# ttyd tmux with color
nohup ttyd -p "$HTTPPORT2" -t titleFixed="${APPNAME}.log" -t fontSize=16 -t 'theme={"foreground":"black","background":"white", "selection":"red"}' /opt/"$APPNAME"/scripts/tmux.sh >> /opt/"$APPNAME"/logs/ttyd2.log 2>&1 &
# ttyd tmux without color
#nohup ttyd -p "$HTTPPORT2" -t titleFixed="${APPNAME}.log" -T xterm-mono -t fontSize=16 -t 'theme={"foreground":"black","background":"white", "selection":"red"}' /opt/"$APPNAME"/scripts/tmux.sh >> /opt/"$APPNAME"/logs/ttyd2.log 2>&1 &
nohup frontail -n "$NLINES" -p "$HTTPPORT3" /opt/"$APPNAME"/logs/"$APPNAME".log >> /opt/"$APPNAME"/logs/frontail.log 2>&1 &
sed -Ei 's/\$lines/'"$NLINES"'/' /opt/"$APPNAME"/configs/tailon.toml
sed -Ei '/^listen-addr = /c listen-addr = [":'"$HTTPPORT4"'"]' /opt/"$APPNAME"/configs/tailon.toml
nohup tailon -c /opt/"$APPNAME"/configs/tailon.toml /opt/"$APPNAME"/logs/"$APPNAME".log /opt/"$APPNAME"/logs/vsftpd_xfers.log /etc/dhcp/dhcpd.conf /etc/vsftpd.conf /etc/default/tftpd-hpa /var/lib/dhcp/dhcpd.leases /opt/"$APPNAME"/logs/ttyd1.log /opt/"$APPNAME"/logs/ttyd2.log /opt/"$APPNAME"/logs/frontail.log /opt/"$APPNAME"/logs/tailon.log >> /opt/"$APPNAME"/logs/tailon.log 2>&1 &

# Remove the .firstrun file if this is the first run
if [ -e /opt/"$APPNAME"/scripts/.firstrun ]; then
    rm -f /opt/"$APPNAME"/scripts/.firstrun
fi

# Keep docker running
bash
