# Complete ECS Setup Guide for 3-Tier Application

This guide provides a complete step-by-step process to deploy your 3-tier application on AWS ECS Fargate with dockerized database and persistent storage.

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Docker installed locally
- AWS CLI configured (`aws configure`)
- Basic knowledge of AWS services

## 🏗️ Architecture Overview

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → Database (Private Subnet)
                                                                    ↓
                                                              EFS Volume (Persistent Storage)
```

## 📁 Application Structure

```
3-tier-app/
├── frontend/          # React application
├── backend/           # Node.js API
├── database/          # PostgreSQL configuration
├── docker-compose.yml # Local development
└── ECS_DEPLOYMENT_GUIDE.md # Detailed deployment steps
```

## 🚀 Step-by-Step ECS Deployment

### Step 1: Local Testing (Required First)

Before deploying to ECS, ensure your application works locally:

```powershell
# Navigate to project directory
cd 3-tier-app

# Test locally
.\test-local.ps1

# Verify all endpoints work:
# - Frontend: http://localhost/health
# - Backend: http://localhost:4000/health
# - API Proxy: http://localhost/api/health
```

### Step 2: Prepare AWS Environment

#### 2.1 Set Environment Variables

Create a file `setup-variables.ps1`:

```powershell
# AWS Configuration
$env:AWS_REGION = "us-east-1"
$env:AWS_ACCOUNT_ID = "YOUR_ACCOUNT_ID"  # Replace with your AWS account ID

# VPC Configuration
$env:VPC_CIDR = "10.0.0.0/16"
$env:PUBLIC_SUBNET_1_CIDR = "10.0.1.0/24"
$env:PUBLIC_SUBNET_2_CIDR = "10.0.2.0/24"
$env:PRIVATE_SUBNET_1_CIDR = "10.0.3.0/24"
$env:PRIVATE_SUBNET_2_CIDR = "10.0.4.0/24"

# Resource Names
$env:VPC_NAME = "ecs-vpc"
$env:CLUSTER_NAME = "ecs-app-cluster"
$env:ALB_NAME = "ecs-alb"
$env:EFS_NAME = "ecs-db-storage"

# ECR Repository Names
$env:FRONTEND_REPO = "ecs-frontend"
$env:BACKEND_REPO = "ecs-backend"
$env:DATABASE_REPO = "ecs-database"

# Task Definition Names
$env:FRONTEND_TASK = "ecs-frontend-task"
$env:BACKEND_TASK = "ecs-backend-task"
$env:DATABASE_TASK = "ecs-database-task"

# Service Names
$env:FRONTEND_SERVICE = "ecs-frontend-service"
$env:BACKEND_SERVICE = "ecs-backend-service"
$env:DATABASE_SERVICE = "ecs-database-service"
```

#### 2.2 Get Your AWS Account ID

```powershell
aws sts get-caller-identity --query Account --output text
```

### Step 3: Create VPC and Networking

#### 3.1 Create VPC

1. **Go to VPC Console**: AWS Console → VPC → Your VPCs
2. **Click "Create VPC"**
3. **Configure**:
   - **VPC name**: `ecs-vpc`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **IPv6 CIDR block**: No IPv6 CIDR block
   - **Tenancy**: Default
4. **Click "Create VPC"**

#### 3.2 Create Subnets

**Public Subnets (for ALB and Frontend)**:

1. **Create Public Subnet 1**:
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1a`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - **Click "Create subnet"**

