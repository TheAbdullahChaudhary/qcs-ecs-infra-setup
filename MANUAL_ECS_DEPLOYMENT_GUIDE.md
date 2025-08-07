# Complete Manual ECS Deployment Guide
## 3-Tier Application: Frontend + Backend + Database

### 🎯 Overview
This guide provides step-by-step instructions to deploy your 3-tier application on AWS ECS using the AWS Console UI, without Terraform.

### 📋 Prerequisites
- AWS Account with appropriate permissions
- Docker images built and pushed to ECR
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
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - **Auto-assign public IPv4 address**: Yes
3. **Click "Create subnet"**

#### Public Subnet 2
1. **Create another subnet**:
   - **Subnet name**: `ecs-public-subnet-2`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - **Auto-assign public IPv4 address**: Yes

#### Private Subnet 1
1. **Create private subnet**:
   - **Subnet name**: `ecs-private-subnet-1`
   - **Availability Zone**: `us-east-1a`
   - **IPv4 CIDR block**: `10.0.11.0/24`
   - **Auto-assign public IPv4 address**: No

#### Private Subnet 2
1. **Create another private subnet**:
   - **Subnet name**: `ecs-private-subnet-2`
   - **Availability Zone**: `us-east-1b`
   - **IPv4 CIDR block**: `10.0.12.0/24`
   - **Auto-assign public IPv4 address**: No

### Step 1.3: Create Internet Gateway
1. **VPC Console** → Internet Gateways → Create internet gateway
2. **Configure**:
   - **Name tag**: `ecs-igw`
3. **Click "Create internet gateway"**
4. **Attach to VPC**:
   - Select the internet gateway
   - Click "Actions" → "Attach to VPC"
   - Select `ecs-vpc`
   - Click "Attach internet gateway"

### Step 1.4: Create NAT Gateway
1. **VPC Console** → NAT Gateways → Create NAT gateway
2. **Configure**:
   - **Name**: `ecs-nat-gateway`
   - **Subnet**: Select `ecs-public-subnet-1`
   - **Elastic IP allocation ID**: Create new EIP
3. **Click "Create NAT gateway"**

### Step 1.5: Create Route Tables

#### Public Route Table
1. **VPC Console** → Route Tables → Create route table
2. **Configure**:
   - **Name**: `ecs-public-rt`
   - **VPC**: Select `ecs-vpc`
3. **Click "Create route table"**
4. **Add route**:
   - Click "Edit routes"
   - Add route: `0.0.0.0/0` → Internet Gateway
   - Click "Save routes"
5. **Associate subnets**:
   - Click "Subnet associations"
   - Associate both public subnets

#### Private Route Table
1. **Create another route table**:
   - **Name**: `ecs-private-rt`
   - **VPC**: Select `ecs-vpc`
2. **Add route**:
   - Add route: `0.0.0.0/0` → NAT Gateway
3. **Associate subnets**:
   - Associate both private subnets

---

## Phase 2: Security Groups Setup

### Step 2.1: ALB Security Group
1. **VPC Console** → Security Groups → Create security group
2. **Configure**:
   - **Name**: `ecs-alb-sg`
   - **Description**: Security group for ALB
   - **VPC**: Select `ecs-vpc`
3. **Inbound rules**:
   - **Type**: HTTP, **Port**: 80, **Source**: 0.0.0.0/0
   - **Type**: HTTPS, **Port**: 443, **Source**: 0.0.0.0/0
4. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0
5. **Click "Create security group"**

### Step 2.2: Frontend Security Group
1. **Create security group**:
   - **Name**: `ecs-frontend-sg`
   - **Description**: Security group for frontend
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: HTTP, **Port**: 80, **Source**: ALB security group
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0

### Step 2.3: Backend Security Group
1. **Create security group**:
   - **Name**: `ecs-backend-sg`
   - **Description**: Security group for backend
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: Custom TCP, **Port**: 4000, **Source**: ALB security group
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0

### Step 2.4: Database Security Group
1. **Create security group**:
   - **Name**: `ecs-database-sg`
   - **Description**: Security group for database
   - **VPC**: Select `ecs-vpc`
2. **Inbound rules**:
   - **Type**: PostgreSQL, **Port**: 5432, **Source**: Backend security group
3. **Outbound rules**:
   - **Type**: All traffic, **Destination**: 0.0.0.0/0

---

## Phase 3: EFS File System Setup

### Step 3.1: Create EFS File System
1. **EFS Console** → Create file system
2. **Configure**:
   - **Name**: `ecs-database-efs`
   - **VPC**: Select `ecs-vpc`
   - **Availability and durability**: One Zone
   - **Availability Zone**: `us-east-1a`
3. **Click "Create"**

