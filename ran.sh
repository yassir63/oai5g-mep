#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {
    nodecore=$1
    shift
    
    echo "init: clone blueprint"
    rm -rf "$PATH_BP"
    git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    echo "init: Setting up ran IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT

    case $nodecore in
	fit0*) suffix_core=${nodecore#*fit0} ;;
	fit*) suffix_core=${nodecore#*fit} ;;
	*) echo "init: unknown core node $nodecore" ;;
    esac
    echo "ip route replace 192.168.70.0/24 via 192.168.3.$suffix_core"
    ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" 
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
    echo "Sleep 10s and check if the core network is healthy"
    sleep 10
    docker compose -f "$RAN_COMPOSE_FILE" ps -a
    echo "start: Launching oai-rnis-xapp"
    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-rnis-xapp
}


function start-nr-ue() {

    RAN_COMPOSE_FILE="docker-compose/docker-compose-ran.yaml"
    cd "$PATH_MEP"
    echo "start-nr-ue: Launching oai-nr-ue"
    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-nr-ue
}


function stop() {
    rru=$1
    shift
    logs=$1
    shift

    # Use the right Docker compose file
    if [[ "$rru" = "rfsim" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran.yaml"
    elif [[ "$rru" = "b210" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran-r2lab.yaml"
    fi

   if [[ "$logs" = "True" ]]; then
	echo "stop: retrieving ran containers logs"
	DATE=`date +"%y.%m.%dT%H.%M"`
	LOGS="oai5g-stats-ran"
	DIR="/tmp/$LOGS"
	rm -rf $DIR; mkdir $DIR
	touch $DIR/$DATE
	docker logs rfsim5g-oai-nr-ue > $DIR/rfsim5g-oai-nr-ue.log 2>&1
	docker logs oai-rnis-xapp > $DIR/oai-rnis-xapp.log 2>&1
	docker logs oai-oai-flexric > $DIR/oai-flexric.log 2>&1
	docker logs rabbitmq-broker > $DIR/rabbitmq-broker.log 2>&1
	docker logs rfsim5g-oai-gnb > $DIR/rfsim5g-oai-gnb.log 2>&1
	cd /tmp
	tar cfz $LOGS.tgz $LOGS
    fi
    
    cd "$PATH_MEP"
    echo "stop: Remove ran container"
    docker compose -f "$RAN_COMPOSE_FILE" down -t2
}

########################################
# wrapper to call the individual functions
"$@"
