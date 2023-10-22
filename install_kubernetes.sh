#!/bin/bash

# Copyright (C) 2023 DRAGHI Olivier
#     This program comes with ABSOLUTELY NO WARRANTY; for details type `install_kubernetes.sh --help'.
#     This is free software, and you are welcome to redistribute it
#     under certain conditions; type `install_kubernetes.sh --copyright' for details.

QUANTITY_OF_K8S_VERSIONS=5
QUANTITY_OF_CPU_MIN=2
QUANTITY_OF_MEMORY_GB_MIN=2

THIS_PROGRAM_VERSION=1.0.0
THIS_PROGRAM=$0

copyright()
{
   cat << EOF
    This program install the prerequisites to run and work with the kubernetes version of your choice.

    Copyright (C) 2023 DRAGHI Olivier

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>
EOF
}

this_version()
{
   echo "Program: ${THIS_PROGRAM} version ${THIS_PROGRAM_VERSION}"
}

this_help()
{
   cat << EOF

    Usage: ${THIS_PROGRAM} [OPTIONS] [kubernetes-version]

DESCRIPTION

   This program install the prerequisites to run and work with the kubernetes.
   By defaut the program list available kubernetes version and ask you which one you want.
   
   To join other nodes in the cluster you must install the same version of kubernetes.
   To do that you would need to run on those server :
      1. ${THIS_PROGRAM}    - Without initialize options (--init or --prod)
      2. kubeadm --join     - With options you get at the end of the initialize of the first node

UNATTENDED INSTALL OF TOOLS AND PREREQUISITES


      ${THIS_PROGRAM} 1.27
      ${THIS_PROGRAM} --latest
      ${THIS_PROGRAM} --older 1.24 

      You can run <kubeadm init> yourself at the end.

UNATTENDED INITIALIZE CLUSTER

      ${THIS_PROGRAM} 1.27 --prod cluster-001.localdomain
      ${THIS_PROGRAM} 1.27 --prod 192.168.10.1
      ${THIS_PROGRAM} --latest --init
      ${THIS_PROGRAM} --older 1.24 --init

      ${THIS_PROGRAM} --latest --init -cni calico --skip-heml

OPTIONS: FOR KUBERNETES VERSION

     --latest        Install the latest version of Kubernetes.

     --older         Allow older version of available Kubernetes version.
                     By default you can only install one of the ${QUANTITY_OF_K8S_VERSIONS} latest versions.

OPTIONS: FOR ADDITIONAL TOOLS

     --skip-heml     Skip HELM install.
                     You should use this option for a production node. 

OPTIONS: TO INITIALIZE CLUSTER

     --init                                  Initialize Kubernetes cluster.

     --prod <FQDN_ENDPOINT>|<VIRTUAL_IP>     Initialize Kubernetes cluster ready for production with multi controller nodes.

                                             <FQDN_ENDPOINT> This name must be in your DNS Server
                                                            or in /etc/hosts of all nodes (controllers and workers).

                                             <VIRTUAL_IP>    If you have configure a loadbalancer for your controle plane.

     --cni  <CNI>                            CNI for your Kubernetes cluster (calico, cilium or antrea).
                                             Default CNI is calico.
  
     --pod-network-cidr <POD_NETWORK_CIDR>  Specify range of IP addresses for the pod network.
                                            If set, the control plane will automatically allocate CIDRs for every node.
                                            This is mandatory for some CNI (only antrea for now..)
                                       
OPTIONS: USER FRIENDLY

     -s, --slow      That let time for humans reading what's happened (INFO/WARNING messages)
     -h, --help      Show this help.

	  -v, --version       Show this program version.
	  -c, --copyright     Show this program copyright.

EOF
}

