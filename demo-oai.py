#!/usr/bin/env python3 -u

"""
This script prepares one fit R2lab node to join the SophiaNode k8s cluster as a worker node for the oai5g demo.
Then, it clones the oai5g-rru and oai-cn5g-fed git directories on one a fit node and applies
different patches on the various OAI5G charts to make them run on the SophiaNode k8s cluster.
Finally, it deploys the different OAI5G pods through the same fit node.

In this demo, the oai-gnb pod can be a USRP N300/N320 device or a jaguar/panther AW2S device located in R2lab.
A variable number of UEs (currently 0 to 6) could be used using -Q option.
Each UE will run on a fit node attached to a Quectel RM 500Q-GL device in R2lab.

This version requires asynciojobs-0.16.3 or higher; if needed, upgrade with
pip install -U asynciojobs

"""

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter

# the default for asyncssh is to be rather verbose
from asyncssh.logging import set_log_level as asyncssh_set_log_level

from asynciojobs import Scheduler

from apssh import YamlLoader, SshJob, Run, Service # Push

# make sure to pip install r2lab
from r2lab import r2lab_hostname, ListOfChoices, ListOfChoicesNullReset, find_local_embedded_script

##########################################################################################

# Default R2lab FIT node images
default_image = 'u18-lowlat-kube-uhd'
#default_quectel_image = 'quectel-mbim'
default_quectel_image = 'quectel-mbim-single-dnn'

# Default FIT nodes used to launch core, gnb and mep containers
default_core = 1
default_gnb = 2
default_mep = 3

# Default RRU
default_rru = "rfsim"

# Default Phones used as UE
default_phones = []

# Default FIT nodes used as UE Quectel
default_quectel_nodes = []

# Default Qhat (Raspberry pi 4 nodes used as UE Quectel) nodes
default_qhat_nodes = []

# Default RRU used for the scenario.
# Currently, following possible options:
# ['b210', 'n300', 'n320', 'jaguar', 'panther', 'rfsim'] 
default_rru = 'n300'

default_gateway  = 'faraday.inria.fr'
default_slicename  = 'inria_sopnode'
default_namespace = 'oai5g'

default_regcred_name = 'r2labuser'
default_regcred_password = 'r2labuser-pwd'
default_regcred_email = 'r2labuser@turletti.com'


