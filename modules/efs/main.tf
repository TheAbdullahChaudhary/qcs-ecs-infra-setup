resource "aws_efs_file_system" "database" {
  creation_token = "database-efs"
  encrypted      = true
  
  tags = {
    Name = "database-efs"
  }
}

resource "aws_efs_mount_target" "database" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.database.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.security_group_id]
}

# EFS Access Point for Database (enables Fargate to mount EFS)
resource "aws_efs_access_point" "database" {
  file_system_id = aws_efs_file_system.database.id

  root_directory {
    path = "/database"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }

  posix_user {
    gid = 999
    uid = 999
  }

  tags = {
    Name = "database-access-point"
  }
}

