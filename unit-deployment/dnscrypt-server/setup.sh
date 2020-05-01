#!/bin/sh
# Set working dir to the directory of the script (POSIX/SH compatible)
cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

# Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
docker run --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp \
--restart=unless-stopped \
-v /LOCAL_CUSTOM_DNSCRYPT_SERVER_CONF_DIR/unbound-conf:/opt/unbound/etc/unbound/zones \
-v /LOCAL_CUSTOM_DNSCRYPT_SERVER_CONF_DIR/keys:/opt/encrypted-dns/etc/keys \
jedisct1/dnscrypt-server init -N NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER -E WAN_IP_IN_FRONT_OF_THE_dnscrypt-server:443
