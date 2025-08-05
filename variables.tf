# Define variables as needed for your modules

variable "efs_subnet_names" {
  description = "List of subnet names for EFS mount targets."
  type        = list(string)
}

variable "jenkins_efs_sg_name" {
  description = "Name of the security group for Jenkins EFS."
  type        = string
}

variable "ecs_execution_role_name" {
  description = "Name of the ECS execution role."
  type        = string
}

variable "ecs_task_role_name" {
  description = "Name of the ECS task role."
  type        = string
}