# UI Setup Checklist for ECS Fargate Deployment

Use this checklist to track your progress through the UI-based setup process.

## ✅ Prerequisites
- [ ] AWS Account with appropriate permissions
- [ ] Docker installed locally
- [ ] AWS CLI configured (for pushing images to ECR)

## ✅ Step 1: VPC and Networking
- [ ] Create VPC (`ecs-vpc`) with CIDR `10.0.0.0/16`
- [ ] Create Public Subnet 1 (`ecs-public-subnet-1a`) in us-east-1a
- [ ] Create Public Subnet 2 (`ecs-public-subnet-1b`) in us-east-1b
- [ ] Create Private Subnet 1 (`ecs-private-subnet-1a`) in us-east-1a
- [ ] Create Private Subnet 2 (`ecs-private-subnet-1b`) in us-east-1b
- [ ] Create Internet Gateway (`ecs-igw`)
- [ ] Attach IGW to VPC
- [ ] Create Public Route Table (`ecs-public-rt`)
- [ ] Add route to internet (0.0.0.0/0 → IGW)
- [ ] Associate public subnets with public route table
- [ ] Enable auto-assign public IP for public subnets

## ✅ Step 2: Security Groups
- [ ] Create ALB Security Group (`ecs-alb-sg`)
  - [ ] Allow HTTP (80) from anywhere
  - [ ] Allow HTTPS (443) from anywhere
- [ ] Create Frontend Security Group (`ecs-frontend-sg`)
  - [ ] Allow HTTP (80) from ALB security group
- [ ] Create Backend Security Group (`ecs-backend-sg`)
  - [ ] Allow Custom TCP (4000) from frontend security group
- [ ] Create Database Security Group (`ecs-db-sg`)
  - [ ] Allow PostgreSQL (5432) from backend security group

## ✅ Step 3: RDS PostgreSQL Database
- [ ] Create DB Subnet Group (`ecs-db-subnet-group`)
  - [ ] Include both private subnets
- [ ] Create Secret in Secrets Manager (`ecs/database/credentials`)
  - [ ] Add username, password, engine, host, port, dbname
- [ ] Create RDS Instance (`ecs-db`)
  - [ ] PostgreSQL 15.x
  - [ ] db.t3.micro instance class
  - [ ] 20 GB storage
  - [ ] Use private subnets
  - [ ] Use database security group
  - [ ] Enable encryption
- [ ] Note database endpoint

## ✅ Step 4: ECR Repositories
- [ ] Create Frontend Repository (`ecs-frontend`)
  - [ ] Enable tag immutability
  - [ ] Enable scan on push
- [ ] Create Backend Repository (`ecs-backend`)
  - [ ] Enable tag immutability
  - [ ] Enable scan on push
- [ ] Build and push frontend Docker image
- [ ] Build and push backend Docker image

## ✅ Step 5: ECS Cluster
- [ ] Create ECS Cluster (`ecs-app-cluster`)
  - [ ] Networking only (Fargate)
  - [ ] Select VPC

## ✅ Step 6: IAM Roles
- [ ] Create ECS Task Execution Role (`ecsTaskExecutionRole`)
  - [ ] Attach `AmazonECSTaskExecutionRolePolicy`
  - [ ] Attach `SecretsManagerReadWrite`
- [ ] Create ECS Task Role (`ecsTaskRole`)
  - [ ] Attach `SecretsManagerReadWrite`

## ✅ Step 7: Task Definitions
- [ ] Create Backend Task Definition (`ecs-backend-task`)
  - [ ] Fargate compatibility
  - [ ] 512 MB memory, 256 CPU
  - [ ] Use backend ECR image
  - [ ] Port mapping 4000
  - [ ] Environment variables (NODE_ENV, POSTGRES_DB, POSTGRES_HOST, POSTGRES_PORT)
  - [ ] Secrets (POSTGRES_USER, POSTGRES_PASSWORD)
  - [ ] CloudWatch logging (`/ecs/backend`)
  - [ ] Health check configuration
