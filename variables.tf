# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

# Application Configuration
variable "app_name" {
  description = "Application name"
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
  description = "Frontend Docker image URI"
  type        = string
  default     = "theabdullahchaudhary/ecs-frontend:latest"
}

variable "backend_image" {
  description = "Backend Docker image URI"
  type        = string
  default     = "theabdullahchaudhary/ecs-backend:latest"
}

variable "database_image" {
  description = "Database Docker image URI"
  type        = string
  default     = "theabdullahchaudhary/ecs-database:latest"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}