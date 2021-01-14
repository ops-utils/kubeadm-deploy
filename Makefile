SHELL = /usr/bin/env bash -euo pipefail


#############
#=== AWS ===#
#############

AWS_ACCOUNT_NUMBER = $(shell aws sts get-caller-identity --query Account --output text)
BUCKET_NAME = "s3://$${cluster_name}-$(AWS_ACCOUNT_NUMBER)"
STACK_NAME = "$${cluster_name}-$${stack}"

help:
	@printf "Review the Makefile for a list of targets. Each target will throw an error if you forgot to pass a required variable.\n"

deploy-aws:
	@aws cloudformation deploy \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			$$(jq -r 'to_entries | map("\(.key)=\(.value | tostring)") | .[]' ./aws-cloudformation/vars.json) \
			ClusterName="$${cluster_name}" \
		--capabilities CAPABILITY_IAM \
		--template-file ./aws-cloudformation/"$${stack}".yaml

destroy-aws:
#	@make -s delete-s3-bucket
	@printf "Sending stack delete request for $(STACK_NAME)...\n"
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)
	@printf "Waiting for stack delete to complete...\n"
	@aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)
	@printf "Done\n"

# You'll need this created first for the Packer builder to build the Control Plane image
# sucessfully
create-s3-bucket:
	@printf "Creating S3 bucket %s...\n" $(BUCKET_NAME) && \
	aws s3 mb $(BUCKET_NAME)
	@printf "Done\n"

delete-s3-bucket:
	@printf "Removing S3 bucket %s...\n" $(BUCKET_NAME)
	@aws s3 rm --recursive $(BUCKET_NAME)
	@aws s3 rb $(BUCKET_NAME)
	@printf "Done\n"

# Use SSM Session Manager to connect to your cluster nodes by nametag
ssmsm-node:
	@aws ssm start-session --target \
		$$( \
			aws ec2 describe-instances \
				--filters \
					Name=tag:Name,Values="$${cluster_name}-$${node_type}" \
					Name=instance-state-name,Values=running \
				--query 'Reservations[*].Instances[*].InstanceId' \
				--output text \
			| head -n1 \
		)
