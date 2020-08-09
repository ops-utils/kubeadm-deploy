#!/usr/bin/env bash

# This is intended for an Ubuntu deployment host

# Core sysutils
apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    awscli \
    htop


# Clean this up later to be safer
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


# Initialize control plane
kubeadm init --pod-network-cidr "10.0.0.0/16" # --ignore-preflight-errors=NumCPU


# Set pointer to config file, so kubectl works
chmod 777 /etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> "${HOME}/.bashrc"
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /home/ubuntu/.bashrc
source "${HOME}/.bashrc"


# Install a "network fabric" (*shrug*, this is required for something about Pod
# DNS)
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml


# Allow Pods to be scheduled on the control plane; don't do this in real life
kubectl taint nodes --all node-role.kubernetes.io/master-
