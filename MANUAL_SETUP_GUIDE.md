# Manual ECS Setup Guide for 3-Tier Application

This guide will walk you through manually setting up a 3-tier application (Frontend + Backend + PostgreSQL) on AWS ECS with proper networking, security, and AWS Secrets Manager integration.

## Architecture Overview

```
Internet → ALB → Frontend (Public Subnet) → Backend (Private Subnet) → PostgreSQL (RDS)
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed locally
- Basic knowledge of AWS services

## Step 1: Create VPC and Networking

### 1.1 Create VPC
```bash
# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications ResourceType=vpc,Tags=[{Key=Name,Value=ecs-vpc}]

# Note the VPC ID from output
VPC_ID=vpc-xxxxxxxxx
```

### 1.2 Create Internet Gateway
```bash
# Create Internet Gateway
aws ec2 create-internet-gateway \
  --tag-specifications ResourceType=internet-gateway,Tags=[{Key=Name,Value=ecs-igw}]

# Note the IGW ID
IGW_ID=igw-xxxxxxxxx

# Attach to VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID
```

### 1.3 Create Subnets

#### Public Subnets (for ALB and Frontend)
```bash
# Public Subnet 1 (AZ a)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=ecs-public-subnet-1a}]

# Public Subnet 2 (AZ b)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=ecs-public-subnet-1b}]

# Note subnet IDs
PUBLIC_SUBNET_1=subnet-xxxxxxxxx
PUBLIC_SUBNET_2=subnet-xxxxxxxxx
```

#### Private Subnets (for Backend and RDS)
```bash
# Private Subnet 1 (AZ a)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=ecs-private-subnet-1a}]

# Private Subnet 2 (AZ b)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.4.0/24 \
  --availability-zone us-east-1b \
  --tag-specifications ResourceType=subnet,Tags=[{Key=Name,Value=ecs-private-subnet-1b}]

# Note subnet IDs
PRIVATE_SUBNET_1=subnet-xxxxxxxxx
PRIVATE_SUBNET_2=subnet-xxxxxxxxx
```

### 1.4 Enable Auto-assign Public IP for Public Subnets
```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_1 \
  --map-public-ip-on-launch

aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_2 \
  --map-public-ip-on-launch
```

### 1.5 Create Route Tables
```bash
# Create route table for public subnets
aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications ResourceType=route-table,Tags=[{Key=Name,Value=ecs-public-rt}]

# Note route table ID
PUBLIC_RT=rtb-xxxxxxxxx

# Add route to internet gateway
aws ec2 create-route \
  --route-table-id $PUBLIC_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate public subnets with public route table
aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_1 \
  --route-table-id $PUBLIC_RT

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_2 \
  --route-table-id $PUBLIC_RT
```

## Step 2: Create Security Groups

### 2.1 ALB Security Group
```bash
# Create ALB security group
aws ec2 create-security-group \
  --group-name ecs-alb-sg \
  --description "Security group for ALB" \
  --vpc-id $VPC_ID

ALB_SG=sg-xxxxxxxxx

# Allow HTTP and HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### 2.2 Frontend Security Group
```bash
# Create frontend security group
aws ec2 create-security-group \
  --group-name ecs-frontend-sg \
  --description "Security group for frontend" \
  --vpc-id $VPC_ID

FRONTEND_SG=sg-xxxxxxxxx

# Allow traffic from ALB
aws ec2 authorize-security-group-ingress \
  --group-id $FRONTEND_SG \
  --protocol tcp \
  --port 80 \
  --source-group $ALB_SG
```

### 2.3 Backend Security Group
```bash
# Create backend security group
aws ec2 create-security-group \
  --group-name ecs-backend-sg \
  --description "Security group for backend" \
  --vpc-id $VPC_ID

BACKEND_SG=sg-xxxxxxxxx

# Allow traffic from frontend
aws ec2 authorize-security-group-ingress \
  --group-id $BACKEND_SG \
  --protocol tcp \
  --port 4000 \
  --source-group $FRONTEND_SG
```

### 2.4 Database Security Group
```bash
# Create database security group
aws ec2 create-security-group \
  --group-name ecs-db-sg \
  --description "Security group for database" \
  --vpc-id $VPC_ID

DB_SG=sg-xxxxxxxxx

# Allow PostgreSQL from backend
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $BACKEND_SG
```

## Step 3: Create RDS PostgreSQL Database

### 3.1 Create DB Subnet Group
```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name ecs-db-subnet-group \
  --db-subnet-group-description "Subnet group for ECS database" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2
```

