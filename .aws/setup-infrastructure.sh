#!/bin/bash

# AWS ECS Infrastructure Setup Script for Hospital Inventory RL
# This script creates all necessary AWS resources for deployment

set -e

# Configuration
PROJECT_NAME="hospital-rl"
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=========================================="
echo "AWS ECS Infrastructure Setup"
echo "=========================================="
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
echo "=========================================="

# Step 1: Create ECR Repository
echo "Creating ECR Repository..."
aws ecr create-repository \
  --repository-name hospital-rl-env \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  || echo "Repository may already exist"

# Step 2: Create S3 Bucket for Models
echo "Creating S3 Bucket for models..."
BUCKET_NAME="${PROJECT_NAME}-models-${AWS_ACCOUNT_ID}"
aws s3 mb s3://${BUCKET_NAME} --region $AWS_REGION || echo "Bucket may already exist"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "S3 Bucket created: ${BUCKET_NAME}"

# Step 3: Create VPC (if needed)
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc}]" \
  --query 'Vpc.VpcId' \
  --output text) || echo "VPC may already exist"

echo "VPC ID: $VPC_ID"

# Enable DNS
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support

# Step 4: Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Step 5: Create Subnets
echo "Creating Subnets..."
SUBNET_1=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-subnet-1}]" \
  --query 'Subnet.SubnetId' \
  --output text)

SUBNET_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone ${AWS_REGION}b \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-subnet-2}]" \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subnet 1: $SUBNET_1"
echo "Subnet 2: $SUBNET_2"

# Step 6: Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-rt}]" \
  --query 'RouteTable.RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table --subnet-id $SUBNET_1 --route-table-id $ROUTE_TABLE
aws ec2 associate-route-table --subnet-id $SUBNET_2 --route-table-id $ROUTE_TABLE

# Step 7: Create Security Groups
echo "Creating Security Groups..."

# ALB Security Group
ALB_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-alb-sg \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# ECS Security Group
ECS_SG=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-ecs-sg \
  --description "Security group for ECS tasks" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG \
  --protocol tcp \
  --port 8000 \
  --source-group $ALB_SG

# Step 8: Create EFS for Shared Storage
echo "Creating EFS File System..."
EFS_ID=$(aws efs create-file-system \
  --creation-token ${PROJECT_NAME}-efs \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --encrypted \
  --tags Key=Name,Value=${PROJECT_NAME}-efs \
  --query 'FileSystemId' \
  --output text)

echo "EFS ID: $EFS_ID"

# Wait for EFS to be available
aws efs wait file-system-available --file-system-id $EFS_ID

# Create mount targets
aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $SUBNET_1 \
  --security-groups $ECS_SG

aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id $SUBNET_2 \
  --security-groups $ECS_SG

# Create access points
MODELS_AP=$(aws efs create-access-point \
  --file-system-id $EFS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/models,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=755}" \
  --tags Key=Name,Value=${PROJECT_NAME}-models-ap \
  --query 'AccessPointId' \
  --output text)

LOGS_AP=$(aws efs create-access-point \
  --file-system-id $EFS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/logs,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=755}" \
  --tags Key=Name,Value=${PROJECT_NAME}-logs-ap \
  --query 'AccessPointId' \
  --output text)

echo "Models Access Point: $MODELS_AP"
echo "Logs Access Point: $LOGS_AP"

# Step 9: Create IAM Roles
echo "Creating IAM Roles..."

# ECS Task Execution Role
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document file://trust-policy.json \
  || echo "Role may already exist"

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# ECS Task Role (for S3 and EFS access)
cat > task-role-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Resource": "arn:aws:elasticfilesystem:${AWS_REGION}:${AWS_ACCOUNT_ID}:file-system/${EFS_ID}"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document file://trust-policy.json \
  || echo "Role may already exist"

aws iam put-role-policy \
  --role-name ecsTaskRole \
  --policy-name ECSTaskPolicy \
  --policy-document file://task-role-policy.json

# Step 10: Create CloudWatch Log Groups
echo "Creating CloudWatch Log Groups..."
aws logs create-log-group --log-group-name /ecs/hospital-rl-api || echo "Log group may already exist"
aws logs create-log-group --log-group-name /ecs/hospital-rl-trainer || echo "Log group may already exist"

# Step 11: Create Application Load Balancer
echo "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name hospital-rl-alb \
  --subnets $SUBNET_1 $SUBNET_2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

echo "ALB ARN: $ALB_ARN"

# Create Target Group
TG_ARN=$(aws elbv2 create-target-group \
  --name hospital-rl-tg \
  --protocol HTTP \
  --port 8000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-enabled \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"

# Create Listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN

# Step 12: Create ECS Cluster
echo "Creating ECS Cluster..."
aws ecs create-cluster \
  --cluster-name hospital-rl-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
  --settings name=containerInsights,value=enabled

# Step 13: Store Secrets in Secrets Manager
echo "Creating Secrets..."
aws secretsmanager create-secret \
  --name hospital-rl/s3-bucket \
  --secret-string ${BUCKET_NAME} \
  --region $AWS_REGION \
  || echo "Secret may already exist"

# Clean up temporary files
rm -f trust-policy.json task-role-policy.json

echo ""
echo "=========================================="
echo "✅ Infrastructure Setup Complete!"
echo "=========================================="
echo ""
echo "📝 Save these values for GitHub Secrets:"
echo ""
echo "AWS_REGION: $AWS_REGION"
echo "S3_MODEL_BUCKET: $BUCKET_NAME"
echo "VPC_ID: $VPC_ID"
echo "SUBNET_1: $SUBNET_1"
echo "SUBNET_2: $SUBNET_2"
echo "ECS_SECURITY_GROUP: $ECS_SG"
echo "ALB_SECURITY_GROUP: $ALB_SG"
echo "TARGET_GROUP_ARN: $TG_ARN"
echo "EFS_FILE_SYSTEM_ID: $EFS_ID"
echo "MODELS_ACCESS_POINT: $MODELS_AP"
echo "LOGS_ACCESS_POINT: $LOGS_AP"
echo ""
echo "📌 Update task definitions with:"
echo "  - Replace YOUR_ACCOUNT_ID with: $AWS_ACCOUNT_ID"
echo "  - Replace fs-XXXXXXXXX with: $EFS_ID"
echo "  - Replace fsap-XXXXXXXXX with: $MODELS_AP"
echo "  - Replace fsap-YYYYYYYYY with: $LOGS_AP"
echo ""
echo "🚀 Next steps:"
echo "  1. Configure GitHub Secrets"
echo "  2. Update task definitions"
echo "  3. Push to main branch to trigger deployment"
echo ""
