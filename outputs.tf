output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "frontend_target_group_arn" {
  description = "Frontend target group ARN"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "Backend target group ARN"
  value       = aws_lb_target_group.backend.arn
}

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "database_service_name" {
  description = "Database service name"
  value       = module.database.service_name
}

output "backend_service_name" {
  description = "Backend service name"
  value       = module.backend.service_name
}

output "frontend_service_name" {
  description = "Frontend service name"
  value       = module.frontend.service_name
}

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = module.efs.efs_id
}

output "efs_access_point_id" {
  description = "EFS access point ID"
  value       = module.efs.access_point_id
}

output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "database_service_discovery_service_id" {
  description = "Database service discovery service ID"
  value       = aws_service_discovery_service.database.id
}

output "backend_service_discovery_service_id" {
  description = "Backend service discovery service ID"
  value       = aws_service_discovery_service.backend.id
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    frontend = aws_cloudwatch_log_group.frontend.name
    backend  = aws_cloudwatch_log_group.backend.name
    database = aws_cloudwatch_log_group.database.name
  }
}

output "security_group_ids" {
  description = "Security group IDs"
  value = {
    alb      = aws_security_group.alb.id
    frontend = aws_security_group.frontend.id
    backend  = aws_security_group.backend.id
    database = aws_security_group.database.id
    efs      = aws_security_group.efs.id
  }
}

output "iam_role_arns" {
  description = "IAM role ARNs"
  value = {
    task_execution_role = aws_iam_role.ecs_task_execution_role.arn
    task_role          = aws_iam_role.ecs_task_role.arn
  }
} 