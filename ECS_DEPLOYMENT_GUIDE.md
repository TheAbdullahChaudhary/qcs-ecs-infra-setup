# Complete ECS Deployment Guide with Dockerized Database

This guide will walk you through deploying your 3-tier application on AWS ECS Fargate with a dockerized PostgreSQL database, proper volume mounting, and secure communication between services.

## Architecture Overview

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → PostgreSQL (Private Subnet)
                                                                    ↓
                                                              EFS Volume (Persistent Storage)
```

## Prerequisites

- AWS Account with appropriate permissions
- Docker installed locally
- AWS CLI configured
- Basic knowledge of AWS services

---

## Step 1: Local Testing

### 1.1 Test Application Locally

1. **Build and test locally first**:
   ```bash
   # Navigate to project directory
   cd 3-tier-app

   # Build and start all services
   docker-compose up --build

   # Test the application
   # Frontend: http://localhost
   # Backend API: http://localhost:4000
   # Database: localhost:5432
   ```

2. **Verify all services are working**:
   - Frontend shows status indicators
   - Backend health check returns success
   - Database connection is established
   - Todo CRUD operations work

---

## Step 2: Create VPC and Networking

### 2.1 Create VPC

1. **Go to VPC Console**
   - AWS Console → VPC → Your VPCs
   - Click "Create VPC"

2. **Configure VPC**
   - **VPC name**: `ecs-vpc`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **IPv6 CIDR block**: No IPv6 CIDR block
   - **Tenancy**: Default
   - Click "Create VPC"

### 2.2 Create Subnets

#### Public Subnets (for ALB and Frontend)
1. **Create Public Subnet 1**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1a`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - Click "Create subnet"

