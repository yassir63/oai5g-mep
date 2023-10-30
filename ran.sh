#!/bin/bash

function init() {

    echo "Clone blueprint"
    git clone --branch master https://gitlab.eurecom.fr/oai/orchestration/blueprints.git
  
    echo "init: Setting up ran IP forwarding rules"
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
    ip route add 192.168.70.169 via 192.168.3.5 # reach oai-rnis via mep host

    ip route add 192.168.70.2 via 192.168.3.5   # reach oai-mep-gateway via mep host
    ip route add 192.168.70.4 via 192.168.3.5   # reach oai-mep-gateway-db via mep host

    ip route add 192.168.70.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route add 192.168.72.134 via 192.168.3.1 # reach vpp-upf via core host
    ip route add 192.168.73.134 via 192.168.3.1 # reach vpp-upf via core host

    ip route add 192.168.73.135 via 192.168.3.1 # reach oai-ext-dn via core host
}

function start() {

    cd blueprints/mep
    echo "init: Launching oai-gnb, oai-flexric and rabbitmq"
    docker compose -f docker-compose/docker-compose-ran.yaml up -d oai-gnb oai-flexric rabbitmq
    echo "init: Launching oai-rnis-xapp"
    docker compose -f docker-compose/docker-compose-ran.yaml up -d oai-rnis-xapp
}

function stop() {

    cd blueprints/mep
    echo "stop: Remove ran container"
    docker compose -f docker-compose/docker-compose-ran.yaml down -t2
}

########################################
# wrapper to call the individual functions
"$@"
