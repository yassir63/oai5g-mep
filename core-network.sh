#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {

    echo "Clone blueprint"
    rm -rf "$PATH_BP"
    git clone --branch r2lab https://gitlab.eurecom.fr/turletti/blueprints.git

    echo "init: Setting up core-network IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
    
#    ip route replace 192.168.70.164 via 192.168.3.2 # reach oai-flexric via gNB host
#    ip route replace 192.168.70.165 via 192.168.3.2 # reach oai-rnis-xapp via gNB host
#    ip route replace 192.168.70.166 via 192.168.3.2 # reach rabbitmq via gNB host

#    ip route replace 192.168.70.160 via 192.168.3.2 # reach oai-gnb via gNB host
#    ip route replace 192.168.72.160 via 192.168.3.2 # reach oai-gnb via gNB host

#    ip route replace 192.168.70.169 via 192.168.3.5 # reach oai-rnis via mep host

#    ip route replace 192.168.70.2 via 192.168.3.5   # reach oai-mep-gateway via mep host
#    ip route replace 192.168.70.4 via 192.168.3.5   # reach oai-mep-gateway-db via mep host
}


function start() {
    rru=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network.yaml"
    elif [[ "$rru" = "b210" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network-r2lab.yaml"
    fi

    cd "$PATH_MEP"
    echo "start: Launching core-network, sleep 10s"
    docker compose -f "$CORE_COMPOSE_FILE" up -d
    echo "Sleep 10s and check if the core network is healthy"
    sleep 10
    docker compose -f "$CORE_COMPOSE_FILE" ps -a
    echo "start: Launching cm"
    docker compose -f docker-compose/docker-compose-cm.yaml up -d
    echo "Sleep 10s and check if cm is healthy"
    sleep 10
    docker compose -f docker-compose/docker-compose-cm.yaml ps -a
}


function stop() {
    rru=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network.yaml"
    elif [[ "$rru" = "b210" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network-r2lab.yaml"
    fi

    cd "$PATH_MEP"
    echo "stop: Remove core-network container"
    docker compose -f "$CORE_COMPOSE_FILE" down -t2
    echo "stop: Remove cm container"
    docker compose -f docker-compose/docker-compose-cm.yaml down -t2
}

########################################
# wrapper to call the individual functions
"$@"
