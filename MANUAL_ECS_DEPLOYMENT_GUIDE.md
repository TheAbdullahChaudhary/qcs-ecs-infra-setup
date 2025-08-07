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
   - **Availability Zone**: `eu-west-1a`
   - **IPv4 CIDR block**: `10.0.1.0/24`
   - **Auto-assign public IPv4 address**: Yes
3. **Click "Create subnet"**

#### Public Subnet 2
1. **Create another subnet**:
   - **Subnet name**: `ecs-public-subnet-2`
   - **Availability Zone**: `eu-west-1b`
   - **IPv4 CIDR block**: `10.0.2.0/24`
   - **Auto-assign public IPv4 address**: Yes

#### Private Subnet 1
1. **Create private subnet**:
   - **Subnet name**: `ecs-private-subnet-1`
   - **Availability Zone**: `eu-west-1a`
   - **IPv4 CIDR block**: `10.0.11.0/24`
   - **Auto-assign public IPv4 address**: No

#### Private Subnet 2
1. **Create another private subnet**:
   - **Subnet name**: `ecs-private-subnet-2`
   - **Availability Zone**: `eu-west-1b`
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
   - **Availability Zone**: `eu-west-1a`
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

### Service Discovery and ECS: Correct Order
To enable DNS-based service discovery in ECS, follow this order:
1. **Create a namespace** in AWS Cloud Map (e.g., `ecs.internal`).
2. **Register a service** in the namespace (e.g., `ecs-database-service`).
3. **Create ECS task definitions** for your application components (database, backend, frontend).
4. **Create ECS services** in ECS, referencing the Cloud Map service for service discovery. When ECS tasks are launched, they are automatically registered with the Cloud Map service and become discoverable by DNS name.

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

### Step 7.3: (Optional) Create Backend Service (Service Discovery Registration)
If you want your backend to be discoverable by internal DNS (for example, for internal microservice communication), repeat the Cloud Map service registration for the backend:
1. **Cloud Map Console** → Services → Create service
2. **Configure**:
   - **Service name**: `ecs-backend-service`
   - **Namespace**: Select `ecs.internal`
   - **DNS configuration**:
     - **TTL**: 10
     - **Routing policy**: Multivalue
   - **Health check**: Custom configuration
     - **Failure threshold**: 1
3. **Click "Create service"**
4. **Result:** This step registers a DNS name (e.g., `ecs-backend-service.ecs.internal`) for your backend. When you create your ECS service for the backend, it will register running tasks with this DNS name, enabling other services (like your frontend) to connect using the name instead of an IP address.

**Note:** You should create all required Cloud Map services (e.g., for database, backend, and optionally frontend) before creating ECS task definitions and ECS services if you want to use service discovery for internal communication.

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

### Step 8.3: Create Listeners and Rules

#### Default Listener
1. **Select ALB** → Listeners → Create listener
2. **Configure**:
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default action**: Forward to `Frontend-Target-Group`
3. **Click "Create listener"**

#### Backend Listener Rule
1. **Select the listener** → Rules → Create rule
2. **Configure**:
   - **Priority**: 100
   - **Name tag**: `backend-api-rule`
   - **IF**: Path is `/api/*`
   - **THEN**: Forward to `Backend-Target-Group`
3. **Click "Create rule"**

**Result**: Your ALB will have:
- **Default rule**: All traffic → `Frontend-Target-Group`
- **Priority 100 rule**: `/api/*` → `Backend-Target-Group`

---

## Phase 9: ECS Task Definitions

### Task Definitions and Service Discovery
You must create your ECS task definitions before you can launch ECS services. The ECS service will use the task definition and, if configured, will register running tasks with the Cloud Map service for DNS-based discovery.

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
   - **Image**: `941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-database:latest`
   - **Port mappings**: 5432:5432
   - **Environment variables**:
     - `POSTGRES_DB`: `ecsdb`
     - `POSTGRES_USER`: `ecsuser`
     - `POSTGRES_PASSWORD`: `ecspassword`
   - **Log configuration**:
     - **Log driver**: awslogs
     - **Log group**: `/ecs/database`
     - **Region**: eu-west-1
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
   - **Image**: `941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-backend:latest`
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
     - **Region**: eu-west-1
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
   - **Image**: `941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-frontend:latest`
   - **Port mappings**: 80:80
   - **Environment variables**:
     - `REACT_APP_API_URL`: `http://ecs-backend-service.ecs.internal:4000/api`
   - **Log configuration**:
     - **Log driver**: awslogs
     - **Log group**: `/ecs/frontend`
     - **Region**: eu-west-1
     - **Stream prefix**: ecs
   - **Health check**:
     - **Command**: `["CMD-SHELL", "curl -f http://localhost/health || exit 1"]`
     - **Interval**: 30 seconds
     - **Timeout**: 5 seconds
     - **Retries**: 3
     - **Start period**: 60 seconds
