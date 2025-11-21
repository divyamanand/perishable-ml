# 🚀 AWS ECS Deployment Guide - Hospital Inventory RL

Complete guide for deploying the Hospital Inventory RL application to AWS ECS using GitHub Actions CI/CD.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [AWS Infrastructure Setup](#aws-infrastructure-setup)
4. [GitHub Configuration](#github-configuration)
5. [Deployment Workflow](#deployment-workflow)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Build   │→ │   Test   │→ │  Train   │→ │  Deploy  │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                   │
│  ┌────────────┐         ┌──────────────────────┐               │
│  │    ECR     │────────→│    ECS Cluster       │               │
│  │  Registry  │         │                      │               │
│  └────────────┘         │  ┌─────────────────┐ │               │
│                         │  │  API Service    │ │               │
│  ┌────────────┐         │  │  (Fargate)      │ │               │
│  │     S3     │←────────┤  └─────────────────┘ │               │
│  │   Models   │         │                      │               │
│  └────────────┘         │  ┌─────────────────┐ │               │
│                         │  │ Trainer Service │ │               │
│  ┌────────────┐         │  │  (Fargate)      │ │               │
│  │    EFS     │←────────┤  └─────────────────┘ │               │
│  │   Shared   │         └──────────────────────┘               │
│  │  Storage   │                    ↓                             │
│  └────────────┘         ┌──────────────────────┐               │
│                         │   Application LB      │               │
│  ┌────────────┐         │   (Port 80/443)       │               │
│  │ CloudWatch │         └──────────┬────────────┘               │
│  │    Logs    │                    │                             │
│  └────────────┘                    ↓                             │
└─────────────────────────────────────┼──────────────────────────┘
                                      │
                                      ↓
                              Internet Users
```

### **Components:**

- **ECR (Elastic Container Registry)**: Stores Docker images
- **ECS (Elastic Container Service)**: Runs containers on Fargate
- **ALB (Application Load Balancer)**: Routes traffic to API containers
- **EFS (Elastic File System)**: Shared storage for models and logs
- **S3**: Backup storage for trained models
- **CloudWatch**: Logging and monitoring

---

## ✅ Prerequisites

### **Local Requirements:**
- AWS CLI installed and configured
- Docker installed
- Git and GitHub account
- Bash shell (WSL on Windows, or Git Bash)

### **AWS Requirements:**
- AWS account with admin access
- AWS CLI configured with credentials
- Sufficient quotas for:
  - ECS Fargate tasks
  - Elastic IPs
  - Load Balancers

---

## 🛠️ AWS Infrastructure Setup

### **Step 1: Run Infrastructure Setup Script**

```bash
cd .aws
chmod +x setup-infrastructure.sh
./setup-infrastructure.sh
```

This script creates:
- ✅ ECR repository
- ✅ S3 bucket for models
- ✅ VPC with subnets
- ✅ Security groups
- ✅ EFS file system
- ✅ IAM roles
- ✅ Application Load Balancer
- ✅ ECS cluster
- ✅ CloudWatch log groups

**Expected Output:**
```
==========================================
✅ Infrastructure Setup Complete!
==========================================

📝 Save these values for GitHub Secrets:

AWS_REGION: us-east-1
S3_MODEL_BUCKET: hospital-rl-models-123456789012
VPC_ID: vpc-abc123
...
```

**⚠️ IMPORTANT:** Save all the output values - you'll need them for GitHub Secrets!

---

### **Step 2: Update Task Definitions**

Edit `.aws/task-definition-api.json` and `.aws/task-definition-trainer.json`:

Replace:
```json
"YOUR_ACCOUNT_ID" → Your AWS Account ID
"fs-XXXXXXXXX" → Your EFS File System ID
"fsap-XXXXXXXXX" → Your Models Access Point ID
"fsap-YYYYYYYYY" → Your Logs Access Point ID
```

---

### **Step 3: Register Task Definitions**

```bash
# Register API task definition
aws ecs register-task-definition \
  --cli-input-json file://.aws/task-definition-api.json

# Register Trainer task definition
aws ecs register-task-definition \
  --cli-input-json file://.aws/task-definition-trainer.json
```

---

### **Step 4: Create ECS Services**

```bash
# Get subnet and security group IDs from setup script output
SUBNET_1="subnet-xxx"
SUBNET_2="subnet-yyy"
ECS_SG="sg-zzz"
TG_ARN="arn:aws:elasticloadbalancing:..."

# Create API service
aws ecs create-service \
  --cluster hospital-rl-cluster \
  --service-name hospital-rl-api-service \
  --task-definition hospital-rl-api-task \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={
    subnets=[$SUBNET_1,$SUBNET_2],
    securityGroups=[$ECS_SG],
    assignPublicIp=ENABLED
  }" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=hospital-rl-api,containerPort=8000" \
  --health-check-grace-period-seconds 60
```

---

## 🔐 GitHub Configuration

### **Step 1: Add GitHub Secrets**

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `S3_MODEL_BUCKET` | S3 bucket for models | `hospital-rl-models-123456789012` |

**To create AWS credentials:**
```bash
aws iam create-user --user-name github-actions

aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam create-access-key --user-name github-actions
```

---

### **Step 2: Verify Workflow File**

Check `.github/workflows/deploy-ecs.yml` is present and configured.

---

## 🚀 Deployment Workflow

### **Automatic Deployment (Recommended)**

Push to main branch:
```bash
git add .
git commit -m "Deploy to ECS"
git push origin main
```

**GitHub Actions will automatically:**
1. ✅ Build and test the code
2. ✅ Build Docker image and push to ECR
3. ✅ Train the model
4. ✅ Upload model to S3
5. ✅ Deploy to ECS
6. ✅ Run smoke tests
7. ✅ Send notifications

---

### **Manual Deployment**

Go to GitHub → Actions → "Deploy to AWS ECS" → Run workflow

---

### **Deployment Stages**

#### **Stage 1: Build and Test** (2-3 minutes)
```
✓ Checkout code
✓ Install dependencies
✓ Run linting
✓ Test environment
✓ Quick training test
```

#### **Stage 2: Build and Push** (5-10 minutes)
```
✓ Login to ECR
✓ Build Docker image
✓ Push to ECR
✓ Tag with commit SHA and 'latest'
```

#### **Stage 3: Train Model** (5-10 minutes)
```
✓ Pull image from ECR
✓ Train model (20,000 timesteps)
✓ Upload to S3
✓ Save as artifact
```

#### **Stage 4: Deploy to ECS** (3-5 minutes)
```
✓ Update task definition
✓ Deploy to ECS service
✓ Wait for stability
✓ Verify health endpoint
```

#### **Stage 5: Smoke Tests** (1-2 minutes)
```
✓ Test health endpoint
✓ Test prediction endpoint
✓ Run load test
```

---

## 📊 Monitoring & Maintenance

### **View Logs**

```bash
# API logs
aws logs tail /ecs/hospital-rl-api --follow

# Trainer logs
aws logs tail /ecs/hospital-rl-trainer --follow
```

### **Check Service Status**

```bash
aws ecs describe-services \
  --cluster hospital-rl-cluster \
  --services hospital-rl-api-service
```

### **View Running Tasks**

```bash
aws ecs list-tasks \
  --cluster hospital-rl-cluster \
  --service-name hospital-rl-api-service
```

### **Get ALB DNS Name**

```bash
aws elbv2 describe-load-balancers \
  --names hospital-rl-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

### **Test API**

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names hospital-rl-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Health check
curl http://${ALB_DNS}/health

# Prediction
curl -X POST http://${ALB_DNS}/predict \
  -H "Content-Type: application/json" \
  -d '{
    "inventory": [10, 8, 6, 4, 2, 1, 0],
    "pipeline": [5, 0, 10, 0, 0, 0],
    "forecast": 15.5
  }'
```

---

## 🔄 Scaling

### **Manual Scaling**

```bash
# Scale API service
aws ecs update-service \
  --cluster hospital-rl-cluster \
  --service hospital-rl-api-service \
  --desired-count 4
```

### **Auto Scaling** (Optional)

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/hospital-rl-cluster/hospital-rl-api-service \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/hospital-rl-cluster/hospital-rl-api-service \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    }
  }'
```

---

## 🐛 Troubleshooting

### **Issue: Deployment Fails**

**Check GitHub Actions logs:**
```
GitHub → Actions → Failed workflow → View logs
```

**Common causes:**
- ❌ Missing GitHub Secrets
- ❌ Incorrect AWS credentials
- ❌ Task definition errors
- ❌ Insufficient AWS quotas

---

### **Issue: Service Won't Start**

**Check ECS logs:**
```bash
aws logs tail /ecs/hospital-rl-api --follow
```

**Common causes:**
- ❌ Model not found (train first)
- ❌ EFS mount issues
- ❌ Port conflicts
- ❌ Resource limits

---

### **Issue: Health Check Failing**

**Test directly:**
```bash
# Get task IP
TASK_ARN=$(aws ecs list-tasks \
  --cluster hospital-rl-cluster \
  --service-name hospital-rl-api-service \
  --query 'taskArns[0]' \
  --output text)

# Get task details
aws ecs describe-tasks \
  --cluster hospital-rl-cluster \
  --tasks $TASK_ARN
```

---

### **Issue: High Costs**

**Optimize:**
- Use Fargate Spot for training tasks
- Reduce task count during off-hours
- Use smaller CPU/memory configurations
- Enable ECS Container Insights selectively

---

## 💰 Cost Estimation

### **Monthly Costs (us-east-1):**

| Component | Specification | Estimated Cost |
|-----------|---------------|----------------|
| ECS Fargate (API) | 1 vCPU, 2GB RAM, 2 tasks | ~$50 |
| ECS Fargate (Trainer) | 2 vCPU, 4GB RAM, occasional | ~$5 |
| ALB | Standard | ~$20 |
| EFS | 5 GB | ~$2 |
| S3 | 10 GB | ~$0.50 |
| CloudWatch Logs | 5 GB | ~$2.50 |
| ECR | 1 GB | ~$0.10 |
| **Total** | | **~$80/month** |

**Cost Optimization:**
- Use Fargate Spot (70% savings)
- Schedule training during off-peak hours
- Reduce API task count to 1 for dev/staging

---

## 🔒 Security Best Practices

### ✅ **Implemented:**
- VPC with private subnets
- Security groups with minimal access
- EFS encryption at rest
- S3 bucket encryption
- IAM roles with least privilege
- Container image scanning in ECR

### 🔐 **Additional Recommendations:**
- Enable AWS WAF on ALB
- Use AWS Secrets Manager for sensitive data
- Enable VPC Flow Logs
- Set up AWS Config rules
- Enable CloudTrail logging
- Use HTTPS with ACM certificates

---

## 📚 Additional Resources

- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [GitHub Actions for AWS](https://github.com/aws-actions)

---

## 🎯 Quick Reference Commands

```bash
# Deploy
git push origin main

# Check status
aws ecs describe-services --cluster hospital-rl-cluster --services hospital-rl-api-service

# View logs
aws logs tail /ecs/hospital-rl-api --follow

# Scale
aws ecs update-service --cluster hospital-rl-cluster --service hospital-rl-api-service --desired-count 3

# Retrain
aws ecs run-task --cluster hospital-rl-cluster --task-definition hospital-rl-trainer-task --launch-type FARGATE

# Test API
curl http://$(aws elbv2 describe-load-balancers --names hospital-rl-alb --query 'LoadBalancers[0].DNSName' --output text)/health
```

---

**🎉 Your Hospital Inventory RL application is now production-ready on AWS ECS!**
