resource "aws_ecs_task_definition" "frontend" {
  family                   = "ecs-frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-frontend:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "REACT_APP_API_URL"
          value = "/api"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost/health || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "ecs-frontend-task"
  }
}

resource "aws_ecs_service" "frontend" {
  name            = "ecs-frontend-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_ecs_task_definition.frontend]

  tags = {
    Name = "ecs-frontend-service"
  }
}

output "service_name" {
  value = aws_ecs_service.frontend.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.frontend.arn
}