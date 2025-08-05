# UI-Based ECS Fargate Setup Guide for 3-Tier Application

This guide will walk you through setting up your 3-tier application (Frontend + Backend + PostgreSQL) on AWS ECS Fargate using the AWS Management Console (UI).

## Architecture Overview

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → PostgreSQL (RDS)
```

## Prerequisites

- AWS Account with appropriate permissions
- Docker images built and pushed to ECR (instructions included)
- Basic knowledge of AWS services

---

## Step 1: Create VPC and Networking

### 1.1 Create VPC

1. **Go to VPC Console**
   - Open AWS Console → VPC → Your VPCs
   - Click "Create VPC"

2. **Configure VPC**
   - **VPC name**: `ecs-vpc`
   - **IPv4 CIDR block**: `10.0.0.0/16`
   - **IPv6 CIDR block**: No IPv6 CIDR block
   - **Tenancy**: Default
   - Click "Create VPC"

3. **Note the VPC ID** (e.g., `vpc-xxxxxxxxx`)

### 1.2 Create Subnets

#### Create Public Subnets

1. **Go to Subnets**
   - VPC Console → Subnets → Create subnet

2. **Create Public Subnet 1**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1a`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - Click "Create subnet"

3. **Create Public Subnet 2**
   - **VPC**: Select `ecs-vpc`
   - **Subnet name**: `ecs-public-subnet-1b`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - Click "Create subnet"

#### Create Private Subnets

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

### 1.3 Create Internet Gateway

1. **Go to Internet Gateways**
   - VPC Console → Internet Gateways → Create internet gateway

2. **Configure IGW**
   - **Name tag**: `ecs-igw`
   - Click "Create internet gateway"

3. **Attach to VPC**
   - Select the created IGW
   - Click "Actions" → "Attach to VPC"
   - Select `ecs-vpc`
   - Click "Attach internet gateway"

### 1.4 Create Route Tables

#### Create Public Route Table

1. **Go to Route Tables**
   - VPC Console → Route Tables → Create route table

2. **Configure Route Table**
   - **Name**: `ecs-public-rt`
   - **VPC**: Select `ecs-vpc`
   - Click "Create route table"

3. **Add Route to Internet**
   - Select the created route table
   - Click "Routes" tab → "Edit routes"
   - Click "Add route"
   - **Destination**: `0.0.0.0/0`
   - **Target**: Internet Gateway → Select your IGW
   - Click "Save changes"

4. **Associate Public Subnets**
   - Click "Subnet associations" tab → "Edit subnet associations"
   - Select both public subnets (`ecs-public-subnet-1a`, `ecs-public-subnet-1b`)
   - Click "Save associations"

#### Enable Auto-assign Public IP

1. **For each public subnet**:
   - Go to Subnets → Select the subnet
   - Click "Actions" → "Modify auto-assign IP settings"
   - Check "Enable auto-assign public IPv4 address"
   - Click "Save"

---

## Step 2: Create Security Groups

### 2.1 Create ALB Security Group

1. **Go to Security Groups**
   - VPC Console → Security Groups → Create security group

2. **Configure ALB Security Group**
   - **Security group name**: `ecs-alb-sg`
   - **Description**: `Security group for ALB`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

3. **Add Inbound Rules**
   - Select the security group → "Inbound rules" → "Edit inbound rules"
   - Click "Add rule"
   - **Type**: HTTP
   - **Source**: Anywhere-IPv4 (0.0.0.0/0)
   - Click "Add rule"
   - **Type**: HTTPS
   - **Source**: Anywhere-IPv4 (0.0.0.0/0)
   - Click "Save rules"

### 2.2 Create Frontend Security Group

1. **Create Security Group**
   - **Security group name**: `ecs-frontend-sg`
   - **Description**: `Security group for frontend`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: HTTP
   - **Source**: Custom → Select `ecs-alb-sg`
   - Click "Save rules"

### 2.3 Create Backend Security Group

