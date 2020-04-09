#!/bin/sh
# Set working dir to the directory of the script (POSIX/SH compatible)
cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

# Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
docker run --ulimit nofile=90000:90000 --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp \
--net=host -v /LOCAL_CUSTOM_UNBOUND_CONF_DIR:/opt/unbound/etc/unbound/zones \
jedisct1/dnscrypt-server init -N NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER -E WAN_IP_IN_FRONT_OF_THE_dnscrypt-server:443

# Start the dnscrypt-server
docker start dnscrypt-server

# Update the restart policy of the container
docker update --restart=unless-stopped dnscrypt-server