2. **Create Public Subnet 2**:
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1b`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - **Click "Create subnet"**

**Private Subnets (for Backend and Database)**:

1. **Create Private Subnet 1**:
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-private-subnet-1a`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.3.0/24`
   - **Click "Create subnet"**

2. **Create Private Subnet 2**:
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-private-subnet-1b`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.4.0/24`
   - **Click "Create subnet"**

#### 3.3 Create Internet Gateway

1. **VPC Console** → Internet Gateways → Create internet gateway
2. **Name tag**: `ecs-igw`
3. **Click "Create internet gateway"**
4. **Select IGW** → Actions → Attach to VPC
5. **Select `ecs-vpc`** → Click "Attach internet gateway"

#### 3.4 Create Route Tables

**Public Route Table**:

1. **VPC Console** → Route Tables → Create route table
2. **Name**: `ecs-public-rt`
3. **VPC**: Select `ecs-vpc`
4. **Click "Create route table"**
5. **Select route table** → Routes → Edit routes
6. **Add route**: Destination `0.0.0.0/0`, Target: Internet Gateway
7. **Click "Save changes"**
8. **Subnet associations** → Edit subnet associations
9. **Select both public subnets** → Click "Save associations"

**Enable Auto-assign Public IP**:
- For each public subnet: Actions → Modify auto-assign IP settings → Enable

### Step 4: Create EFS File System

#### 4.1 Create EFS File System

1. **EFS Console** → File systems → Create file system
2. **Configure**:
   - **Name**: `ecs-db-storage`
   - **VPC**: Select `ecs-vpc`
   - **Availability and durability**: Regional
3. **Click "Create"**

#### 4.2 Create Mount Targets

1. **Select file system** → Network → Create mount target
2. **Subnet**: Select `ecs-private-subnet-1a`
3. **Security groups**: Create new security group `ecs-efs-sg`
4. **Click "Create mount target"**

5. **Create second mount target**:
   - **Subnet**: Select `ecs-private-subnet-1b`
   - **Security groups**: Select `ecs-efs-sg`
   - **Click "Create mount target"**

### Step 5: Create Security Groups

#### 5.1 ALB Security Group

1. **VPC Console** → Security Groups → Create security group
2. **Security group name**: `ecs-alb-sg`
3. **Description**: `Security group for ALB`
4. **VPC**: Select `ecs-vpc`
5. **Click "Create security group"**
6. **Add Inbound Rules**:
   - **Type**: HTTP, Source: Anywhere-IPv4
   - **Type**: HTTPS, Source: Anywhere-IPv4
7. **Click "Save rules"**

#### 5.2 Frontend Security Group

1. **Create Security Group**:
   - **Security group name**: `ecs-frontend-sg`
   - **Description**: `Security group for frontend`
   - **VPC**: Select `ecs-vpc`
2. **Add Inbound Rules**:
   - **Type**: HTTP, Source: Custom → Select `ecs-alb-sg`
3. **Click "Save rules"**

#### 5.3 Backend Security Group

1. **Create Security Group**:
   - **Security group name**: `ecs-backend-sg`
   - **Description**: `Security group for backend`
   - **VPC**: Select `ecs-vpc`
2. **Add Inbound Rules**:
   - **Type**: Custom TCP, Port: 4000, Source: Custom → Select `ecs-frontend-sg`
3. **Click "Save rules"**

#### 5.4 Database Security Group

1. **Create Security Group**:
   - **Security group name**: `ecs-db-sg`
   - **Description**: `Security group for database`
   - **VPC**: Select `ecs-vpc`
2. **Add Inbound Rules**:
   - **Type**: PostgreSQL, Source: Custom → Select `ecs-backend-sg`
3. **Click "Save rules"**

#### 5.5 EFS Security Group

1. **Create Security Group**:
   - **Security group name**: `ecs-efs-sg`
   - **Description**: `Security group for EFS`
   - **VPC**: Select `ecs-vpc`
2. **Add Inbound Rules**:
   - **Type**: NFS, Source: Custom → Select `ecs-db-sg`
3. **Click "Save rules"**

### Step 6: Create ECR Repositories

#### 6.1 Create Repositories

1. **ECR Console** → Repositories → Create repository

**Frontend Repository**:
- **Repository name**: `ecs-frontend`
- **Tag immutability**: Enable
- **Scan on push**: Enable
- **Click "Create repository"**

**Backend Repository**:
- **Repository name**: `ecs-backend`
- **Tag immutability**: Enable
- **Scan on push**: Enable
- **Click "Create repository"**

**Database Repository**:
- **Repository name**: `ecs-database`
- **Tag immutability**: Enable
- **Scan on push**: Enable
- **Click "Create repository"**

#### 6.2 Build and Push Images

Create a script `build-and-push.ps1`:

```powershell
# Get AWS Account ID
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = "us-east-1"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push frontend
Write-Host "Building and pushing frontend..." -ForegroundColor Green
cd frontend
docker build -t ecs-frontend .
docker tag ecs-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-frontend:latest
cd ..

