resource "aws_ecs_task_definition" "database" {
  family                   = "ecs-database-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "database"
      image = "941377128979.dkr.ecr.us-east-1.amazonaws.com/ecs-database:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5432
          protocol      = "tcp"
        }
      ]
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

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command = ["CMD-SHELL", "pg_isready -U ecsuser -d ecsdb"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])



  tags = {
    Name = "ecs-database-task"
  }
}

resource "aws_ecs_service" "database" {
  name            = "ecs-database-service"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.database.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = var.service_discovery_service_arn
  }

  depends_on = [aws_ecs_task_definition.database]

  tags = {
    Name = "ecs-database-service"
  }
}

output "service_name" {
  value = aws_ecs_service.database.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.database.arn
} 