#!/usr/bin/env bash

# shellcheck disable=SC2155
export AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query Account --output text)

until aws s3 cp "s3://kubeadm-${AWS_ACCOUNT_NUMBER}/token" .; do
  printf "Cluster token is not yet ready; sleeping\n"
  sleep 15
done

until aws s3 cp "s3://kubeadm-${AWS_ACCOUNT_NUMBER}/hash" .; do
  printf "Cluster hash is not yet ready; sleeping\n"
  sleep 15
done

# Find aw
kubeadm_ip=$(
  aws ec2 describe-instances \
    --filters 'Name=tag:Name,Values=kubeadm-control-plane' \
    --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
    --output text \
  | grep -v None
)

# Join Cluster
kubeadm join \
  "${kubeadm_ip}:6443" \
  --token "$(cat ./token)" \
  --discovery-token-ca-cert-hash "sha256:$(cat ./hash)"
