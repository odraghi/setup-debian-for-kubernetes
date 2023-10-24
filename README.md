# setup-debian-for-kubernetes

## Description
This script help you to quickly setup a kubernetes cluster an Debian12.

- PHASE1: Install Kubernetes and prerequisites
- PHASE2: Initialize a cluster
- PHASE3: Join other node

## PHASE1: Install Kubernetes and prerequisites
Setup Debian12 with prerequisites to run kubernetes.

The script follow kubernetes prerequisites :
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/

The script let you the choose the kubernetes version or default to the latest version.

The CRI (Container Runtime Interface) is Containerd.

## PHASE2: Initialize a cluster
You can initialize a cluster with a CNI (Container Network Interface).
You can do that with the option '--init' or '--prod'.

Supported CNI:
- calico (default)
- antrea

In progess of supporting CNI:
- cilium (Soon...) I've issue with pod newtorking but you can try yourself with '--force'

For production cluster, a minimum of 3 controllers is advised.
You need to prepare the API_ENDPOINT of your production cluster.
You have in 3 way:
- With a __FQDN__. This fqdn name must be in your DNS Server
- With a __VIRTUAL_IP__. If you have a loadbalancer for your controle plane.
- With a __FQDN__ and with a __FQDN__.


## PHASE3: Join other node
If you want to add to your cluster you need to:
1. Install Kubernetes and prerequisites. So Run the script without args '--init' and '--prod'
2. Launch the 'kubeadm join' command you are going to see at the end of the initalization of the cluster (PHASE2)


## Installed packages
The script install those packages:
- kubernetes (repo: https://apt.kubernetes.io/ )
- containerd (repo: Debian official)
- heml (repo: Debian official)
- openvswitch-switch (repo: Debian official) (when cni is antrea)


## Launch on the first controller node
As root
```
root@control-01:~# bash install_kubernetes.sh
```

Or as un-privileged user
```
debian@control-01:~$ sudo bash install_kubernetes.sh
```

### Chose your version of Kubernetes
The script ask you witch version of kubertenetes packages you want.
By defaut it install the lastet version available.
```
1) Kubernetes-1.24
2) Kubernetes-1.25
3) Kubernetes-1.26
4) Kubernetes-1.27
5) Kubernetes-1.28 (latest)
Install (5):
```

At the end of PHASE1 (Install Kubernetes and prerequisites), you will see that
```
INFO: Installed Kubertenes packages
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name           Version      Architecture Description
+++-==============-============-============-=====================================
hi  kubeadm        1.28.2-00    amd64        Kubernetes Cluster Bootstrapping Tool
hi  kubectl        1.28.2-00    amd64        Kubernetes Command Line Tool
hi  kubelet        1.28.2-00    amd64        Kubernetes Node Agent

INFO: You are ready to go with : kubeadm init
```

### At the end of PHASE2 (Initialize a cluster), you will see that

```
WARNING: To start using your cluster as  <root>          You to need to re-connect or run:  export KUBECONFIG=/etc/kubernetes/admin.conf

   To start using your cluster, please scroll-up (Ctrl+Shit Arrow-up) to see what to do.

   Notice: For root user we have already added the export in /root/.profile

   To join other nodes in the cluster you must install the same version of kubernetes.
   To do that you can run this on them :
      1. bash install_kubernetes.sh --cni calico 1.28
      2. kubeadm --join  <args>
      Please scroll-up (Ctrl+Shit Arrow-up) to see args to use.

   Have good time with Kubernetes.
```
Here you can see in that sample, that I 've chosen to install kubernetes with calico (default CNI).

### Exemple to setup my worker node as root
```
root@control-01:~# scp install_kubernetes.sh root@worker-01:
root@control-01:~# ssh root@worker-01

root@worker-01:~# bash install_kubernetes.sh --cni calico 1.28
root@worker-01:~# kubeadm join 192.168.10.11:6443 --token sc1zw7.0exkak1fborbrbjt \
        --discovery-token-ca-cert-hash sha256:a870fa93c0c4ded0b892879d397c0374484defc41305e5122308bd01dea174a7
```