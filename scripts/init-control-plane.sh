#!/usr/bin/env bash
set -u

# Initialize control plane
kubeadm init --pod-network-cidr "${POD_NETWORK_CIDR}" # --ignore-preflight-errors=NumCPU

# Set pointer to config file, so kubectl works on the control plane node if needed
chmod 777 /etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /home/ubuntu/.bashrc
# shellcheck disable=SC1091
source "/root/.bashrc"

# Install a "network fabric" (*shrug*, this is required for something about Pod
# DNS)
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# # Allow Pods to be scheduled on the control plane; don't do this in real life
# kubectl taint nodes --all node-role.kubernetes.io/master-
