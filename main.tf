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
  security_group_id = aws_security_group.jenkins_efs.id
}

module "jenkins" {
  source                = "./modules/jenkins"
  cluster_name          = module.ecs_cluster.cluster_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  security_group_id     = aws_security_group.jenkins.id
  execution_role_arn    = aws_iam_role.ecs_execution.arn
  task_role_arn         = aws_iam_role.ecs_task.arn
  efs_file_system_id    = module.efs.efs_id
  efs_access_point_id   = module.efs.access_point_arn
}

module "frontend" {
  source             = "./modules/frontend"
  family             = "frontend"
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
}

module "backend" {
  source             = "./modules/backend"
  family             = "backend"
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
  postgres_host      = aws_db_instance.postgres.endpoint
}

# ECS Service for Backend
resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = module.ecs_cluster.cluster_name
  task_definition = module.backend.task_definition_arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.backend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 4000
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name = "backend-service"
  }
}

# ECS Service for Frontend
resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = module.ecs_cluster.cluster_name
  task_definition = module.frontend.task_definition_arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name = "frontend-service"
  }
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Security group for backend service
resource "aws_security_group" "backend" {
  name        = "backend-sg"
  description = "Security group for backend service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id, aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# Security group for frontend service
resource "aws_security_group" "frontend" {
  name        = "frontend-sg"
  description = "Security group for frontend service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# Security group for database
resource "aws_security_group" "database" {
  name        = "database-sg"
  description = "Security group for database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  tags = {
    Name = "database-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "main-alb"
  }
}

# Target group for frontend
resource "aws_lb_target_group" "frontend" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "frontend-tg"
  }
}

# Target group for backend
resource "aws_lb_target_group" "backend" {
  name     = "backend-tg"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "backend-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ALB Listener Rule for API traffic
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Security group and IAM role lookups remain as before
# All ECS and EFS resources are now in private subnets

# Use created IAM roles
# IAM roles are now created in iam-roles.tf

data "aws_subnets" "efs_subnets" {
  filter {
    name   = "tag:Name" 
    values = var.efs_subnet_names
  }
}

# Database subnet group
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name = "main-db-subnet-group"
  }
}

# RDS PostgreSQL Database
resource "aws_db_instance" "postgres" {
  identifier     = "ecs-postgres-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "ecsdb"
  username = "ecsuser"
  password = "ecspassword123!"  # In production, use AWS Secrets Manager

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "ecs-postgres-db"
  }
}

# Outputs
output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "database_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}