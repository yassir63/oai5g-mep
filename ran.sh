#!/bin/bash

PATH_BP="/root/blueprints"
PATH_MEP="$PATH_BP/mep"

function init() {
    nodecore=$1
    shift
    nodemep=$1
    shift
    
    echo "init: clone blueprint"
    rm -rf "$PATH_BP"
    #git clone --branch r2lab https://gitlab.eurecom.fr/oai/orchestration/blueprints.git
    git clone --branch r2lab-7080 https://gitlab.eurecom.fr/turletti/blueprints.git

    echo "init: Setting up ran IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT

    case $nodecore in
	fit0*) suffix_core=${nodecore#*fit0} ;;
	fit*) suffix_core=${nodecore#*fit} ;;
	*) echo "init: unknown core node $nodecore" ;;
    esac
    case $nodemep in
	fit0*) suffix_mep=${nodemep#*fit0} ;;
	fit*) suffix_mep=${nodemep#*fit} ;;
	*) echo "init: unknown mep node $nodemep" ;;
    esac
    echo "init: Adding route to reach 192.168.70.0/24subnet via 192.168.3.$suffix_core"
    ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" 
    #echo "ip route replace 192.168.90.0/24 via 192.168.3.$suffix_mep"
    #ip route replace 192.168.90.0/24 via 192.168.3."$suffix_mep" 
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
    echo "Sleep 30s and check if RAN containers are healthy"
    sleep 30
    docker compose -f "$RAN_COMPOSE_FILE" ps -a
    
    echo "start: Launching oai-rnis-xapp"
    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-rnis-xapp

    echo "Sleep 10s and run curl http://192.168.80.166:15672/#/queues"
    sleep 10

    echo "Show IPs of RAN containers"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n

    echo "Run: curl http://192.168.80.166:15672/#/queues"
    curl http://192.168.80.166:15672/#/queues
    
    #mep start bloc 
    echo "***** Deploy OAI-MEP"
    echo "start: Launching mep docker container"
    docker compose -f docker-compose/docker-compose-mep.yaml up -d
    echo "Sleep 20s and check if mep is healthy"
    sleep 20
    docker compose -f docker-compose/docker-compose-mep.yaml ps -a

    echo "run curl http://oai-mep.org/service_registry/v1/ui"
    curl http://oai-mep.org/service_registry/v1/ui

    echo "***** Deploy OAI-RNIS"
    echo "start: Launching rnis docker container"
    docker compose -f docker-compose/docker-compose-rnis.yaml up -d
    echo "Sleep 15s"
    sleep 15

    if [[ "$rru" = "rfsim" ]]; then
	echo "Now deploy the simulated UE and wait 10s"
	    echo "start-nr-ue: Launching oai-nr-ue"
	    docker compose -f "$RAN_COMPOSE_FILE" up -d oai-nr-ue
	    sleep 10
    fi
    
    echo "Show IPs of MEP containers"
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
    
    echo "Check the services exposed by mep"
    echo "Run: curl http://oai-mep.org/service_registry/v1/discover"
    curl http://oai-mep.org/service_registry/v1/discover

    echo "Run: curl -X 'GET' 'http://oai-mep.org/rnis/v2/queries/layer2_meas'"
    curl -X 'GET' 'http://oai-mep.org/rnis/v2/queries/layer2_meas'
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
	GNB_NAME="rfsim5g-oai-gnb"
	UE_NAME="rfsim5g-oai-nr-ue"
    elif [[ "$rru" = "b210" ]]; then
	RAN_COMPOSE_FILE="docker-compose/docker-compose-ran-r2lab.yaml"
	GNB_NAME="b210-oai-gnb"
	UE_NAME="oai-nr-ue"
    fi

   if [[ "$logs" = "True" ]]; then
	echo "stop: retrieving ran containers logs"
	DATE=`date +"%y.%m.%dT%H.%M"`
	LOGS="oai5g-stats-ran"
	DIR="/tmp/$LOGS"
	rm -rf $DIR; mkdir $DIR
	touch $DIR/$DATE
	docker logs $UE_NAME > $DIR/$UE_NAME.log 2>&1
	docker logs oai-rnis-xapp > $DIR/oai-rnis-xapp.log 2>&1
	docker logs oai-flexric > $DIR/oai-flexric.log 2>&1
	docker logs rabbitmq-broker > $DIR/rabbitmq-broker.log 2>&1
	docker logs $GNB_NAME > $DIR/$GNB_NAME.log 2>&1
	# mep bloc follows
	docker logs oai-rnis > $DIR/oai-rnis.log 2>&1
	docker logs oai-mep-registry > $DIR/oai-mep-registry.log 2>&1
	docker logs oai-mep-gateway > $DIR/oai-mep-gateway.log 2>&1
	docker logs oai-mep-gateway-db > $DIR/oai-mep-gateway-db.log 2>&1
	
	cd /tmp
	tar cfz $LOGS.tgz $LOGS
    fi
    
    cd "$PATH_MEP"
    echo "stop: Remove ran container"
    docker compose -f "$RAN_COMPOSE_FILE" down -t2

    # mep bloc
    echo "stop: Remove mep container"
    docker compose -f docker-compose/docker-compose-mep.yaml down -t2
    echo "stop: Remove rnis container"
    docker compose -f docker-compose/docker-compose-rnis.yaml down -t2    
}

########################################
# wrapper to call the individual functions
"$@"
