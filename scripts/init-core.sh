#!/usr/bin/env bash

# This is intended for an Ubuntu deployment host

# Core sysutils
apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    htop


# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
apt-get update && apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io


# Install kubeadm etc.
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
if [[ ! -f /etc/apt/sources.list.d/kubernetes.list ]]; then
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
fi
apt-get update
apt-get install -y \
  kubelet \
  kubeadm \
  kubectl


# Lock versions
apt-mark hold \
  docker-ce \
  kubelet \
  kubeadm \
  kubectl


# Add iptables rule
echo "net.bridge.bridge-nf-call-iptables=1" | tee -a /etc/sysctl.conf
sysctl -p
