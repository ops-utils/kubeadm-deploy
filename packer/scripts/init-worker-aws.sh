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

printf "Initializing Worker for platform 'aws'...\n" > /dev/stderr

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

# Wait for S3 cluster files to be available, then grab them
for i in control-plane-address token hash; do
  until aws s3 cp "s3://${cluster_name:-NO_CLUSTER_NAME_SPECIFIED}-${AWS_ACCOUNT_NUMBER}/${i}" /tmp/"${i}"; do
    printf "%s is not yet ready in S3; sleeping\n" "${i}"
    sleep 15
  done
done


# Keep trying to join the Cluster
joinerr() {
  printf "Unable to join cluster's control plane at %s; sleeping...\n" "$(cat control-plane-address)" > /dev/stderr
  sleep 15
}

while true; do

  case "${k8s_distro:-NOT_SET}" in

    k3s)
      curl -fsSL -o /tmp/install.sh https://get.k3s.io
      sh /tmp/install.sh agent \
        --server https://"$(cat /tmp/control-plane-address)":6443 \
        --token-file /tmp/token \
      || {
        joinerr
        continue
      }
    ;;

    kubeadm)
      kubeadm join \
        "$(cat /tmp/control-plane-address)":6443 \
        --token "$(cat /tmp/token)" \
        --discovery-token-ca-cert-hash "sha256:$(cat /tmp/hash)" \
      || {
        joinerr
        continue
      }
    ;;

    *)
      printf "ERROR: Bad KubernetesDistro/k8s_distro variable (%s) -- cannot init\n" "${k8s_distro}" > /dev/stderr
      exit 1
    ;;

  esac

  break

done

exit 0
