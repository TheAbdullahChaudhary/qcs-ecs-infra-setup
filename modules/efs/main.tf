resource "aws_efs_file_system" "jenkins" {
  creation_token = "jenkins-efs"
  tags = {
    Name = "jenkins-efs"
  }
}

resource "aws_efs_mount_target" "jenkins" {
  for_each = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.jenkins.id
  subnet_id       = each.value
  security_groups = [var.security_group_id]
}

# EFS Access Point for Jenkins (enables Fargate to mount EFS)
resource "aws_efs_access_point" "jenkins" {
  file_system_id = aws_efs_file_system.jenkins.id

  root_directory {
    path = "/jenkins"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = {
    Name = "jenkins-access-point"
  }
}