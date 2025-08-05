variable "vpc_id" {
  description = "VPC ID where RDS will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "backend_security_group_id" {
  description = "Security group ID of the backend service"
  type        = string
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "ecsdb"
}

variable "database_username" {
  description = "Username for the database"
  type        = string
  default     = "ecsuser"
}

variable "secret_name" {
  description = "Name of the existing secret in AWS Secrets Manager"
  type        = string
}