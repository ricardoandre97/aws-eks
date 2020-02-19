#!/bin/bash
AWS_DEFAULT_REGION=us-east-1
CFN_BUCKET=cfn-eks-bucket
PROJECT=eks-cool-project
KEY_NAME=eks-test-key
MIN_NODES=1
MAX_NODES=3
DESIRED_NODES=2
INSTANCE_TYPE=t2.medium

# Create the ssh key
ls $KEY_NAME >/dev/null 2>&1 || ssh-keygen -f $KEY_NAME -N "" -m PEM -t rsa

# Import it in aws if it's not there
aws ec2 describe-key-pairs --key-name  $KEY_NAME >/dev/null 2>&1 || aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material file://$PWD/$KEY_NAME.pub

# Bucket to upload cfn files!
aws s3 ls $CFN_BUCKET >/dev/null 2>&1 || aws s3api create-bucket --bucket $CFN_BUCKET

# Upload files
echo "Uploading cfn templates to s3 (If any)" && aws s3 sync ./cfn s3://$CFN_BUCKET

# Deploy the stack
aws cloudformation deploy --template-file ./cfn/main.yaml    \
   --stack-name $PROJECT                                     \
   --capabilities CAPABILITY_IAM                             \
   --parameter-overrides                                     \
    TemplateBucket=$CFN_BUCKET                               \
    Project=$PROJECT                                         \
    KeyName=$KEY_NAME                                        \
    NodeAutoScalingGroupMinSize=$MIN_NODES                   \
    NodeAutoScalingGroupMaxSize=$MAX_NODES                   \
    DesiredCapacity=$DESIRED_NODES                           \
    NodeInstanceType=$INSTANCE_TYPE

# Get the NodeRole
NODE_ROLE=$(aws cloudformation describe-stacks --stack-name=$PROJECT --region $AWS_DEFAULT_REGION --query "Stacks[0].Outputs[?OutputKey=='NodeInstanceRole'].OutputValue" --output text)

# Create the aws configmap to join the nodes
# See https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html
cat <<EOF >aws-auth.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $NODE_ROLE
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

# Apply config
echo "Applying configuration for aws nodes to join the cluster..."
kubectl apply -f aws-auth.yaml
echo -e "\e[32mEnjoy :)\e[0m"