# Build and push backend
Write-Host "Building and pushing backend..." -ForegroundColor Green
cd backend
docker build -t ecs-backend .
docker tag ecs-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-backend:latest
cd ..

# Build and push database
Write-Host "Building and pushing database..." -ForegroundColor Green
cd database
docker build -t ecs-database .
docker tag ecs-database:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-database:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-database:latest
cd ..

Write-Host "All images pushed successfully!" -ForegroundColor Green
```

Run the script:
```powershell
.\build-and-push.ps1
```

### Step 7: Create ECS Cluster

1. **ECS Console** → Clusters → Create cluster
2. **Configure**:
   - **Cluster name**: `ecs-app-cluster`
   - **Networking VPC**: Select `ecs-vpc`
   - **Cluster type**: Networking only (for Fargate)
3. **Click "Create"**

### Step 8: Create IAM Roles

#### 8.1 ECS Task Execution Role

1. **IAM Console** → Roles → Create role
2. **Trusted entity**: AWS service
3. **Service**: ECS
4. **Use case**: ECS - Task
5. **Click "Next"**
6. **Attach Policies**:
   - `AmazonECSTaskExecutionRolePolicy`
   - `SecretsManagerReadWrite`
7. **Click "Next"**
8. **Role name**: `ecsTaskExecutionRole`
9. **Click "Create role"**

#### 8.2 ECS Task Role

1. **Create Role**:
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
2. **Attach Policies**:
   - `SecretsManagerReadWrite`
3. **Role name**: `ecsTaskRole`
4. **Click "Create role"**

### Step 9: Create Task Definitions

#### 9.1 Database Task Definition

1. **ECS Console** → Task Definitions → Create new Task Definition
2. **Configure**:
   - **Task Definition Name**: `ecs-database-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskRole`
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 1024 MB
   - **Task CPU**: 512 (.5 vCPU)
3. **Click "Next"**

4. **Configure Container**:
   - **Container name**: `database`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest`
   - **Port mappings**: 5432
   - **Essential**: Yes

5. **Environment Variables**:
   - **POSTGRES_DB**: `ecsdb`
   - **POSTGRES_USER**: `ecsuser`
   - **POSTGRES_PASSWORD**: `ecspassword`

6. **Mount Points**:
   - **Source volume**: `database-storage`
   - **Container path**: `/var/lib/postgresql/data`
   - **Read only**: No

7. **Log Configuration**:
   - **Log driver**: awslogs
   - **Log group**: `/ecs/database`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

8. **Health Check**:
   - **Command**: `["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

9. **Volumes**:
   - **Name**: `database-storage`
   - **Volume type**: EFS
   - **File system ID**: Select your EFS file system
   - **Root directory**: `/`
   - **Transit encryption**: Enable

10. **Click "Next" → "Create"**

#### 9.2 Backend Task Definition

1. **Create New Task Definition**:
   - **Task Definition Name**: `ecs-backend-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskRole`
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)

2. **Configure Container**:
   - **Container name**: `backend`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest`
   - **Port mappings**: 4000
   - **Essential**: Yes

3. **Environment Variables**:
   - **NODE_ENV**: `production`
   - **POSTGRES_DB**: `ecsdb`
   - **POSTGRES_HOST**: `database`
   - **POSTGRES_PORT**: `5432`
   - **POSTGRES_USER**: `ecsuser`
   - **POSTGRES_PASSWORD**: `ecspassword`

