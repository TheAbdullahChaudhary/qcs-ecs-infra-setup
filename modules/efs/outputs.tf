output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.database.id
}

output "access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.database.id
} 