#!/bin/sh
# Set working dir to the directory of the script (POSIX/SH compatible)
cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

# Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
docker-compose up -d

# Output the log
docker-compose logs
