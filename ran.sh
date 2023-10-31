#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {

    echo "init: clone blueprint"
    rm -rf "$PATH_BP"
    git clone --branch r2lab https://gitlab.eurecom.fr/turletti/blueprints.git

    echo "init: Setting up ran IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
    ip route replace 192.168.70.130 via 192.168.3.1 # reach oai-nrf via core host
    ip route replace 192.168.70.131 via 192.168.3.1 # reach mysql via core host
    ip route replace 192.168.70.132 via 192.168.3.1 # reach oai-amf via core host
    ip route replace 192.168.70.133 via 192.168.3.1 # reach oai-smf via core host
    ip route replace 192.168.70.136 via 192.168.3.1 # reach oai-udr via core host
    ip route replace 192.168.70.137 via 192.168.3.1 # reach oai-udm via core host
    ip route replace 192.168.70.138 via 192.168.3.1 # reach oai-ausf via core host

    ip route replace 192.168.70.167 via 192.168.3.1 # reach mongodb via core host
    ip route replace 192.168.70.168 via 192.168.3.1 # reach oai-cm via core host
    ip route replace 192.168.70.169 via 192.168.3.5 # reach oai-rnis via mep host

    ip route replace 192.168.70.2 via 192.168.3.5   # reach oai-mep-gateway via mep host
    ip route replace 192.168.70.4 via 192.168.3.5   # reach oai-mep-gateway-db via mep host

    ip route replace 192.168.70.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route replace 192.168.72.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route replace 192.168.73.134 via 192.168.3.1 # reach vpp-upf via core host

    ip route replace 192.168.73.135 via 192.168.3.1 # reach oai-ext-dn via core host
}

function start() {
    rru=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran.yaml"
    elif [[ "$rru" = "b210" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran-r2lab.yaml"
    fi
  
    cd "$PATH_MEP"
    echo "start: Launching oai-gnb, oai-flexric and rabbitmq"
    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-gnb oai-flexric rabbitmq
    echo "start: Launching oai-rnis-xapp"
    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-rnis-xapp
}

function stop() {
    rru=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran.yaml"
    elif [[ "$rru" = "b210" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran-r2lab.yaml"
    fi
  
    cd "$PATH_MEP"
    echo "stop: Remove ran container"
    docker compose -f "$RAN_COMPOSE_FILE" down -t2
}

########################################
# wrapper to call the individual functions
"$@"