4. **Log Configuration**:
   - **Log driver**: awslogs
   - **Log group**: `/ecs/backend`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

5. **Health Check**:
   - **Command**: `["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

6. **Click "Next" → "Create"**

#### 9.3 Frontend Task Definition

1. **Create New Task Definition**:
   - **Task Definition Name**: `ecs-frontend-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)

2. **Configure Container**:
   - **Container name**: `frontend`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest`
   - **Port mappings**: 80
   - **Essential**: Yes

3. **Environment Variables**:
   - **REACT_APP_API_URL**: `/api`

4. **Log Configuration**:
   - **Log driver**: awslogs
   - **Log group**: `/ecs/frontend`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

5. **Health Check**:
   - **Command**: `["CMD-SHELL", "curl -f http://localhost/health || exit 1"]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

6. **Click "Next" → "Create"**

### Step 10: Create Application Load Balancer

#### 10.1 Create ALB

1. **EC2 Console** → Load Balancers → Create load balancer
2. **Choose**: Application Load Balancer
3. **Configure**:
   - **Name**: `ecs-alb`
   - **Scheme**: internet-facing
   - **IP address type**: ipv4
   - **VPC**: Select `ecs-vpc`
   - **Mappings**: Select both public subnets

4. **Configure Security Groups**:
   - **Security groups**: Select `ecs-alb-sg`
   - **Click "Next: Configure Security Settings"**

5. **Security Settings**: Click "Next: Configure Routing"

6. **Configure Routing**:
   - **Target group**: New target group
   - **Target group name**: `ecs-frontend-tg`
   - **Target type**: IP addresses
   - **Protocol**: HTTP
   - **Port**: 80
   - **Health check protocol**: HTTP
   - **Health check path**: `/health`
   - **Advanced health check settings**:
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 2
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
   - **Click "Next: Register Targets"**

7. **Register Targets**: Skip for now
8. **Click "Next: Review"**
9. **Review and Create**

#### 10.2 Create Backend Target Group

1. **EC2 Console** → Target Groups → Create target group
2. **Configure**:
   - **Target group name**: `ecs-backend-tg`
   - **Target type**: IP addresses
   - **Protocol**: HTTP
   - **Port**: 4000
   - **VPC**: Select `ecs-vpc`
   - **Health check protocol**: HTTP
   - **Health check path**: `/health`
   - **Advanced health check settings**:
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 2
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
3. **Click "Next: Register Targets"**
4. **Register Targets**: Skip for now
5. **Click "Create target group"**

### Step 11: Create ECS Services

#### 11.1 Create Database Service

1. **ECS Console** → Clusters → `ecs-app-cluster` → Services → Create
2. **Configure Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-database-task`
   - **Service name**: `ecs-database-service`
   - **Number of tasks**: 1
3. **Click "Next step"**

4. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-db-sg`
   - **Auto-assign public IP**: Disabled
5. **Click "Next step"**

6. **Configure Load Balancer**: Skip load balancer configuration
7. **Click "Next step"**

8. **Configure Auto Scaling**: Skip for now
9. **Click "Next step"**

10. **Review and Create**

#### 11.2 Create Backend Service

1. **Create Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-backend-task`
   - **Service name**: `ecs-backend-service`
   - **Number of tasks**: 2

2. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled

3. **Configure Load Balancer**:
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Create new role
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-backend-tg`
   - **Container name**: `backend`
   - **Container port**: 4000

4. **Configure Auto Scaling**: Skip for now
5. **Review and Create**

#### 11.3 Create Frontend Service

1. **Create Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-frontend-task`
   - **Service name**: `ecs-frontend-service`
   - **Number of tasks**: 2

2. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both public subnets
   - **Security groups**: Select `ecs-frontend-sg`
   - **Auto-assign public IP**: Enabled

3. **Configure Load Balancer**:
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Use existing role (created for backend)
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-frontend-tg`
   - **Container name**: `frontend`
   - **Container port**: 80