2. **Create Public Subnet 2**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1b`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - Click "Create subnet"

#### Private Subnets (for Backend and Database)
1. **Create Private Subnet 1**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-private-subnet-1a`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.3.0/24`
   - Click "Create subnet"

2. **Create Private Subnet 2**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-private-subnet-1b`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.4.0/24`
   - Click "Create subnet"

### 2.3 Create Internet Gateway

1. **Create IGW**
   - VPC Console → Internet Gateways → Create internet gateway
   - **Name tag**: `ecs-igw`
   - Click "Create internet gateway"

2. **Attach to VPC**
   - Select the IGW → Actions → Attach to VPC
   - Select `ecs-vpc` → Click "Attach internet gateway"

### 2.4 Create Route Tables

#### Public Route Table
1. **Create Route Table**
   - VPC Console → Route Tables → Create route table
   - **Name**: `ecs-public-rt`
   - **VPC**: Select `ecs-vpc`
   - Click "Create route table"

2. **Add Internet Route**
   - Select route table → Routes → Edit routes
   - Add route: Destination `0.0.0.0/0`, Target: Internet Gateway
   - Click "Save changes"

3. **Associate Public Subnets**
   - Subnet associations → Edit subnet associations
   - Select both public subnets
   - Click "Save associations"

#### Enable Auto-assign Public IP
- For each public subnet: Actions → Modify auto-assign IP settings → Enable

---

## Step 3: Create EFS File System

### 3.1 Create EFS File System

1. **Go to EFS Console**
   - AWS Console → EFS → File systems → Create file system

2. **Configure File System**
   - **Name**: `ecs-db-storage`
   - **VPC**: Select `ecs-vpc`
   - **Availability and durability**: Regional
   - Click "Create"

### 3.2 Create Mount Targets

1. **Create Mount Target 1**
   - Select file system → Network → Create mount target
   - **Subnet**: Select `ecs-private-subnet-1a`
   - **Security groups**: Create new security group `ecs-efs-sg`
   - Click "Create mount target"

2. **Create Mount Target 2**
   - **Subnet**: Select `ecs-private-subnet-1b`
   - **Security groups**: Select `ecs-efs-sg`
   - Click "Create mount target"

### 3.3 Configure EFS Security Group

1. **Create EFS Security Group**
   - VPC Console → Security Groups → Create security group
   - **Security group name**: `ecs-efs-sg`
   - **Description**: `Security group for EFS`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: NFS
   - **Source**: Custom → Select `ecs-db-sg`
   - Click "Save rules"

---

## Step 4: Create Security Groups

### 4.1 ALB Security Group
1. **Create Security Group**
   - **Security group name**: `ecs-alb-sg`
   - **Description**: `Security group for ALB`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: HTTP, Source: Anywhere-IPv4
   - **Type**: HTTPS, Source: Anywhere-IPv4
   - Click "Save rules"

### 4.2 Frontend Security Group
1. **Create Security Group**
   - **Security group name**: `ecs-frontend-sg`
   - **Description**: `Security group for frontend`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: HTTP, Source: Custom → Select `ecs-alb-sg`
   - Click "Save rules"

### 4.3 Backend Security Group
1. **Create Security Group**
   - **Security group name**: `ecs-backend-sg`
   - **Description**: `Security group for backend`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: Custom TCP, Port: 4000, Source: Custom → Select `ecs-frontend-sg`
   - Click "Save rules"

### 4.4 Database Security Group
1. **Create Security Group**
   - **Security group name**: `ecs-db-sg`
   - **Description**: `Security group for database`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: PostgreSQL, Source: Custom → Select `ecs-backend-sg`
   - Click "Save rules"

---

## Step 5: Create ECR Repositories

### 5.1 Create Repositories

1. **Frontend Repository**
   - ECR Console → Repositories → Create repository
   - **Repository name**: `ecs-frontend`
   - **Tag immutability**: Enable
   - **Scan on push**: Enable
   - Click "Create repository"

2. **Backend Repository**
   - **Repository name**: `ecs-backend`
   - **Tag immutability**: Enable
   - **Scan on push**: Enable
   - Click "Create repository"

3. **Database Repository**
   - **Repository name**: `ecs-database`
   - **Tag immutability**: Enable
   - **Scan on push**: Enable
   - Click "Create repository"

### 5.2 Build and Push Images

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push frontend
cd frontend
docker build -t ecs-frontend .
docker tag ecs-frontend:latest <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest

# Build and push backend
cd ../backend
docker build -t ecs-backend .
docker tag ecs-backend:latest <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest

# Build and push database
cd ../database
docker build -t ecs-database .
docker tag ecs-database:latest <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest
```

---

## Step 6: Create ECS Cluster

### 6.1 Create Cluster

1. **Go to ECS Console**
   - AWS Console → ECS → Clusters → Create cluster

2. **Configure Cluster**
   - **Cluster name**: `ecs-app-cluster`
   - **Networking VPC**: Select `ecs-vpc`
   - **Cluster type**: Networking only (for Fargate)
   - Click "Create"

---

## Step 7: Create IAM Roles

### 7.1 ECS Task Execution Role

1. **Go to IAM Console**
   - AWS Console → IAM → Roles → Create role

2. **Configure Role**
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
   - Click "Next"

3. **Attach Policies**
   - `AmazonECSTaskExecutionRolePolicy`
   - `SecretsManagerReadWrite`
   - Click "Next"

4. **Role Details**
   - **Role name**: `ecsTaskExecutionRole`
   - Click "Create role"

### 7.2 ECS Task Role

1. **Create Role**
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
   - Click "Next"

2. **Attach Policies**
   - `SecretsManagerReadWrite`
   - Click "Next"

3. **Role Details**
   - **Role name**: `ecsTaskRole`
   - Click "Create role"

---

## Step 8: Create Task Definitions

### 8.1 Database Task Definition

1. **Go to ECS Console**
   - ECS → Task Definitions → Create new Task Definition

2. **Configure Task Definition**
   - **Task Definition Name**: `ecs-database-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskRole`
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 1024 MB
   - **Task CPU**: 512 (.5 vCPU)
   - Click "Next"

