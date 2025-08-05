provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "./modules/vpc"
}

# Security group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "ecs-instances-sg"
  description = "Security group for ECS instances"
  vpc_id      = module.vpc.vpc_id

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

# Security group for Jenkins service
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow from VPC
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

module "ecs_cluster" {
  source             = "./modules/ecs-cluster"
  name               = "3-tier-ecs-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = aws_security_group.ecs_instances.id
}

module "efs" {
  source            = "./modules/efs"
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = data.aws_security_group.jenkins_efs.id
}

module "jenkins" {
  source                = "./modules/jenkins"
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.jenkins.id
  execution_role_arn    = data.aws_iam_role.ecs_execution.arn
  task_role_arn         = data.aws_iam_role.ecs_task.arn
  efs_file_system_id    = module.efs.efs_id
  efs_access_point_id   = module.efs.access_point_arn
}

module "frontend" {
  source             = "./modules/frontend"
  family             = "frontend"
  execution_role_arn = data.aws_iam_role.ecs_execution.arn
  task_role_arn      = data.aws_iam_role.ecs_task.arn
}

module "backend" {
  source             = "./modules/backend"
  family             = "backend"
  execution_role_arn = data.aws_iam_role.ecs_execution.arn
  task_role_arn      = data.aws_iam_role.ecs_task.arn
}

# Security group and IAM role lookups remain as before
# All ECS and EFS resources are now in private subnets