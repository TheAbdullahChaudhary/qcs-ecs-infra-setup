# Complete End-to-End AWS ECS Manual Deployment Guide

## 🎯 Overview
This comprehensive guide covers every detail needed to deploy a 3-tier application (Frontend + Backend + Database) on AWS ECS using the AWS Console UI, without Terraform.

## 📋 Prerequisites
- AWS Account with appropriate permissions
- Docker images for frontend, backend, and database
- Basic understanding of AWS services

---

## Phase 1: VPC and Networking Setup

### Step 1.1: Create VPC
1. **Navigate to VPC Console**
   - AWS Console → VPC → Create VPC
2. **Configure VPC Settings**
   - **Name tag**: `ecs-vpc`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **IPv6 CIDR block**: No IPv6 CIDR block
   - **Tenancy**: Default
   - **Enable DNS hostnames**: Yes
   - **Enable DNS resolution**: Yes
3. **Click "Create VPC"**

### Step 1.2: Create Subnets

#### Public Subnet 1
1. **VPC Console** → Subnets → Create subnet
2. **Configure**:
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1`
   - **Availability Zone**: us-east-1a
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - **Auto-assign IPv4**: Enable
3. **Click "Create subnet"**

#### Public Subnet 2
1. **Create another subnet**:
   - **Subnet name**: `ecs-public-subnet-2`
   - **Availability Zone**: us-east-1b
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - **Auto-assign IPv4**: Enable

#### Private Subnet 1
1. **Create subnet**:
   - **Subnet name**: `ecs-private-subnet-1`
   - **Availability Zone**: us-east-1a
   - **IPv4 CIDR block**: `10.0.11.0/24`
   - **Auto-assign IPv4**: Disable

#### Private Subnet 2
1. **Create subnet**:
   - **Subnet name**: `ecs-private-subnet-2`
   - **Availability Zone**: us-east-1b
   - **IPv4 CIDR block**: `10.0.12.0/24`
   - **Auto-assign IPv4**: Disable

### Step 1.3: Create Internet Gateway
1. **VPC Console** → Internet Gateways → Create internet gateway
2. **Configure**:
   - **Name tag**: `ecs-igw`
3. **Click "Create internet gateway"**
4. **Attach to VPC**:
   - Select the internet gateway → Actions → Attach to VPC
   - **VPC**: Select `ecs-vpc`
   - **Click "Attach internet gateway"**

### Step 1.4: Create NAT Gateway
1. **VPC Console** → NAT Gateways → Create NAT gateway
2. **Configure**:
   - **Name**: `ecs-nat-gateway`
   - **Subnet**: Select `ecs-public-subnet-1`
   - **Connectivity type**: Public
   - **Elastic IP allocation ID**: Allocate Elastic IP
3. **Click "Create NAT gateway"**

### Step 1.5: Create Route Tables

#### Public Route Table
1. **VPC Console** → Route Tables → Create route table
2. **Configure**:
   - **Name**: `ecs-public-rt`
   - **VPC**: Select `ecs-vpc`
3. **Click "Create route table"**
4. **Edit routes** → Add route:
   - **Destination**: `0.0.0.0/0`
   - **Target**: Internet Gateway (`ecs-igw`)
5. **Subnet associations** → Edit subnet associations:
   - Select both public subnets (`ecs-public-subnet-1`, `ecs-public-subnet-2`)

#### Private Route Table
1. **Create route table**:
   - **Name**: `ecs-private-rt`
   - **VPC**: Select `ecs-vpc`
2. **Edit routes** → Add route:
   - **Destination**: `0.0.0.0/0`
   - **Target**: NAT Gateway (`ecs-nat-gateway`)
3. **Subnet associations** → Edit subnet associations:
   - Select both private subnets (`ecs-private-subnet-1`, `ecs-private-subnet-2`)

### Step 1.6: Create Security Groups

#### ALB Security Group
1. **VPC Console** → Security Groups → Create security group
2. **Configure**:
   - **Security group name**: `ecs-alb-sg`
   - **Description**: Security group for Application Load Balancer
   - **VPC**: Select `ecs-vpc`
3. **Inbound rules**:
   - **Type**: HTTP, **Port**: 80, **Source**: 0.0.0.0/0
4. **Click "Create security group"**

#### Frontend Security Group
1. **Create security group**:
   - **Security group name**: `ecs-frontend-sg`
   - **Description**: Security group for frontend containers
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: HTTP, **Port**: 80, **Source**: `ecs-alb-sg`
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0
4. **Click "Create security group"**

#### Backend Security Group
1. **Create security group**:
   - **Security group name**: `ecs-backend-sg`
   - **Description**: Security group for backend containers
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: HTTP, **Port**: 4000, **Source**: `ecs-alb-sg`
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0
4. **Click "Create security group"**

#### Database Security Group
1. **Create security group**:
   - **Security group name**: `ecs-database-sg`
   - **Description**: Security group for database containers
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: PostgreSQL, **Port**: 5432, **Source**: `ecs-backend-sg`
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0
4. **Click "Create security group"**

#### EFS Security Group
1. **Create security group**:
   - **Security group name**: `ecs-efs-sg`
   - **Description**: Security group for EFS file system
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: NFS, **Port**: 2049, **Source**: `ecs-database-sg`
3. **Click "Create security group"**

---

## Phase 2: EFS Storage Setup

### Step 2.1: Create EFS File System
1. **Navigate to EFS Console**
   - AWS Console → EFS → Create file system
2. **Configure**:
   - **Name**: `ecs-database-efs`
   - **VPC**: Select `ecs-vpc`
   - **Availability and durability**: Regional
   - **Performance mode**: General Purpose
   - **Throughput mode**: Bursting
   - **Encryption**: Enable encryption in transit and at rest
3. **Click "Create"**

### Step 2.2: Create Access Point
1. **EFS Console** → Access points → Create access point
2. **Configure**:
   - **Name**: `ecs-database-ap`
   - **Root directory path**: `/ecs/database`
   - **User ID**: 1000
   - **Group ID**: 1000
   - **Permissions**: 755
3. **Click "Create access point"**

### Step 2.3: Create Mount Targets
1. **EFS Console** → Mount targets → Create mount target
2. **Configure for Private Subnet 1**:
   - **Subnet**: Select `ecs-private-subnet-1`
   - **Security groups**: Select `ecs-efs-sg`
3. **Click "Create mount target"**
4. **Repeat for Private Subnet 2**:
   - **Subnet**: Select `ecs-private-subnet-2`
   - **Security groups**: Select `ecs-efs-sg`

---

## Phase 3: ECR Repositories

### Step 3.1: Create ECR Repositories
1. **Navigate to ECR Console**
   - AWS Console → ECR → Create repository

#### Frontend Repository
1. **Configure**:
   - **Repository name**: `ecs-frontend`
   - **Tag immutability**: Disable
   - **Scan on push**: Enable
2. **Click "Create repository"**

#### Backend Repository
1. **Create repository**:
   - **Repository name**: `ecs-backend`
   - **Tag immutability**: Disable
   - **Scan on push**: Enable

#### Database Repository
1. **Create repository**:
   - **Repository name**: `ecs-database`
   - **Tag immutability**: Disable
   - **Scan on push**: Enable

---

## Phase 4: ECS Cluster

### Step 4.1: Create ECS Cluster
1. **Navigate to ECS Console**
   - AWS Console → ECS → Create cluster
2. **Configure**:
   - **Cluster name**: `ecs-app-cluster`
   - **VPC**: Select `ecs-vpc`
   - **Networking**: VPC only
3. **Click "Create"**

---

## Phase 5: IAM Roles

### Step 5.1: Create Task Execution Role
1. **Navigate to IAM Console**
   - AWS Console → IAM → Roles → Create role
2. **Configure**:
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
3. **Attach policies**:
   - `AmazonECSTaskExecutionRolePolicy`
   - `AmazonEFSFullAccess`
4. **Role name**: `ecsTaskExecutionRole`
5. **Click "Create role"**

### Step 5.2: Create Task Role
1. **Create another role**:
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
2. **Attach policies**:
   - `AmazonEFSFullAccess`
3. **Role name**: `ecsTaskRole`
4. **Click "Create role"**

---

## Phase 6: Load Balancer Setup

### Step 6.1: Create Application Load Balancer
1. **Navigate to EC2 Console**
   - AWS Console → EC2 → Load Balancers → Create load balancer
2. **Choose Load Balancer Type**:
   - **Application Load Balancer**
   - Click "Create"
3. **Configure Load Balancer**:
   - **Name**: `ecs-alb`
   - **Scheme**: internet-facing
   - **IP address type**: ipv4
   - **VPC**: Select `ecs-vpc`
   - **Mappings**: Select both public subnets
4. **Configure Security Groups**:
   - **Security groups**: Select `ecs-alb-sg`
5. **Configure Routing**:
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
6. **Click "Create load balancer"**

### Step 6.2: Create Backend Target Group
1. **Navigate to Target Groups**
   - EC2 Console → Target Groups → Create target group
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
3. **Click "Create target group"**

### Step 6.3: Configure ALB Listeners
1. **Navigate to Load Balancers**
   - Select your ALB → "Listeners" tab
2. **Edit Default Listener**:
   - Click "Edit" on the existing listener
   - **Default action**: Forward to `ecs-frontend-tg`
   - Click "Save changes"
3. **Add Backend Listener Rule**:
   - Click "Add listener"
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default action**: Forward to `ecs-backend-tg`
   - Click "Add listener"

---

## Phase 7: ECS Task Definitions

### Step 7.1: Create Database Task Definition
1. **Navigate to ECS Console**
   - ECS → Task Definitions → Create new task definition
2. **Configure**:
   - **Task Definition Name**: `ecs-database-task`
   - **Task memory**: 1024 MB
   - **Task CPU**: 512 (.5 vCPU)
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task role**: Select `ecsTaskRole`
3. **Add Container**:
   - **Container name**: `database`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest`
   - **Port mappings**: 5432:5432
   - **Environment variables**:
     - `POSTGRES_DB`: `ecsdb`
     - `POSTGRES_USER`: `ecsuser`
     - `POSTGRES_PASSWORD`: `ecspassword`
   - **Health check**:
     - **Command**: `["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
4. **Configure Storage**:
   - **Volume type**: EFS
   - **File system ID**: Select your EFS
   - **Access point ID**: Select your access point
   - **Root directory**: `/`
   - **Container path**: `/var/lib/postgresql/data`
5. **Click "Create"**

### Step 7.2: Create Backend Task Definition
1. **Create new task definition**:
   - **Task Definition Name**: `ecs-backend-task`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task role**: Select `ecsTaskRole`
2. **Add Container**:
   - **Container name**: `backend`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest`
   - **Port mappings**: 4000:4000
   - **Environment variables**:
     - `NODE_ENV`: `production`
     - `POSTGRES_DB`: `ecsdb`
     - `POSTGRES_HOST`: `ecs-database-service`
     - `POSTGRES_PORT`: `5432`
     - `POSTGRES_USER`: `ecsuser`
     - `POSTGRES_PASSWORD`: `ecspassword`
   - **Health check**:
     - **Command**: `["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
3. **Click "Create"**

### Step 7.3: Create Frontend Task Definition
1. **Create new task definition**:
   - **Task Definition Name**: `ecs-frontend-task`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)
   - **Task execution role**: Select `ecsTaskExecutionRole`
2. **Add Container**:
   - **Container name**: `frontend`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest`
   - **Port mappings**: 80:80
   - **Environment variables**:
     - `REACT_APP_API_URL`: `http://[ALB-DNS-NAME]/api`
   - **Health check**:
     - **Command**: `["CMD-SHELL", "curl -f http://localhost/health || exit 1"]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
3. **Click "Create"**

---

## Phase 8: ECS Services

### Step 8.1: Create Database Service
1. **Navigate to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services → Create
2. **Configure Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-database-task`
   - **Service name**: `ecs-database-service`
   - **Number of tasks**: 1
