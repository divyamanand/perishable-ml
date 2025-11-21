# 🚀 AWS ECS Deployment - Quick Setup Checklist

Follow this checklist to deploy the Hospital Inventory RL application to AWS ECS.

---

## ☑️ Pre-Deployment Checklist

### **1. AWS Account Setup**
- [ ] AWS account created and active
- [ ] AWS CLI installed locally
- [ ] AWS CLI configured with credentials (`aws configure`)
- [ ] Verify access: `aws sts get-caller-identity`

### **2. Local Environment**
- [ ] Docker installed and running
- [ ] Git installed
- [ ] Bash/WSL available (for setup script)
- [ ] GitHub account with repository access

### **3. Initial Testing**
- [ ] Project builds locally: `docker build -t custom-rl-env .`
- [ ] Model trains successfully: `docker run --rm -v ${PWD}/models:/app/models custom-rl-env`
- [ ] API works locally: `docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000`

---

## 🛠️ AWS Infrastructure Setup

### **Step 1: Run Setup Script**
```bash
cd .aws
chmod +x setup-infrastructure.sh
./setup-infrastructure.sh
```

- [ ] Script completed successfully
- [ ] All AWS resources created
- [ ] Output values saved (see below)

**Save these values:**
```
AWS_REGION: _________________
S3_MODEL_BUCKET: _________________
VPC_ID: _________________
SUBNET_1: _________________
SUBNET_2: _________________
ECS_SECURITY_GROUP: _________________
ALB_SECURITY_GROUP: _________________
TARGET_GROUP_ARN: _________________
EFS_FILE_SYSTEM_ID: _________________
MODELS_ACCESS_POINT: _________________
LOGS_ACCESS_POINT: _________________
AWS_ACCOUNT_ID: _________________
```

### **Step 2: Update Task Definitions**
- [ ] Edit `.aws/task-definition-api.json`
  - [ ] Replace `YOUR_ACCOUNT_ID` with AWS Account ID
  - [ ] Replace `fs-XXXXXXXXX` with EFS File System ID
  - [ ] Replace `fsap-XXXXXXXXX` with Models Access Point
- [ ] Edit `.aws/task-definition-trainer.json`
  - [ ] Replace `YOUR_ACCOUNT_ID` with AWS Account ID
  - [ ] Replace `fs-XXXXXXXXX` with EFS File System ID
  - [ ] Replace `fsap-XXXXXXXXX` with Models Access Point
  - [ ] Replace `fsap-YYYYYYYYY` with Logs Access Point

### **Step 3: Register Task Definitions**
```bash
aws ecs register-task-definition --cli-input-json file://.aws/task-definition-api.json
aws ecs register-task-definition --cli-input-json file://.aws/task-definition-trainer.json
```

- [ ] API task definition registered
- [ ] Trainer task definition registered
- [ ] No errors in output

### **Step 4: Create ECS Service**
```bash
# Use your saved values
aws ecs create-service \
  --cluster hospital-rl-cluster \
  --service-name hospital-rl-api-service \
  --task-definition hospital-rl-api-task \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[SUBNET_1,SUBNET_2],
    securityGroups=[ECS_SECURITY_GROUP],
    assignPublicIp=ENABLED
  }" \
  --load-balancers "targetGroupArn=TARGET_GROUP_ARN,containerName=hospital-rl-api,containerPort=8000"
```

- [ ] Service created successfully
- [ ] Service status is ACTIVE

---

## 🔐 GitHub Setup

### **Step 1: Create GitHub Secrets**

Go to: Repository → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

- [ ] `AWS_ACCESS_KEY_ID`
  ```bash
  # Get from: aws iam create-access-key --user-name github-actions
  ```

- [ ] `AWS_SECRET_ACCESS_KEY`
  ```bash
  # Get from: aws iam create-access-key --user-name github-actions
  ```

- [ ] `S3_MODEL_BUCKET`
  ```
  Value: (from setup script output)
  ```

### **Step 2: Create IAM User for GitHub**
```bash
# Create user
aws iam create-user --user-name github-actions

# Attach policies
aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam attach-user-policy \
  --user-name github-actions \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create access key
aws iam create-access-key --user-name github-actions
```

- [ ] IAM user created
- [ ] Policies attached
- [ ] Access key created and saved

### **Step 3: Verify Workflow File**
- [ ] `.github/workflows/deploy-ecs.yml` exists
- [ ] File has correct AWS region
- [ ] File has correct service names

---

## 🚀 First Deployment

### **Step 1: Commit and Push**
```bash
git add .
git commit -m "Initial ECS deployment setup"
git push origin main
```

- [ ] Code pushed to GitHub
- [ ] GitHub Actions workflow triggered

