# Security group for frontend service
resource "aws_security_group" "frontend" {
  name        = "ecs-app-frontend-sg"
  description = "Security group for frontend service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-app-frontend-sg"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = file("${path.module}/app-taskdef.json")
}

# ECS Service
resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.frontend.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [var.frontend_target_group_arn]

  tags = {
    Name = "frontend-service"
  }
}