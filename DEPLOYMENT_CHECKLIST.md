# ECS Deployment Checklist with Dockerized Database

Use this checklist to ensure your 3-tier application is properly deployed on ECS with persistent database storage.

## ✅ Pre-Deployment Testing

### Local Testing
- [ ] Run `chmod +x test-local.sh && ./test-local.sh`
- [ ] Verify all services start correctly
- [ ] Test frontend at http://localhost
- [ ] Test backend API at http://localhost:4000
- [ ] Verify database connection
- [ ] Test todo CRUD operations
- [ ] Check status indicators show "Connected"

### Application Verification
- [ ] Frontend displays real-time status
- [ ] Backend health endpoint returns success
- [ ] Database connection is established
- [ ] Todo operations work (create, read, update, delete)
- [ ] Error handling works properly
- [ ] Logs are generated correctly

---

## ✅ Infrastructure Setup

### VPC and Networking
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

### EFS File System
- [ ] Create EFS File System (`ecs-db-storage`)
- [ ] Create Mount Target 1 in private subnet 1a
- [ ] Create Mount Target 2 in private subnet 1b
- [ ] Create EFS Security Group (`ecs-efs-sg`)
- [ ] Allow NFS traffic from database security group

### Security Groups
- [ ] Create ALB Security Group (`ecs-alb-sg`)
  - [ ] Allow HTTP (80) from anywhere
  - [ ] Allow HTTPS (443) from anywhere
- [ ] Create Frontend Security Group (`ecs-frontend-sg`)
  - [ ] Allow HTTP (80) from ALB security group
- [ ] Create Backend Security Group (`ecs-backend-sg`)
  - [ ] Allow Custom TCP (4000) from frontend security group
- [ ] Create Database Security Group (`ecs-db-sg`)
  - [ ] Allow PostgreSQL (5432) from backend security group

---

## ✅ Container Registry

### ECR Repositories
- [ ] Create Frontend Repository (`ecs-frontend`)
  - [ ] Enable tag immutability
  - [ ] Enable scan on push
- [ ] Create Backend Repository (`ecs-backend`)
  - [ ] Enable tag immutability
  - [ ] Enable scan on push
- [ ] Create Database Repository (`ecs-database`)
  - [ ] Enable tag immutability
  - [ ] Enable scan on push

### Build and Push Images
- [ ] Build and push frontend image
- [ ] Build and push backend image
- [ ] Build and push database image
- [ ] Verify all images are available in ECR

---

## ✅ ECS Setup

### ECS Cluster
- [ ] Create ECS Cluster (`ecs-app-cluster`)
- [ ] Select VPC
- [ ] Configure for Fargate

### IAM Roles
- [ ] Create ECS Task Execution Role (`ecsTaskExecutionRole`)
  - [ ] Attach `AmazonECSTaskExecutionRolePolicy`
  - [ ] Attach `SecretsManagerReadWrite`
- [ ] Create ECS Task Role (`ecsTaskRole`)
  - [ ] Attach `SecretsManagerReadWrite`

### Task Definitions
- [ ] Create Database Task Definition (`ecs-database-task`)
  - [ ] Fargate compatibility
  - [ ] 1024 MB memory, 512 CPU
  - [ ] Use database ECR image
  - [ ] Port mapping 5432
  - [ ] Environment variables (POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD)
  - [ ] Mount EFS volume to `/var/lib/postgresql/data`
  - [ ] CloudWatch logging (`/ecs/database`)
  - [ ] Health check configuration
  - [ ] EFS volume configuration with encryption

- [ ] Create Backend Task Definition (`ecs-backend-task`)
  - [ ] Fargate compatibility
  - [ ] 512 MB memory, 256 CPU
  - [ ] Use backend ECR image
  - [ ] Port mapping 4000
  - [ ] Environment variables (NODE_ENV, POSTGRES_DB, POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PASSWORD)
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

---

## ✅ Load Balancer Setup

### Application Load Balancer
- [ ] Create ALB (`ecs-alb`)
  - [ ] Internet-facing
  - [ ] Use public subnets
  - [ ] Use ALB security group

### Target Groups
- [ ] Create Frontend Target Group (`ecs-frontend-tg`)
  - [ ] IP addresses target type
  - [ ] HTTP port 80
  - [ ] Health check path `/health`
- [ ] Create Backend Target Group (`ecs-backend-tg`)
  - [ ] IP addresses target type
  - [ ] HTTP port 4000
  - [ ] Health check path `/health`

