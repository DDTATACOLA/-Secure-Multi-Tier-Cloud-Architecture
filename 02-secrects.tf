# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 26
  lower            = true
  upper            = true
  numeric          = true
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Builds container intended to hold secrets gained from block #3
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = var.secret_name
  description             = "Database credentials for RDS MySQL"
  recovery_window_in_days = 0 # Lab setting: immediate deletion on destroy

  tags = {
    Name = "${var.project_name}-${var.environment}-db-secret"
  }
}

# Puts the actual username and password inside the container built in block #2
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Using jsonencode() for proper JSON formatting
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    port     = 3306
    host     = aws_db_instance.mysql.address
    dbname   = var.db_name
  })
}

# ================================================================ #

# Parameters

# Store the Database Endpoint (Not sensitive)
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/lab/db/endpoint"
  description = "The endpoint address of the RDS instance"
  type        = "String"
  value       = aws_db_instance.mysql.address
}

# Store the Database Name (Not sensitive)
resource "aws_ssm_parameter" "db_name" {
  name        = "/lab/db/dbname"
  description = "The name of the database"
  type        = "String"
  value       = var.db_name
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(var.db_port)
}
