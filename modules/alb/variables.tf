variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "name_prefix" {
  description = "Name prefix for ALB resources"
  type        = string
  default     = "ecs-app"
}