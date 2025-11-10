FROM toddwint/mybaseimage
COPY app /opt/transfer
LABEL LICENSE="GPL-3.0-or-later"
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    TZ=UTC \
    HTTPPORT1=8080 \
    HTTPPORT2=8081 \
    HTTPPORT3=8082 \
    HTTPPORT4=8083 \
    HUID=0 \
    HGID=0 \
    ENABLE_DHCP=True \
    ENABLE_HTTP=True \
    ENABLE_TFTP=True \
    ENABLE_FTP=True \
    HOSTNAME=transfersrvr \
    APPNAME=transfer
RUN apt-get update \
    && \
    apt-get install -y \
    rsyslog \
    isc-dhcp-server \
    ftp \
    vsftpd \
    tftp-hpa \
    tftpd-hpa \
    webfs \
    && \
    echo $HOSTNAME > /etc/hostname \
    && \
    apt-get autoremove -y \
    && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /opt/transfer/debug
CMD ["/opt/transfer/scripts/startup.sh"]
