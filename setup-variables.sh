#!/bin/bash

# ECS 3-Tier Application Setup Variables
# This script helps you set up the necessary variables for the manual ECS setup

echo "ECS 3-Tier Application Setup Variables"
echo "======================================"
echo ""

# Set your AWS region
export AWS_REGION="us-east-1"
echo "AWS Region: $AWS_REGION"

# Set your AWS account ID (you'll need to replace this)
echo "Please enter your AWS Account ID:"
read AWS_ACCOUNT_ID
export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

# VPC Configuration
export VPC_CIDR="10.0.0.0/16"
export PUBLIC_SUBNET_1_CIDR="10.0.1.0/24"
export PUBLIC_SUBNET_2_CIDR="10.0.2.0/24"
export PRIVATE_SUBNET_1_CIDR="10.0.3.0/24"
export PRIVATE_SUBNET_2_CIDR="10.0.4.0/24"

# Availability Zones (adjust for your region)
export AZ_1="us-east-1a"
export AZ_2="us-east-1b"

# Database Configuration
export DB_INSTANCE_CLASS="db.t3.micro"
export DB_NAME="ecsdb"
export DB_USERNAME="ecsuser"
export DB_PASSWORD="YourSecurePassword123!"

# ECS Configuration
export CLUSTER_NAME="ecs-app-cluster"
export FRONTEND_SERVICE_NAME="ecs-frontend-service"
export BACKEND_SERVICE_NAME="ecs-backend-service"

# ECR Repository Names
export FRONTEND_REPO_NAME="ecs-frontend"
export BACKEND_REPO_NAME="ecs-backend"

# Security Group Names
export ALB_SG_NAME="ecs-alb-sg"
export FRONTEND_SG_NAME="ecs-frontend-sg"
export BACKEND_SG_NAME="ecs-backend-sg"
export DB_SG_NAME="ecs-db-sg"

# Load Balancer Name
export ALB_NAME="ecs-alb"

# Target Group Names
export FRONTEND_TG_NAME="ecs-frontend-tg"
export BACKEND_TG_NAME="ecs-backend-tg"

# IAM Role Names
export TASK_EXECUTION_ROLE_NAME="ecsTaskExecutionRole"
export TASK_ROLE_NAME="ecsTaskRole"

# Secrets Manager Secret Name
export SECRET_NAME="ecs/database/credentials"

# CloudWatch Log Groups
export FRONTEND_LOG_GROUP="/ecs/frontend"
export BACKEND_LOG_GROUP="/ecs/backend"

echo ""
echo "Variables set successfully!"
echo ""
echo "Next steps:"
echo "1. Run the VPC creation commands from MANUAL_SETUP_GUIDE.md"
echo "2. Replace placeholder values (xxxxxxxxx) with actual resource IDs"
echo "3. Follow the step-by-step guide in MANUAL_SETUP_GUIDE.md"
echo ""
echo "Important: Make sure to update the AWS Account ID and region if needed!" 