# EC2 instance running the Flask notes application
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # This wildcard finds the latest version of AL2023 for standard x86 processors
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # no public ip
  associate_public_ip_address = false

  # User data script to install and run Flask app
  user_data_base64 = filebase64("./1a_user_data_tf.sh")

  # Root volume configuration
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Disable detailed monitoring for free tier
  monitoring = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only for security
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web"
  }

  # Ensure secrets, RDS, and NAT Gateway are available before EC2 starts
  depends_on = [
    aws_secretsmanager_secret_version.db_credentials,
    aws_db_instance.mysql,
    aws_nat_gateway.main
  ]
}

# ================================================================ #

# RDS

resource "aws_db_instance" "mysql" {
  identifier = "${var.project_name}-${var.environment}-mysql"

  # Engine configuration
  engine            = "mysql"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = var.db_port

  # Network configuration - PRIVATE subnets, NOT publicly accessible
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # Critical: RDS not exposed to internet
  multi_az               = false # Single AZ for lab cost savings

  # Parameter group
  parameter_group_name = "default.mysql8.0"

  # Backup and maintenance - minimal for lab
  backup_retention_period = 0
  skip_final_snapshot     = true  # Lab setting: allows quick teardown
  deletion_protection     = false # Lab setting: allows terraform destroy

  # Performance Insights disabled for free tier
  performance_insights_enabled = false

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql"
  }
}
