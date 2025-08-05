#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REGISTRY="941377128979.dkr.ecr.us-east-1.amazonaws.com"
BACKEND_REPO="ecs-backend"
FRONTEND_REPO="ecs-frontend"

echo "🚀 Starting 3-Tier ECS Application Deployment"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command_exists aws; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

if ! command_exists docker; then
    echo "❌ Docker is not installed"
    exit 1
fi

if ! command_exists terraform; then
    echo "❌ Terraform is not installed"
    exit 1
fi

echo "✅ All prerequisites are installed"

# Get ECR login
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push backend
echo "🏗️ Building and pushing backend image..."
cd backend
docker build -t $BACKEND_REPO .
docker tag $BACKEND_REPO:latest $ECR_REGISTRY/$BACKEND_REPO:latest
docker push $ECR_REGISTRY/$BACKEND_REPO:latest
cd ..

# Build and push frontend
echo "🏗️ Building and pushing frontend image..."
cd frontend
docker build -t $FRONTEND_REPO .
docker tag $FRONTEND_REPO:latest $ECR_REGISTRY/$FRONTEND_REPO:latest
docker push $ECR_REGISTRY/$FRONTEND_REPO:latest
cd ..

# Deploy infrastructure
echo "🏗️ Deploying infrastructure with Terraform..."
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get outputs
echo "📋 Deployment completed successfully!"
echo ""
echo "🌐 Application URL: http://$(terraform output -raw alb_dns_name)"
echo "🗄️ Database Endpoint: $(terraform output -raw database_endpoint)"
echo "🔐 Secret Name: $(terraform output -raw secret_name)"
echo ""
echo "⏳ Note: It may take a few minutes for services to become healthy."
echo "   Check the status dashboard on the frontend for real-time status."