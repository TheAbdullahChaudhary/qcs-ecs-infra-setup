output "backend_security_group_id" {
  description = "Security group ID of the backend service"
  value       = aws_security_group.backend.id
}

output "task_definition_arn" {
  description = "ARN of the backend task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "service_name" {
  description = "Name of the backend ECS service"
  value       = aws_ecs_service.backend.name
}