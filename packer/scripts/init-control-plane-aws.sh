#!/usr/bin/env bash
set -euo pipefail

printf "Initializing Control Plane for platform 'aws'...\n" > /dev/stderr

# SSM agent isn't installed on AWS Debian AMIs, so install it here. Do this
# first, so it's reachable if something else breaks. us-east-1 is just the
# endpoint; nothing's configured for that region specifically
curl -fsSL -o /tmp/ssm.deb 'https://s3.us-east-2.amazonaws.com/amazon-ssm-us-east-2/latest/debian_amd64/amazon-ssm-agent.deb'
dpkg -i /tmp/ssm.deb
systemctl enable amazon-ssm-agent
# Fail if not enabled & running
systemctl is-enabled amazon-ssm-agent
systemctl is-active amazon-ssm-agent

# Detect if Packer is building this image (using a Packer var we pass in only at
# build time); if so, relegate the script invocation to the worker EC2 userdata
if [[ -n "${platform:-}" ]]; then
  printf "NOTE: This control-plane init script is found at %s, and should instead be run during EC2 userdata evaluation\n" "${PWD}/$(basename "$0")" > /dev/stderr
  exit 0
fi

# Make sure you're in a spot to run/source other scripts from the same workdir
cd "$(dirname "$0")" || exit 1

# Docker 20+ needs $HOME set, else kubeadm will fail when it tries to parse
# `docker info`, and cloud-init/userdata doesn't set a $HOME variable. So be
# safe and set it here
export HOME="${HOME:-/root}"

# Run the core init script first
bash ./init-control-plane.sh

# kubeadm: For SOME REASON, CoreDNS isn't reachable from within Pods, but a
# restart of its Deployment here seems to fix that -- maybe this is an issue
# once the CNI is applied? I can confirm this is an issue with both Calico and
# Flannel with kubeadm. Which is especially weird, because CoreDNS isn't even
# supposed to come online until there's a CNI applied (it spins on Pending).
# Could be that once the CNI is applied, CoreDNS starts, but the CNI isn't ready
# yet.
# So, set KUBECONFIG for kubeadm (k3s sets this already), then try to restart it
echo "Using KUBECONFIG ${KUBECONFIG:-/etc/kubernetes/admin.conf}"
kubectl -n kube-system rollout restart deployment coredns || true

# Add No* taints to the Control Planes -- even for k3s, if you're running this
# in the cloud, it'd be weird to not have Workers running too
kubectl taint nodes --all node-role.kubernetes.io/control-plane="":NoSchedule
kubectl taint nodes --all node-role.kubernetes.io/control-plane="":NoExecute

apt-get update && apt-get install -y awscli

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_ACCOUNT_ID

# Push the control plane address, token, and (maybe) CA cert hash to S3 for
# Workers to use
hostname | sed 's/-/./g' | sed 's/ip\.//' > /root/k8s-join/control-plane-address
for i in control-plane-address token hash; do
  if [[ -f /root/k8s-join/"${i}" ]]; then
    printf "Found %s; pushing to S3\n" "${i}"
  else
    printf "%s not found; creating empty file and pushing to S3 so worker check will pass\n" "${i}"
    touch /root/k8s-join/"${i}"
  fi
  aws s3 cp /root/k8s-join/"${i}" s3://"${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_ID}/${i}"
done

exit 0
