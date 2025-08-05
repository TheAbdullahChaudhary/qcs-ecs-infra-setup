# 3-Tier Todo Application on AWS ECS

A complete 3-tier web application deployed on AWS ECS with the following architecture:

- **Frontend**: React.js application served by nginx, accessible via Application Load Balancer (ALB)
- **Backend**: Node.js/Express API with health monitoring
- **Database**: PostgreSQL on Amazon RDS with credentials stored in AWS Secrets Manager

## Architecture Overview

```
Internet → ALB → Frontend (ECS) ─┐
                                 ├─ Backend (ECS) → RDS PostgreSQL
                                 └─ /api/* requests
```

## Features

- ✅ Frontend accessible via ALB
- ✅ Backend API with health endpoints
- ✅ PostgreSQL database on RDS
- ✅ Database credentials in AWS Secrets Manager
- ✅ Real-time status monitoring for backend and database
- ✅ Auto-scaling ECS services
- ✅ Private subnet deployment for security

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0
3. Docker (for building images)
4. AWS ECR repositories created for frontend and backend images

## Required AWS Permissions

Your AWS user/role needs permissions for:
- ECS (tasks, services, clusters)
- EC2 (VPC, subnets, security groups, ALB)
- RDS (PostgreSQL instance)
- Secrets Manager
- IAM (roles and policies)
- CloudWatch Logs

## Deployment Steps

### 1. Build and Push Docker Images

First, build and push your Docker images to ECR:

```bash
# Get ECR login
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

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### 3. Access the Application

After deployment, Terraform will output the ALB DNS name:

```bash
# Get the ALB DNS name
terraform output alb_dns_name
```

Access your application at: `http://<alb-dns-name>`

## Application Features

### Frontend
- Todo list interface
- Real-time backend and database status monitoring
- Responsive design
- Error handling and user feedback

### Backend API Endpoints

- `GET /api/health` - Backend and database health check
- `GET /health` - Detailed service status
- `GET /health/database` - Detailed database status
- `GET /api/todos` - Get all todos
- `POST /api/todos` - Create new todo
- `PATCH /api/todos/:id` - Update todo
- `DELETE /api/todos/:id` - Delete todo

### Database
- PostgreSQL 15.4 on RDS
- Automatic backups
- Encrypted storage
- Credentials stored in AWS Secrets Manager

## Configuration

### Environment Variables

The application uses the following environment variables:

**Backend:**
- `DB_SECRET_NAME`: Name of the secret in AWS Secrets Manager (default: `ecs-app-db-credentials`)
- `AWS_REGION`: AWS region (default: `us-east-1`)
- `PORT`: Server port (default: `4000`)
- `NODE_ENV`: Environment (default: `production`)

**Frontend:**
- `REACT_APP_API_URL`: Backend API URL (handled by ALB routing)

### AWS Secrets Manager

Database credentials are stored in AWS Secrets Manager with the following structure:

```json
{
  "username": "ecsuser",
  "password": "<generated-password>",
  "host": "<rds-endpoint>",
  "port": 5432,
  "dbname": "ecsdb"
}
```

## Monitoring

The application includes comprehensive health monitoring:

1. **Frontend Status Dashboard**: Real-time display of backend and database status
2. **Health Endpoints**: Multiple endpoints for different types of health checks
3. **CloudWatch Logs**: All container logs are sent to CloudWatch

## Security

- All services run in private subnets
- RDS is only accessible from backend services
- Database credentials are stored in AWS Secrets Manager
- Security groups follow least privilege principle
- All traffic is encrypted in transit

## Scaling

The application is configured for auto-scaling:
- ECS services with desired count of 2
- Auto Scaling Group for EC2 instances
- RDS with storage auto-scaling

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check Secrets Manager permissions
   - Verify RDS security group allows backend access
   - Check CloudWatch logs for detailed error messages

2. **ALB Health Check Failures**
   - Ensure containers are listening on correct ports
   - Check security group configurations
   - Verify health check paths are correct

3. **Service Discovery Issues**
   - Ensure all services are in the same VPC
   - Check route tables and NAT gateway configuration

### Logs

View application logs in CloudWatch:
- Frontend logs: `/ecs/frontend`
- Backend logs: `/ecs/backend`

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all data including the RDS database. Make sure to backup any important data before destroying.

## Cost Optimization

For development/testing:
- Use `db.t3.micro` for RDS (included in free tier)
- Use `t3.small` EC2 instances
- Set desired count to 1 for ECS services

For production:
- Scale up RDS instance class as needed
- Increase ECS service desired count
- Enable RDS Multi-AZ for high availability 