### **Step 2: Monitor Deployment**
- [ ] Go to GitHub → Actions
- [ ] Watch workflow execution
- [ ] All jobs completed successfully

**Expected Jobs:**
1. ✅ Build and Test (2-3 min)
2. ✅ Build and Push to ECR (5-10 min)
3. ✅ Train Model (5-10 min)
4. ✅ Deploy to ECS (3-5 min)
5. ✅ Smoke Tests (1-2 min)

---

## ✅ Post-Deployment Verification

### **Step 1: Get ALB DNS**
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names hospital-rl-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)
echo "API URL: http://${ALB_DNS}"
```

- [ ] ALB DNS obtained
- [ ] DNS name: _________________

### **Step 2: Test Health Endpoint**
```bash
curl http://${ALB_DNS}/health
```

Expected response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "environment": "HospitalInventoryEnvv"
}
```

- [ ] Health check returns 200 OK
- [ ] Model loaded = true

### **Step 3: Test Prediction Endpoint**
```bash
curl -X POST http://${ALB_DNS}/predict \
  -H "Content-Type: application/json" \
  -d '{
    "inventory": [10, 8, 6, 4, 2, 1, 0],
    "pipeline": [5, 0, 10, 0, 0, 0],
    "forecast": 15.5
  }'
```

Expected response:
```json
{
  "action": 12,
  "observation": {...}
}
```

- [ ] Prediction endpoint works
- [ ] Returns valid action

### **Step 4: Check API Documentation**
```bash
open http://${ALB_DNS}/docs
```

- [ ] Swagger UI loads
- [ ] All endpoints visible
- [ ] Can test endpoints interactively

### **Step 5: Verify Logging**
```bash
aws logs tail /ecs/hospital-rl-api --follow
```

- [ ] Logs are streaming
- [ ] No errors visible
- [ ] API requests logged

---

## 📊 Monitoring Setup

### **Step 1: CloudWatch Dashboard**
- [ ] Go to AWS CloudWatch Console
- [ ] Navigate to Dashboards
- [ ] View ECS metrics

### **Step 2: Set Up Alarms (Optional)**
```bash
# CPU Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name hospital-rl-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold
```

- [ ] CPU alarm created
- [ ] Memory alarm created (optional)
- [ ] Error rate alarm created (optional)

---

## 🎯 Success Criteria

All items checked = Deployment successful! 🎉

### **Infrastructure:**
- ✅ All AWS resources created
- ✅ ECS cluster running
- ✅ Load balancer healthy
- ✅ EFS mounted

### **Application:**
- ✅ Container image in ECR
- ✅ Model trained and uploaded to S3
- ✅ API service running (2+ tasks)
- ✅ Health check passing

### **CI/CD:**
- ✅ GitHub Actions workflow completes
- ✅ Automatic deployments on push
- ✅ Smoke tests passing

### **Verification:**
- ✅ API accessible via ALB DNS
- ✅ Health endpoint returns 200
- ✅ Prediction endpoint works
- ✅ Logs visible in CloudWatch

---

## 🐛 Troubleshooting

### **Issue: Setup script fails**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check quotas
aws service-quotas list-service-quotas --service-code ecs
```

### **Issue: Task won't start**
```bash
# Check service events
aws ecs describe-services \
  --cluster hospital-rl-cluster \
  --services hospital-rl-api-service \
  --query 'services[0].events[0:5]'

# Check task logs
aws logs tail /ecs/hospital-rl-api --follow
```

### **Issue: Health check fails**
```bash
# Test from within VPC
aws ecs execute-command \
  --cluster hospital-rl-cluster \
  --task TASK_ARN \
  --container hospital-rl-api \
  --interactive \
  --command "/bin/bash"
```

### **Issue: GitHub Actions fails**
- Check GitHub Secrets are set correctly
- Verify AWS credentials have correct permissions
- Check workflow logs for specific error

---

## 📞 Support Resources

- **AWS Documentation**: https://docs.aws.amazon.com/ecs/
- **GitHub Actions**: https://docs.github.com/actions
- **Project Documentation**: See `AWS_DEPLOYMENT.md`

---

## 🔄 Next Steps

After successful deployment:

1. **Set up monitoring alerts**
2. **Configure auto-scaling**
3. **Enable HTTPS with ACM certificate**
4. **Set up custom domain name**
5. **Configure backup strategies**
6. **Implement blue-green deployments**

---

**Date Completed**: _______________  
**Deployed By**: _______________  
**ALB DNS**: _______________  
**Notes**: _______________

---

✅ **Deployment Complete!** Your Hospital Inventory RL API is now live on AWS ECS.
