SHELL = /usr/bin/env bash

AWS_ACCOUNT_NUMBER := $(shell aws sts get-caller-identity --query Account --output text)

deploy-aws:
	@aws cloudformation deploy \
		--stack-name kubeadm \
		--capabilities CAPABILITY_IAM \
		--template-file ./aws-cloudformation/kubeadm.yaml
	@make -s push-scripts-to-s3

push-scripts-to-s3:
	@aws s3 cp --recursive ./scripts s3://kubeadm-$(AWS_ACCOUNT_NUMBER)/scripts/

destroy-aws:
	@aws cloudformation delete-stack --stack-name kubeadm
	@printf "Waiting for stack delete to complete...\n"
	@aws cloudformation wait stack-delete-complete --stack-name kubeadm
# You can remove the following lines, but the CFN template assumes you're doing
# this. You'd also need to refactor the template to fully prevent this behavior
	@printf "Removing S3 bucket...\n"
	@aws s3 rm --recursive s3://kubeadm-$(AWS_ACCOUNT_NUMBER)
	@aws s3 rb s3://kubeadm-$(AWS_ACCOUNT_NUMBER)