1. **Create Security Group**
   - **Security group name**: `ecs-backend-sg`
   - **Description**: `Security group for backend`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: Custom TCP
   - **Port**: 4000
   - **Source**: Custom → Select `ecs-frontend-sg`
   - Click "Save rules"

### 2.4 Create Database Security Group

1. **Create Security Group**
   - **Security group name**: `ecs-db-sg`
   - **Description**: `Security group for database`
   - **VPC**: Select `ecs-vpc`
   - Click "Create security group"

2. **Add Inbound Rules**
   - **Type**: PostgreSQL
   - **Port**: 5432
   - **Source**: Custom → Select `ecs-backend-sg`
   - Click "Save rules"

---

## Step 3: Create RDS PostgreSQL Database

### 3.1 Create DB Subnet Group

1. **Go to RDS Console**
   - AWS Console → RDS → Subnet groups → Create DB subnet group

2. **Configure Subnet Group**
   - **Name**: `ecs-db-subnet-group`
   - **Description**: `Subnet group for ECS database`
   - **VPC**: Select `ecs-vpc`
   - **Availability Zones**: Select both AZs
   - **Subnets**: Select both private subnets
   - Click "Create"

### 3.2 Create Database Credentials in Secrets Manager

1. **Go to Secrets Manager**
   - AWS Console → Secrets Manager → Store a new secret

2. **Configure Secret**
   - **Secret type**: Other type of secret
   - **Key/value pairs**:
     ```
     username: ecsuser
     password: YourSecurePassword123!
     engine: postgres
     host: ecs-db.xxxxxxxxx.us-east-1.rds.amazonaws.com
     port: 5432
     dbname: ecsdb
     ```
   - **Secret name**: `ecs/database/credentials`
   - **Description**: `Database credentials for ECS application`
   - Click "Next" → "Next" → "Store"