3. **Configure Container**
   - **Container name**: `database`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest`
   - **Port mappings**: 5432
   - **Essential**: Yes

4. **Environment Variables**
   - **POSTGRES_DB**: `ecsdb`
   - **POSTGRES_USER**: `ecsuser`
   - **POSTGRES_PASSWORD**: `ecspassword`

5. **Mount Points**
   - **Source volume**: `database-storage`
   - **Container path**: `/var/lib/postgresql/data`
   - **Read only**: No

6. **Log Configuration**
   - **Log driver**: awslogs
   - **Log group**: `/ecs/database`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

7. **Health Check**
   - **Command**: `["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

8. **Volumes**
   - **Name**: `database-storage`
   - **Volume type**: EFS
   - **File system ID**: Select your EFS file system
   - **Root directory**: `/`
   - **Transit encryption**: Enable

9. **Click "Next" → "Create"**

### 8.2 Backend Task Definition

1. **Create New Task Definition**
   - **Task Definition Name**: `ecs-backend-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskRole`
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)
   - Click "Next"

2. **Configure Container**
   - **Container name**: `backend`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest`
   - **Port mappings**: 4000
   - **Essential**: Yes

3. **Environment Variables**
   - **NODE_ENV**: `production`
   - **POSTGRES_DB**: `ecsdb`
   - **POSTGRES_HOST**: `database`
   - **POSTGRES_PORT**: `5432`
   - **POSTGRES_USER**: `ecsuser`
   - **POSTGRES_PASSWORD**: `ecspassword`

4. **Log Configuration**
   - **Log driver**: awslogs
   - **Log group**: `/ecs/backend`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

5. **Health Check**
   - **Command**: `["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

6. **Click "Next" → "Create"**

### 8.3 Frontend Task Definition

1. **Create New Task Definition**
   - **Task Definition Name**: `ecs-frontend-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)
   - Click "Next"

2. **Configure Container**
   - **Container name**: `frontend`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest`
   - **Port mappings**: 80
   - **Essential**: Yes

3. **Environment Variables**
   - **REACT_APP_API_URL**: `/api`

4. **Log Configuration**
   - **Log driver**: awslogs
   - **Log group**: `/ecs/frontend`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

5. **Health Check**
   - **Command**: `["CMD-SHELL", "curl -f http://localhost/health || exit 1"]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

6. **Click "Next" → "Create"**

---

## Step 9: Create Application Load Balancer

### 9.1 Create ALB

1. **Go to EC2 Console**
   - AWS Console → EC2 → Load Balancers → Create load balancer

2. **Choose Load Balancer Type**
   - **Application Load Balancer**
   - Click "Create"

3. **Configure Load Balancer**
   - **Name**: `ecs-alb`
   - **Scheme**: internet-facing
   - **IP address type**: ipv4
   - **VPC**: Select `ecs-vpc`
   - **Mappings**: Select both public subnets

4. **Configure Security Groups**
   - **Security groups**: Select `ecs-alb-sg`
   - Click "Next: Configure Security Settings"

5. **Security Settings**
   - Click "Next: Configure Routing"

6. **Configure Routing**
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
   - Click "Next: Register Targets"

7. **Register Targets**
   - Skip for now
   - Click "Next: Review"

8. **Review and Create**
   - Review settings
   - Click "Create"

### 9.2 Create Backend Target Group

1. **Go to Target Groups**
   - EC2 Console → Target Groups → Create target group

2. **Configure Target Group**
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
   - Click "Next: Register Targets"

3. **Register Targets**
   - Skip for now
   - Click "Create target group"

### 9.3 Configure ALB Listeners

1. **Go to Load Balancers**
   - Select your ALB → "Listeners" tab

2. **Edit Default Listener**
   - Click "Edit" on the existing listener
   - **Default action**: Forward to `ecs-frontend-tg`
   - Click "Save changes"

3. **Add Backend Listener Rule**
   - Click "Add listener"
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default action**: Forward to `ecs-backend-tg`
   - Click "Add listener"

---

## Step 10: Create ECS Services

### 10.1 Create Database Service

1. **Go to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services → Create

2. **Configure Service**
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-database-task`
   - **Service name**: `ecs-database-service`
   - **Number of tasks**: 1
   - Click "Next step"

3. **Configure Network**
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-db-sg`
   - **Auto-assign public IP**: Disabled
   - Click "Next step"

4. **Configure Load Balancer**
   - Skip load balancer configuration
   - Click "Next step"

5. **Configure Auto Scaling**
   - Skip for now
   - Click "Next step"

6. **Review and Create**
   - Review settings
   - Click "Create service"

### 10.2 Create Backend Service

1. **Create Service**
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-backend-task`
   - **Service name**: `ecs-backend-service`
   - **Number of tasks**: 2
   - Click "Next step"

2. **Configure Network**
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled
   - Click "Next step"

3. **Configure Load Balancer**
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Create new role
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-backend-tg`
   - **Container name**: `backend`
   - **Container port**: 4000
   - Click "Next step"

4. **Configure Auto Scaling**
   - Skip for now
   - Click "Next step"

5. **Review and Create**
   - Review settings
   - Click "Create service"

### 10.3 Create Frontend Service

1. **Create Service**
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-frontend-task`
   - **Service name**: `ecs-frontend-service`
   - **Number of tasks**: 2
   - Click "Next step"

2. **Configure Network**
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both public subnets
   - **Security groups**: Select `ecs-frontend-sg`
   - **Auto-assign public IP**: Enabled
   - Click "Next step"

3. **Configure Load Balancer**
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Use existing role (created for backend)
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-frontend-tg`
   - **Container name**: `frontend`
   - **Container port**: 80
   - Click "Next step"

4. **Configure Auto Scaling**
   - Skip for now
   - Click "Next step"

5. **Review and Create**
   - Review settings
   - Click "Create service"

---

## Step 11: Create CloudWatch Log Groups

### 11.1 Create Log Groups

1. **Go to CloudWatch Console**
   - AWS Console → CloudWatch → Log groups → Create log group

2. **Create Log Groups**
   - **Frontend**: `/ecs/frontend`
   - **Backend**: `/ecs/backend`
   - **Database**: `/ecs/database`
   - Click "Create" for each

---

## Step 12: Test the Application

### 12.1 Get ALB DNS Name

1. **Go to Load Balancers**
   - EC2 Console → Load Balancers
   - Select your ALB
   - Copy the DNS name from the "Description" tab

### 12.2 Test Health Endpoints

1. **Test Frontend Health**
   - Open browser: `http://<your-alb-dns>/health`
   - Should return "healthy"

2. **Test Backend Health**
   - Open browser: `http://<your-alb-dns>/api/health`
   - Should return JSON with status information

3. **Test Application**
   - Open browser: `http://<your-alb-dns>`
   - Should show the Todo application with status indicators

---

## Step 13: Monitoring and Troubleshooting

### 13.1 Check Service Status

1. **Go to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services
   - Check service status and running tasks

### 13.2 View Logs

1. **Go to CloudWatch Console**
   - CloudWatch → Log groups
   - Select log group and click on log streams

### 13.3 Check Target Health

1. **Go to Target Groups**
   - EC2 Console → Target Groups
   - Select target group
   - Check "Targets" tab for health status

---

## Common Issues and Solutions

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

---

## Cleanup

To clean up all resources:

1. **Delete ECS Services**
   - Update desired count to 0
   - Delete services

2. **Delete Load Balancer and Target Groups**
   - Delete ALB and target groups

3. **Delete ECR Repositories**
   - Delete all repositories

4. **Delete EFS File System**
   - Delete file system and mount targets

5. **Delete VPC**
   - Delete VPC (will delete all associated resources)

---

## Notes

1. **Database Persistence**: Data is stored in EFS volume for persistence
2. **Security**: All services run in private subnets except frontend
3. **Scalability**: Services can be scaled independently
4. **Monitoring**: All logs are centralized in CloudWatch
5. **High Availability**: Services run across multiple AZs

This setup provides a production-ready 3-tier application with persistent database storage, proper security, and scalability. 