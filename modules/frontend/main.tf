variable "family" {
  description = "Task definition family name"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
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

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}