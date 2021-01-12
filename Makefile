SHELL = /usr/bin/env bash


####################
#=== DEPLOY:AWS ===#
####################

AWS_ACCOUNT_NUMBER = $(shell aws sts get-caller-identity --query Account --output text)

deploy-aws:
	@aws cloudformation deploy \
		--stack-name kubeadm \
		--parameter-overrides $$(paste -s -d' ' ./aws-cloudformation/vars.txt) \
		--capabilities CAPABILITY_IAM \
		--template-file ./aws-cloudformation/kubeadm.yaml

# You'll need this created first for the Packer builder to build the Control Plane image
# sucessfully
create-s3-bucket:
	@printf "Creating S3 bucket s3://kubeadm-$(AWS_ACCOUNT_NUMBER)...\n"
	@aws s3 mb s3://kubeadm-$(AWS_ACCOUNT_NUMBER)
	@printf "Done\n"

destroy-s3-bucket:
	@printf "Removing S3 bucket s3://kubeadm-$(AWS_ACCOUNT_NUMBER)...\n"
	@aws s3 rm --recursive s3://kubeadm-$(AWS_ACCOUNT_NUMBER)
	@aws s3 rb s3://kubeadm-$(AWS_ACCOUNT_NUMBER)
	@printf "Done\n"

destroy-aws:
	@aws cloudformation delete-stack --stack-name kubeadm
	@printf "Waiting for stack delete to complete...\n"
	@aws cloudformation wait stack-delete-complete --stack-name kubeadm
	@printf "Done\n"
# You can remove the following lines, but the CFN template assumes you're
# retaining the S3 bucket when the stack goes down (since you can't delete a
# bucket with contents)

# Use SSM Session Manager to connect to your cluster nodes by nametag
ssmsm-node:
	@set -eu; \
	aws ssm start-session --target \
		$$( \
			aws ec2 describe-instances \
				--filters \
					Name=tag:Name,Values="$${nametag}" \
					Name=instance-state-name,Values=running \
				--query 'Reservations[*].Instances[*].InstanceId' \
				--output text \
			| head -n1 \
		)
