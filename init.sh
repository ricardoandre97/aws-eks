#!/bin/bash

AWS_DEFAULT_REGION=us-east-1
CFN_BUCKET=cfn-eks
PROJECT=eks-cool-project
# KEY_NAME=timeoff-key-ricardo

# Create the ssh key
# ls $KEY_NAME >/dev/null 2>&1 || ssh-keygen -f $KEY_NAME -N "" -m PEM -t rsa
# Import it in aws if it's not there
# aws ec2 describe-key-pairs --key-name  $KEY_NAME >/dev/null 2>&1 || aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material file://$PWD/$KEY_NAME.pub
# Bucket to upload cfn files!
#aws s3 ls $CFN_BUCKET >/dev/null 2>&1 || aws s3api create-bucket --bucket $CFN_BUCKET
# Version it
#aws s3api put-bucket-versioning --bucket $CFN_BUCKET --versioning-configuration Status=Enabled
# Upload files
echo "Uploading cfn templates to s3" && aws s3 sync ./cfn s3://$CFN_BUCKET

aws cloudformation deploy --template-file ./cfn/main.yaml    \
   --stack-name $PROJECT                                     \
   --capabilities CAPABILITY_IAM                             \
   --parameter-overrides          						     \
	TemplateBucket=$CFN_BUCKET 						         \
	Project=$PROJECT                                         \
	ClusterName=$PROJECT