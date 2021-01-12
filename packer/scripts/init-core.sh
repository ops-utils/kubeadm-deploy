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
    ca-certificates \
    curl \
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
  printf "br_netfilter\n" > /etc/modules-load.d/k8s.conf
  printf "net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\n" > /etc/sysctl.d/k8s.conf
  sysctl --system
}

# Kubernetes doesn't want swap enabled, so disable it here
disable-swap() {
  printf "\nDisabling swap...\n\n" > /dev/stderr && sleep 2
  sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  swapoff -a
}

main() {
  init-sys-packages
  init-cri "${cri:-}"
  init-kubeadm
  lock-versions
  edit-iptables
  disable-swap

  apt-wipe
}

main


# Now, fork remaining logic based on target platform
if [[ "${node_type:-undefined_node_type}" == "control-plane" ]]; then
  bash ./init-control-plane-"${platform:-undefined_platform}".sh
elif [[ "${node_type:-undefined_node_type}" == "worker" ]]; then
  bash ./init-worker-"${platform:-undefined_platform}".sh
else
  printf "\nYou have not provided a 'node_type' variable to the build! Exiting.\n\n" > /dev/stderr
  exit 1
fi

exit 0
