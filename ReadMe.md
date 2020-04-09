# HushDNS

A project made for hushing the leaky nature of standard DNS query usage. By using [encryption][DNSCryptProject], [DNS Query Name Mimisation][DQM], [DNSSEC][DNSSEC], [Anonymized-DNS][AnonymizedDNS] and [Pi-hole][PiHole].

This repository contains guidance on how-to get `HushDNS` up and running and the files related to doing so.

For an in depth detailed rundown of the ins and outs of the `HushDNS` components and the background of the **HushDNS** project. Read the initial [HushDNS blog post][hush-dns-blog-post].

## Making it work for ya

### Pre-requisites

1. `docker` have to be installed
1. `docker-compose` as well
1. *optionally* a server away from your LAN, where `dnscrypt-server` can run. This heightens the anonymity and privacy level of the solution. As it will be harder to trace the origin of 'x' DNS query
    1. You can run the `dnscrypt-server` on a box on your LAN though. It would work fine. However, not with the same level of privacy and anonymity. So you really should consider isolating it on an external host

### Doin' it

The order of the below component installation guidelines **is** important

#### Running dnscrypt-server

The [dnscrypt-server][dnscrypt-server] packs **unbound**, a DNS recursive name-server, wrapped in the [`encrypted-dns-server` project][encrypted-dns-server-proxy]. It's an easy to install, high-performant, zero maintenance way to run your own DNS recursive name-server in a secure and private way. Letting you control logging and so forth.

> N.B. we need to install the `dnscrypt-server` first as it generates a so called `stamp` that we need to "give" to the `dnscrypt-proxy` instance. This stamp holds information and a unique signature that is needed to connect to the `dnscrypt-server`

