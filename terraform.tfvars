aws_region = "us-east-1"

database_name     = "ecsdb"
database_username = "ecsuser"

# Jenkins configuration (optional)
efs_subnet_names         = []
jenkins_efs_sg_name      = "jenkins-efs-sg"
ecs_execution_role_name  = "ecs-execution-role"
ecs_task_role_name       = "ecs-task-role"