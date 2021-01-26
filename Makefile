SHELL = /usr/bin/env bash -euo pipefail


#############
#=== AWS ===#
#############

AWS_ACCOUNT_NUMBER = $(shell aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME = $(shell jq -r .ClusterName ./aws-cloudformation/vars.json)
BUCKET_NAME = "s3://$(CLUSTER_NAME)-$(AWS_ACCOUNT_NUMBER)"
STACK_NAME = "$(CLUSTER_NAME)-$${stack}"

help:
	@printf "Review the Makefile(s) for a list of targets. Each target will throw a meaningful error if you forgot to pass a required variable.\n"

deploy-aws:
	@make -s create-s3-bucket || true
	@aws cloudformation deploy \
		--no-fail-on-empty-changeset \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			$$(jq -r 'to_entries | map("\(.key)=\(.value | tostring)") | .[]' ./aws-cloudformation/vars.json) \
		--capabilities CAPABILITY_IAM \
		--template-file ./aws-cloudformation/"$${stack}".yaml

destroy-aws:
	@printf "Sending stack delete request for $(STACK_NAME)...\n"
	@aws cloudformation delete-stack --stack-name $(STACK_NAME)
	@printf "Waiting for stack delete to complete...\n"
	@aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)
	@make -s delete-s3-bucket || true
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
					Name=tag:Name,Values="$(CLUSTER_NAME)-$${node_type}" \
					Name=instance-state-name,Values=running \
				--query 'Reservations[*].Instances[*].InstanceId' \
				--output text \
			| head -n1 \
		)