- [ ] Create Frontend Task Definition (`ecs-frontend-task`)
  - [ ] Fargate compatibility
  - [ ] 512 MB memory, 256 CPU
  - [ ] Use frontend ECR image
  - [ ] Port mapping 80
  - [ ] Environment variables (REACT_APP_API_URL)
  - [ ] CloudWatch logging (`/ecs/frontend`)
  - [ ] Health check configuration

## ✅ Step 8: Application Load Balancer
- [ ] Create ALB (`ecs-alb`)
  - [ ] Internet-facing
  - [ ] Use public subnets
  - [ ] Use ALB security group
- [ ] Create Frontend Target Group (`ecs-frontend-tg`)
  - [ ] IP addresses target type
  - [ ] HTTP port 80
  - [ ] Health check path `/health`
- [ ] Create Backend Target Group (`ecs-backend-tg`)
  - [ ] IP addresses target type
  - [ ] HTTP port 4000
  - [ ] Health check path `/health`
- [ ] Configure ALB Listeners
  - [ ] Default listener forwards to frontend target group
  - [ ] Add listener rule for backend target group

## ✅ Step 9: ECS Services
- [ ] Create Backend Service (`ecs-backend-service`)
  - [ ] Fargate launch type
  - [ ] Use backend task definition
  - [ ] 2 desired tasks
  - [ ] Use private subnets
  - [ ] Use backend security group
  - [ ] Disable auto-assign public IP
  - [ ] Configure load balancer integration
- [ ] Create Frontend Service (`ecs-frontend-service`)
  - [ ] Fargate launch type
  - [ ] Use frontend task definition
  - [ ] 2 desired tasks
  - [ ] Use public subnets
  - [ ] Use frontend security group
  - [ ] Enable auto-assign public IP
  - [ ] Configure load balancer integration

## ✅ Step 10: CloudWatch Log Groups
- [ ] Create Frontend Log Group (`/ecs/frontend`)
- [ ] Create Backend Log Group (`/ecs/backend`)

## ✅ Step 11: Testing
- [ ] Get ALB DNS name
- [ ] Test frontend health endpoint (`/health`)
- [ ] Test backend health endpoint (`/api/health`)
- [ ] Test main application
- [ ] Verify status indicators show connected
- [ ] Test todo functionality

## ✅ Step 12: Monitoring
- [ ] Check ECS service status
- [ ] Verify target health in load balancer
- [ ] Review CloudWatch logs
- [ ] Monitor application performance

## 🔧 Troubleshooting Checklist

### If Tasks Not Starting:
- [ ] Check IAM role permissions
- [ ] Verify Secrets Manager access
- [ ] Review task definition configuration
- [ ] Check CloudWatch logs

### If Database Connection Failed:
- [ ] Verify security group rules
- [ ] Check database endpoint
- [ ] Confirm Secrets Manager configuration
- [ ] Review backend logs

### If Frontend Not Loading:
- [ ] Check ALB health checks
- [ ] Verify nginx configuration
- [ ] Review frontend logs
- [ ] Check target group health

### If Backend API Errors:
- [ ] Check database connectivity
- [ ] Verify environment variables
- [ ] Review backend logs
- [ ] Test health endpoints

## 📝 Important Notes

- **Resource Names**: Use the exact names specified in the guide
- **Security Groups**: Ensure proper inbound rules are configured
- **Subnets**: Frontend in public, backend in private
- **Secrets**: Update the host in Secrets Manager after RDS creation
- **Images**: Make sure to push latest images to ECR before creating services

## 🎯 Success Criteria

Your setup is complete when:
- [ ] Frontend is accessible via ALB DNS name
- [ ] Backend and database status show as "Connected"
- [ ] Todo functionality works (create, read, update, delete)
- [ ] Health checks are passing
- [ ] Logs are being generated in CloudWatch 