3. **Click "Create"**

**Note:** This configuration uses ECS Service Discovery (Cloud Map) for internal communication between frontend and backend. The backend service must be registered in Cloud Map (as done in Step 7.3) for the frontend to resolve `ecs-backend-service.ecs.internal`. This approach provides faster internal communication without going through the ALB.

---

## ✅ Application Configuration Verification

### Frontend Configuration ✅
**File: `frontend/src/App.js`**
- ✅ Uses `process.env.REACT_APP_API_URL` for API calls
- ✅ Falls back to `/api` if environment variable not set
- ✅ Makes requests to `${API_BASE_URL}/health`, `${API_BASE_URL}/todos`
- ✅ Correctly handles CORS and error states

**File: `frontend/nginx.conf`**
- ✅ Listens on port 80
- ✅ Has `/health` endpoint for health checks
- ✅ Serves React app from `/usr/share/nginx/html`
- ✅ Handles React Router with `try_files $uri $uri/ /index.html`

### Backend Configuration ✅
**File: `backend/index.js`**
- ✅ Uses environment variables for database connection:
  - `POSTGRES_HOST` (defaults to "db")
  - `POSTGRES_PORT` (defaults to 5432)
  - `POSTGRES_DB` (defaults to "ecsdb")
  - `POSTGRES_USER` (defaults to "ecsuser")
  - `POSTGRES_PASSWORD` (defaults to "ecspassword")
- ✅ Has `/health` endpoint for health checks
- ✅ Has `/health/database` endpoint for detailed DB status
- ✅ Uses Sequelize with proper connection pooling
- ✅ Handles database connection retries

### Database Configuration ✅
**File: `database/init.sql`**
- ✅ Creates database with correct name (`ecsdb`)
- ✅ Sets up user permissions for `ecsuser`
- ✅ Creates initialization tracking table
- ✅ Grants necessary privileges

### Docker Configuration ✅
**File: `frontend/Dockerfile`**
- ✅ Multi-stage build with Node.js and nginx
- ✅ Exposes port 80
- ✅ Copies nginx configuration

**File: `backend/Dockerfile`**
- ✅ Uses Node.js 18-alpine
- ✅ Exposes port 4000
- ✅ Runs as non-root user (nodejs)
- ✅ Has health check configured

**File: `database/Dockerfile`**
- ✅ Uses PostgreSQL 15-alpine
- ✅ Exposes port 5432
- ✅ Sets environment variables
- ✅ Copies initialization script

### Environment Variables Summary
**Frontend Task Definition:**
```env
REACT_APP_API_URL=http://ecs-backend-service.ecs.internal:4000/api
```

**Backend Task Definition:**
```env
NODE_ENV=production
POSTGRES_DB=ecsdb
POSTGRES_HOST=ecs-database-service.ecs.internal
POSTGRES_PORT=5432
POSTGRES_USER=ecsuser
POSTGRES_PASSWORD=ecspassword
```

**Database Task Definition:**
```env
POSTGRES_DB=ecsdb
POSTGRES_USER=ecsuser
POSTGRES_PASSWORD=ecspassword
```

### Communication Flow ✅
1. **Frontend → Backend**: `http://ecs-backend-service.ecs.internal:4000/api`
2. **Backend → Database**: `ecs-database-service.ecs.internal:5432`
3. **External → Frontend**: Through ALB on port 80

### Health Check Endpoints ✅
- **Frontend**: `http://localhost/health` (nginx)
- **Backend**: `http://localhost:4000/health` (Express)
- **Database**: `pg_isready -U ecsuser -d ecsdb` (PostgreSQL)

**All application files are correctly configured for ECS deployment with service discovery!**

---

## Frontend-to-Backend Communication: ALB DNS vs. Service Discovery

### Why Use ALB DNS for Backend API?
In this manual, the frontend communicates with the backend using the Application Load Balancer (ALB) DNS name (e.g., `http://[ALB-DNS-NAME]/api`). This is set via the environment variable:

```
REACT_APP_API_URL=http://[ALB-DNS-NAME]/api
```

#### When to Use ALB DNS:
- You want the frontend to talk to the backend through the ALB
- Public access is required (exposing APIs to the internet)
- You need load balancing, SSL termination, or WAF protection

