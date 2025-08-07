variable "family" {
  description = "Task definition family name"
  type        = string
}

variable "container_name" {
  description = "Container name"
  type        = string
}

variable "container_image" {
  description = "Container image URI"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
}

variable "memory" {
  description = "Memory for the task in MB"
  type        = number
}

variable "execution_role_arn" {
  description = "Execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "Task role ARN"
  type        = string
  default     = null
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "log_group_region" {
  description = "CloudWatch log group region"
  type        = string
}

variable "environment" {
  description = "Environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "health_check" {
  description = "Health check configuration"
  type = object({
    command     = list(string)
    interval    = number
    timeout     = number
    retries     = number
    start_period = number
  })
  default = null
}

variable "efs_volume" {
  description = "EFS volume configuration"
  type = object({
    name = string
    file_system_id = string
    access_point_id = string
    root_directory = string
    transit_encryption = string
    mount_point = string
  })
  default = null
}
