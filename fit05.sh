#!/bin/bash

# First SSH command
ssh -tt -L 9100:localhost:9099 -L 9101:localhost:9100 -t inria_ter01@faraday.inria.fr "\
    # Second SSH command after the first connection is established
    ssh -tt -L 9099:localhost:9090 -L 9100:localhost:3000 root@fit05 << EOF
        # Docker run command
        docker run -it --rm --name=iperf3-server -p 5201:5201 networkstatic/iperf3 -s
EOF
"

