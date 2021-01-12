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

printf "Initializing Control Plane for platform 'aws'...\n" > /dev/stderr

apt-get update && apt-get install -y awscli

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_ACCOUNT_ID

# Push token and CA cert hash to S3 for Workers to use
aws s3 cp /root/kubeadm-join/token s3://"${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_ID}"/token
aws s3 cp /root/kubeadm-join/hash s3://"${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_ID}"/hash

exit 0
