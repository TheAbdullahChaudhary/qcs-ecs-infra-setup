output "service_id" {
  description = "Service ID"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Service name"
  value       = aws_ecs_service.main.name
}

output "service_arn" {
  description = "Service ARN"
  value       = aws_ecs_service.main.arn
}

output "service_cluster" {
  description = "Service cluster"
  value       = aws_ecs_service.main.cluster
}

output "service_desired_count" {
  description = "Service desired count"
  value       = aws_ecs_service.main.desired_count
}