parse_args()
{
   POSITIONAL_ARGS=()

   while [[ $# -gt 0 ]]; do
      case $1 in
         # --my-argument)
         #    ARG_MY_ARGUMENT="$2"
         #    shift # past argument
         #    shift # past value
         #    ;;
         --latest)
            ARG_LATEST="yes"
            shift # past argument
            ;;
         --older)
            ARG_OLDER_K8S_VERSIONS="yes"
            shift # past argument
            ;;
         --skip-helm)
            ARG_SKIP_HELM="yes"
            shift # past argument
            ;;
         --cni)
            ARG_CNI="$2"
            validate_arg_cni
            shift # past argument
            shift # past value
            ;;
         --pod-network-cidr)
            ARG_POD_NETWORK="yes"
            ARG_POD_NETWORK_CIDR="$2"
            validate_arg_pod_network_cidr
            shift # past argument
            shift # past value
            ;;
         --prod)
            ARG_INIT_CLUSTER="yes"
            ARG_PRODUCTION="yes"
            ARG_API_ENDPOINT="$2"
            validate_arg_api_endpoint
            shift # past argument
            shift # past value
            ;;
         --init )
            ARG_INIT_CLUSTER="yes"
            shift # past argument
            ;;
         -s|--slow)
            DELAY_SECOND=2
            shift # past argument
            ;;
         -h|--help)
            this_help
            exit
            ;;
         -v|--version)
            this_version
            exit
            ;;
         -c|--copyright)
            copyright
            exit
            ;;
         -*|--*)
            echo "Unknown option $1"
            exit 1
            ;;
         *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift # past argument
            [ ${#POSITIONAL_ARGS[@]} -gt 1 ] && fatal_error "Unexpected positional args : ${POSITIONAL_ARGS[0]}"
            ;;
      esac
   done

   # Set defaut values if not parsed
   ARG_OLDER_K8S_VERSIONS=${ARG_OLDER_K8S_VERSIONS:-no}
   ARG_LATEST=${ARG_LATEST:-no}
   ARG_SKIP_HELM=${ARG_SKIP_HELM:-no}
   ARG_INIT_CLUSTER=${ARG_INIT_CLUSTER:-no}
   ARG_PRODUCTION=${ARG_PRODUCTION:-no}
   ARG_CNI=${ARG_CNI:-calico}
   ARG_POD_NETWORK=${ARG_POD_NETWORK:-no}
   ARG_POD_NETWORK_CIDR=${ARG_POD_NETWORK_CIDR:-10.244.0.0/12}

   [ ${#POSITIONAL_ARGS[@]} -eq 1 ] && ARG_K8S_VERSION=${POSITIONAL_ARGS[0]} && validate_arg_k8s_version
   check_incompatible_args
}

check_incompatible_args()
{
  ([ ! -z ${ARG_K8S_VERSION} ] && [ ${ARG_LATEST} == yes ]) && fatal_error "You can't request at the same time --latest and a specific version."
   [ ${ARG_CNI} == cilium ] && [ ${ARG_SKIP_HELM} == yes ] && fatal_error "Can't skip helm with '--cni cilium'"
   [ ${ARG_CNI} == antrea ] && [ ${ARG_SKIP_HELM} == yes ] && fatal_error "Can't skip helm with '--cni antrea'"
}

validate_arg_cni()
{
   ([ -z ${ARG_CNI} ] || [[ "${ARG_CNI}" =~ ^- ]]) && fatal_error "Need a value with --cni   Expecting: calico,antrea or cilium"
   [ ${ARG_CNI} == calico ] && return 
   [ ${ARG_CNI} == antrea ] && return 
   [ ${ARG_CNI} == cilium ] && return 
   fatal_error "Invalid CNI   Expecting: calico,antrea or cilium"
}

validate_arg_pod_network_cidr()
{
   ([ -z ${ARG_POD_NETWORK_CIDR} ] || [[ "${ARG_POD_NETWORK_CIDR}" =~ ^- ]]) && fatal_error "Need a <CIDR> with --pod-network-cidr   Expecting format: 10.244.0.0/12"
   [[ "${ARG_POD_NETWORK_CIDR}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$ ]] || fatal_error "Invalid <CIDR> with --pod-network-cidr    Expecting format: 10.244.0.0/12"
}

validate_arg_k8s_version()
{
   [[ "${ARG_K8S_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]] || fatal_error "Invalid [kubernetes-version]   Expecting format look like this: 1.25"
}

validate_arg_api_endpoint()
{
   ([ -z ${ARG_API_ENDPOINT} ] || [[ "${ARG_API_ENDPOINT}" =~ ^- ]]) && fatal_error "Need a value with --prod   Expect <FQDN_ENDPOINT> or <VIRTUAL_IP>"
   [[ "${ARG_API_ENDPOINT}" =~ ^.*[_]+.*$ ]] && fatal_error "Invalid --prod <FQDN_ENDPOINT>   Forbiden special character (_ underscrore)"
   [[ "${ARG_API_ENDPOINT}" =~ ^[-a-zA-Z0-9\.]+$ ]] || fatal_error "Invalid --prod <FQDN_ENDPOINT>|<VIRTUAL_IP>  Forbiden special character"
}

is_debian12()
{
   return $(grep -q "Debian GNU/Linux 12" /etc/issue)
}

is_debian_package_installed()
{
   PACKAGE_NAME=$1
   PACKAGE_VERSION=$2
   return $( dpkg -s ${PACKAGE_NAME} 2>/dev/null| grep -q "^Version: ${PACKAGE_VERSION}" )
}

get_local_ip_address()
{
    ip -4 -br address list | awk -F '[/ ]*' '$2 == "UP" { print $3 }' | head -1
}

setup_kubernetes_repo()
{
   if [ ! -f /etc/apt/sources.list.d/kubernetes.list ] ; then
      log_info "Setup Kubernetes Official Repository"
      apt-get install -y apt-transport-https ca-certificates curl gpg

      [ ! -d /etc/apt/keyrings ] && mkdir -m 755 /etc/apt/keyrings
      curl -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
         | tee /etc/apt/sources.list.d/kubernetes.list
      apt-get update
   fi
}

is_kubernetes_repo_exist()
{
   return $( [ -f /etc/apt/sources.list.d/kubernetes.list ] )
}

select_kubernetes_version()
{ 
  [ ${ARG_OLDER_K8S_VERSIONS} == yes ] && QUANTITY_LIMIT=100

  VERSIONS=$(apt-cache madison kubectl \
		| awk -F "[. ]*" 'BEGIN {VERSION=x}  ($4 "." $5) != VERSION {print $4 "." $5 "." $6; VERSION = $4 "." $5 }' \
		| head -${QUANTITY_LIMIT:-${QUANTITY_OF_K8S_VERSIONS}} \
		| tac)

  LATEST_VERSION_INDEX=$(echo ${VERSIONS} | wc -w)

  ARRAY_VERSIONS=()
  COUNT=1
  for VERSION in ${VERSIONS}; do
    ARRAY_VERSIONS+=(${VERSION})
    [ ${COUNT} -eq ${LATEST_VERSION_INDEX} ] && MESSAGE=" (latest)" || MESSAGE=""
    [ ! -z ${ARG_K8S_VERSION} ] &&  [[ ${VERSION} =~ ^${ARG_K8S_VERSION}\. ]] \
         && AUTO_INPUT=${COUNT} && MESSAGE="${MESSAGE} (requested version)"
    echo "${COUNT}) Kubernetes-$( echo ${VERSION} | sed 's/\.[0-9]*-.*$//')"${MESSAGE}
    ((COUNT++))
  done
 
  echo -e "Install (${LATEST_VERSION_INDEX}):\c "
  [ ! -z ${ARG_K8S_VERSION} ] && [ -z ${AUTO_INPUT} ] && fatal_error "Kubernetes requested version not found. Maybe you need to increase the history of available version."
  ([ ${ARG_LATEST} == no ] && [ -z ${ARG_K8S_VERSION} ]) && read USER_INPUT  # Interactive input
  [ ${ARG_LATEST} == yes ] && echo ${LATEST_VERSION_INDEX}                   # Latest version
  [ ! -z ${AUTO_INPUT} ] && USER_INPUT=${AUTO_INPUT} && echo ${AUTO_INPUT}       # Specific version

  # If input is string
  expr ${USER_INPUT} + 1 &> /dev/null
  [ $? -ne 0 ] && log_warn "Invalid input.." && USER_INPUT=${QUANTITY_OF_K8S_VERSIONS}
   
  [ ${USER_INPUT} -gt ${LATEST_VERSION_INDEX} ] &> /dev/null
  [ $? -eq 0 ] && log_warn "Invalid input.." && USER_INPUT=${QUANTITY_OF_K8S_VERSIONS}

  [ -z ${USER_INPUT} ] && log_info "Using latest" # (-1) last element of the array of versions
  
  ((USER_INPUT--))
  VERSION_TO_INSTALL=${ARRAY_VERSIONS[${USER_INPUT}]}
}

is_kubernetes_pkg_installed()
{
   return $( is_debian_package_installed kubeadm ${VERSION_TO_INSTALL} )
}

kubernetes_prerequisites()
{
   log_info "Checking Kubernetes prerequisites for CPUs"
   is_system_have_enought_cpu || fatal_error "Kubernetes need ${QUANTITY_OF_CPU_MIN} CPUs"

   log_info "Checking Kubernetes prerequisites for Memory"
   is_system_have_enought_memory || fatal_error "Kubernetes need ${QUANTITY_OF_MEMORY_GB_MIN} GB of Memory"

   log_info "Setup Kubernetes prerequisites for Swap"
   disable_swap

   log_info "Checking CRI (Container Runtime Interface) for Kubernetes"
   is_containerd_installed && log_info "containerd is already installed" || install_containerd
   is_containerd_configured_for_kubernetes && log_info "containerd seems already configured with SystemdCgroup" || setup_containerd
   log_info "You can use contaired as CRI (Container Runtime Interface) for Kubernetes"
   
   setup_crictl_to_containerd

   container_runtimes_prerequisites
}

container_runtimes_prerequisites()
{
   log_info "Container Runtimes Prerequisites"
   enable_ipv4_forwarding_and_iptables_see_bridge_traffic
}

enable_ipv4_forwarding_and_iptables_see_bridge_traffic()
{
   log_info "Enable Forwarding IPv4 and letting iptables see bridged traffic"
   
   log_info "Load kernel modules"
   cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
   modprobe overlay
   modprobe br_netfilter

   cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

   log_info "Apply kernel settings"
   sysctl -p /etc/sysctl.d/k8s.conf \
      | sed "s/= 1$/\t: Enabled/" |  sed "s/= 0$/\t: Disabled/"
}

is_system_have_enought_cpu()
{
   CPU_COUNT=$(grep "^$" /proc/cpuinfo | wc -l)
   log_info "Found ${CPU_COUNT} CPUs"
   return $( [ ${CPU_COUNT} -ge ${QUANTITY_OF_CPU_MIN} ] )
}

is_system_have_enought_memory()
{
   MEMORY_KB=$(awk '$1 == "MemTotal:" {print $2}' /proc/meminfo)
   log_info "Found ${MEMORY_KB} KB of Memory"
   MEMORY_GB=$(expr ${MEMORY_KB} / 1000000)
   return $( [ ${MEMORY_GB} -ge ${QUANTITY_OF_MEMORY_GB_MIN} ] )
}

disable_swap()
{
   log_info "Disabling swap"

   swapoff -a
   sed -i "s/^\(UUID.*swap.*\)$/#\1/" /etc/fstab

   SWAP_DEVICES=$(systemctl --type swap --all | grep swap | sed "s/.*\(dev-[^\.]*\.swap\).*/\1/")
   for DEVICE in ${SWAP_DEVICES} ; do systemctl mask ${DEVICE}; done
   log_info "Swap devices need to be masked with systemctl"
   systemctl --type swap --all
}

is_containerd_installed()
{
   return $(is_debian_package_installed containerd)
}

install_containerd()
{
   log_info "Installing Containerd"
   apt-get install -y containerd
   apt-mark hold containerd
}

setup_crictl_to_containerd()
{
   log_info "Set runtine endpoint of crictl to containerd socket"
   crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
}

is_containerd_configured_for_kubernetes()
{
   [ ! -f /etc/containerd/config.toml ] && return false
   return $(grep -q "SystemdCgroup = true" /etc/containerd/config.toml)
}

setup_containerd()
{
   [ ! -f /etc/containerd/config.toml.debian ] \
      && log_info "Save debian config file. /etc/containerd/config.toml" \
      && cp -p /etc/containerd/config.toml{,.debian}

   cp -p /etc/containerd/config.toml{,.backup-$(date "+%Y-%m-%d-%Hh%M")}

   log_info "Containerd config - Load default configuration attributes"
   containerd config default > /etc/containerd/config.toml
   
   log_info "Containerd config - Don't comply with Debian, bin_dir = \"/usr/lib/cni\" because CNI are going to the default /opt/cni/bin "
   # sed -i "s/^\(.*bin_dir = \).*/\1\"\/usr\/lib\/cni\"/" /etc/containerd/config.toml

   log_info "Containerd config - Comply Debian, io.containerd.internal.v1.opt : path = /var/lib/containerd/opt"
   sed -i "s/^\( *path =\) \"\/opt\/containerd\"/\1 \"\/var\/lib\/containerd\/opt\"/" /etc/containerd/config.toml
   
   log_info "Containerd config - Enable Systemd cgroup driver"
   sed -i "s/^\( *SystemdCgroup =\).*/\1 true/" /etc/containerd/config.toml

   service containerd restart
}

link_kubernetes_cni_to_containerd()
{
   log_info "Linking Kubernetes-cni to Containerd"
   
   [ ! -d /var/lib/containerd/opt/bin ] && mkdir -p /var/lib/containerd/opt/bin
   for CNI in /opt/cni/bin/* ; do ln -s -v --force ${CNI} /var/lib/containerd/opt/bin/; done
}

is_hemld_installed()
{
   return $(is_debian_package_installed hemld)
}

install_helm()
{
   log_info "Installing Heml"
   curl https://baltocdn.com/helm/signing.asc | gpg --dearmor --yes -o /usr/share/keyrings/helm.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
         | tee /etc/apt/sources.list.d/helm-stable-debian.list
   apt-get update
   apt-get install -y helm
}

add_some_helm_repo()
{
   log_info "Heml - Adding some repository"
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   log_info "Helm - You can find other repo here:  https://artifacthub.io"
}

export_kubeconfig()
{
   EXPORT_CMD="export KUBECONFIG=/etc/kubernetes/admin.conf"
   eval ${EXPORT_CMD}

   grep -q "^${EXPORT_CMD}" /root/.profile && return

   log_info "To be able to run 'kubectl' as root, we add this in /root/.profile  '${EXPORT_CMD}'"
   echo ${EXPORT_CMD} >> /root/.profile
}

kubdeadm_init()
{
   log_info "Initializing Kubernetes cluster.."
   unset OPTIONS
   [ ${ARG_CNI} == calico ] && OPTIONS="${OPTIONS}"
   [ ${ARG_CNI} == cilium ] && OPTIONS="${OPTIONS} --skip-phases=addon/kube-proxy"
   ([ ${ARG_CNI} == antrea ] || [ ${ARG_POD_NETWORK} == yes ]) && OPTIONS="${OPTIONS} --pod-network-cidr=${ARG_POD_NETWORK_CIDR}"

   [ ${ARG_PRODUCTION} == yes ] && kubdeadm_init_multi_controller ${OPTIONS}
   [ ${ARG_PRODUCTION} == no ]  && kubdeadm_init_single_controller ${OPTIONS}
}

kubdeadm_init_single_controller()
{
   OPTIONS=$*
   LOCAL_IP_ADDRESS=$(get_local_ip_address)
   kubeadm init --apiserver-advertise-address ${LOCAL_IP_ADDRESS} ${OPTIONS} || exit 3
}

kubdeadm_init_multi_controller()
{
   OPTIONS=$*
   kubeadm init --control-plane-endpoint ${ARG_API_ENDPOINT} --upload-certs ${OPTIONS} || exit 3
}

install_cni()
{
   [ ${ARG_CNI} == calico ] && install_cni_calico
   [ ${ARG_CNI} == antrea ] && install_cni_antrea
   [ ${ARG_CNI} == cilium ] && install_cni_cilium
}

install_cni_calico()
{
   log_info "Installing CNI - Calico"
   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
}

antrea_prerequisites()
{
   apt install -y openvswitch-switch openvswitch-common openvswitch-switch-dpdk
}

install_cni_antrea()
{
   log_info "Installing CNI - Antrea"
   helm repo add antrea https://charts.antrea.io
   helm repo update antrea
   helm install antrea antrea/antrea --namespace kube-system
}

install_cni_cilium()
{
   log_info "Installing CNI - Cilium"

   VERSION_CILIUM_STABLE=$(curl -s https://raw.githubusercontent.com/cilium/cilium/main/stable.txt)
   API_SERVER_PORT=6443

   helm repo add cilium https://helm.cilium.io/
   helm repo update cilium
   helm install cilium cilium/cilium --version ${VERSION_CILIUM_STABLE} \
       --namespace kube-system \
       --set kubeProxyReplacement=true \
       --set k8sServiceHost=${ARG_API_ENDPOINT:-${LOCAL_IP_ADDRESS}} \
       --set k8sServicePort=${API_SERVER_PORT}
      #  --set clusterPoolIPv4PodCIDRList=${ARG_POD_NETWORK_CIDR} \

   log_info "Installing Cilium cli - /usr/local/bin/cilium"
   curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
   sha256sum --check cilium-linux-amd64.tar.gz.sha256sum \
      && tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin \
      && rm cilium-linux-amd64.tar.gz{,.sha256sum}

   log_warn "Humm.. seems something don't work well with cilium"
   log_warn "Check inter pod communication: ping OK, tcp KO"
   log_warn "Pod can't reach dns"
   log_warn "Check cilium-health status  Look at agent communication!!"
}

log_info()
{
   echo -e "\nINFO: $*"
   sleep ${DELAY_SECOND:-0}
}

log_warn()
{
   echo -e "\nWARNING: $*"
   sleep ${DELAY_SECOND:-0}
}

fatal_error()
{
   echo -e "\nERROR: $*"
   exit 2
}

## Main

parse_args $*

is_debian12 || fatal_error "This script is only tested for Debian12"

[ ! is_kubernetes_repo_exist ] && setup_kubernetes_repo || apt-get update

select_kubernetes_version
log_info "Installing kubernetes ${VERSION_TO_INSTALL}"

is_kubernetes_pkg_installed && log_info "kubernetes ${VERSION_TO_INSTALL} are already installed"
if ! is_kubernetes_pkg_installed; then
   log_info "Need to replace kubernetes packages"
   apt-mark unhold	kubelet kubeadm kubectl
   apt remove -y	kubelet kubeadm kubectl
   apt install -y	kubelet=${VERSION_TO_INSTALL} kubeadm=${VERSION_TO_INSTALL} kubectl=${VERSION_TO_INSTALL}
   apt-mark hold	kubelet kubeadm kubectl
   link_kubernetes_cni_to_containerd
fi

kubernetes_prerequisites

([ ${ARG_SKIP_HELM} == no ]) && (is_hemld_installed || install_helm) && add_some_helm_repo

log_info "Installed Kubernetes packages"
dpkg -l		kubelet kubeadm kubectl

export_kubeconfig

[ ${ARG_CNI} == antrea ] && antrea_prerequisites

[ ${ARG_INIT_CLUSTER} == no ] && log_info "You are ready to go with : kubeadm" && exit

kubdeadm_init
install_cni

log_warn "To start using your cluster as  <root>          You to need to re-connect or run:  export KUBECONFIG=/etc/kubernetes/admin.conf"

cat << EOF

   To start using your cluster, please scroll-up (Ctrl+Shit Arrow-up) to see what to do.

   Notice: For root user we have already added the export in /root/.profile

   To join other nodes in the cluster you must install the same version of kubernetes.
   To do that you can run this on them :
      1. ${THIS_PROGRAM}    -Without --init or --prod
      2. kubeadm --join     - Please scroll-up (Ctrl+Shit Arrow-up) to see args to use

   Have good time with Kubernetes.

EOF