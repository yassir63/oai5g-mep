#!/bin/bash

# First SSH command
ssh -t inria_ter01@faraday.inria.fr "\
    # Second SSH command after the first connection is established
    ssh root@fit02
"
