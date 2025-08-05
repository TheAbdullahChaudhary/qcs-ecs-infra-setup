# ECS Deployment Guide

## Overview
This guide covers deploying a 3-tier Todo application on AWS ECS with proper connectivity between frontend, backend, and database.

## Architecture
- **Frontend**: React app served by Nginx on ECS
- **Backend**: Node.js API on ECS connected to PostgreSQL
- **Database**: RDS PostgreSQL
- **Load Balancer**: Application Load Balancer routing traffic
- **Network**: VPC with public/private subnets, NAT Gateway

## Prerequisites
1. AWS CLI configured with appropriate permissions
2. Terraform installed (version 1.0+)
3. Docker images pushed to ECR repositories

## ECR Setup
Before deploying, ensure your Docker images are built and pushed to ECR:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 941377128979.dkr.ecr.us-east-1.amazonaws.com

# Build and push backend
cd backend
docker build -t ecs-backend .
docker tag ecs-backend:latest 941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest
docker push 941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest

# Build and push frontend
cd ../frontend
docker build -t ecs-frontend .
docker tag ecs-frontend:latest 941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest
docker push 941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest
```

## Deployment Steps

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Plan Deployment
```bash
terraform plan
```

### 3. Deploy Infrastructure
```bash
terraform apply
```

### 4. Get Load Balancer URL
After deployment, get the load balancer URL:
```bash
terraform output load_balancer_url
```

## Connectivity Architecture

### Frontend → Backend
- Frontend makes API calls to `/api/*` paths
- ALB routes `/api/*` requests to backend target group
- Backend runs on port 4000 in private subnets

### Backend → Database
- Backend connects to RDS PostgreSQL endpoint
- Database runs in private subnets
- Security groups allow only backend access to database

### User → Frontend
- Users access application via ALB DNS name
- ALB forwards requests to frontend target group
- Frontend runs on port 80 in private subnets

## Security Groups
- **ALB**: Allows HTTP/HTTPS from internet
- **Frontend**: Allows port 80 from ALB only
- **Backend**: Allows port 4000 from ALB and frontend
- **Database**: Allows port 5432 from backend only

## Environment Variables
Backend automatically receives:
- `POSTGRES_HOST`: RDS endpoint
- `POSTGRES_DB`: ecsdb
- `POSTGRES_USER`: ecsuser
- `POSTGRES_PASSWORD`: ecspassword123!

## Health Checks
- **Frontend**: `/health` endpoint
- **Backend**: `/api/health` endpoint with database connectivity check
- **Database**: Automatic RDS health monitoring

## Troubleshooting

### Backend can't connect to database
1. Check security groups allow port 5432
2. Verify RDS endpoint in task definition
3. Check backend logs: `aws logs tail /ecs/backend --follow`

### Frontend can't reach backend
1. Verify ALB listener rules for `/api/*`
2. Check target group health
3. Check frontend logs: `aws logs tail /ecs/frontend --follow`

### Services not starting
1. Check ECS service events
2. Verify Docker images exist in ECR
3. Check IAM role permissions

## Monitoring
- CloudWatch logs for all containers
- ECS service metrics
- ALB access logs
- RDS performance insights

## Cleanup
To destroy all resources:
```bash
terraform destroy
```

## Important Notes
- Database password is hardcoded (use AWS Secrets Manager in production)
- No HTTPS/SSL configured (add ACM certificate for production)
- Default security group rules (restrict further for production)
- No backup/disaster recovery configured