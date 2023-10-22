# setup-debian-for-kubernetes
Setup Debian12 to install the kubernetes version of your choice

## Description
The script follow kubernetes prerequisites :
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/

## Installed packages
The script install those packages:
- kubernetes (repo: https://apt.kubernetes.io/ )
- containerd (repo: Debian official)
- heml (repo: Debian official)

## Launch
As root
```bash
bash install_kubernetes.sh
```

Or as a un-privileged user
```bash
sudo bash install_kubernetes.sh
```

## Chose your version of Kubernetes
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

At the end you will see that
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

