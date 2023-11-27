#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {
    nodecore=$1
    shift
    noderan=$1
    shift
    
    echo "init: Clone blueprint"
    rm -rf "$PATH_BP"
    git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git

    if [ $(grep -ic "oai-mep.org" /etc/hosts) -eq 0 ]
    then
	echo 'init: add oai-mep.org IP address to /etc/hosts'
	echo '192.168.90.2 oai-mep.org' >> /etc/hosts
    else
	echo 'init: oai-mep.org IP address already set in /etc/hosts'
    fi

    echo "init: Setting up mep IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT

    case $nodecore in
	fit0*) suffix_core=${nodecore#*fit0} ;;
	fit*) suffix_core=${nodecore#*fit} ;;
	*) echo "init: unknown core node $nodecore" ;;
    esac
    case $noderan in
	fit0*) suffix_ran=${noderan#*fit0} ;;
	fit*) suffix_ran=${noderan#*fit} ;;
	pc01) suffix_ran="61" ;;
	pc02) suffix_ran="62" ;;
	*) echo "init: unknown ran node $noderan" ;;
    esac
    echo "ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" dev control"
    ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" dev control
    echo "ip route replace 192.168.80.0/24 via 192.168.3."$suffix_ran" dev control"
    ip route replace 192.168.80.0/24 via 192.168.3."$suffix_ran" dev control
}


function start() {

    cd "$PATH_MEP"
    echo "start: Launching mep docker container"
    docker compose -f docker-compose/docker-compose-mep.yaml up -d
    echo "Sleep 10s and check if mep is healthy"
    sleep 10
    docker compose -f docker-compose/docker-compose-mep.yaml ps -a

    echo "start: Launching rnis docker container"
    docker compose -f docker-compose/docker-compose-rnis.yaml up -d
    echo "Sleep 10s and check the services exposed by mep"
    sleep 10
    curl http://oai-mep.org/service_registry/v1/discover
}


function stop() {
    logs=$1
    shift

   if [[ "$logs" = "True" ]]; then
	echo "stop: retrieving mep containers logs"
	DATE=`date +"%y.%m.%dT%H.%M"`
	LOGS="oai5g-stats-mep"
	DIR="/tmp/$LOGS"
	rm -rf $DIR; mkdir $DIR
	touch $DIR/$DATE
	docker logs oai-rnis > $DIR/oai-rnis.log 2>&1
	docker logs oai-mep-registry > $DIR/oai-mep-registry.log 2>&1
	docker logs oai-mep-gateway > $DIR/oai-mep-gateway.log 2>&1
	docker logs oai-mep-gateway-db > $DIR/oai-mep-gateway-db.log 2>&1
	cd /tmp
	tar cfz $LOGS.tgz $LOGS
    fi
    
    cd "$PATH_MEP"
    echo "stop: Remove mep container"
    docker compose -f docker-compose/docker-compose-mep.yaml down -t2
    echo "stop: Remove rnis container"
    docker compose -f docker-compose/docker-compose-rnis.yaml down -t2
}

########################################
# wrapper to call the individual functions
"$@"