### 3.2 Create Database Credentials in Secrets Manager
```bash
# Create secret for database credentials
aws secretsmanager create-secret \
  --name ecs/database/credentials \
  --description "Database credentials for ECS application" \
  --secret-string '{
    "username": "ecsuser",
    "password": "YourSecurePassword123!",
    "engine": "postgres",
    "host": "ecs-db.xxxxxxxxx.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "dbname": "ecsdb"
  }'

# Note the secret ARN
SECRET_ARN=arn:aws:secretsmanager:us-east-1:xxxxxxxxx:secret:ecs/database/credentials-xxxxxxxxx
```

### 3.3 Create RDS Instance
```bash
aws rds create-db-instance \
  --db-instance-identifier ecs-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username ecsuser \
  --master-user-password YourSecurePassword123! \
  --allocated-storage 20 \
  --storage-type gp2 \
  --db-name ecsdb \
  --vpc-security-group-ids $DB_SG \
  --db-subnet-group-name ecs-db-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "sun:04:00-sun:05:00" \
  --publicly-accessible \
  --storage-encrypted \
  --tags Key=Name,Value=ecs-db

# Wait for database to be available
aws rds wait db-instance-available --db-instance-identifier ecs-db

# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier ecs-db --query 'DBInstances[0].Endpoint.Address' --output text)
```

## Step 4: Create ECR Repositories

### 4.1 Create ECR Repositories
```bash
# Create frontend repository
aws ecr create-repository \
  --repository-name ecs-frontend \
  --image-scanning-configuration scanOnPush=true

# Create backend repository
aws ecr create-repository \
  --repository-name ecs-backend \
  --image-scanning-configuration scanOnPush=true

# Get repository URIs
FRONTEND_REPO_URI=$(aws ecr describe-repositories --repository-names ecs-frontend --query 'repositories[0].repositoryUri' --output text)
BACKEND_REPO_URI=$(aws ecr describe-repositories --repository-names ecs-backend --query 'repositories[0].repositoryUri' --output text)
```

### 4.2 Get ECR Login Token
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $FRONTEND_REPO_URI
```

## Step 5: Build and Push Docker Images

### 5.1 Build Frontend Image
```bash
cd frontend
docker build -t ecs-frontend .
docker tag ecs-frontend:latest $FRONTEND_REPO_URI:latest
docker push $FRONTEND_REPO_URI:latest
```

### 5.2 Build Backend Image
```bash
cd ../backend
docker build -t ecs-backend .
docker tag ecs-backend:latest $BACKEND_REPO_URI:latest
docker push $BACKEND_REPO_URI:latest
```

## Step 6: Create ECS Cluster

### 6.1 Create ECS Cluster
```bash
aws ecs create-cluster \
  --cluster-name ecs-app-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

## Step 7: Create Task Definitions

### 7.1 Create Backend Task Definition
```bash
cat > backend-task-definition.json << EOF
{
  "family": "ecs-backend-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::xxxxxxxxx:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::xxxxxxxxx:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "$BACKEND_REPO_URI:latest",
      "portMappings": [
        {
          "containerPort": 4000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "POSTGRES_DB",
          "value": "ecsdb"
        },
        {
          "name": "POSTGRES_HOST",
          "value": "$DB_ENDPOINT"
        },
        {
          "name": "POSTGRES_PORT",
          "value": "5432"
        }
      ],
      "secrets": [
        {
          "name": "POSTGRES_USER",
          "valueFrom": "$SECRET_ARN:username::"
        },
        {
          "name": "POSTGRES_PASSWORD",
          "valueFrom": "$SECRET_ARN:password::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/backend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://backend-task-definition.json
```

### 7.2 Create Frontend Task Definition
```bash
cat > frontend-task-definition.json << EOF
{
  "family": "ecs-frontend-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::xxxxxxxxx:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "frontend",
      "image": "$FRONTEND_REPO_URI:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "REACT_APP_API_URL",
          "value": "/api"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/frontend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://frontend-task-definition.json
```

## Step 8: Create Application Load Balancer

### 8.1 Create ALB
```bash
aws elbv2 create-load-balancer \
  --name ecs-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG \
  --scheme internet-facing \
  --type application

# Note the ALB ARN
ALB_ARN=arn:aws:elasticloadbalancing:us-east-1:xxxxxxxxx:loadbalancer/app/ecs-alb/xxxxxxxxx
```

### 8.2 Create Target Groups

#### Frontend Target Group
```bash
aws elbv2 create-target-group \
  --name ecs-frontend-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2

FRONTEND_TG_ARN=arn:aws:elasticloadbalancing:us-east-1:xxxxxxxxx:targetgroup/ecs-frontend-tg/xxxxxxxxx
```

#### Backend Target Group
```bash
aws elbv2 create-target-group \
  --name ecs-backend-tg \
  --protocol HTTP \
  --port 4000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2

BACKEND_TG_ARN=arn:aws:elasticloadbalancing:us-east-1:xxxxxxxxx:targetgroup/ecs-backend-tg/xxxxxxxxx
```