def run(*, mode, gateway, slicename, auto_start, load_images, 
        core, gnb, mep, phones, quectel_nodes, qhat_nodes, rru, 
        regcred_name, regcred_password, regcred_email,
        image, quectel_image, verbose, dry_run):
    """
    run the OAI5G demo on the k8s cluster

    Arguments:
        slicename: the Unix login name (slice name) to enter the gateway
        auto_start: pods will be launched
        load_images: FIT images will be deployed
        core: node name in which CN and CM will be deployed
        gnb: node name in which gnb, flexric, rabbitmq and rnis-xapp will be deployed
        mep: node name in which mep and rnis will be deployed
        phones: list of indices of phones to use
        quectel_nodes: list of indices of quectel UE nodes to use
        qhat_nodes: list of indices of qhat UE nodes to use
        rru: hardware device attached to gNB
        image: R2lab image name
        quectel_image: R2lab Quectel image name
    """

    wait1_dict = dict()
    wait2_dict = dict()
    if phones:
        sleeps_ran = (55, 75)
        phone_msgs = [f"wait for {sleep}s for eNB to start up before waking up phone{id}"
                      for sleep, id in zip(sleeps_ran, phones)]
        wait1_cmd = [f"echo '{msg}'; sleep {sleep}"
                     for msg, sleep in zip(phone_msgs, sleeps_ran)]
        sleeps_phone = (15, 20)
        phone2_msgs = [f"wait for {sleep}s for phone{id} before starting tests"
                       for sleep, id in zip(sleeps_phone, phones)]
        wait2_cmd = [f"echo '{msg}'; sleep {sleep}"
                     for msg, sleep in zip(phone2_msgs, sleeps_phone)]
        for i, n in enumerate(phones):
            wait1_dict.update({n: wait1_cmd[i]})
            wait2_dict.update({n: wait2_cmd[i]})
    
    quectel_dict = dict((n, r2lab_hostname(n)) for n in quectel_nodes)
    qhat_dict = dict((n, "qhat0"+n) for n in qhat_nodes)

    INCLUDES = [find_local_embedded_script(x) for x in (
      "r2labutils.sh", "nodes.sh", "faraday.sh"
    )]

    jinja_variables = dict(
        gateway=gateway,
        auto_start=auto_start,
        nodes=dict(
            core=r2lab_hostname(core),
            gnb=r2lab_hostname(gnb),
            mep=r2lab_hostname(mep),
        ),
        phones=phones,
        wait1_dict=wait1_dict,
        wait2_dict=wait2_dict,
        quectel_dict=quectel_dict,
        qhat_dict=qhat_dict,
        rru=rru,
        regcred=dict(
            name=regcred_name,
            password=regcred_password,
            email=regcred_email,
        ),
        image=image,
        quectel_image=quectel_image,
        verbose=verbose,
        nodes_sh=find_local_embedded_script("nodes.sh"),
        faraday_sh=find_local_embedded_script("faraday.sh"),
        INCLUDES=INCLUDES,
    )

    # (*) first compute the complete logic (but without check_lease)
    # (*) then simplify/prune according to the mode
    # (*) only then add check_lease in all modes

    loader = YamlLoader("demo-oai.yaml.j2")
    nodes_map, jobs_map, scheduler = loader.load_with_maps(jinja_variables, save_intermediate = verbose)
    scheduler.verbose = verbose
    # debug: to visually inspect the full scenario
    if verbose:
        complete_output = "demo-oai-complete"
        print(f"Verbose: storing full scenario (before mode processing) in {complete_output}.svg")
        scheduler.export_as_svgfile(complete_output)
        print(f"Verbose: storing full scenario (before mode processing) in {complete_output}.png")
        scheduler.export_as_pngfile(complete_output)


    # retrieve jobs for the surgery part
    j_load_images = [jobs_map[k] for k in jobs_map if k.startswith('load-image')]
    j_start_demo = [jobs_map[k] for k in jobs_map if k.startswith('start')]
    j_stop_demo = jobs_map['stop-demo']
    j_cleanups = [jobs_map[k] for k in jobs_map if k.startswith('cleanup')]

    j_leave_joins = [jobs_map[k] for k in jobs_map if k.startswith('leave-join')]
    if quectel_nodes:
        j_prepare_quectels = jobs_map['prepare-quectels']
    j_init_quectels = [jobs_map[k] for k in jobs_map if k.startswith('init-quectel-')]
    j_attach_quectels = [jobs_map[k] for k in jobs_map if k.startswith('attach-quectel-')]
    j_detach_quectels = [jobs_map[k] for k in jobs_map if k.startswith('detach-quectel-')]
    #j_stop_quectels = [jobs_map[k] for k in jobs_map if k.startswith('stop-quectel-')]

    if qhat_nodes:
        j_prepare_qhats = jobs_map['prepare-qhats']
    j_init_qhats = [jobs_map[k] for k in jobs_map if k.startswith('init-qhat-')]
    j_attach_qhats = [jobs_map[k] for k in jobs_map if k.startswith('attach-qhat-')]
    j_detach_qhats = [jobs_map[k] for k in jobs_map if k.startswith('detach-qhat-')]
    #j_stop_qhats = [jobs_map[k] for k in jobs_map if k.startswith('stop-qhat-')]

    j_attach_phones = [jobs_map[k] for k in jobs_map if k.startswith('attach-phone')]
    j_test_cx_phones = [jobs_map[k] for k in jobs_map if k.startswith('test-cx-phone')]
    j_detach_phones = [jobs_map[k] for k in jobs_map if k.startswith('detach-phone')]
    
    # run subparts as requested
    purpose = f"{mode} mode"
    ko_message = f"{purpose} KO"

    if mode == "cleanup":
        scheduler.keep_only(j_cleanups)
        ko_message = f"Could not cleanup demo"
        ok_message = f"Thank you, FIT nodes have been switched off"
    elif mode == "stop":
        #scheduler.keep_only_between(starts=[j_stop_demo], ends=j_cleanups, keep_ends=False)
        scheduler.keep_only([j_stop_demo]+j_detach_quectels+j_detach_qhats+j_detach_phones)
        ko_message = f"Could not stop containers"
        ok_message = f"""No more containers running
Nota: If you are done with the demo, do not forget to clean up the demo:
\t ./demo-oai.py --cleanup
"""
    elif mode == "start":
        scheduler.keep_only(j_start_demo + j_attach_quectels + j_attach_qhats + j_attach_phones + j_test_cx_phones)
        ok_message = f"RNIS demo started, you can check logs on the different containers"
        ko_message = f"Could not launch containers"
    else:
        if auto_start:
            scheduler.keep_only_between(ends=j_start_demo + j_attach_quectels + j_attach_qhats + j_attach_phones + j_test_cx_phones, keep_ends=True)
        else:
            scheduler.keep_only_between(ends=j_start_demo + j_init_quectels + j_init_qhats, keep_ends=True)
        if not load_images:
            scheduler.bypass_and_remove(j_load_images)
