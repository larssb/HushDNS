#!/bin/sh
# Set working dir to the directory of the script (POSIX/SH compatible)
cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

# Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
# REMEMBER! to change the volume mounts in the docker-compose.yml
docker compose run dnscrypt-server init -N NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER -E WAN_IP_IN_FRONT_OF_THE_dnscrypt-server:443
