# Build and Push Docker Images to ECR
Write-Host "🐳 Building and Pushing Docker Images to ECR" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Get AWS Account ID
Write-Host "Getting AWS Account ID..." -ForegroundColor Yellow
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = "us-east-1"

Write-Host "AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "AWS Region: $AWS_REGION" -ForegroundColor Cyan

# Login to ECR
Write-Host "Logging in to ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to login to ECR" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Successfully logged in to ECR" -ForegroundColor Green

# Build and push frontend
Write-Host ""
Write-Host "Building and pushing frontend..." -ForegroundColor Green
cd frontend
docker build -t ecs-frontend .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build frontend image" -ForegroundColor Red
    exit 1
}

docker tag ecs-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-frontend:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push frontend image" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Frontend image pushed successfully" -ForegroundColor Green
cd ..

# Build and push backend
Write-Host ""
Write-Host "Building and pushing backend..." -ForegroundColor Green
cd backend
docker build -t ecs-backend .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build backend image" -ForegroundColor Red
    exit 1
}

docker tag ecs-backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-backend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-backend:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push backend image" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Backend image pushed successfully" -ForegroundColor Green
cd ..

# Build and push database
Write-Host ""
Write-Host "Building and pushing database..." -ForegroundColor Green
cd database
docker build -t ecs-database .
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to build database image" -ForegroundColor Red
    exit 1
}

docker tag ecs-database:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-database:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-database:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to push database image" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Database image pushed successfully" -ForegroundColor Green
cd ..

Write-Host ""
Write-Host "🎉 All images pushed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Image URIs for ECS Task Definitions:" -ForegroundColor Cyan
Write-Host "Frontend: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-frontend:latest" -ForegroundColor White
Write-Host "Backend: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-backend:latest" -ForegroundColor White
Write-Host "Database: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecs-database:latest" -ForegroundColor White
Write-Host ""
Write-Host "You can now proceed with creating ECS Task Definitions using these image URIs." -ForegroundColor Yellow 