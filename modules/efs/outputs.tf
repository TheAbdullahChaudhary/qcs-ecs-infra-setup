output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.jenkins.id
}

output "access_point_arn" {
  description = "ARN of the EFS access point"
  value       = aws_efs_access_point.jenkins.arn
} 