#### Pros:
- Secure (if using HTTPS)
- Scalable
- Supports path-based routing (e.g., `/api`)

### Alternative: Service Discovery (Cloud Map)
For internal-only communication (no public access), you could use ECS Service Discovery (Cloud Map) DNS names (e.g., `http://ecs-backend-service.ecs.internal/api`). This avoids ALB costs and is faster for internal microservices, but does not provide public access or SSL.

#### Summary Table

| Feature                | Using ALB DNS                           | Using ECS Namespace (Cloud Map)     |
| ---------------------- | --------------------------------------- | ----------------------------------- |
| Communication Type     | External or internal (via ALB)          | Internal only (within VPC)          |
| DNS Example            | `ecs-backend-alb-xyz.elb.amazonaws.com` | `backend.ecs.internal`              |
| Requires Load Balancer | ✅ Yes                                   | ❌ No                                |
| Cost                   | 💰 Higher (ALB costs money)             | 💸 Lower (no ALB required)          |
| SSL / HTTPS Support    | ✅ Yes                                   | ❌ Not built-in                      |
| Speed                  | 🌐 Slower (external path)               | ⚡ Faster (internal DNS resolution)  |
| Use Case               | Public access, centralized API gateway  | Internal microservice communication |

**This manual uses the ALB DNS approach for frontend-backend communication.**

---

## Phase 10: ECS Services

### Note on Service Discovery Registration
When you create an ECS service and enable service discovery, ECS will automatically register the running tasks with the Cloud Map service you created earlier. This makes your tasks discoverable by DNS name (e.g., `ecs-database-service.ecs.internal`).

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
   - **Number of tasks**: 1
2. **Networking**:
   - **VPC**: **Select your VPC here** (e.g., `ecs-vpc`)
   - **Subnets**: Select both private subnets
   - **Security groups**: Select `ecs-backend-sg`
   - **Auto-assign public IP**: Disabled
3. **Service discovery**:
   - **Enable service discovery**: Yes
   - **Namespace**: Select `ecs.internal`
   - **Service name**: `ecs-backend-service`
4. **Load balancing**:
   - **Load balancer type**: Application Load Balancer
   - **Load balancer**: Select `ecs-alb`
   - **Target group**: Select `Backend-Target-Group`
   - **Container name**: `backend`
   - **Container port**: 4000
   - **Health check path**: `/health`
5. **Click "Create service"**

### Step 10.3: Frontend Service
1. **Create service**:
   - **Launch type**: FARGATE
   - **Task definition**: `ecs-frontend-task`
   - **Service name**: `ecs-frontend-service`
   - **Number of tasks**: 1
2. **Networking**:
   - **VPC**: **Select your VPC here** (e.g., `ecs-vpc`)
   - **Subnets**: Select both public subnets
   - **Security groups**: Select `ecs-frontend-sg`
   - **Auto-assign public IP**: Enabled
3. **Load balancing**:
   - **Load balancer type**: Application Load Balancer
   - **Load balancer**: Select `ecs-alb`
   - **Target group**: Select `Frontend-Target-Group`
   - **Container name**: `frontend`
   - **Container port**: 80
   - **Health check path**: `/health`
4. **Click "Create service"**

---

## Phase 11: Application Code Verification

### ✅ Frontend Application Code Verification

**File: `frontend/src/App.js`**
- ✅ **API Configuration**: Uses `process.env.REACT_APP_API_URL` with fallback to `/api`
- ✅ **Health Check**: Makes requests to `${API_BASE_URL}/health` for status monitoring
- ✅ **CRUD Operations**: Implements full todo CRUD (Create, Read, Update, Delete)
- ✅ **Error Handling**: Proper error handling and user feedback
- ✅ **Status Monitoring**: Real-time backend and database status display

**File: `frontend/package.json`**
- ✅ **Dependencies**: React 18.2.0, react-scripts 5.0.1
- ✅ **Build Script**: `npm run build` for production build
- ✅ **Browserslist**: Proper production browser support

**File: `frontend/nginx.conf`**
- ✅ **Port Configuration**: Listens on port 80
- ✅ **Health Endpoint**: `/health` returns 200 "healthy"
- ✅ **React Router**: Handles client-side routing with `try_files`
- ✅ **Security Headers**: XSS protection, content security policy
- ✅ **Static Assets**: Proper caching for JS/CSS files

**File: `frontend/Dockerfile`**
- ✅ **Multi-stage Build**: Node.js build + nginx production
- ✅ **Port Exposure**: Exposes port 80
- ✅ **Nginx Config**: Copies custom nginx.conf
- ✅ **Production Ready**: Serves built React app

