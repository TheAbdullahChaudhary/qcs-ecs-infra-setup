output "frontend_security_group_id" {
  description = "Security group ID of the frontend service"
  value       = aws_security_group.frontend.id
}

output "task_definition_arn" {
  description = "ARN of the frontend task definition"
  value       = aws_ecs_task_definition.app.arn
}

output "service_name" {
  description = "Name of the frontend ECS service"
  value       = aws_ecs_service.frontend.name
}