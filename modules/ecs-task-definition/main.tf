resource "aws_ecs_task_definition" "main" {
  family                   = var.family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = var.container_image
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = var.environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.log_group_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = var.health_check != null ? {
        command     = var.health_check.command
        interval    = var.health_check.interval
        timeout     = var.health_check.timeout
        retries     = var.health_check.retries
        startPeriod = var.health_check.start_period
      } : null
      mountPoints = var.efs_volume != null ? [
        {
          sourceVolume  = var.efs_volume.name
          containerPath = var.efs_volume.mount_point
          readOnly      = false
        }
      ] : []
      essential = true
    }
  ])

  dynamic "volume" {
    for_each = var.efs_volume != null ? [var.efs_volume] : []
    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id          = volume.value.file_system_id
        transit_encryption      = volume.value.transit_encryption
        transit_encryption_port = 2049
        authorization_config {
          access_point_id = volume.value.access_point_id
          iam             = "ENABLED"
        }
      }
    }
  }

  tags = {
    Name = var.family
  }
}
