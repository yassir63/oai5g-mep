#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {

    echo "Clone blueprint"
    rm -rf "$PATH_BP"
    git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    echo "init: Setting up core-network IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
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
    logs=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network.yaml"
    elif [[ "$rru" = "b210" ]]; then
	CORE_COMPOSE_FILE="docker-compose/docker-compose-core-network-r2lab.yaml"
    fi

    if [[ "$logs" = "True" ]]; then
	echo "stop: retrieving core containers logs"
	DATE=`date +"%y.%m.%dT%H.%M"`
	LOGS="oai5g-stats-core"
	DIR="/tmp/$LOGS"
	rm -rf $DIR; mkdir $DIR
	touch $DIR/$DATE
	docker logs oai-amf > $DIR/amf.log 2>&1
	docker logs oai-smf > $DIR/smf.log 2>&1
	docker logs oai-nrf > $DIR/nrf.log 2>&1
	docker logs oai-vpp-upf > $DIR/vpp-upf.log 2>&1
	docker logs oai-udr > $DIR/udr.log 2>&1
	docker logs oai-udm > $DIR/udm.log 2>&1
	docker logs oai-ausf > $DIR/ausf.log 2>&1
	docker logs oai-cm > $DIR/cm.log 2>&1
	cd /tmp
	tar cfz $LOGS.tgz $LOGS
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