3. **Click "Next step"**
4. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-database-sg`
   - **Auto-assign public IP**: Disabled
5. **Click "Next step"**
6. **Configure Load Balancer**: Skip
7. **Click "Next step"**
8. **Configure Auto Scaling**: Skip
9. **Click "Next step"**
10. **Review and Create**

### Step 8.2: Create Backend Service
1. **Create Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-backend-task`
   - **Service name**: `ecs-backend-service`
   - **Number of tasks**: 2
2. **Click "Next step"**
3. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled
4. **Click "Next step"**
5. **Configure Load Balancer**:
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Create new role
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-backend-tg`
   - **Container name**: `backend`
   - **Container port**: 4000
6. **Click "Next step"**
7. **Configure Auto Scaling**: Skip
8. **Click "Next step"**
9. **Review and Create**

### Step 8.3: Create Frontend Service
1. **Create Service**:
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-frontend-task`
   - **Service name**: `ecs-frontend-service`
   - **Number of tasks**: 2
2. **Click "Next step"**
3. **Configure Network**:
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both public subnets
   - **Security groups**: Select `ecs-frontend-sg`
   - **Auto-assign public IP**: Enabled
4. **Click "Next step"**
5. **Configure Load Balancer**:
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Create new role
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-frontend-tg`
   - **Container name**: `frontend`
   - **Container port**: 80
6. **Click "Next step"**
7. **Configure Auto Scaling**: Skip
8. **Click "Next step"**
9. **Review and Create**

---

## Phase 9: Testing and Verification

### Step 9.1: Get ALB DNS Name
1. **Navigate to Load Balancers**
   - EC2 Console → Load Balancers
   - Copy the DNS name of your ALB

### Step 9.2: Update Frontend Environment Variable
1. **Navigate to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services → `ecs-frontend-service`
2. **Update Service**:
   - Click "Update"
   - Go to task definition
   - Update the `REACT_APP_API_URL` environment variable with your ALB DNS name
   - Example: `http://ecs-alb-123456789.us-east-1.elb.amazonaws.com/api`

