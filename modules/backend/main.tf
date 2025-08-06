resource "aws_ecs_task_definition" "backend" {
  family                   = "ecs-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-backend:latest"
      essential = true
      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]
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
          value = var.database_host
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
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:4000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })\""]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "ecs-backend-task"
  }
}

resource "aws_ecs_service" "backend" {
  name            = "ecs-backend-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "backend"
    container_port   = 4000
  }

  depends_on = [aws_ecs_task_definition.backend]

  tags = {
    Name = "ecs-backend-service"
  }
}

output "service_name" {
  value = aws_ecs_service.backend.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.backend.arn
}