#TT see how to add scheduler.bypass_and_remove(j_init_quectels)
            purpose += f" (no image loaded)"
            if quectel_nodes and j_prepare_quectels in scheduler.jobs:
                scheduler.bypass_and_remove(j_prepare_quectels)
            purpose += f" (no quectel node prepared)"
            if qhat_nodes and j_prepare_qhats in scheduler.jobs:
                scheduler.bypass_and_remove(j_prepare_qhats)
            purpose += f" (no qhat node prepared)"
        else:
            purpose += f" WITH rhubarbe imaging the FIT nodes"
            if not quectel_nodes:
                purpose += f" (no quectel node prepared)"
            else:
                purpose += f" (quectel node(s) prepared: {quectel_nodes})"
            if not qhat_nodes:
                purpose += f" (no qhat node prepared)"
            else:
                purpose += f" (qhat node(s) prepared: {qhat_nodes})"
            if not phones:
                purpose += f" (no phone prepared)"
            else:
                purpose += f" (phone(s) prepared: {phones})"

        if not auto_start:
            scheduler.bypass_and_remove(j_start_demo)
            purpose += f" (NO auto start)"
            ok_message = f"RUN SetUp OK. You can now start the demo by running ./demo-oai.py --start"
        else:
            ok_message = f"RUN SetUp and demo started OK. You can now check the logs on the different containers."


    # add this job as a requirement for all scenarios
    check_lease = SshJob(
        scheduler=scheduler,
        node = nodes_map['faraday'],
        critical = True,
        verbose=verbose,
        command = Run("rhubarbe leases --check"),
    )
    # this becomes a requirement for all entry jobs
    for entry in scheduler.entry_jobs():
        entry.requires(check_lease)


    scheduler.check_cycles()
    print(10*'*', purpose, "\n", 'See main scheduler in', scheduler.export_as_svgfile("demo-oai-graph"))

    if verbose:
        scheduler.list()

    if dry_run:
        return True

    if not scheduler.orchestrate():
        print(f"{ko_message}: {scheduler.why()}")
        scheduler.debrief()
        return False
    print(ok_message)

    print(80*'*')
    return True

HELP = """

In its simplest form (no option given), the script will
  * load images on board of the FIT nodes
  * and then deploy the docker containers on that substrate (unless the --no-auto-start is not provided)

Thanks to the --stop and --start option, one can relaunch
the scenario without the need to re-image the selected FIT nodes;
a typical sequence of runs would then be

  * with no option
  * then with the --stop option to destroy the deployment
  * and then with the --start option to re-create the deployment a second time

Or,

  * with the --no-auto-start option to simply load images
  * then with the --start option to create the network
  * and then again any number of --stop / --start calls

At the end of your tests, please run the script with the --cleanup option to switch off FIT nodes.
"""