### Step 3.2: Create Access Point
1. **Select the EFS file system** → Access points → Create access point
2. **Configure**:
   - **Name**: `ecs-database-ap`
   - **User ID**: 1000
   - **Group ID**: 1000
   - **Root directory path**: `/`
   - **Owner user ID**: 1000
   - **Owner group ID**: 1000
   - **Permissions**: 755
3. **Click "Create access point"**

---

## Phase 4: IAM Roles Setup

### Step 4.1: ECS Task Execution Role
1. **IAM Console** → Roles → Create role
2. **Configure**:
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
3. **Attach policies**:
   - `AmazonECSTaskExecutionRolePolicy`
4. **Role name**: `ecs-task-execution-role`

### Step 4.2: ECS Task Role (with EFS Access)
1. **Create a custom policy**:
   - **Name**: `elasticfilesystem-ClientRootAccess`
   - **Policy JSON**:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "elasticfilesystem:ClientMount",
             "elasticfilesystem:ClientWrite"
           ],
           "Resource": "arn:aws:elasticfilesystem:eu-west-1:941377128979:file-system/fs-0c0ff6ec7511fc458"
         }
       ]
     }
     ```
2. **IAM Console** → Roles → Create role
3. **Configure**:
   - **Trusted entity**: AWS service
   - **Service**: ECS
   - **Use case**: ECS - Task
4. **Attach policies**:
   - Attach your custom policy: `elasticfilesystem-ClientRootAccess`
5. **Role name**: `ecs-task-role`
6. **Create the role**

---

## Phase 5: CloudWatch Log Groups

### Step 5.1: Create Log Groups
1. **CloudWatch Console** → Log groups → Create log group
2. **Create three log groups**:
   - **Name**: `/ecs/frontend`
   - **Name**: `/ecs/backend`
   - **Name**: `/ecs/database`
3. **Retention**: 7 days

---

## Phase 6: ECS Cluster Setup

### Step 6.1: Create ECS Cluster
1. **ECS Console** → Clusters → Create cluster
2. **Configure**:
   - **Cluster name**: `3-tier-ecs-cluster`
   - **Note:** In the new ECS Console, you **do not select a VPC at this step**. The cluster is just a logical grouping. You will select the VPC and subnets when you create each ECS service.
3. **Click "Create"**

---

## Phase 7: Service Discovery Setup

### What is a Namespace?
A namespace in AWS Cloud Map is a logical container for service names. It enables ECS services to discover and communicate with each other using DNS names (e.g., `ecs-database-service.ecs.internal`). This is essential for dynamic environments like ECS, where IP addresses change frequently. By creating a namespace, you enable reliable, DNS-based service discovery for your application components.

### Step 7.1: Create Private DNS Namespace
1. **Cloud Map Console** → Namespaces → Create namespace
2. **Configure**:
   - **Namespace name**: `ecs.internal`
   - **Description**: Private DNS namespace for ECS services
   - **Instance discovery**: **Select 'API calls and DNS queries in VPCs'** (this is required for a Private DNS namespace and will make the VPC selection field appear)
   - **VPC**: Select your VPC (e.g., `ecs-vpc`).
   - **Note:** If you do not see the VPC field, make sure you have selected 'API calls and DNS queries in VPCs'. If it still does not appear, try refreshing the page, using a different browser, or checking your IAM permissions.
3. **Click "Create namespace"**
4. **Result:** Your namespace (e.g., `ecs.internal`) is now created and ready to use. You can now register services (like your database) in this namespace, which will allow other ECS services to discover them by DNS name.

### Step 7.2: Create Database Service (Service Discovery Registration)
1. **Cloud Map Console** → Services → Create service
2. **Configure**:
   - **Service name**: `ecs-database-service`
   - **Namespace**: Select `ecs.internal`
   - **DNS configuration**:
     - **TTL**: 10
     - **Routing policy**: Multivalue
   - **Health check**: Custom configuration
     - **Failure threshold**: 1
3. **Click "Create service"**
4. **Result:** This step registers a DNS name (e.g., `ecs-database-service.ecs.internal`) for your database. When you create your ECS service for the database, it will register running tasks with this DNS name, enabling other services (like your backend) to connect using the name instead of an IP address.

---

## Phase 8: Application Load Balancer Setup

### What is an Application Load Balancer (ALB)?
An ALB distributes incoming application traffic across multiple ECS tasks (containers) to ensure high availability and scalability. It supports path-based routing, health checks, and integrates with ECS services. In this setup, the ALB routes `/api/*` requests to the backend service and all other requests to the frontend service.

### Step 8.1: Create ALB
1. **EC2 Console** → Load Balancers → Create load balancer
2. **Configure**:
   - **Load balancer type**: Application Load Balancer
   - **Name**: `ecs-alb`
   - **Scheme**: Internet-facing
   - **IP address type**: IPv4
   - **VPC**: Select `ecs-vpc`
   - **Mappings**: Select both public subnets
   - **Security groups**: Select `ecs-alb-sg`
3. **Click "Create load balancer"**

### Step 8.2: Create Target Groups

#### Frontend Target Group
1. **EC2 Console** → Target Groups → Create target group
2. **Configure**:
   - **Target type**: IP addresses
   - **Protocol**: HTTP
   - **Port**: 80
   - **VPC**: Select `ecs-vpc`
   - **Health check**:
     - **Protocol**: HTTP
     - **Path**: `/health`
     - **Port**: traffic-port
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 2
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
3. **Click "Create target group"**

#### Backend Target Group
1. **Create another target group**:
   - **Target type**: IP addresses
   - **Protocol**: HTTP
   - **Port**: 4000
   - **VPC**: Select `ecs-vpc`
   - **Health check**:
     - **Protocol**: HTTP
     - **Path**: `/health`
     - **Port**: traffic-port
     - **Healthy threshold**: 2
     - **Unhealthy threshold**: 2
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds

### Step 8.3: Create Listeners

#### Default Listener
1. **Select ALB** → Listeners → Create listener
2. **Configure**:
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default action**: Forward to frontend target group
3. **Click "Create listener"**

#### Backend Listener Rule
1. **Select the listener** → Rules → Create rule
2. **Configure**:
   - **Priority**: 100
   - **IF**: Path is `/api/*`
   - **THEN**: Forward to backend target group
3. **Click "Create rule"**

---

## Phase 9: ECS Task Definitions

### What is a Task Definition?
A task definition is the blueprint for your containerized application. It specifies the Docker image, environment variables, ports, resource requirements, IAM roles, and other settings needed to run your application in ECS. You must create a task definition before you can launch an ECS service.

### Step 9.1: Database Task Definition
1. **ECS Console** → Task Definitions → Create new task definition
2. **Configure**:
   - **Task definition name**: `ecs-database-task`
   - **Task role**: `ecs-task-role`
   - **Task execution role**: `ecs-task-execution-role`
   - **Task memory**: 1024 MB
   - **Task CPU**: 512 vCPU
3. **Add container**:
   - **Container name**: `database`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest`
   - **Port mappings**: 5432:5432
   - **Environment variables**:
     - `POSTGRES_DB`: `ecsdb`
     - `POSTGRES_USER`: `ecsuser`
     - `POSTGRES_PASSWORD`: `ecspassword`
   - **Log configuration**:
     - **Log driver**: awslogs
     - **Log group**: `/ecs/database`
     - **Region**: us-east-1
     - **Stream prefix**: ecs
   - **Health check**:
     - **Command**: `["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
4. **Click "Create"**

### Step 9.2: Backend Task Definition
1. **Create new task definition**:
   - **Task definition name**: `ecs-backend-task`
   - **Task role**: `ecs-task-role`
   - **Task execution role**: `ecs-task-execution-role`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 vCPU
2. **Add container**:
   - **Container name**: `backend`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest`
   - **Port mappings**: 4000:4000
   - **Environment variables**:
     - `NODE_ENV`: `production`
     - `POSTGRES_DB`: `ecsdb`
     - `POSTGRES_HOST`: `ecs-database-service.ecs.internal`
     - `POSTGRES_PORT`: `5432`
     - `POSTGRES_USER`: `ecsuser`
     - `POSTGRES_PASSWORD`: `ecspassword`
   - **Log configuration**:
     - **Log driver**: awslogs
     - **Log group**: `/ecs/backend`
     - **Region**: us-east-1
     - **Stream prefix**: ecs
   - **Health check**:
     - **Command**: `["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
3. **Click "Create"**

### Step 9.3: Frontend Task Definition
1. **Create new task definition**:
   - **Task definition name**: `ecs-frontend-task`
   - **Task execution role**: `ecs-task-execution-role`
   - **Task memory**: 512 MB
   - **Task CPU**: 256 vCPU
2. **Add container**:
   - **Container name**: `frontend`
   - **Image**: `941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest`
   - **Port mappings**: 80:80
   - **Environment variables**:
     - `REACT_APP_API_URL`: `http://[ALB-DNS-NAME]/api`
   - **Log configuration**:
     - **Log driver**: awslogs
     - **Log group**: `/ecs/frontend`
     - **Region**: us-east-1
     - **Stream prefix**: ecs
   - **Health check**:
     - **Command**: `["CMD-SHELL", "curl -f http://localhost/health || exit 1"]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
3. **Click "Create"**

---

## Phase 10: ECS Services

### What is an ECS Service?
An ECS service is responsible for running and maintaining a specified number of instances (tasks) of a task definition. It ensures that the desired number of tasks are always running, restarts failed tasks, and integrates with load balancers and service discovery. When you create a service, you specify the task definition, networking, and (optionally) service discovery and load balancing settings.

### Step 10.1: Database Service
1. **ECS Console** → Clusters → Select cluster → Services → Create service
2. **Configure**:
   - **Launch type**: FARGATE
   - **Task definition**: `ecs-database-task`
   - **Service name**: `ecs-database-service`
   - **Number of tasks**: 1
   - **Deployment type**: Service
3. **Networking**:
   - **VPC**: **Select your VPC here** (e.g., `ecs-vpc`)
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-database-sg`
   - **Auto-assign public IP**: Disabled
4. **Service discovery**:
   - **Enable service discovery**: Yes
   - **Namespace**: Select `ecs.internal`
   - **Service name**: `ecs-database-service`
5. **Click "Create service"**

### Step 10.2: Backend Service
1. **Create service**:
   - **Launch type**: FARGATE
   - **Task definition**: `ecs-backend-task`
   - **Service name**: `ecs-backend-service`
   - **Number of tasks**: 2
2. **Networking**:
   - **VPC**: **Select your VPC here** (e.g., `ecs-vpc`)
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled
3. **Load balancing**:
   - **Load balancer type**: Application Load Balancer
   - **Load balancer**: Select `ecs-alb`
   - **Target group**: Select backend target group
   - **Container name**: `backend`
   - **Container port**: 4000
4. **Click "Create service"**

### Step 10.3: Frontend Service
1. **Create service**:
   - **Launch type**: FARGATE
   - **Task definition**: `ecs-frontend-task`
   - **Service name**: `ecs-frontend-service`
   - **Number of tasks**: 2
2. **Networking**:
   - **VPC**: **Select your VPC here** (e.g., `ecs-vpc`)
   - **Subnets**: Select both public subnets
   - **Security groups**: Select `ecs-frontend-sg`
   - **Auto-assign public IP**: Enabled
3. **Load balancing**:
   - **Load balancer type**: Application Load Balancer
   - **Load balancer**: Select `ecs-alb`
   - **Target group**: Select frontend target group
   - **Container name**: `frontend`
   - **Container port**: 80
4. **Click "Create service"**

---

## Phase 11: Testing and Verification

### Step 11.1: Check Service Status
1. **ECS Console** → Clusters → Select cluster
2. **Verify all services are running**:
   - Database service: 1 task running
   - Backend service: 2 tasks running
   - Frontend service: 2 tasks running

### Step 11.2: Test Application
1. **Get ALB DNS name** from EC2 Console → Load Balancers
2. **Test endpoints**:
   - **Frontend**: `http://[ALB-DNS-NAME]/`
   - **Backend Health**: `http://[ALB-DNS-NAME]/api/health`
   - **Database Health**: `http://[ALB-DNS-NAME]/api/health/database`

### Step 11.3: Monitor Logs
1. **CloudWatch Console** → Log groups
2. **Check logs for each service**:
   - `/ecs/frontend`
   - `/ecs/backend`
   - `/ecs/database`

---

## 🎉 Deployment Complete!

Your 3-tier application is now deployed on ECS with:
- ✅ **Frontend**: React app served by nginx
- ✅ **Backend**: Node.js API with Express
- ✅ **Database**: PostgreSQL with EFS persistence
- ✅ **Load Balancer**: ALB with proper routing
- ✅ **Service Discovery**: Database accessible by name
- ✅ **Security**: Proper security groups and IAM roles
- ✅ **Monitoring**: CloudWatch logs for all services

### 📊 Architecture Summary
```
Internet → ALB → Frontend Service (React) → Backend Service (Node.js) → Database Service (PostgreSQL)
```

### 🔧 Key Features
- **High Availability**: Multiple tasks across AZs
- **Auto Scaling**: ECS can scale based on demand
- **Health Checks**: All services monitored
- **Service Discovery**: Database accessible by service name
- **Load Balancing**: ALB distributes traffic
- **Logging**: Centralized CloudWatch logs
- **Security**: Proper network isolation

---

## 🚨 Troubleshooting Tips

### Common Issues:
1. **Tasks not starting**: Check IAM roles and security groups
2. **Health check failures**: Verify container ports and health check paths
3. **Database connection issues**: Check service discovery and security groups
4. **ALB routing issues**: Verify listener rules and target groups

### Useful Commands:
- **Check service status**: ECS Console → Services
- **View logs**: CloudWatch Console → Log groups
- **Test connectivity**: Use ALB DNS name in browser
- **Monitor metrics**: CloudWatch Console → Metrics

---

## 📝 Notes
- Replace `[ALB-DNS-NAME]` with your actual ALB DNS name
- Update ECR image URIs if using different repository
- Consider adding HTTPS listener for production
- Set up CloudWatch alarms for monitoring
- Configure auto-scaling policies as needed
