# OAI5G MEC demo on SophiaNode/R2lab

This *[demo-oai.py](./demo-oai.py)* script aims to deploy the [OpenAirInterface Multi-access Edge Computing Platform blueprint](https://gitlab.eurecom.fr/oai/orchestration/blueprints/-/blob/master/mep/README.md) within the Sopnode/R2lab platform. 

The [OpenAirInterface Multi-access Edge Computing Platform blueprint](https://gitlab.eurecom.fr/oai/orchestration/blueprints/-/blob/master/mep/README.md) developed by Eurecom has been modified to be able to run it using either the rfsim mode or B210-based gNB and UE nodes (such as Quectel nodes and 5G phones) located in the R2lab platform. In the original blueprint, all the CN, RAN and MEP docker containers were running on the same host. The modified blueprint available [in this r2lab branch](https://gitlab.eurecom.fr/turletti/blueprints/-/tree/r2lab?ref_type=heads) will deploy the core-networks, ran and mep docker compose files on three different FIT nodes. 


### Software dependencies

Before you can run the script in this directory, you need to install its dependencies

    pip install -r requirements.txt

### Basic usage


The mental model is we are dealing with essentially three states:

* (0) initially, the FIT/R2lab nodes are down;
* (1) after setup, 3 FIT/R2lab node are loaded with the proper image to deploy the blueprint, and depending on the UEs selected more FIT nodes can be loaded with Quectel-specific UE images;
* (2) at that point one can use the `--start` option to start the system, which amounts to deploying containers on FIT nodes;
* (back to 1) it is point one can roll back and come back to the previous state, using the `--stop` option

with none of the `--start/--stop/--cleanup` option the script goes from state 0 to (2),
unless the `--no-auto-start` option is given.

Run `demo-oai.py --help` for more details.

### References

* [OpenAirInterface MEC Platform blueprint](https://gitlab.eurecom.fr/oai/orchestration/blueprints/-/blob/master/mep/README.md)
* [OAI 5G Core Network Deployment using Helm Charts](https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed/-/blob/master/docs/DEPLOY_SA5G_HC.md)
* [R2lab welcome page](https://r2lab.inria.fr/)
* [R2lab run page (requires login)](https://r2lab.inria.fr/run.md)
* [github repo for this page](https://github.com/sopnode/oai5g-rfsim)



### Customization

The **demo-oai.py** nepi-ng script has various options to change default parameters, run ``./demo-oai.py --help`` on your laptop to see all of them.

The main options are:

  * `--a` to not deploy the docker containers launch the OAI5G pods by default.
  * `-s slicename` to provide the slicename that you used to book the platform, which by default is *`inria_sopnode`*.
  * `--ran mode` use this option to select a specific node to run the gNB. It is by default fit02 but you can for instance use the new miniPC r2lab nodes *pc01* and *pc02* to run the gNB with B210 USRP device. E.g., `--ran pc01` to select miniPC node *pc01* or `--ran 10` tu use FIT node *fit10*.
  * `-R rfsim` or `-R b210` to select simulation mode or USRP B210-based gNB; by default the escript runs in simulation mode.
  * `-L` to retrieve all container logs when running `--stop` option.
  * `-P 1` and `-P 2` to select phone1 and phone2 5G UEs.
  * `-Q X` to select FIT node with 5G Quectel UE; a specific r2lab image will be loaded in this case on the node; e.g. `-Q9` will use *fit09*.
  * `-q X` to select Raspberry Pi4 with 5G Quectel UEs, e.g. `-q9` will use *qhat02*. 


We added the two following options to be used only when the demo-oai.py script has already run at least once, i.e., when FIT nodes are up and ready to start the docker containers:

* `--stop` to delete all docker containers. 
* `--start` to launch (again) all docker containers with same configuration as before.


### Testing: 


First assume that you want to deploy the MEP blueprint with a gNB deployed on fit02 and with the Quectel fit09 selected as UE, you will run:


`your-host$ ./demo-oai.py -s your-slicename -Rb210 --ran 2 -Q9 -l`

Then, when the script returns, you can check the containers created on the 3 physical hosts:

- on the core-network host (fit01):

``` bash
root@fit01:~# docker ps

CONTAINER ID   IMAGE                                     COMMAND                  CREATED         STATUS                   PORTS                          NAMES
34dd4ce6fe75   oaisoftwarealliance/oai-cm:latest         "oai_cm"                 5 minutes ago   Up 5 minutes (healthy)                                  oai-cm
0fe43bce5971   mongo:latest                              "docker-entrypoint.s…"   5 minutes ago   Up 5 minutes (healthy)   27017/tcp                      mongodb
5420399fe1aa   oaisoftwarealliance/oai-smf:v1.5.0        "python3 /openair-sm…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp, 8080/tcp, 8805/udp     oai-smf
4efe8e9b2398   oaisoftwarealliance/oai-amf:v1.5.0        "python3 /openair-am…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp, 9090/tcp, 38412/sctp   oai-amf
cef4ce845368   oaisoftwarealliance/oai-ausf:v1.5.0       "python3 /openair-au…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp                         oai-ausf
0a16f3ed5d88   oaisoftwarealliance/oai-udm:v1.5.0        "python3 /openair-ud…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp                         oai-udm
1063fd213422   oaisoftwarealliance/oai-udr:v1.5.0        "python3 /openair-ud…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp                         oai-udr
83540a65cd8a   oaisoftwarealliance/oai-upf-vpp:v1.5.0    "/openair-upf/bin/en…"   6 minutes ago   Up 6 minutes (healthy)   2152/udp, 8085/udp             vpp-upf
220bec835b76   mysql:8.0                                 "docker-entrypoint.s…"   6 minutes ago   Up 6 minutes (healthy)   3306/tcp, 33060/tcp            mysql
1926edfd8a0e   oaisoftwarealliance/trf-gen-cn5g:latest   "/bin/bash -c ' ipta…"   6 minutes ago   Up 6 minutes (healthy)                                  oai-ext-dn
f72e4bed1fd8   oaisoftwarealliance/oai-nrf:v1.5.0        "python3 /openair-nr…"   6 minutes ago   Up 6 minutes (healthy)   80/tcp, 9090/tcp               oai-nrf
```

- on the ran host (fit02):

``` bash
root@fit02:~# docker ps

CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS                   PORTS                                                                                                                                                   NAMES
48bf1b55db1e   oaisoftwarealliance/oai-flexric:1.0   "python3 -u rnisxapp…"   7 minutes ago   Up 7 minutes (healthy)   36421-36422/sctp                                                                                                                                        oai-rnis-xapp
38eb39552d4e   oaisoftwarealliance/oai-flexric:1.0   "/usr/local/bin/near…"   7 minutes ago   Up 7 minutes (healthy)   36421-36422/sctp                                                                                                                                        oai-flexric
e8568ea8ae26   rabbitmq:3-management-alpine          "docker-entrypoint.s…"   7 minutes ago   Up 7 minutes (healthy)   4369/tcp, 5671/tcp, 15671/tcp, 15691-15692/tcp, 25672/tcp, 0.0.0.0:32769->5672/tcp, :::32769->5672/tcp, 0.0.0.0:32768->15672/tcp, :::32768->15672/tcp   rabbitmq-broker
```

- on the mep host (fit03):

``` bash
root@fit03:~# docker ps

CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS                     PORTS                                                                                                           NAMES
97ef6555ca31   oaisoftwarealliance/oai-rnis:latest   "oai_rnis"               7 minutes ago   Up 7 minutes (healthy)                                                                                                                     oai-rnis
401253b207be   oaisoftwarealliance/oai-mep:latest    "oai_mep"                7 minutes ago   Up 7 minutes (healthy)                                                                                                                     oai-mep-registry
72fb320f9b15   kong:latest                           "/docker-entrypoint.…"   7 minutes ago   Up 7 minutes (unhealthy)   8000/tcp, 8443-8444/tcp, 0.0.0.0:32773->80/tcp, :::32773->80/tcp, 0.0.0.0:32772->8001/tcp, :::32772->8001/tcp   oai-mep-gateway
eb69f6121e8b   postgres:9.6                          "docker-entrypoint.s…"   7 minutes ago   Up 7 minutes (healthy)     5432/tcp                                                                                                        oai-mep-gateway-db
```

Now, stop the demo and retrieve the logs for all docker containers:

`./demo-oai.py -Rb210 --ran 2 -Q9 --stop -L`

The following logs will be retrieved directly to your local machine:

``` bash
(r2lab) your-laptop:oai5g-rnis $ tar -ztvf STATS/oai5g-stats-core.tgz
drwxr-xr-x  0 root   root        0  6 nov 15:05 oai5g-stats-core/
-rw-r--r--  0 root   root    35757  6 nov 15:05 oai5g-stats-core/amf.log
-rw-r--r--  0 root   root     8186  6 nov 15:05 oai5g-stats-core/udm.log
-rw-r--r--  0 root   root       59  6 nov 15:05 oai5g-stats-core/vpp-upf.log
-rw-r--r--  0 root   root    25271  6 nov 15:05 oai5g-stats-core/udr.log
-rw-r--r--  0 root   root    62943  6 nov 15:05 oai5g-stats-core/nrf.log
-rw-r--r--  0 root   root    56010  6 nov 15:05 oai5g-stats-core/smf.log
-rw-r--r--  0 root   root        0  6 nov 15:05 oai5g-stats-core/23.11.06T15.05
-rw-r--r--  0 root   root     8169  6 nov 15:05 oai5g-stats-core/ausf.log
-rw-r--r--  0 root   root     8963  6 nov 15:05 oai5g-stats-core/cm.log
(r2lab) your-laptop:oai5g-rnis $ tar -ztvf STATS/oai5g-stats-ran.tgz
drwxr-xr-x  0 root   root        0  6 nov 15:05 oai5g-stats-ran/
-rw-r--r--  0 root   root    59254  6 nov 15:05 oai5g-stats-ran/rfsim5g-oai-gnb.log
-rw-r--r--  0 root   root       63  6 nov 15:05 oai5g-stats-ran/oai-flexric.log
-rw-r--r--  0 root   root       65  6 nov 15:05 oai5g-stats-ran/rfsim5g-oai-nr-ue.log
-rw-r--r--  0 root   root     3026  6 nov 15:05 oai5g-stats-ran/oai-rnis-xapp.log
-rw-r--r--  0 root   root        0  6 nov 15:05 oai5g-stats-ran/23.11.06T15.05
-rw-r--r--  0 root   root    19905  6 nov 15:05 oai5g-stats-ran/rabbitmq-broker.log
(r2lab) your-laptop:oai5g-rnis $ tar -ztvf STATS/oai5g-stats-mep.tgz
drwxr-xr-x  0 root   root        0  6 nov 15:05 oai5g-stats-mep/
-rw-r--r--  0 root   root     3134  6 nov 15:05 oai5g-stats-mep/oai-mep-gateway.log
-rw-r--r--  0 root   root     1392  6 nov 15:05 oai5g-stats-mep/oai-rnis.log
-rw-r--r--  0 root   root        0  6 nov 15:05 oai5g-stats-mep/23.11.06T15.05
-rw-r--r--  0 root   root     1946  6 nov 15:05 oai5g-stats-mep/oai-mep-gateway-db.log
-rw-r--r--  0 root   root     1335  6 nov 15:05 oai5g-stats-mep/oai-mep-registry.log
```


Now, assume that you want to restart the demo in simulation mode, you will not have to reload R2lab images on the FIT nodes, just run:


Then, start the UE sim on the ran host:

``` bash
root@fit02:~# cd blueprints/mep/
root@fit02:~/blueprints/mep# docker compose -f docker-compose/docker-compose-ran.yaml up -d oai-nr-ue
```

Note that we don't use "--start" option in this case as this option skips the reconfiguration step.

Now, retrieve the IP addresses of all containers created in the different hosts:

- on the core-network host:
``` bash
root@fit01:~/blueprints/mep# docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n

192.168.70.130 	 oai-nrf
192.168.70.131 	 mysql
192.168.70.132 	 oai-amf
192.168.70.133 	 oai-smf
192.168.70.136 	 oai-udr
192.168.70.137 	 oai-udm
192.168.70.138 	 oai-ausf
192.168.70.167 	 mongodb
192.168.70.168 	 oai-cm
192.168.70.134 192.168.72.134 192.168.73.134 	 vpp-upf
192.168.73.135 	 oai-ext-dnb
```

- on the ran host:
``` bash
root@fit02:~/blueprints/mep# docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n

192.168.80.161 	 rfsim5g-oai-nr-ue
192.168.80.164 	 oai-flexric
192.168.80.165 	 oai-rnis-xapp
192.168.80.166 	 rabbitmq-broker
192.168.80.160 192.168.82.160 	 rfsim5g-oai-gnb
```

- and finally, on mep host:
``` bash
root@fit03:~/blueprints/mep# docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} %tab% {{.Name}}' $(docker ps -aq) | sed 's#%tab%#\t#g' | sed 's#/##g' | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n

192.168.90.2 	 oai-mep-gateway
192.168.90.4 	 oai-mep-gateway-db
192.168.90.5 	 oai-mep-registry
192.168.90.169 	 oai-rnis
```

Now fetch what RAN KPIs are available by running on the mep host:

``` bash
root@fit03:~# curl -X 'GET' 'http://oai-mep.org/rnis/v2/queries/layer2_meas' -H 'accept: application/json'
[
  {
    "KPIs": {
      "bler_dl": {
        "kpi": "bler_dl",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 5.605193857299268e-45
      },
      "bler_ul": {
        "kpi": "bler_ul",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 5.605193857299268e-45
      },
      "cqi": {
        "kpi": "cqi",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 0
      },
      "data_dl": {
        "kpi": "data_dl",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 0
      },
      "data_ul": {
        "kpi": "data_ul",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 0
      },
      "mcs_dl": {
        "kpi": "mcs_dl",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 9
      },
      "mcs_ul": {
        "kpi": "mcs_ul",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 9
      },
      "phr": {
        "kpi": "phr",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": null,
        "value": 0
      },
      "rsrp": {
        "kpi": "rsrp",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": "dBm",
        "value": -44
      },
      "snr": {
        "kpi": "snr",
        "labels": {
          "amf_ue_ngap_id": 1
        },
        "source": "RAN",
        "timestamp": 1699281114469113,
        "unit": "dBm",
        "value": 55.0
      }
    },
    "ueIPs": [
      "12.1.1.2"
    ]
  }
]

```

You can also try the xapp example application provided in the Eurecom MEP blueprint to track the KPIs in real-time:

``` bash
root@fit03:~# cd blueprints/mep/
root@fit03:~/blueprints/mep# python examples/example-mec-app.py
{'AssociateId': ['12.1.1.2'], 'CellId': 0, 'Report': {'cqi': {'kpi': 'cqi', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 0, 'labels': {'amf_ue_ngap_id': 1}}, 'rsrp': {'kpi': 'rsrp', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': 'dBm', 'value': -44, 'labels': {'amf_ue_ngap_id': 1}}, 'mcs_ul': {'kpi': 'mcs_ul', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 9, 'labels': {'amf_ue_ngap_id': 1}}, 'mcs_dl': {'kpi': 'mcs_dl', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 9, 'labels': {'amf_ue_ngap_id': 1}}, 'phr': {'kpi': 'phr', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 0, 'labels': {'amf_ue_ngap_id': 1}}, 'bler_ul': {'kpi': 'bler_ul', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 5.605193857299268e-45, 'labels': {'amf_ue_ngap_id': 1}}, 'bler_dl': {'kpi': 'bler_dl', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 5.605193857299268e-45, 'labels': {'amf_ue_ngap_id': 1}}, 'data_ul': {'kpi': 'data_ul', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 0, 'labels': {'amf_ue_ngap_id': 1}}, 'data_dl': {'kpi': 'data_dl', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': None, 'value': 0, 'labels': {'amf_ue_ngap_id': 1}}, 'snr': {'kpi': 'snr', 'source': 'RAN', 'timestamp': 1699281400219109, 'unit': 'dBm', 'value': 55.0, 'labels': {'amf_ue_ngap_id': 1}}}, 'TimeStamp': 1699281400.2334554}
192.168.90.169 - - [06/Nov/2023 15:36:40] "POST /subscriptions/l2meas-200 HTTP/1.1" 200 -
...
```



### Cleanup

To clean up the demo, you should first delete all docker containers by running on your laptop:
 
`$ ./demo-oai.py --stop` 

Then, to shutdown R2lab nodes and switch off USRP/Quectel devices, run on your laptop the following command:

`$ ./demo-oai.py --cleanup`