### ✅ Backend Application Code Verification

**File: `backend/index.js`**
- ✅ **Environment Variables**: Uses all required PostgreSQL env vars
- ✅ **Database Connection**: Sequelize with proper connection pooling
- ✅ **Health Endpoints**: `/health` and `/health/database` endpoints
- ✅ **CRUD API**: Full REST API for todos (`/todos`)
- ✅ **Error Handling**: Comprehensive error handling and logging
- ✅ **CORS**: Enabled for frontend communication
- ✅ **Connection Retries**: Database connection retry logic

**File: `backend/package.json`**
- ✅ **Dependencies**: Express, Sequelize, pg, cors, dotenv
- ✅ **Start Script**: `node index.js` for production
- ✅ **Production Ready**: All necessary dependencies included

**File: `backend/Dockerfile`**
- ✅ **Security**: Runs as non-root user (nodejs)
- ✅ **Health Check**: Built-in health check for port 4000
- ✅ **Port Exposure**: Exposes port 4000
- ✅ **Production Ready**: Uses `npm ci --only=production`

### ✅ Database Application Code Verification

**File: `database/Dockerfile`**
- ✅ **Base Image**: PostgreSQL 15-alpine
- ✅ **Environment Variables**: Sets up database, user, password
- ✅ **Initialization**: Copies init.sql for database setup
- ✅ **Port Exposure**: Exposes port 5432
- ✅ **Configuration**: Uses custom postgresql.conf

**File: `database/init.sql`**
- ✅ **Database Setup**: Creates ecsdb database
- ✅ **User Permissions**: Grants proper permissions to ecsuser
- ✅ **Extensions**: Enables uuid-ossp extension
- ✅ **Initialization Tracking**: Creates db_init table

### ✅ Environment Variables Summary

**Frontend Environment:**
```env
REACT_APP_API_URL=http://ecs-backend-service.ecs.internal:4000/api
```

**Backend Environment:**
```env
NODE_ENV=production
POSTGRES_DB=ecsdb
POSTGRES_HOST=ecs-database-service.ecs.internal
POSTGRES_PORT=5432
POSTGRES_USER=ecsuser
POSTGRES_PASSWORD=ecspassword
```

**Database Environment:**
```env
POSTGRES_DB=ecsdb
POSTGRES_USER=ecsuser
POSTGRES_PASSWORD=ecspassword
```

### ✅ Health Check Endpoints

| Service | Endpoint | Expected Response |
|---------|----------|-------------------|
| Frontend | `http://localhost/health` | `200 "healthy"` |
| Backend | `http://localhost:4000/health` | JSON with status |
| Database | `pg_isready -U ecsuser -d ecsdb` | Exit code 0 |

**All application code is correctly configured for ECS deployment!**

---

## Phase 12: Build and Push Docker Images

### Step 12.1: Build Docker Images
Before creating ECS services, you need to build and push your Docker images to ECR.

1. **Login to ECR**:
   ```bash
   aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 941377128979.dkr.ecr.eu-west-1.amazonaws.com
   ```

2. **Build Frontend Image**:
   ```bash
   cd frontend
   docker build -t ecs-frontend .
   docker tag ecs-frontend:latest 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-frontend:latest
   ```

3. **Build Backend Image**:
   ```bash
   cd ../backend
   docker build -t ecs-backend .
   docker tag ecs-backend:latest 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-backend:latest
   ```

4. **Build Database Image**:
   ```bash
   cd ../database
   docker build -t ecs-database .
   docker tag ecs-database:latest 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-database:latest
   ```

### Step 12.2: Push Images to ECR
1. **Push Frontend**:
   ```bash
   docker push 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-frontend:latest
   ```

2. **Push Backend**:
   ```bash
   docker push 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-backend:latest
   ```

3. **Push Database**:
   ```bash
   docker push 941377128979.dkr.ecr.eu-west-1.amazonaws.com/ecs-database:latest
   ```

---

## Phase 13: Testing and Verification

### Step 13.1: Check Service Status
1. **ECS Console** → Clusters → Select cluster
2. **Verify all services are running**:
   - Database service: 1 task running
   - Backend service: 1 task running
   - Frontend service: 1 task running

### Step 13.2: Check Target Groups
1. **EC2 Console** → Target Groups
2. **Verify targets are registered**:
   - `Frontend-Target-Group`: Should show 1 healthy target
   - `Backend-Target-Group`: Should show 1 healthy target

### Step 13.3: Test Application Endpoints
Use your ALB DNS name: `ecs-alb-1564719148.eu-west-1.elb.amazonaws.com`

