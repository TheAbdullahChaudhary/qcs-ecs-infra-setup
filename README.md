# 3-Tier Application on AWS ECS - Terraform Configuration

This Terraform configuration deploys a 3-tier application (Frontend, Backend, Database) on AWS ECS Fargate with the following architecture:

## Architecture Overview

```
Internet → ALB → Frontend (React) → Backend (Node.js) → Database (PostgreSQL)
                    ↓                    ↓                    ↓
                Public Subnets    Private Subnets    Private Subnets + EFS
```

## Components

### Networking
- **VPC**: `10.0.0.0/16` with DNS support enabled
- **Public Subnets**: `10.0.0.0/20` (eu-west-1a), `10.0.16.0/20` (eu-west-1b)
- **Private Subnets**: `10.0.128.0/20` (eu-west-1a), `10.0.144.0/20` (eu-west-1b)
- **Internet Gateway**: For public subnet internet access
- **NAT Gateway**: For private subnet internet access
- **Route Tables**: Separate routing for public and private subnets

### Security Groups
- **ALB SG**: Allows HTTP/HTTPS from internet
- **Frontend SG**: Allows HTTP from ALB
- **Backend SG**: Allows port 4000 from ALB
- **Database SG**: Allows PostgreSQL (5432) from Backend
- **EFS SG**: Allows NFS (2049) from Database

### Application Load Balancer
- **ALB**: Internet-facing load balancer
- **Target Groups**: 
  - Frontend-Target-Group (port 80, health check `/health`)
  - Backend-Target-Group (port 4000, health check `/health`)
- **Listener Rules**:
  - Priority 100: `/api/*` → Backend-Target-Group
  - Default: All traffic → Frontend-Target-Group

### Service Discovery (Cloud Map)
- **Namespace**: `ecs.internal`
- **Services**:
  - `ecs-database-service.ecs.internal:5432`
  - `ecs-backend-service.ecs.internal:4000`

### ECS Cluster & Services
- **Cluster**: `3-tier-ecs-cluster`
- **Services**:
  - Database: 1 task, private subnets, EFS mounted
  - Backend: 1 task, private subnets, service discovery
  - Frontend: 1 task, public subnets, ALB integration

### Storage
- **EFS**: Encrypted file system for database persistence
- **Access Point**: Configured for PostgreSQL user (999:999)

### IAM Roles
- **Task Execution Role**: For ECS agent operations
- **Task Role**: For application permissions (EFS access)

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** (version >= 1.0)
3. **Docker images** pushed to Docker Hub:
   - `theabdullahchaudhary/ecs-frontend:latest`
   - `theabdullahchaudhary/ecs-backend:latest`
   - `theabdullahchaudhary/ecs-database:latest`

## Configuration

### Variables

Edit `terraform.tfvars` to customize the deployment:

```hcl
aws_region = "eu-west-1"
app_name   = "3-tier-app"
environment = "production"

# Docker Hub Image URIs
frontend_image = "theabdullahchaudhary/ecs-frontend:latest"
backend_image  = "theabdullahchaudhary/ecs-backend:latest"
database_image = "theabdullahchaudhary/ecs-database:latest"
```

## Deployment

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Plan the Deployment
```bash
terraform plan
```

### 3. Apply the Configuration
```bash
terraform apply
```

### 4. Verify Deployment
```bash
terraform output alb_url
```

## Application Access

- **Frontend**: `http://<ALB-DNS-NAME>`
- **Backend API**: `http://<ALB-DNS-NAME>/api`
- **Health Checks**:
  - Frontend: `http://<ALB-DNS-NAME>/health`
  - Backend: `http://<ALB-DNS-NAME>/api/health`

## Service Communication

### Frontend → Backend
- Uses service discovery: `http://ecs-backend-service.ecs.internal:4000/api`
- Environment variable: `REACT_APP_API_URL`

### Backend → Database
- Uses service discovery: `ecs-database-service.ecs.internal:5432`
- Environment variables: `POSTGRES_HOST`, `POSTGRES_PORT`, etc.

## Monitoring & Logging

### CloudWatch Log Groups
- `/ecs/frontend`
- `/ecs/backend`
- `/ecs/database`

### Health Checks
- **Frontend**: `curl -f http://localhost/health`
- **Backend**: HTTP GET to `/health` endpoint
- **Database**: `pg_isready -U ecsuser -d ecsdb`

## Resource Specifications

### Task Definitions
- **Database**: 512 vCPU, 1024 MB memory, EFS mounted
- **Backend**: 256 vCPU, 512 MB memory
- **Frontend**: 256 vCPU, 512 MB memory

### Security
- All containers run as non-root users
- EFS transit encryption enabled
- IAM roles with minimal required permissions
- Security groups with least-privilege access

## Troubleshooting

### Common Issues

1. **Account Blocked Error**
   - Check AWS account status and billing
   - Verify service quotas for ECS Fargate
   - Contact AWS Support if needed

2. **Service Discovery Issues**
   - Verify namespace and service names
   - Check DNS resolution within VPC
   - Ensure services are in the same VPC

3. **EFS Mount Issues**
   - Verify EFS mount targets in private subnets
   - Check IAM permissions for EFS access
   - Ensure transit encryption is enabled

### Useful Commands

```bash
# Check ECS services
aws ecs describe-services --cluster 3-tier-ecs-cluster --services ecs-database-service ecs-backend-service ecs-frontend-service

# Check CloudWatch logs
aws logs describe-log-streams --log-group-name /ecs/frontend --order-by LastEventTime --descending

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will delete all data including the EFS file system and database data.

## Cost Optimization

- Use Fargate Spot for non-production workloads
- Consider auto-scaling based on CloudWatch metrics
- Monitor and adjust resource allocations
- Use CloudWatch Insights for log analysis

## Security Best Practices

- Enable AWS Config for compliance monitoring
- Use AWS Secrets Manager for sensitive data
- Implement VPC Flow Logs for network monitoring
- Regular security group reviews
- Enable CloudTrail for API logging 