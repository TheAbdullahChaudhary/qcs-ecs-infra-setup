# Terraform variables for ECS deployment

# EFS subnet names (will be created by VPC module)
efs_subnet_names = ["ecs_vpc-private-us-east-1a", "ecs_vpc-private-us-east-1b"]

# Jenkins EFS security group name (will be created)
jenkins_efs_sg_name = "jenkins-efs-sg"

# ECS execution role name (will be created)
ecs_execution_role_name = "ecsTaskExecutionRole"

# ECS task role name (will be created)
ecs_task_role_name = "ecsTaskRole"