1. **Frontend Application**:
   ```
   http://ecs-alb-1564719148.eu-west-1.elb.amazonaws.com/
   ```
   - Should show the Todo app interface
   - Should display backend and database status

2. **Backend Health Check**:
   ```
   http://ecs-alb-1564719148.eu-west-1.elb.amazonaws.com/api/health
   ```
   - Should return JSON with database connection status

3. **Backend API Endpoints**:
   ```
   http://ecs-alb-1564719148.eu-west-1.elb.amazonaws.com/api/todos
   ```
   - Should return empty array or existing todos

### Step 13.4: Test Full Application Flow
1. **Add a Todo**: Use the frontend form to add a new todo
2. **Verify Database**: Check that the todo is persisted
3. **Toggle Todo**: Mark a todo as complete/incomplete
4. **Delete Todo**: Remove a todo from the list

### Step 13.5: Monitor Logs
1. **CloudWatch Console** → Log groups
2. **Check logs for each service**:
   - `/ecs/frontend`
   - `/ecs/backend`
   - `/ecs/database`

### Step 13.6: Verify Service Discovery
1. **Test internal communication**:
   - Frontend should connect to backend via `ecs-backend-service.ecs.internal:4000`
   - Backend should connect to database via `ecs-database-service.ecs.internal:5432`

---

## 🎉 Deployment Complete!

Your 3-tier application is now deployed on ECS with:
- ✅ **Frontend**: React app served by nginx on port 80
- ✅ **Backend**: Node.js API with Express on port 4000
- ✅ **Database**: PostgreSQL with proper initialization
- ✅ **Load Balancer**: ALB with path-based routing (`/api/*` → backend)
- ✅ **Service Discovery**: Internal DNS resolution for service communication
- ✅ **Security**: Proper security groups and IAM roles
- ✅ **Monitoring**: CloudWatch logs for all services
- ✅ **Health Checks**: All services monitored and healthy

### 📊 Architecture Summary
```
Internet → ALB → Frontend Service (React) → Backend Service (Node.js) → Database Service (PostgreSQL)
                ↑         ↑
            (service    (service
             discovery)   discovery)
```

### 🔧 Key Features
- **High Availability**: Services across multiple AZs
- **Auto Scaling**: ECS can scale based on demand
- **Health Checks**: All services monitored
- **Service Discovery**: Internal DNS-based communication
- **Load Balancing**: ALB with intelligent routing
- **Logging**: Centralized CloudWatch logs
- **Security**: Network isolation and IAM roles

---

## 🚨 Troubleshooting Tips

### Common Issues:
1. **Tasks not starting**: Check IAM roles and security groups
2. **Health check failures**: Verify container ports and health check paths
3. **Database connection issues**: Check service discovery and security groups
4. **ALB routing issues**: Verify listener rules and target groups

### ALB and Target Group Issues:
1. **Target group dropdown shows "No target groups found"**:
   - Ensure target groups are created with **Target type: IP addresses**
   - Verify target groups are in the same VPC as your ECS service
   - Associate target groups with ALB listeners first
   - Refresh the ECS service creation page

2. **Target groups show "None associated" for load balancer**:
   - Go to ALB → Listeners → Rules and ensure target groups are properly assigned
   - Verify listener rules are configured correctly

3. **Health check failures**:
   - Ensure health check paths match your application endpoints (`/health`)
   - Verify container ports are correctly exposed
   - Check security groups allow health check traffic

### Useful Commands:
- **Check service status**: ECS Console → Services
- **View logs**: CloudWatch Console → Log groups
- **Test connectivity**: Use ALB DNS name in browser
- **Monitor metrics**: CloudWatch Console → Metrics

### Target Group Configuration Summary:
| Target Group | Port | Health Check Path | Protocol |
|--------------|------|-------------------|----------|
| Frontend-Target-Group | 80 | `/health` | HTTP |
| Backend-Target-Group | 4000 | `/health` | HTTP |

### ALB Listener Rules Summary:
| Priority | Path | Target Group |
|----------|------|--------------|
| 100 | `/api/*` | Backend-Target-Group |
| Default | All other paths | Frontend-Target-Group |

---

## 📝 Next Steps for Production

1. **Add HTTPS**: Configure SSL certificate for ALB
2. **Auto Scaling**: Set up ECS auto-scaling policies
3. **Monitoring**: Configure CloudWatch alarms
4. **Backup**: Set up database backups
5. **CI/CD**: Implement automated deployment pipeline
6. **Security**: Add WAF and additional security measures
