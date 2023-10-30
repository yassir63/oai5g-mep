#!/bin/bash


function init() {

    echo "init: Clone blueprint"
    git clone --branch master https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    echo "init: Setting up mep IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
    ip route add 192.168.70.130 via 192.168.3.1 # reach oai-nrf via core host
    ip route add 192.168.70.131 via 192.168.3.1 # reach mysql via core host
    ip route add 192.168.70.132 via 192.168.3.1 # reach oai-amf via core host
    ip route add 192.168.70.133 via 192.168.3.1 # reach oai-smf via core host
    ip route add 192.168.70.136 via 192.168.3.1 # reach oai-udr via core host
    ip route add 192.168.70.137 via 192.168.3.1 # reach oai-udm via core host
    ip route add 192.168.70.138 via 192.168.3.1 # reach oai-ausf via core host

    ip route add 192.168.70.167 via 192.168.3.1 # reach mongodb via core host
    ip route add 192.168.70.168 via 192.168.3.1 # reach oai-cm via core host

    ip route add 192.168.70.164 via 192.168.3.2 # reach oai-flexric via ran host
    ip route add 192.168.70.165 via 192.168.3.2 # reach oai-rnis-xapp via ran host
    ip route add 192.168.70.166 via 192.168.3.2 # reach rabbitmq via ran host

    ip route add 192.168.70.160 via 192.168.3.2 # reach oai-gnb via ran host
    ip route add 192.168.72.160 via 192.168.3.2 # reach oai-gnb via ran host

    ip route add 192.168.70.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route add 192.168.72.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route add 192.168.73.134 via 192.168.3.1 # reach vpp-upf via core host

    ip route add 192.168.73.135 via 192.168.3.1 # reach oai-ext-dn via core host
}


function start() {

    cd blueprints/mep
    echo "start: Launching mep docker container"
    docker compose -f docker-compose/docker-compose-mep.yaml up -d
    echo "start: Launching rnis docker container"
    docker compose -f docker-compose/docker-compose-rnis.yaml up -d
}


function stop() {

    cd blueprints/mep
    echo "stop: Remove mep container"
    docker compose -f docker-compose/docker-compose-mep.yaml down -t2
    echo "stop: Remove rnis container"
    docker compose -f docker-compose/docker-compose-rnis.yaml down -t2
}

########################################
# wrapper to call the individual functions
"$@"
