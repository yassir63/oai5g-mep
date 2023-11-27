#!/bin/bash

PATH_BP="/root/blueprints"
PATH_PROMETHEUS="$PATH_BP/prometheus"

function init() {
    # nodecore=$1
    # shift
    # noderan=$1
    # shift

    echo "INIT PROMETHEUS"
    
    echo "init: Clone blueprint Prometheus"
    rm -rf "$PATH_BP"
    git clone --branch main https://gitlab.com/yassir63/blueprints.git

    

    if [ $(grep -ic "prometheus" /etc/hosts) -eq 0 ]; then
        echo 'init: add prometheus IP address to /etc/hosts'
        echo '192.168.99.1 prometheus' >> /etc/hosts
    else
	    echo 'init: Prometheus IP address already set in /etc/hosts'
    fi

    echo "init: Setting up Prometheus IP forwarding rules"
    sysctl net.ipv4.conf.all.forwarding=1
    iptables -P FORWARD ACCEPT

    # case $nodecore in
	# fit0*) suffix_core=${nodecore#*fit0} ;;
	# fit*) suffix_core=${nodecore#*fit} ;;
	# *) echo "init: unknown core node $nodecore" ;;
    # esac
    # case $noderan in
	# fit0*) suffix_ran=${noderan#*fit0} ;;
	# fit*) suffix_ran=${noderan#*fit} ;;
	# pc01) suffix_ran="61" ;;
	# pc02) suffix_ran="62" ;;
	# *) echo "init: unknown ran node $noderan" ;;
    # esac
    # echo "ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" dev control"
    # ip route replace 192.168.70.0/24 via 192.168.3."$suffix_core" dev control
    # echo "ip route replace 192.168.80.0/24 via 192.168.3."$suffix_ran" dev control"
    # ip route replace 192.168.80.0/24 via 192.168.3."$suffix_ran" dev control
}


function start() {

    cd "$PATH_PROMETHEUS"
    echo "start: Launching prometheus docker container"
    docker compose up -d
    echo "Sleep 10s and assure Prometheus container is up"
    sleep 10
    docker compose ps -a
    # curl http://oai-mep.org/service_registry/v1/discover
    curl http://localhost:9090/api/v1/status/config
}


function stop() {
    logs=$1
    shift

    if [[ "$logs" == "True" ]]; then
        echo "stop: retrieving prometheus container logs"
        DATE=$(date +"%y.%m.%dT%H.%M")
        LOGS="prometheus-logs"
        DIR="/tmp/$LOGS"
        rm -rf "$DIR"; mkdir "$DIR"
        touch "$DIR/$DATE"
        docker logs prometheus > "$DIR/prometheus.log" 2>&1
        cd /tmp
        tar cfz "$LOGS.tgz" "$LOGS"
    fi

    cd "$PATH_PROMETHEUS"
    echo "stop: Remove prometheus container"
    docker-compose down -t2
}

########################################
# wrapper to call the individual functions
"$@"