### Step 9.3: Test the Application
1. **Open browser**: `http://[ALB-DNS-NAME]`
2. **Check status indicators**: Should show "Connected" for both backend and database
3. **Test todo functionality**: Add, edit, delete todos
4. **Verify data persistence**: Create a todo, restart database service, verify todo still exists

---

## Phase 10: Monitoring and Troubleshooting

### Step 10.1: Check Service Status
1. **ECS Console** → Clusters → `ecs-app-cluster` → Services
2. **Check service status and running tasks**

### Step 10.2: View Logs
1. **CloudWatch Console** → Log groups
2. **Select log group and click on log streams**

### Step 10.3: Check Target Health
1. **EC2 Console** → Target Groups
2. **Select target group**
3. **Check "Targets" tab for health status**

---

## 🔧 Common Issues and Solutions

### 1. Database Connection Issues
- **Check**: Security group rules between backend and database
- **Solution**: Verify `ecs-backend-sg` can access `ecs-database-sg` on port 5432

### 2. EFS Mount Issues
- **Check**: EFS security group and mount targets
- **Solution**: Ensure `ecs-database-sg` can access `ecs-efs-sg` on NFS port

### 3. Task Startup Issues
- **Check**: IAM role permissions and task definition
- **Solution**: Verify task execution role has EFS access

### 4. Load Balancer Health Check Failures
- **Check**: Health check paths and container responses
- **Solution**: Verify health check endpoints are responding correctly

---

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
- Target group health indicates load balancer status
- ECS service events show deployment status

---

## �� Success Criteria

Your deployment is successful when:
- ✅ All ECS services are running with desired task count
- ✅ Target groups show healthy targets
- ✅ Application is accessible via ALB DNS name
- ✅ Frontend shows "Connected" status for backend and database
- ✅ Todo functionality works (create, read, update, delete)
- ✅ Data persists after database service restart

---

This comprehensive guide covers every detail needed to deploy your 3-tier application on AWS ECS using the AWS Console UI! 🚀