### Listeners
- [ ] Configure default listener to forward to frontend target group
- [ ] Add listener rule for backend target group

---

## ✅ ECS Services

### Database Service
- [ ] Create Database Service (`ecs-database-service`)
  - [ ] Fargate launch type
  - [ ] Use database task definition
  - [ ] 1 desired task
  - [ ] Use private subnets
  - [ ] Use database security group
  - [ ] Disable auto-assign public IP
  - [ ] Skip load balancer configuration

### Backend Service
- [ ] Create Backend Service (`ecs-backend-service`)
  - [ ] Fargate launch type
  - [ ] Use backend task definition
  - [ ] 2 desired tasks
  - [ ] Use private subnets
  - [ ] Use backend security group
  - [ ] Disable auto-assign public IP
  - [ ] Configure load balancer integration

### Frontend Service
- [ ] Create Frontend Service (`ecs-frontend-service`)
  - [ ] Fargate launch type
  - [ ] Use frontend task definition
  - [ ] 2 desired tasks
  - [ ] Use public subnets
  - [ ] Use frontend security group
  - [ ] Enable auto-assign public IP
  - [ ] Configure load balancer integration

---

## ✅ Monitoring and Logging

### CloudWatch Log Groups
- [ ] Create Frontend Log Group (`/ecs/frontend`)
- [ ] Create Backend Log Group (`/ecs/backend`)
- [ ] Create Database Log Group (`/ecs/database`)

---

## ✅ Testing and Verification

### Service Health
- [ ] Check ECS service status
- [ ] Verify all tasks are running
- [ ] Check target health in load balancer
- [ ] Verify health checks are passing

### Application Testing
- [ ] Get ALB DNS name
- [ ] Test frontend health endpoint (`/health`)
- [ ] Test backend health endpoint (`/api/health`)
- [ ] Test main application
- [ ] Verify status indicators show "Connected"
- [ ] Test todo functionality (create, read, update, delete)

### Database Persistence
- [ ] Create a todo item
- [ ] Restart database service
- [ ] Verify todo item still exists
- [ ] Test database logs in CloudWatch

---

## 🔧 Troubleshooting Checklist

### If Database Service Fails
- [ ] Check EFS mount targets are in correct subnets
- [ ] Verify EFS security group allows NFS from database security group
- [ ] Check task execution role has EFS permissions
- [ ] Review database logs in CloudWatch

### If Backend Service Fails
- [ ] Check database connection (security groups, hostname)
- [ ] Verify environment variables are correct
- [ ] Check backend logs in CloudWatch
- [ ] Test database connectivity from backend task

### If Frontend Service Fails
- [ ] Check ALB health checks
- [ ] Verify nginx configuration
- [ ] Check frontend logs in CloudWatch
- [ ] Test backend API connectivity

### If Load Balancer Health Checks Fail
- [ ] Verify health check paths are correct
- [ ] Check security group rules
- [ ] Test health endpoints directly
- [ ] Review container logs

---

## 📝 Important Notes

### Security Considerations
- [ ] Database runs in private subnets
- [ ] Backend runs in private subnets
- [ ] Only frontend is accessible from internet
- [ ] EFS volume is encrypted in transit
- [ ] Security groups follow least privilege principle

### Performance Considerations
- [ ] Database has 1024 MB memory for better performance
- [ ] EFS provides persistent storage across AZs
- [ ] Services can be scaled independently
- [ ] Load balancer distributes traffic across tasks

### Monitoring Considerations
- [ ] All logs are centralized in CloudWatch
- [ ] Health checks monitor service availability
- [ ] ECS service metrics are available
- [ ] Database logs show connection and query information

---

## 🎯 Success Criteria

Your deployment is successful when:
- [ ] All ECS services are running with desired task count
- [ ] Load balancer health checks are passing
- [ ] Frontend is accessible via ALB DNS name
- [ ] Backend and database status show as "Connected"
- [ ] Todo functionality works completely
- [ ] Database data persists across service restarts
- [ ] All logs are being generated in CloudWatch
- [ ] No security group or networking issues

---

## 🚀 Next Steps

After successful deployment:
- [ ] Set up CloudWatch alarms for monitoring
- [ ] Configure auto-scaling policies
- [ ] Set up CI/CD pipeline for updates
- [ ] Implement backup strategy for EFS
- [ ] Consider using AWS Secrets Manager for credentials
- [ ] Set up monitoring dashboards
- [ ] Document runbooks for common issues 