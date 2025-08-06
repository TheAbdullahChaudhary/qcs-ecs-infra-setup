# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Application Configuration
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "3-tier-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# ECR Image URIs
variable "frontend_image" {
  description = "ECR URI for frontend image"
  type        = string
  default     = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest"
}

variable "backend_image" {
  description = "ECR URI for backend image"
  type        = string
  default     = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest"
}

variable "database_image" {
  description = "ECR URI for database image"
  type        = string
  default     = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest"
}