#!/bin/bash

function init() {

    echo "Clone blueprint"
    git clone --branch master https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    echo "init: Setting up core-network IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
    ip route add 192.168.70.164 via 192.168.3.2 # reach oai-flexric via gNB host
    ip route add 192.168.70.165 via 192.168.3.2 # reach oai-rnis-xapp via gNB host
    ip route add 192.168.70.166 via 192.168.3.2 # reach rabbitmq via gNB host

    ip route add 192.168.70.160 via 192.168.3.2 # reach oai-gnb via gNB host
    ip route add 192.168.72.160 via 192.168.3.2 # reach oai-gnb via gNB host

    ip route add 192.168.70.169 via 192.168.3.5 # reach oai-rnis via mep host

    ip route add 192.168.70.2 via 192.168.3.5   # reach oai-mep-gateway via mep host
    ip route add 192.168.70.4 via 192.168.3.5   # reach oai-mep-gateway-db via mep host
}


function start() {

    cd blueprints/mep
    echo "start: Launching core-network"
    docker compose -f docker-compose/docker-compose-core-network.yaml up -d
    echo "start: Launching cm"
    docker compose -f docker-compose/docker-compose-cm.yaml up -d
}


function stop() {

    cd blueprints/mep
    echo "stop: Remove core-network container"
    docker compose -f docker-compose/docker-compose-core-network.yaml down -t2
    echo "stop: Remove cm container"
    docker compose -f docker-compose/docker-compose-cm.yaml down -t2
}

########################################
# wrapper to call the individual functions
"$@"