3. **Note the Secret ARN** (you'll need this later)

### 3.3 Create RDS Instance

1. **Go to RDS Console**
   - AWS Console → RDS → Databases → Create database

2. **Choose Database Creation Method**
   - **Standard create**
   - Click "Next"

3. **Configure Database**
   - **Engine type**: PostgreSQL
   - **Version**: PostgreSQL 15.x (latest)
   - **Template**: Free tier (or Production for better performance)

4. **Settings**
   - **DB instance identifier**: `ecs-db`
   - **Master username**: `ecsuser`
   - **Master password**: `YourSecurePassword123!`

5. **Instance Configuration**
   - **DB instance class**: `db.t3.micro` (or larger for production)
   - **Storage**: 20 GB
   - **Storage type**: General Purpose SSD (gp2)

6. **Connectivity**
   - **VPC**: Select `ecs-vpc`
   - **Subnet group**: Select `ecs-db-subnet-group`
   - **Publicly accessible**: Yes
   - **VPC security groups**: Select `ecs-db-sg`
   - **Availability Zone**: No preference
   - **Database port**: 5432

7. **Database Authentication**
   - **Database authentication options**: Password authentication

8. **Additional Configuration**
   - **Initial database name**: `ecsdb`
   - **Backup retention period**: 7 days
   - **Backup window**: 03:00-04:00
   - **Maintenance window**: sun:04:00-sun:05:00
   - **Enable encryption**: Yes

9. **Click "Create database"**

10. **Wait for database to be available** (this may take 5-10 minutes)

11. **Note the database endpoint** from the database details page

---

## Step 4: Create ECR Repositories

### 4.1 Create Frontend Repository

1. **Go to ECR Console**
   - AWS Console → ECR → Repositories → Create repository

2. **Configure Repository**
   - **Repository name**: `ecs-frontend`
   - **Tag immutability**: Enable tag immutability
   - **Scan on push**: Enable scan on push
   - Click "Create repository"

### 4.2 Create Backend Repository

1. **Create Repository**
   - **Repository name**: `ecs-backend`
   - **Tag immutability**: Enable tag immutability
   - **Scan on push**: Enable scan on push
   - Click "Create repository"

### 4.3 Build and Push Docker Images

#### Build Frontend Image

1. **Open Terminal/Command Prompt**
2. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

3. **Build and push image**
   ```bash
   # Get ECR login token
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.us-east-1.amazonaws.com

   # Build image
   docker build -t ecs-frontend .

   # Tag image
   docker tag ecs-frontend:latest <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest

   # Push image
   docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest
   ```

#### Build Backend Image

1. **Navigate to backend directory**
   ```bash
   cd ../backend
   ```

2. **Build and push image**
   ```bash
   # Build image
   docker build -t ecs-backend .

   # Tag image
   docker tag ecs-backend:latest <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest

   # Push image
   docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest
   ```

---

## Step 5: Create ECS Cluster

### 5.1 Create Cluster

1. **Go to ECS Console**
   - AWS Console → ECS → Clusters → Create cluster

2. **Configure Cluster**
   - **Cluster name**: `ecs-app-cluster`
   - **Networking VPC**: Select `ecs-vpc`
   - **Cluster type**: Networking only (for Fargate)
   - Click "Create"

---

## Step 6: Create IAM Roles

### 6.1 Create ECS Task Execution Role

1. **Go to IAM Console**
   - AWS Console → IAM → Roles → Create role

2. **Configure Role**
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
   - Click "Next"

3. **Attach Policies**
   - Search and select: `AmazonECSTaskExecutionRolePolicy`
   - Search and select: `SecretsManagerReadWrite`
   - Click "Next"

4. **Role Details**
   - **Role name**: `ecsTaskExecutionRole`
   - **Description**: `ECS Task Execution Role for ECS tasks`
   - Click "Create role"

### 6.2 Create ECS Task Role

1. **Create Role**
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
   - Click "Next"

2. **Attach Policies**
   - Search and select: `SecretsManagerReadWrite`
   - Click "Next"

3. **Role Details**
   - **Role name**: `ecsTaskRole`
   - **Description**: `ECS Task Role for application permissions`
   - Click "Create role"

---

## Step 7: Create Task Definitions

### 7.1 Create Backend Task Definition

1. **Go to ECS Console**
   - ECS → Task Definitions → Create new Task Definition

2. **Configure Task Definition**
   - **Task Definition Name**: `ecs-backend-task`
   - **Requires compatibilities**: FARGATE
   - **Task role**: Select `ecsTaskRole`
   - **Task execution role**: Select `ecsTaskExecutionRole`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 (.25 vCPU)
   - Click "Next"

3. **Configure Container**
   - **Container name**: `backend`
   - **Image URI**: `<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest`
   - **Port mappings**: 4000
   - **Essential**: Yes

4. **Environment Variables**
   - Add the following:
     - **NODE_ENV**: `production`
     - **POSTGRES_DB**: `ecsdb`
     - **POSTGRES_HOST**: `<your-database-endpoint>`
     - **POSTGRES_PORT**: `5432`

5. **Secrets**
   - Add the following:
     - **POSTGRES_USER**: Select your secret ARN, key: `username`
     - **POSTGRES_PASSWORD**: Select your secret ARN, key: `password`

6. **Log Configuration**
   - **Log driver**: awslogs
   - **Log group**: `/ecs/backend`
   - **Region**: `us-east-1`
   - **Stream prefix**: `ecs`

7. **Health Check**
   - **Command**: `["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]`
   - **Interval**: 30 seconds
   - **Timeout**: 5 seconds
   - **Retries**: 3
   - **Start period**: 60 seconds

8. **Click "Next" → "Create"**

### 7.2 Create Frontend Task Definition

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
   - Add the following:
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

## Step 8: Create Application Load Balancer

### 8.1 Create ALB

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
   - Skip for now (targets will be registered by ECS)
   - Click "Next: Review"

8. **Review and Create**
   - Review settings
   - Click "Create"

### 8.2 Create Backend Target Group

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

### 8.3 Configure ALB Listeners

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

## Step 9: Create ECS Services

### 9.1 Create Backend Service

1. **Go to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services → Create

2. **Configure Service**
   - **Launch type**: FARGATE
   - **Task Definition**: Select `ecs-backend-task`
   - **Service name**: `ecs-backend-service`
   - **Number of tasks**: 2
   - Click "Next step"

3. **Configure Network**
   - **VPC**: Select `ecs-vpc`
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled
   - Click "Next step"

4. **Configure Load Balancer**
   - **Load balancer type**: Application Load Balancer
   - **Service IAM role**: Create new role
   - **Load balancer name**: Select `ecs-alb`
   - **Target group name**: Select `ecs-backend-tg`
   - **Container name**: `backend`
   - **Container port**: 4000
   - Click "Next step"

5. **Configure Auto Scaling**
   - Skip for now
   - Click "Next step"

6. **Review and Create**
   - Review settings
   - Click "Create service"

### 9.2 Create Frontend Service

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

## Step 10: Create CloudWatch Log Groups

### 10.1 Create Log Groups

1. **Go to CloudWatch Console**
   - AWS Console → CloudWatch → Log groups → Create log group

2. **Create Frontend Log Group**
   - **Log group name**: `/ecs/frontend`
   - Click "Create"

3. **Create Backend Log Group**
   - **Log group name**: `/ecs/backend`
   - Click "Create"

---

## Step 11: Test the Application

### 11.1 Get ALB DNS Name

1. **Go to Load Balancers**
   - EC2 Console → Load Balancers
   - Select your ALB
   - Copy the DNS name from the "Description" tab

### 11.2 Test Health Endpoints

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

## Step 12: Monitoring and Troubleshooting

### 12.1 Check Service Status

1. **Go to ECS Console**
   - ECS → Clusters → `ecs-app-cluster` → Services
   - Check service status and running tasks

### 12.2 View Logs

1. **Go to CloudWatch Console**
   - CloudWatch → Log groups
   - Select `/ecs/frontend` or `/ecs/backend`
   - Click on log streams to view logs

### 12.3 Check Target Health

1. **Go to Target Groups**
   - EC2 Console → Target Groups
   - Select target group
   - Check "Targets" tab for health status

---

## Common Issues and Solutions

### 1. Tasks Not Starting
- **Check**: IAM roles and permissions
- **Solution**: Verify task execution role has Secrets Manager access

### 2. Database Connection Failed
- **Check**: Security group rules and database endpoint
- **Solution**: Verify backend security group allows traffic to database

### 3. Frontend Not Loading
- **Check**: ALB health checks and nginx configuration
- **Solution**: Verify health check path and container logs

### 4. Backend API Errors
- **Check**: Database connectivity and environment variables
- **Solution**: Review backend logs and Secrets Manager configuration

---

## Cleanup (Optional)

To clean up all resources:

1. **Delete ECS Services**
   - ECS → Services → Update desired count to 0
   - Delete services

2. **Delete Load Balancer**
   - EC2 → Load Balancers → Delete ALB

3. **Delete Target Groups**
   - EC2 → Target Groups → Delete target groups

4. **Delete RDS Instance**
   - RDS → Databases → Delete database

5. **Delete ECR Repositories**
   - ECR → Repositories → Delete repositories

6. **Delete Secrets**
   - Secrets Manager → Delete secret

7. **Delete VPC**
   - VPC → Delete VPC (will delete all associated resources)

---

## Notes

1. **Security**: Backend runs in private subnets, accessible only through frontend
2. **Scalability**: Services configured with 2 tasks each for high availability
3. **Secrets Management**: Database credentials securely stored in Secrets Manager
4. **Health Checks**: Both frontend and backend have health checks configured
5. **Logging**: All container logs sent to CloudWatch Logs

This setup provides a production-ready 3-tier application with proper security, scalability, and monitoring capabilities. 