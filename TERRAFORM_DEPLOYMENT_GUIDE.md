# Terraform Deployment Guide for 3-Tier ECS Application

This guide provides step-by-step instructions to deploy your 3-tier application using Terraform on AWS ECS Fargate.

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version >= 1.0)
- Docker images already pushed to ECR (as specified in terraform.tfvars)
- Basic knowledge of AWS services and Terraform

## 🏗️ Architecture Overview

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → Database (Private Subnet)
                                                                    ↓
                                                              EFS Volume (Persistent Storage)
```

## 📁 Terraform Structure

```
3-tier-app/
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── outputs.tf              # Output values
├── terraform.tfvars        # Variable values
├── modules/
│   ├── vpc/               # VPC and networking
│   ├── ecs-cluster/       # ECS cluster
│   ├── efs/               # EFS file system
│   ├── database/          # Database service
│   ├── backend/           # Backend service
│   └── frontend/          # Frontend service
└── TERRAFORM_DEPLOYMENT_GUIDE.md
```

## 🚀 Deployment Steps

### Step 1: Verify Prerequisites

1. **Check AWS CLI configuration**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Verify Terraform version**:
   ```bash
   terraform version
   ```

3. **Verify ECR images exist**:
   ```bash
   aws ecr describe-images --repository-name ecs-frontend --region us-east-1
   aws ecr describe-images --repository-name ecs-backend --region us-east-1
   aws ecr describe-images --repository-name ecs-database --region us-east-1
   ```

### Step 2: Initialize Terraform

```bash
# Navigate to the project directory
cd 3-tier-app

# Initialize Terraform
terraform init
```

### Step 3: Review the Plan

```bash
# Review what will be created
terraform plan
```

This will show you all the resources that will be created:
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Security Groups for ALB, Frontend, Backend, Database, and EFS
- ECS Cluster (Fargate)
- EFS File System with access points
- Application Load Balancer with target groups
- ECS Task Definitions and Services
- CloudWatch Log Groups
- IAM Roles

### Step 4: Deploy the Infrastructure

```bash
# Deploy the infrastructure
terraform apply
```

When prompted, type `yes` to confirm the deployment.

### Step 5: Monitor the Deployment

1. **Check ECS Services**:
   ```bash
   aws ecs list-services --cluster 3-tier-ecs-cluster
   ```

2. **Check service status**:
   ```bash
   aws ecs describe-services --cluster 3-tier-ecs-cluster --services ecs-database-service ecs-backend-service ecs-frontend-service
   ```

3. **Check ALB target health**:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

### Step 6: Test the Application

After deployment, Terraform will output the URLs:

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Test the application
curl http://<alb-dns-name>/health
curl http://<alb-dns-name>/api/health
```

## 🔧 Configuration Details

### Security Groups

- **ALB Security Group**: Allows HTTP/HTTPS from internet
- **Frontend Security Group**: Allows HTTP from ALB
- **Backend Security Group**: Allows port 4000 from Frontend
- **Database Security Group**: Allows PostgreSQL from Backend
- **EFS Security Group**: Allows NFS from Database

### ECS Services

- **Database Service**: 1 task, private subnets, EFS mounted
- **Backend Service**: 2 tasks, private subnets, load balancer attached
- **Frontend Service**: 2 tasks, public subnets, load balancer attached

### Load Balancer

- **Frontend Target Group**: Port 80, health check `/health`
- **Backend Target Group**: Port 4000, health check `/health`
- **Listener Rule**: Routes `/api/*` to backend, everything else to frontend

## 📊 Monitoring and Logs

### CloudWatch Logs

```bash
# View frontend logs
aws logs tail /ecs/frontend --follow

# View backend logs
aws logs tail /ecs/backend --follow

# View database logs
aws logs tail /ecs/database --follow
```

### ECS Service Events

```bash
# Check service events
aws ecs describe-services --cluster 3-tier-ecs-cluster --services ecs-frontend-service
```

## 🚨 Troubleshooting

### Common Issues

1. **Task Definition Issues**:
   - Check ECR image URIs are correct
   - Verify IAM roles have proper permissions
   - Check container health checks

2. **Networking Issues**:
   - Verify security group rules
   - Check subnet configurations
   - Ensure NAT Gateway is working

3. **EFS Mount Issues**:
   - Check EFS security group allows NFS from database
   - Verify access point permissions
   - Check task execution role has EFS permissions

4. **Load Balancer Issues**:
   - Check target group health
   - Verify listener rules
   - Check security group allows traffic

### Debugging Commands

```bash
# Check ECS task status
aws ecs describe-tasks --cluster 3-tier-ecs-cluster --tasks $(aws ecs list-tasks --cluster 3-tier-ecs-cluster --service-name ecs-frontend-service --query 'taskArns' --output text)

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names ecs-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

# Check EFS mount targets
aws efs describe-mount-targets --file-system-id $(terraform output -raw efs_file_system_id)
```

## 🔄 Updating the Application

### Update Container Images

1. **Push new images to ECR**:
   ```bash
   # Build and push new images
   ./build-and-push.ps1
   ```

2. **Update task definitions**:
   ```bash
   # Force new deployment
   aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-frontend-service --force-new-deployment
   aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-backend-service --force-new-deployment
   aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-database-service --force-new-deployment
   ```

### Scale Services

```bash
# Scale frontend service
aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-frontend-service --desired-count 3

# Scale backend service
aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-backend-service --desired-count 3
```

## 🧹 Cleanup

### Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy
```

When prompted, type `yes` to confirm.

### Manual Cleanup (if needed)

```bash
# Delete ECS services
aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-frontend-service --desired-count 0
aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-backend-service --desired-count 0
aws ecs update-service --cluster 3-tier-ecs-cluster --service ecs-database-service --desired-count 0

# Delete ECS cluster
aws ecs delete-cluster --cluster 3-tier-ecs-cluster

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>

# Delete EFS
aws efs delete-file-system --file-system-id <efs-id>
```

## 📝 Important Notes

### Security Considerations

- Database runs in private subnets
- Backend runs in private subnets
- Only frontend is accessible from internet
- EFS volume is encrypted
- Security groups follow least privilege principle

### Cost Considerations

- NAT Gateway incurs hourly charges
- EFS charges for storage and requests
- ALB charges for hours and data processed
- Fargate charges for CPU and memory usage

### Performance Considerations

- Database has 1024 MB memory for better performance
- EFS provides persistent storage across AZs
- Services can be scaled independently
- Load balancer distributes traffic across tasks

## 🎯 Success Criteria

Your deployment is successful when:
- All ECS services are running with desired task count
- Load balancer health checks are passing
- Frontend is accessible via ALB DNS name
- Backend and database status show as "Connected"
- Todo functionality works completely
- Database data persists across service restarts
- All logs are being generated in CloudWatch

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review CloudWatch logs for error messages
3. Verify security group configurations
4. Test health endpoints manually
5. Check ECS service events for deployment issues

This Terraform setup provides a production-ready 3-tier application with persistent database storage, proper security, and scalability. 