def main():
    """
    CLI frontend
    """
    
    parser = ArgumentParser(usage=HELP, formatter_class=ArgumentDefaultsHelpFormatter)

    parser.add_argument(
        "--start", default=False,
        action='store_true', dest='start',
        help="start the oai-demo, i.e., launch OAI5G pods")

    parser.add_argument(
        "--stop", default=False,
        action='store_true', dest='stop',
        help="stop the oai-demo, i.e., delete OAI5G pods")

    parser.add_argument(
        "--cleanup", default=False,
        action='store_true', dest='cleanup',
        help="Remove smoothly FIT nodes from the k8s cluster and switch them off")

    parser.add_argument(
        "-a", "--no-auto-start", default=True,
        action='store_false', dest='auto_start',
        help="default is to start the oai-demo after setup")

    parser.add_argument(
        "-l", "--load-images", default=False, action='store_true',
        help="load the kubernetes image on the nodes before anything else")

    parser.add_argument(
        "-i", "--image", default=default_image,
        help="kubernetes image to load on nodes")

    parser.add_argument(
        "-R", "--rru", dest='rru',
        default=default_rru,
        choices=("b210", "rfsim"),
        help="specify the hardware RRU to use for gNB or rfsim if simulation")

    parser.add_argument("--quectel-image", dest="quectel_image",
                        default=default_quectel_image)

    parser.add_argument("--core", default=default_core,
                        help="id of the FIT node that will run the core container")

    parser.add_argument("--gnb", default=default_gnb,
                        help="id of the FIT node that will run the gnb container")

    parser.add_argument("--mep", default=default_mep,
                        help="id of the FIT node that will run the mep container")

    parser.add_argument(
        "-s", "--slicename", default=default_slicename,
        help="slicename used to book FIT nodes")

    parser.add_argument(
        "--regcred_name", default=default_regcred_name,
        help=f"registry credential name for docker pull")

    parser.add_argument(
        "--regcred_password", default=default_regcred_password,
        help=f"registry credential password for docker pull")

    parser.add_argument(
        "--regcred_email", default=default_regcred_email,
        help=f"registry credential email for docker pull")

    parser.add_argument("-P", "--phones", dest='phones',
                        action=ListOfChoicesNullReset, type=int, choices=(1, 2, 0),
                        default=default_phones,
                        help='Commercial phones to use; use -p 0 to choose no phone')

    parser.add_argument(
        "-Q", "--quectel-id", dest='quectel_nodes',
        default=default_quectel_nodes,
        choices=["7", "9", "18", "31", "32", "34"],
	action=ListOfChoices,
	help="specify as many node ids with Quectel UEs as you want.")

    parser.add_argument(
        "-q", "--qhat-id", dest='qhat_nodes',
        default=default_qhat_nodes,
        choices=["1", "2", "3"],
	action=ListOfChoices,
	help="specify as many node ids with Quectel UEs as you want.")


    parser.add_argument("-v", "--verbose", default=False,
                        action='store_true', dest='verbose',
                        help="run script in verbose mode")

    parser.add_argument("-n", "--dry-runmode", default=False,
                        action='store_true', dest='dry_run',
                        help="only pretend to run, don't do anything")

    args = parser.parse_args()
    print("Running the MEP demo version on following FIT nodes:")
    print(f"\t{r2lab_hostname(args.core)} for CN and CM containers")
    print(f"\t{r2lab_hostname(args.gnb)} for gNB, flexric, rabbitmq and rnis-xapp containers")
    print(f"\t{r2lab_hostname(args.mep)} for MEP and rnis containers")
            
    if args.quectel_nodes:
        for quectel in args.quectel_nodes:
            print(f"Using Quectel UE on node {r2lab_hostname(quectel)}")
    else:
        print("No Quectel UE involved")

    if args.phones:
        for i in args.phones:
            print(f"Using UE phone {i} ")
    else:
        print("No UE phone involved")
        args.phones.clear()

    if args.qhat_nodes:
        for i in args.qhat_nodes:
            print(f"Using qhat0{i} UE")
    else:
        print("No qhat UE involved")

    if args.start:
        print(f"**** Launch all containers")
        mode = "start"
    elif args.stop:
        print(f"delete all containers")
        mode = "stop"
    elif args.cleanup:
        print(f"**** swith off FIT nodes")
        mode = "cleanup"
    else:
        if args.rru == "rfsim":
            print(f"\toai-gnb running in simulation mode")
        else:
            print(f"\toai-gnb running with b210")
        print(f"FIT image loading:",
              f"YES with {args.image}" if args.load_images
              else "NO (use --load-images if needed)")
        if args.auto_start:
            print("Automatically start the demo after setup")
        else:
            print("Do not start the demo after setup")

        mode = "run"

    run(mode=mode, gateway=default_gateway, slicename=args.slicename,
        auto_start=args.auto_start, load_images=args.load_images,
        core=args.core, gnb=args.gnb, mep=args.mep,
        phones=args.phones, quectel_nodes=args.quectel_nodes,
        qhat_nodes=args.qhat_nodes, rru=args.rru,
        regcred_name=args.regcred_name,
        regcred_password=args.regcred_password,
        regcred_email=args.regcred_email,
        image=args.image, quectel_image=args.quectel_image, 
        verbose=args.verbose, dry_run=args.dry_run)


if __name__ == '__main__':
    # return something useful to your OS
    exit(0 if main() else 1)
