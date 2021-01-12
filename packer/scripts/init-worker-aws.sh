#!/usr/bin/env bash
set -euo pipefail

# SSM agent isn't installed on AWS Debian AMIs, so install it here. Do this
# first, so it's reachable if something else breaks. us-east-1 is just the
# endpoint; nothing's configured for that region specifically
curl -fsSL -o /tmp/ssm.deb 'https://s3.us-east-2.amazonaws.com/amazon-ssm-us-east-2/latest/debian_amd64/amazon-ssm-agent.deb'
dpkg -i /tmp/ssm.deb
systemctl enable amazon-ssm-agent
# Fail if not enabled & running
systemctl is-enabled amazon-ssm-agent
systemctl is-active amazon-ssm-agent

printf "Initializing Worker for platform 'aws'...\n" "${platform:-}" > /dev/stderr

# Detect if Packer is building this image (using a Packer var we pass in only at
# build time); if so, relegate the script invocation to the worker EC2 userdata
if [[ -n "${platform:-}" ]]; then
  printf "NOTE: This worker init script is found at %s, and should instead be run during EC2 userdata evaluation\n" "${PWD}/$(basename "$0")" > /dev/stderr
  exit 0
fi

apt-get update && apt-get install -y awscli

AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query Account --output text)
AWS_DEFAULT_REGION=$(curl -fsSL http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export AWS_ACCOUNT_NUMBER
export AWS_DEFAULT_REGION

# Docker 20+ needs $HOME set, else kubeadm will fail when it tries to parse
# `docker info`, and cloud-init/userdata doesn't set a $HOME variable. So be
# safe and set it here
export HOME="${HOME:-/root}"

# Wait for cluster token & hash to be available, then grab them
until aws s3 cp "s3://${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_NUMBER}/token" /tmp/token; do
  printf "Cluster token is not yet ready; sleeping\n"
  sleep 15
done

until aws s3 cp "s3://${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_NUMBER}/hash" /tmp/hash; do
  printf "Cluster hash is not yet ready; sleeping\n"
  sleep 15
done

# Find control plane IP
control_plane_ip=$(
  aws ec2 describe-instances \
    --filters \
      "Name=tag:Name,Values=${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-control-plane" \
      'Name=instance-state-name,Values=running' \
    --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
    --output text \
  | grep -v None
)

# Join Cluster
kubeadm join \
  "${control_plane_ip}":6443 \
  --token "$(cat /tmp/token)" \
  --discovery-token-ca-cert-hash "sha256:$(cat /tmp/hash)"

exit 0
