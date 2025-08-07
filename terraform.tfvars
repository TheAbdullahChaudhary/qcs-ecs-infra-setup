# AWS Configuration
aws_region = "eu-west-1"

# Application Configuration
app_name    = "3-tier-app"
environment = "production"

# Docker Hub Image URIs (using your Docker Hub images)
frontend_image = "theabdullahchaudhary/ecs-frontend:latest"
backend_image  = "theabdullahchaudhary/ecs-backend:latest"
database_image = "theabdullahchaudhary/ecs-database:latest" 