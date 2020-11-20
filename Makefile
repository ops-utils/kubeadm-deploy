SHELL = /usr/bin/env bash


### AWS ###
AWS_ACCOUNT_NUMBER := $(shell aws sts get-caller-identity --query Account --output text)
STACK_NAME = kubeadm

deploy-aws:
	@aws cloudformation deploy \
		--stack-name $(STACK_NAME) \
		--capabilities CAPABILITY_IAM \
		--template-file ./aws-cloudformation/kubeadm.yaml
	@make -s push-scripts-to-s3

push-scripts-to-aws-s3:
	@aws s3 cp --recursive ./scripts s3://$(STACK_NAME)-$(AWS_ACCOUNT_NUMBER)/scripts/

destroy-aws-s3:
	@printf "Deleting S3 bucket %s...\n" s3://$(STACK_NAME)-$(AWS_ACCOUNT_NUMBER)
	python3 -c "import boto3; s3 = boto3.resource('s3').Bucket('$(STACK_NAME)-$(AWS_ACCOUNT_NUMBER)').object_versions.delete()"

destroy-aws:
	@make -s destroy-aws-s3
	@printf "Waiting for stack delete to complete...\n"
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME)
	aws cloudformation wait \
		stack-delete-complete \
		--stack-name $(STACK_NAME)


### BARE METAL ###


### GCP ###


### AZURE ###