**If you plan to use e.g. `CloudFlare` or `Scaleway` to be your encrypted DNS recursive name-server provider, you can skip installing the `dnscrypt-server`. Instead jump to the [Running dnscrypt-proxy](#Running-dnscrypt-proxy) section. Duly note that you will certainly NOT have a private setup. Encrypted yes, but your DNS queries will be in the hands of e.g. `CloudFlare` or `Scaleway`. Do you really want that?**

As the `dnscrypt-server` needs an `init` container, and that is [not supported][docker-init-container] by the `Docker` engine, you'll have to do with a shell script.

1. Create a file with the following content. Ensure to update the placeholders (capital words, separated by an underscore) with actual useful values

    ```bash
    #!/bin/sh
    # Set working dir to the dir of the script (POSIX/SH compatible)
    cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

    # Initialize the dnscrypt-server. Pre-requisite for running the full svc. afterwards
    docker run --ulimit nofile=90000:90000 --name=dnscrypt-server -p 443:443/udp -p 443:443/tcp --net=host \
    -v /LOCAL_CUSTOM_UNBOUND_CONF_DIR:/opt/unbound/etc/unbound/zones jedisct1/dnscrypt-server \
    init -N NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER -E WAN_IP_IN_FRONT_OF_THE_dnscrypt-server:443

    # Start the dnscrypt-server
    docker start dnscrypt-server

    # Update the restart policy of the container
    docker update --restart=unless-stopped dnscrypt-server
    ```

    1. Change the port of the `dnscrypt-server` if you need to (already have 'x' service running on port 443)
    2. Make the file executable by executing: `sudo chmod +x ./THE_NAME_YOU_GAVE_THE_FILE`
2. Execute the file on the system that is to host the `dnscrypt-server`
3. Note down the output of the `init -N NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER...` command as you need the info when configuring `dnscrypt-proxy`
   1. you can also get the input after the fact by executing `docker logs dnscrypt-server`
   2. The output to copy is the generated `stamp`. You need this in order to connect to the `dnscrypt-server` via the `dnscrypt-proxy` ... we will set the stamp when we install and configure the `dnscrypt-proxy` instance

#### Running dnscrypt-proxy

The `dnscrypt-proxy` instance uses [this][dnscrypt-proxy-container-image] container image. It acts as an encrypting intermediary DNS forwarder. Between a non-DoH/DoT/DNSCrypt supporting DNS recursive name-server (in the `HushDNS` case, its `Pi-hole`) and e.g. a `dnscrypt-server` instance or a service like [`CloudFlare's` 1.1.1.1 service][CloudFlare-1.1.1.1].

1. Download [this docker-compose file][dnscrypt-proxyDockerComposeFile]
2. Execute: `docker-compose --project-name dnscrypt-proxy -f ./PATH_TO_THE_DNSCRYPT_PROXY_DOCKER_COMPOSE_FILE up -d`
   1. This will install `dnscrypt-proxy`. Name the compose "project" and container **dnscrypt-proxy** and detach from the container

##### Settings for the dnscrypt-proxy container

- `DNSCRYPT_LISTEN_PORT`: "5354": Self-explanatory
- `DNSCRYPT_SERVER_NAMES`: "['MY_SECRET_DNSCRYPT-SERVER']": The dnscrypt-server or DoH server that `dnscrypt-proxy` should connect to. The *NAME_TO_GIVE_YOUR_DNSCRYPT_SERVER* part of the `dnscrypt-server init` command
- `network_mode`: "host": Needed so that `Pi-hole` can reach the `dnscrypt-proxy` listening port

In order to setup `Anonymized-DNS` we need to complete the following steps.

*You don't necessarily have to use `Anonymized-DNS`. But, if you don't it will be a bit easier to track your ...     ([see this explanation][considering-anonymized-dns] for more on why)*

1. Ensure that there is a sub-folder named `conf` in the folder of the `dnscrypt-proxy` `docker-compose.yml` file
    1. In this folder create a file named `dnscrypt-proxy.toml`
2. Use [this dnscrypt-proxy.toml file as a template][dnscrypt-proxy-toml-example]
    1. Change the value of `server_names` in the `Global settings` section to the name you gave your `dnscrypt-server` or use e.g. `CloudFlare` or `Scaleway`
    2. Potentially change the `listen_addresses` to the port you want (in the `Global section`)
    3. Under the `Anonymized DNS` section change the `routes` array to contain one or more `Anonymized DNS` relay servers of your choice. Find available relay servers [here][Anonymized-DNS-relays]. Make sure to change the `server_name` in the `routes` definition, to reflect the value of the `server_names` property in the `Global section`

> N.B. if you look at the `dnscrypt-proxy` `docker-compose.yml` file you'll notice that there is a `volumes` mapping. This volume mapping is what the above steps relate to

##### OPTIONAL - Using `dnscrypt-proxy` together with your own `dnscrypt-server` - OPTIONAL

As you saw in the section above. Configuring `dnscrypt-proxy` involves its `dnscrypt-proxy.toml` file. This file comes into play again, now that we are to use the `dnscrypt-proxy` instance together with the `dnscrypt-server` you spun up earlier.

1. Find the `[static]` section in the file
1. Change the server name part of `[static.'hush.dns']` to the server name you've used throughout the `dnscrypt-proxy.toml` file
1. Finally set the value of the `stamp` property to the `DNSCrypt` stamp that the `dnscrypt-server` spit out when it was initialized

#### Running Pi-hole

The ad blackhole system. Reduces your risk of being [PFL (page load finger printed)][PFL], blocks ads, speeds up the load-time of websites.

1. Download the [Pi-hole docker-compose file][pihole-docker-compose]
   1. Ensure to go through the template Pi-hole docker-compose file and change the necessary values accordingly
1. Execute: `docker-compose --project-name pihole -f ./PATH_TO_THE_PIHOLE_DOCKER_COMPOSE_FILE up -d`
1. Execute: `docker logs pihole` to verify that the container started properly and that Pi-hole is running as it should

##### Pi-hole configuration details

- is configured to use a `dnscrypt-proxy` instance, so that Pi-hole forwards DNS requests to `dnscrypt-proxy`, in order to secure the queries
  - That `dnscrypt-proxy` instance is/should be configured to listen on port `5354`
- It is assumed that there is a [`HAProxy`][HAProxy] container, acting as a load-balancer, in front of the `Pi-hole` container. And that `HAProxy` instance have the Pi-hole backend as its default_backend

[//]: # "Links"
[DQM]: https://tools.ietf.org/html/rfc7816
[AnonymizedDNS]: https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Anonymized-DNS
[DNSCryptProject]: https://dnscrypt.info/
[DNSSEC]: https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions
[PiHole]: https://docs.pi-hole.net/
[dnscrypt-proxy-container-image]: https://github.com/djaydev/docker-dnscrypt-proxy
[hush-dns-blog-post]: https://bengtssondd.it/anonymity/privacy/security/2020/04/02/HushDNS-can-I-please-get-me-some-DNS-privacy/
[PFL]: https://blog.apnic.net/2019/08/23/what-can-you-learn-from-an-ip-address/
[pihole-docker-compose]: https://github.com/larssb/HushDNS/blob/master/Unit-deployment/pi-hole/docker-compose.yml
[CloudFlare-1.1.1.1]: https://developers.cloudflare.com/1.1.1.1/dns-over-https/cloudflared-proxy/
[dnscrypt-server]: https://github.com/DNSCrypt/dnscrypt-server-docker
[encrypted-dns-server-proxy]: https://github.com/jedisct1/encrypted-dns-server
[docker-init-container]: https://github.com/docker/compose/issues/6855
[dnscrypt-proxyDockerComposeFile]: https://github.com/larssb/HushDNS/blob/master/Unit-deployment/dnscrypt-proxy/docker-compose.yml
[considering-anonymized-dns]: https://bengtssondd.it/anonymity/privacy/security/2020/04/02/HushDNS-can-I-please-get-me-some-DNS-privacy/#considering-anonymized-dns-header
[dnscrypt-proxy-toml-example]: https://github.com/larssb/HushDNS/blob/master/Unit-deployment/dnscrypt-proxy/provider-own-server/conf/dnscrypt-proxy.toml
[Anonymized-DNS-relays]: https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v2/relays.md
[HAProxy]: http://www.haproxy.org/