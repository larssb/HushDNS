#!/bin/sh
# Set working dir to the directory of the script (POSIX/SH compatible)
cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

# Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
docker run --ulimit nofile=90000:90000 --name=dnscrypt-server -p 4443:443/udp -p 4443:443/tcp --network=piholed_static-network \
--ip 172.20.128.3 jedisct1/dnscrypt-server init -N hush.dns -E 172.20.128.3:4443

# Start the dnscrypt-server
docker start dnscrypt-server

# Update the restart policy of the container
docker update --restart=unless-stopped dnscrypt-server