### 8.3 Create Listeners
```bash
# Create listener for frontend (port 80)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN

# Create listener for backend API (port 80, path /api/*)
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN
```

## Step 9: Create ECS Services

### 9.1 Create Backend Service
```bash
aws ecs create-service \
  --cluster ecs-app-cluster \
  --service-name ecs-backend-service \
  --task-definition ecs-backend-task:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$BACKEND_SG],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=$BACKEND_TG_ARN,containerName=backend,containerPort=4000" \
  --health-check-grace-period-seconds 60
```

### 9.2 Create Frontend Service
```bash
aws ecs create-service \
  --cluster ecs-app-cluster \
  --service-name ecs-frontend-service \
  --task-definition ecs-frontend-task:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PUBLIC_SUBNET_1,$PUBLIC_SUBNET_2],securityGroups=[$FRONTEND_SG],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$FRONTEND_TG_ARN,containerName=frontend,containerPort=80" \
  --health-check-grace-period-seconds 60
```

## Step 10: Create IAM Roles (if not exists)

### 10.1 Create ECS Task Execution Role
```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach required policies
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

### 10.2 Create ECS Task Role
```bash
# Create the role
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach required policies
aws iam attach-role-policy \
  --role-name ecsTaskRole \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
```

## Step 11: Create CloudWatch Log Groups
```bash
aws logs create-log-group --log-group-name /ecs/frontend
aws logs create-log-group --log-group-name /ecs/backend
```

## Step 12: Test the Application

### 12.1 Get ALB DNS Name
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --names ecs-alb --query 'LoadBalancers[0].DNSName' --output text)
echo "Your application is available at: http://$ALB_DNS"
```

### 12.2 Test Health Endpoints
```bash
# Test frontend health
curl http://$ALB_DNS/health

# Test backend health
curl http://$ALB_DNS/api/health
```

## Step 13: Monitoring and Troubleshooting

### 13.1 Check Service Status
```bash
# Check backend service
aws ecs describe-services \
  --cluster ecs-app-cluster \
  --services ecs-backend-service

# Check frontend service
aws ecs describe-services \
  --cluster ecs-app-cluster \
  --services ecs-frontend-service
```

### 13.2 View Logs
```bash
# View backend logs
aws logs tail /ecs/backend --follow

# View frontend logs
aws logs tail /ecs/frontend --follow
```

### 13.3 Check Target Health
```bash
# Check frontend target health
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG_ARN

# Check backend target health
aws elbv2 describe-target-health --target-group-arn $BACKEND_TG_ARN
```

## Cleanup (Optional)

To clean up all resources:
```bash
# Delete ECS services
aws ecs update-service --cluster ecs-app-cluster --service ecs-frontend-service --desired-count 0
aws ecs update-service --cluster ecs-app-cluster --service ecs-backend-service --desired-count 0
aws ecs delete-service --cluster ecs-app-cluster --service ecs-frontend-service
aws ecs delete-service --cluster ecs-app-cluster --service ecs-backend-service

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete target groups
aws elbv2 delete-target-group --target-group-arn $FRONTEND_TG_ARN
aws elbv2 delete-target-group --target-group-arn $BACKEND_TG_ARN

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier ecs-db --skip-final-snapshot

# Delete ECR repositories
aws ecr delete-repository --repository-name ecs-frontend --force
aws ecr delete-repository --repository-name ecs-backend --force

# Delete secrets
aws secretsmanager delete-secret --secret-id ecs/database/credentials --force

# Delete security groups
aws ec2 delete-security-group --group-id $FRONTEND_SG
aws ec2 delete-security-group --group-id $BACKEND_SG
aws ec2 delete-security-group --group-id $DB_SG
aws ec2 delete-security-group --group-id $ALB_SG

# Delete subnets and VPC (after deleting all resources)
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## Notes

1. **Security**: The backend is placed in private subnets and can only be accessed through the frontend proxy.
2. **Scalability**: The services are configured with 2 desired tasks each for high availability.
3. **Secrets Management**: Database credentials are stored in AWS Secrets Manager and accessed securely by the backend.
4. **Health Checks**: Both frontend and backend have health checks configured.
5. **Logging**: All container logs are sent to CloudWatch Logs for monitoring.

## Troubleshooting Common Issues

1. **Tasks not starting**: Check the task execution role permissions and Secrets Manager access.
2. **Database connection issues**: Verify the security group rules and database endpoint.
3. **ALB health check failures**: Ensure the health check paths are correct and containers are responding.
4. **Frontend not loading**: Check if the nginx configuration is correct and the React app is built properly. 