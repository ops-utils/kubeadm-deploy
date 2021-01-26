#!/usr/bin/env bash
set -euo pipefail

# This is intended for a Debian-based deployment host

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

apt-get update

# Make sure you're in a spot to run other scripts from the same workdir
cd "$(dirname "$0")" || exit 1

apt-wipe() {
  apt-get autoremove -y
  apt-get autoclean
  apt-get clean
}

init-sys-packages() {
  printf "\nInstalling system packages...\n\n" > /dev/stderr && sleep 2
  apt-get install -y \
    apt-transport-https \
    bash-completion \
    ca-certificates \
    curl \
    dnsutils \
    gnupg-agent \
    htop \
    jq \
    nmap \
    software-properties-common \
    tmux
  apt-wipe
}

init-cri() {
  printf "\nInstalling CRI for k8s to use...\n\n" > /dev/stderr && sleep 2

  if [[ "$1" == "docker" ]]; then
    printf "\nUsing Docker as CRI\n\n" > /dev/stderr && sleep 2
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/debian \
      $(lsb_release -cs) \
      stable"
    apt-get update && apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io
    # Set systemd as the cgroup driver
    {
      echo '{'
      echo '  "exec-opts": ["native.cgroupdriver=systemd"],'
			echo '  "log-driver": "json-file",'
			echo '  "log-opts": {'
			echo '    "max-size": "100m"'
		  echo '  },'
			echo '  "storage-driver": "overlay2"'
      echo '}'
    } > /etc/docker/daemon.json
  else
    printf "\nERROR: env var 'cri' not correctly passed to init-core.sh. Exiting.\n\n" > /dev/stderr && sleep 2
    return 1
  fi
  apt-wipe
  systemctl restart docker
  command -v docker || return 1
}

init-kubeadm() {
  printf "\nInstalling kubeadm...\n\n" > /dev/stderr && sleep 2
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  if [[ ! -f /etc/apt/sources.list.d/kubernetes.list ]]; then
    printf "%s\n" "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
  fi
  apt-get update && apt-get install -y \
    kubelet \
    kubeadm \
    kubectl
  
  # printf "\nInstalling helm...\n\n" > /dev/stderr && sleep 2
  # curl https://baltocdn.com/helm/signing.asc | apt-key add -
  # printf "deb https://baltocdn.com/helm/stable/debian/ all main\n" > /etc/apt/sources.list.d/helm-stable-debian.list
  # apt-get update && apt-get install -y helm
  # helm repo add stable https://charts.helm.sh/stable
}

lock-versions() {
  printf "\nLocking kube versions...\n\n" > /dev/stderr && sleep 2
  apt-mark hold \
    docker-ce \
    kubelet \
    kubeadm \
    kubectl
}

edit-iptables() {
  printf "\nChanging some settings for iptables...\n\n" > /dev/stderr && sleep 2
  lsmod | grep br_netfilter || modprobe br_netfilter
  printf "br_netfilter\n" > /etc/modules-load.d/k8s.conf
  {
    printf "net.bridge.bridge-nf-call-iptables = 1\n"
    printf "net.bridge.bridge-nf-call-ip6tables = 1\n"
  } > /etc/sysctl.d/k8s.conf
  sysctl --system
}

# Kubernetes doesn't want swap enabled, so disable it here
disable-swap() {
  printf "\nDisabling swap...\n\n" > /dev/stderr && sleep 2
  sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  swapoff -a
}

init-k3s() {
  printf "Will not initialize k3s node during core init; will do it during its dedicated init phase\n" > /dev/stderr
}

main() {
  init-sys-packages

  case "${k8s_distro:-}" in

    k3s)
      init-k3s
    ;;

    kubeadm)
      init-cri "${cri:-}"
      init-kubeadm
      lock-versions
      edit-iptables
      disable-swap
    ;;

    *)
      printf "ERROR: Invalid k8s_distro var provided. Exiting.\n" > /dev/stderr
      exit 1
    ;;
  
  esac

  apt-wipe

  # Now, fork remaining logic based on node type & target platform
  bash ./init-"${node_type:-undefined_node_type}"-"${platform:-undefined_platform}".sh
}


main

exit 0
