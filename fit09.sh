#!/bin/bash

# First SSH command
ssh -tt inria_ter01@faraday.inria.fr "\
    # Second SSH command after the first connection is established
    ssh -tt root@fit02 << EOF
        # Install Docker using snap
        snap install docker

        # Docker run command
        docker run -it --rm --name=iperf3-server -p 5201:5201 networkstatic/iperf3 -s
EOF
"
