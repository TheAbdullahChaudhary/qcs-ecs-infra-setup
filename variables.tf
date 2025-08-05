variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "ecsdb"
}

variable "database_username" {
  description = "Username for the PostgreSQL database"
  type        = string
  default     = "ecsuser"
}

# Legacy variables for Jenkins (keeping for compatibility)
variable "efs_subnet_names" {
  description = "List of subnet names for EFS mount targets."
  type        = list(string)
  default     = []
}

variable "jenkins_efs_sg_name" {
  description = "Name of the security group for Jenkins EFS."
  type        = string
  default     = "jenkins-efs-sg"
}

variable "ecs_execution_role_name" {
  description = "Name of the ECS execution role."
  type        = string
  default     = "ecs-execution-role"
}

variable "ecs_task_role_name" {
  description = "Name of the ECS task role."
  type        = string
  default     = "ecs-task-role"
}