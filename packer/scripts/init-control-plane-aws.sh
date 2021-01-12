#!/usr/bin/env bash
set -euo pipefail

apt-get update && apt-get install -y awscli

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_ACCOUNT_ID

# SSM agent isn't installed on AWS Debian AMIs, so install it here
# us-east-1 is just the endpoint; nothing's configured for that region specifically
curl -fsSL -o /tmp/ssm.deb 'https://s3.us-east-2.amazonaws.com/amazon-ssm-us-east-2/latest/debian_amd64/amazon-ssm-agent.deb'
dpkg -i /tmp/ssm.deb
systemctl enable amazon-ssm-agent
# Fail if not enabled & running
systemctl is-enabled amazon-ssm-agent
systemctl is-active amazon-ssm-agent

# Push token and CA cert hash to S3 for Workers to use
aws s3 cp "${HOME}"/kubeadm-join/token s3://kubeadm-"${AWS_ACCOUNT_ID}"/token
aws s3 cp "${HOME}"/kubeadm-join/hash s3://kubeadm-"${AWS_ACCOUNT_ID}"/hash

exit 0
