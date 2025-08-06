# AWS Configuration
aws_region = "us-east-1"

# Application Configuration
app_name    = "3-tier-app"
environment = "production"

# ECR Image URIs (using your provided images)
frontend_image = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest"
backend_image  = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest"
database_image = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest" 