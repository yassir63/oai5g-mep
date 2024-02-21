#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {
    noderan=$1
    shift

    echo "init: clone blueprint"
    rm -rf "$PATH_BP"
    
    #git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git
    git clone --branch r2lab-7080 https://gitlab.eurecom.fr/turletti/blueprints.git
    #git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    echo "init: Setting up core-network IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT
    case $noderan in
	fit0*) suffix_ran=${noderan#*fit0} ;;
	fit*) suffix_ran=${noderan#*fit} ;;
	pc01) suffix_ran=61 ;;
	pc02) suffix_ran=62 ;;
	*) echo "init: unknown ran node $noderan" ;;
    esac
    echo "init: Adding routes to reach 192.168.80.0/24 and 192.168.82.0/24 subnets via 192.168.3.$suffix_ran"
    ip route replace 192.168.80.0/24 via 192.168.3."$suffix_ran"
    ip route replace 192.168.82.0/24 via 192.168.3."$suffix_ran" # N6 (upf - gnb)
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
    echo "Deploy OAI 5G Core Network"
    docker compose -f "$CORE_COMPOSE_FILE" up -d
    echo "Sleep 30s and check if the core network is healthy"
    sleep 30
    docker compose -f "$CORE_COMPOSE_FILE" ps -a
    echo "Deploy cm"
    docker compose -f docker-compose/docker-compose-cm.yaml up -d
    echo "Sleep 10s and check if cm is healthy"
    sleep 10
    docker compose -f docker-compose/docker-compose-cm.yaml ps -a
    echo "Show IPs of CN containers"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
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
