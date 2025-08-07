provider "aws" {
  region = "eu-west-1"
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

resource "aws_service_discovery_service" "backend" {
  name = "ecs-backend-service"

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
    security_groups = [aws_security_group.alb.id]
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
  name = "ecs-task-execution-role"

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
  name = "ecs-task-role"

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

# EFS Access Policy for Task Role
resource "aws_iam_policy" "efs_access_policy" {
  name        = "elasticfilesystem-ClientRootAccess"
  description = "Policy for EFS access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeAccessPoints"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_efs_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.efs_access_policy.arn
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
  name        = "Frontend-Target-Group"
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

  tags = {
    Name = "Frontend-Target-Group"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "Backend-Target-Group"
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

  tags = {
    Name = "Backend-Target-Group"
  }
}

# ALB Listener
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ALB Listener Rule for Backend
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

# ECS Task Definitions
module "database_task" {
  source = "./modules/ecs-task-definition"

  family                = "ecs-database-task"
  container_name        = "database"
  container_image       = var.database_image
  container_port        = 5432
  cpu                   = 512
  memory                = 1024
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = aws_iam_role.ecs_task_role.arn
  log_group_name        = aws_cloudwatch_log_group.database.name
  log_group_region      = "eu-west-1"

  environment = [
    {
      name  = "POSTGRES_DB"
      value = "ecsdb"
    },
    {
      name  = "POSTGRES_USER"
      value = "ecsuser"
    },
    {
      name  = "POSTGRES_PASSWORD"
      value = "ecspassword"
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]
    interval    = 30
    timeout     = 5
    retries     = 3
    start_period = 60
  }

  efs_volume = {
    name = "database-efs"
    file_system_id = module.efs.efs_id
    access_point_id = module.efs.access_point_id
    root_directory = "/"
    transit_encryption = "ENABLED"
    mount_point = "/var/lib/postgresql/data"
  }
}

module "backend_task" {
  source = "./modules/ecs-task-definition"

  family                = "ecs-backend-task"
  container_name        = "backend"
  container_image       = var.backend_image
  container_port        = 4000
  cpu                   = 256
  memory                = 512
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = aws_iam_role.ecs_task_role.arn
  log_group_name        = aws_cloudwatch_log_group.backend.name
  log_group_region      = "eu-west-1"

  environment = [
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "POSTGRES_DB"
      value = "ecsdb"
    },
    {
      name  = "POSTGRES_HOST"
      value = "ecs-database-service.ecs.internal"
    },
    {
      name  = "POSTGRES_PORT"
      value = "5432"
    },
    {
      name  = "POSTGRES_USER"
      value = "ecsuser"
    },
    {
      name  = "POSTGRES_PASSWORD"
      value = "ecspassword"
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]
    interval    = 30
    timeout     = 5
    retries     = 3
    start_period = 60
  }
}

module "frontend_task" {
  source = "./modules/ecs-task-definition"

  family                = "ecs-frontend-task"
  container_name        = "frontend"
  container_image       = var.frontend_image
  container_port        = 80
  cpu                   = 256
  memory                = 512
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = null
  log_group_name        = aws_cloudwatch_log_group.frontend.name
  log_group_region      = "eu-west-1"

  environment = [
    {
      name  = "REACT_APP_API_URL"
      value = "http://ecs-backend-service.ecs.internal:4000/api"
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    start_period = 60
  }
}

# ECS Services
module "database" {
  source = "./modules/ecs-service"

  name                = "ecs-database-service"
  cluster_id          = module.ecs_cluster.cluster_id
  task_definition_arn = module.database_task.task_definition_arn
  desired_count       = 1

  subnets         = module.vpc.private_subnet_ids
  security_groups = [aws_security_group.database.id]
  assign_public_ip = false

  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_service_id   = aws_service_discovery_service.database.id

  depends_on = [module.efs]
}

module "backend" {
  source = "./modules/ecs-service"

  name                = "ecs-backend-service"
  cluster_id          = module.ecs_cluster.cluster_id
  task_definition_arn = module.backend_task.task_definition_arn
  desired_count       = 1

  subnets         = module.vpc.private_subnet_ids
  security_groups = [aws_security_group.backend.id]
  assign_public_ip = false

  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_service_id   = aws_service_discovery_service.backend.id

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 4000
  }

  depends_on = [module.database]
}

module "frontend" {
  source = "./modules/ecs-service"

  name                = "ecs-frontend-service"
  cluster_id          = module.ecs_cluster.cluster_id
  task_definition_arn = module.frontend_task.task_definition_arn
  desired_count       = 1

  subnets         = module.vpc.public_subnet_ids
  security_groups = [aws_security_group.frontend.id]
  assign_public_ip = true

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [module.backend]
}

