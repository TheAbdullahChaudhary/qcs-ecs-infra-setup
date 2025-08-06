output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "frontend_url" {
  description = "URL to access the frontend application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_health_url" {
  description = "URL to check backend health"
  value       = "http://${aws_lb.main.dns_name}/api/health"
}

output "frontend_health_url" {
  description = "URL to check frontend health"
  value       = "http://${aws_lb.main.dns_name}/health"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_id
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = module.frontend.service_name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = module.backend.service_name
}

output "database_service_name" {
  description = "Name of the database ECS service"
  value       = module.database.service_name
} 