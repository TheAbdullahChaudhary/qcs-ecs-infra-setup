provider "aws" {
  region = "us-east-1"
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
}

# EFS for database persistence
module "efs" {
  source            = "./modules/efs"
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = aws_security_group.efs.id
}

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "ecs.internal"
  description = "Private DNS namespace for ECS services"
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "database" {
  name = "ecs-database-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ECS Cluster
module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  name   = "3-tier-ecs-cluster"
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "ecs-alb-sg"
  description = "Security group for ALB"
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
    Name = "ecs-alb-sg"
  }
}

resource "aws_security_group" "frontend" {
  name        = "ecs-frontend-sg"
  description = "Security group for frontend"
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
    Name = "ecs-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "ecs-backend-sg"
  description = "Security group for backend"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-backend-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "ecs-database-sg"
  description = "Security group for database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-database-sg"
  }
}

resource "aws_security_group" "efs" {
  name        = "ecs-efs-sg"
  description = "Security group for EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.database.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-efs-sg"
  }
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "ecs-alb"
  }
}

# Target Groups
resource "aws_lb_target_group" "frontend" {
  name        = "ecs-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "ecs-backend-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# ALB Listeners
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.frontend.arn
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

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/backend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "database" {
  name              = "/ecs/database"
  retention_in_days = 7
}

# ECS Task Definitions and Services
module "database" {
  source = "./modules/database"
  
  cluster_name                = module.ecs_cluster.cluster_name
  execution_role_arn          = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn               = aws_iam_role.ecs_task_role.arn
  subnet_ids                  = module.vpc.private_subnet_ids
  security_group_ids          = [aws_security_group.database.id]
  efs_file_system_id          = module.efs.efs_id
  efs_access_point_id         = module.efs.access_point_id
  log_group_name              = aws_cloudwatch_log_group.database.name
  service_discovery_service_arn = aws_service_discovery_service.database.arn
}

module "backend" {
  source = "./modules/backend"
  
  cluster_name       = module.ecs_cluster.cluster_name
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.backend.id]
  target_group_arn   = aws_lb_target_group.backend.arn
  log_group_name     = aws_cloudwatch_log_group.backend.name
}

module "frontend" {
  source = "./modules/frontend"
  
  cluster_name       = module.ecs_cluster.cluster_name
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [aws_security_group.frontend.id]
  target_group_arn   = aws_lb_target_group.frontend.arn
  log_group_name     = aws_cloudwatch_log_group.frontend.name
  alb_url            = "http://${aws_lb.main.dns_name}"
}

