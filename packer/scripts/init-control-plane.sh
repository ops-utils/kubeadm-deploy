#!/usr/bin/env bash
set -euo pipefail

# Initialize control plane
kubeadm init --pod-network-cidr "${pod_network_cidr:-NO_POD_NETWORK_CIDR}" # --ignore-preflight-errors=NumCPU

# Set pointer to config file, so kubectl works on the control plane node if needed
chmod 777 /etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /root/.bashrc

# Set some helpful aliases
{
  echo "alias k='kubectl'"
  echo "alias kgp='kubectl get pods'"
  echo "alias kdp='kubectl describe pods'"
  echo "alias kgn='kubectl get nodes'"
  echo "alias kdn='kubectl describe nodes'"
} >> /root/.bashrc

# shellcheck disable=SC1091
source "/root/.bashrc"

# Install a "network fabric" (k8s says it is "CNI-agnostic", so you need to
# choose & install your own container network interface). Here I chose Flannel
# since it doesn't run as an Operator by default, which at the time of this
# writing was a slightly newer k8s feature
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Allow Pods to be scheduled on the control plane; don't do this in prod, but if
# you just want a single-node k8s cluster, then run the following (even
# post-init):
# kubectl taint nodes --all node-role.kubernetes.io/master-

# You can re-add that taint with the following (I think):
# kubectl taint nodes --all node-role.kubernetes.io/master="":NoSchedule

# Generate permanent token, and grab cluster's CA cert hash. Subsequent,
# platform-specific scripts will need to push/store them somewhere the Workers
# can access them

mkdir -p "${HOME}"/kubeadm-join

kubeadm token create --ttl 0 > "${HOME}"/kubeadm-join/token

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | sed 's/^.* //' \
> "${HOME}"/kubeadm-join/hash

exit 0