4. **Configure Auto Scaling**: Skip for now
5. **Review and Create**

### Step 12: Create CloudWatch Log Groups

1. **CloudWatch Console** → Log groups → Create log group
2. **Create Log Groups**:
   - **Frontend**: `/ecs/frontend`
   - **Backend**: `/ecs/backend`
   - **Database**: `/ecs/database`
3. **Click "Create" for each**

### Step 13: Test the Application

#### 13.1 Get ALB DNS Name

1. **EC2 Console** → Load Balancers
2. **Select your ALB**
3. **Copy the DNS name from the "Description" tab**

#### 13.2 Test Health Endpoints

```powershell
# Test frontend health
Invoke-WebRequest -Uri "http://<your-alb-dns>/health"

# Test backend health
Invoke-WebRequest -Uri "http://<your-alb-dns>/api/health"

# Test main application
Start-Process "http://<your-alb-dns>"
```

#### 13.3 Verify Application

1. **Open browser**: `http://<your-alb-dns>`
2. **Check status indicators**: Should show "Connected" for both backend and database
3. **Test todo functionality**: Add, edit, delete todos
4. **Verify data persistence**: Create a todo, restart database service, verify todo still exists

### Step 14: Monitoring and Troubleshooting

#### 14.1 Check Service Status

1. **ECS Console** → Clusters → `ecs-app-cluster` → Services
2. **Check service status and running tasks**

#### 14.2 View Logs

1. **CloudWatch Console** → Log groups
2. **Select log group and click on log streams**

#### 14.3 Check Target Health

1. **EC2 Console** → Target Groups
2. **Select target group**
3. **Check "Targets" tab for health status**

## 🔧 Common Issues and Solutions

### 1. Database Connection Issues
- **Check**: Security group rules between backend and database
- **Solution**: Verify `ecs-backend-sg` can access `ecs-db-sg` on port 5432

### 2. EFS Mount Issues
- **Check**: EFS security group and mount targets
- **Solution**: Ensure `ecs-db-sg` can access `ecs-efs-sg` on NFS port

### 3. Task Startup Issues
- **Check**: IAM role permissions and task definition
- **Solution**: Verify task execution role has EFS and Secrets Manager access

### 4. Load Balancer Health Check Failures
- **Check**: Health check paths and container responses
- **Solution**: Verify health check endpoints are responding correctly

## 📝 Important Notes

### Security Considerations
- Database runs in private subnets
- Backend runs in private subnets
- Only frontend is accessible from internet
- EFS volume is encrypted in transit
- Security groups follow least privilege principle

### Performance Considerations
- Database has 1024 MB memory for better performance
- EFS provides persistent storage across AZs
- Services can be scaled independently
- Load balancer distributes traffic across tasks

### Monitoring Considerations
- All logs are centralized in CloudWatch
- Health checks monitor service availability
- ECS service metrics are available
- Database logs show connection and query information

## 🎯 Success Criteria

Your deployment is successful when:
- All ECS services are running with desired task count
- Load balancer health checks are passing
- Frontend is accessible via ALB DNS name
- Backend and database status show as "Connected"
- Todo functionality works completely
- Database data persists across service restarts
- All logs are being generated in CloudWatch
- No security group or networking issues

## 🚀 Next Steps

After successful deployment:
- Set up CloudWatch alarms for monitoring
- Configure auto-scaling policies
- Set up CI/CD pipeline for updates
- Implement backup strategy for EFS
- Consider using AWS Secrets Manager for credentials
- Set up monitoring dashboards
- Document runbooks for common issues

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review CloudWatch logs for error messages
3. Verify security group configurations
4. Test health endpoints manually
5. Check ECS service events for deployment issues

This setup provides a production-ready 3-tier application with persistent database storage, proper security, and scalability. 