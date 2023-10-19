#!/bin/bash

# Copyright (C) 2023 DRAGHI Olivier
#     This program comes with ABSOLUTELY NO WARRANTY; for details type `install_kubernetes.sh help'.
#     This is free software, and you are welcome to redistribute it
#     under certain conditions; type `install_kubernetes.sh conditions' for details.

QUANTITY_OF_K8S_VERSIONS=5
QUANTITY_OF_CPU_MIN=2
QUANTITY_OF_MEMORY_GB_MIN=2


function copyright()
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

function is_debian12()
{
   return $(cat /etc/issue | grep -q "Debian GNU/Linux 12")
}

function setup_kubernetes_repo()
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

function is_kubernetes_repo_exist()
{
   return $( [ -f /etc/apt/sources.list.d/kubernetes.list ] )
}

function select_kubernetes_version()
{ 
  VERSIONS=$(apt-cache madison kubectl \
		| awk '{print $3}' \
		| awk -F "." 'BEGIN {VERSION=x} $2!= VERSION {print $1 "." $2 "." $3; VERSION = $2}'\
		| head -${QUANTITY_OF_K8S_VERSIONS} \
		| tac)
  ARRAY_VERSIONS=()
  COUNT=1
  for VERSION in ${VERSIONS}; do
    ARRAY_VERSIONS+=(${VERSION})
    [ ${COUNT} -eq ${QUANTITY_OF_K8S_VERSIONS} ] && LATEST_MESSAGE=" (latest)" || LATEST_MESSAGE=""
    echo "${COUNT}) Kubernetes-$( echo ${VERSION} | sed 's/\.[0-9]*-.*$//')"${LATEST_MESSAGE}
    ((COUNT++))
  done

  echo -e "Install (${QUANTITY_OF_K8S_VERSIONS}):\c "
  read USER_INPUT

  # If input is string
  expr ${USER_INPUT} + 1 &> /dev/null
  [ $? -ne 0 ] && log_warn "Invalid input.." && USER_INPUT=${QUANTITY_OF_K8S_VERSIONS}
   
  [ ${USER_INPUT} -gt ${QUANTITY_OF_K8S_VERSIONS} ] &> /dev/null
  [ $? -eq 0 ] && log_warn "Invalid input.." && USER_INPUT=${QUANTITY_OF_K8S_VERSIONS}

  [ -z ${USER_INPUT} ] && log_info "Using latest" # (-1) last element of the array of versions
  
  ((USER_INPUT--))
  VERSION_TO_INSTALL=${ARRAY_VERSIONS[${USER_INPUT}]}
}

is_debian_package_installed()
{
   PACKAGE_NAME=$1
   PACKAGE_VERSION=$2

   DPKG_CHECK_OUPUT=$(dpkg -l ${PACKAGE_NAME} | grep ${PACKAGE_NAME})
   [ ! -z ${PACKAGE_VERSION} ] && DPKG_CHECK_OUPUT=$(echo ${DPKG_CHECK_OUPUT} | grep ${PACKAGE_VERSION})
   
   return $( echo ${DPKG_CHECK_OUPUT} | awk '{print $1}' | grep -q "i" )
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
   is_containerd_installed || install_containerd
   link_kubernetes_cni_binaries_to_containerd_path
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
   CPU_COUNT=$(cat /proc/cpuinfo | grep processor | wc -l)
   log_info "Found ${CPU_COUNT} CPUs"
   return $( [ ${CPU_COUNT} -ge ${QUANTITY_OF_CPU_MIN} ] )
}

is_system_have_enought_memory()
{
   MEMORY_KB=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
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

   [ ! -f /etc/containerd/config.toml.debian ] \
      && log_info "Save debian config file. /etc/containerd/config.toml" \
      && cp -p /etc/containerd/config.toml{,.debian}

   setup_containerd
}

setup_crictl_to_containerd()
{
   log_info "Set runtine endpoint of crictl to containerd socket"
   crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
}

setup_containerd()
{
   cp -p /etc/containerd/config.toml{,.ori}

   log_info "Setup Containerd - Load default configuration attributs"
   containerd config default > /etc/containerd/config.toml

   log_info "Setup Containerd - Configure systemd cgroup driver"
   sed -i "s/^\( *SystemdCgroup =\).*/\1 true/" /etc/containerd/config.toml

   log_info "Setup Containerd - Comply with Debian path /opt/containerd -> /var/lib/containerd/opt"
   sed -i "s/^\( *path =\) \"\/opt\/containerd\"/\1 \"\/var\/lib\/containerd\/opt\"/" /etc/containerd/config.toml

   service containerd restart
}

link_kubernetes_cni_binaries_to_containerd_path()
{
   log_info "Linking Kubernetes installed CNI to Containerd CNI directory: /var/lib/containerd/opt/bin (official debian path)"
   for CNI in /opt/cni/bin/* ; do ln -s -v --force ${CNI} /var/lib/containerd/opt/bin/; done
}

is_hemld_installed()
{
   return $(is_debian_package_installed hemld)
}

install_helm()
{
   curl https://baltocdn.com/helm/signing.asc | gpg --dearmor --yes -o /usr/share/keyrings/helm.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
         | tee /etc/apt/sources.list.d/helm-stable-debian.list
   apt-get update
   apt-get install -y helm
}

add_some_helm_repo()
{
   log_info "Heml - Adding some repository"
   helm repo add cilium https://helm.cilium.io/
   helm repo add antrea https://charts.antrea.io
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   log_info "Helm - You can find other repo here:  https://artifacthub.io"
}

log_info()
{
   echo -e "\nINFO: $*"
   sleep 1
}

log_warn()
{
   echo -e "\nWARNING: $*"
   sleep 1
}

fatal_error()
{
   echo -e "\nERROR: $*"
   exit 2
}

## Main

if [ ! -z $1 ]; then
   copyright
   log_info "The script '$0' run without parameter"
   log_info "Adding argument will simply show the copyright"
   exit
fi

is_debian12 || fatal_error "This script is only tested for Debian12"

[ ! is_kubernetes_repo_exist ] && setup_kubernetes_repo || apt-get update

select_kubernetes_version
echo "You are going to install packages for kubernetes ${VERSION_TO_INSTALL}"

is_kubernetes_pkg_installed && log_info "Packages are already installed"
if ! is_kubernetes_pkg_installed; then
   log_info "Need to replace kubernetes packages"
   apt-mark unhold	kubelet kubeadm kubectl
   apt remove -y	kubelet kubeadm kubectl
   apt install -y	kubelet=${VERSION_TO_INSTALL} kubeadm=${VERSION_TO_INSTALL} kubectl=${VERSION_TO_INSTALL}
   apt-mark hold	kubelet kubeadm kubectl
fi

kubernetes_prerequisites

is_hemld_installed || install_helm
add_some_helm_repo

log_info "Installed Kubertenes packages"
dpkg -l		kubelet kubeadm kubectl

log_info "You are ready to go with : kubeadm init"
