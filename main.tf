terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
}

# ECS Cluster Module
module "ecs_cluster" {
  source             = "./modules/ecs-cluster"
  name               = "3-tier-ecs-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = aws_security_group.ecs_instances.id
}

# Security group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "ecs-instances-sg"
  description = "Security group for ECS instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-instances-sg"
  }
}

# ALB Module
module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# Secrets Manager secret (created first)
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "ecs-app-db-credentials"
  description = "Database credentials for ECS application"
  
  tags = {
    Name = "ecs-app-db-credentials"
  }
}

# IAM Module
module "iam" {
  source     = "./modules/iam"
  secret_arn = aws_secretsmanager_secret.db_credentials.arn
}

# Backend Module
module "backend" {
  source                    = "./modules/backend"
  family                    = "backend"
  execution_role_arn        = module.iam.ecs_execution_role_arn
  task_role_arn            = module.iam.ecs_task_role_arn
  cluster_name             = module.ecs_cluster.cluster_name
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  alb_security_group_id    = module.alb.alb_security_group_id
  backend_target_group_arn = module.alb.backend_target_group_arn
}

# RDS Module
module "rds" {
  source                    = "./modules/rds"
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  backend_security_group_id = module.backend.backend_security_group_id
  secret_name              = aws_secretsmanager_secret.db_credentials.name
}

# Frontend Module
module "frontend" {
  source                     = "./modules/frontend"
  family                     = "frontend"
  execution_role_arn         = module.iam.ecs_execution_role_arn
  task_role_arn             = module.iam.ecs_task_role_arn
  cluster_name              = module.ecs_cluster.cluster_name
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  alb_security_group_id     = module.alb.alb_security_group_id
  frontend_target_group_arn = module.alb.frontend_target_group_arn
}

# EFS Module (for Jenkins)
module "efs" {
  source            = "./modules/efs"
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = aws_security_group.jenkins_efs.id
}

# Security group for Jenkins EFS
resource "aws_security_group" "jenkins_efs" {
  name        = "jenkins-efs-sg"
  description = "Security group for Jenkins EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-efs-sg"
  }
}

# Security group for Jenkins service
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# Jenkins Module
module "jenkins" {
  source                = "./modules/jenkins"
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.jenkins.id
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  efs_file_system_id    = module.efs.efs_id
  efs_access_point_id   = module.efs.access_point_arn
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_instance_endpoint
}

output "secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}