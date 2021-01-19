#!/usr/bin/env bash
set -euo pipefail

# This is kind of irritating, but initializing a control plane on/in a DIFFERENT
# IP or network than the launch location causes etcd/kube-apiserver to not work
# at next launch. So this script contains the core init functionality to be run
# by other control-plane init scripts, which can then run their own additional
# inits in top of it.

printf "Initializing Control Plane...\n" > /dev/stderr
kubeadm init --pod-network-cidr="${pod_network_cidr:-NO_POD_NETWORK_CIDR}" # --ignore-preflight-errors=NumCPU
chmod 777 /etc/kubernetes/admin.conf

# This block will:
# * Set pointer to config file, so kubectl works on the control plane node if needed
# * Set some helpful aliases
# * Enable shell completion on launch
{
  echo "export KUBECONFIG=/etc/kubernetes/admin.conf"
  echo "alias k='kubectl'"
  echo "alias kgp='kubectl get pods'"
  echo "alias kdp='kubectl describe pods'"
  echo "alias kgn='kubectl get nodes'"
  echo "alias kdn='kubectl describe nodes'"
  echo 'source <(kubectl completion bash)'
  echo "complete -F __start_kubectl k" # this is so shell completion works with the main alias
  # shellcheck disable=SC2016
  echo '[[ "${TERM}" != "screen" ]] && exec tmux' # tmux runs at shell launch; THIS NEEDS TO BE LAST
} >> /root/.bashrc

# shellcheck disable=SC1091
source /root/.bashrc

# Install a "network fabric" (k8s says it is "CNI-agnostic", so you need to
# choose & install your own container network interface). kubeadm only does e2e
# tests using one called Calico, so that's what's used here by default. Another
# option is Flannel, commented below.
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
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

mkdir -p /root/kubeadm-join

kubeadm token create --ttl 0 > /root/kubeadm-join/token

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | sed 's/^.* //' \
> /root/kubeadm-join/hash

# kubeadm init exits successfully before everything's online, and since the CNI
# is applied after the init, it also takes time to come up. Workers will have a
# hard time joining if they come up too fast.
printf "Sleeping for 60s to let all Control Plane components come up...\n" > /dev/stderr
sleep 60

exit 0
