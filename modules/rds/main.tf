# RDS Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "ecs-app-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "ECS App DB subnet group"
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "ecs-app-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.backend_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-app-rds-sg"
  }
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier     = "ecs-app-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.database_username
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "ecs-app-postgres"
  }
}

# Update the existing secret with database credentials
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.secret_name
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.db_password.result
    host     = aws_db_instance.postgres.endpoint
    port     = aws_db_instance.postgres.port
    dbname   = var.database_name
  })
}