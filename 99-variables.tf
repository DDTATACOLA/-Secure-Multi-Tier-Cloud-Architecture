# Locals
# Local list of services to loop through
locals {
  services = {
    "ssm"            = "com.amazonaws.${var.region}.ssm"
    "ec2messages"    = "com.amazonaws.${var.region}.ec2messages"
    "ssmmessages"    = "com.amazonaws.${var.region}.ssmmessages"
    "logs"           = "com.amazonaws.${var.region}.logs"
    "secretsmanager" = "com.amazonaws.${var.region}.secretsmanager"
    "kms"            = "com.amazonaws.${var.region}.kms"
  }
}

locals {
  app_fqdn = "${var.subdomain_name}.${var.domain_name}"
}

# ================================================================ #

# Variables

variable "region" {
  description = "The region for this deployment"
  type        = string
  default     = "us-east-2"
}

variable "cidr" {
  description = "The cidr block for the vpc"
  type        = string
  default     = "10.14.0.0/16"
}

variable "secret_name" {
  description = "The name of the secret"
  type        = string
  default     = "lab/rds/mysql"
}

variable "db_name" {
  description = "Name of the MySQL database to create"
  type        = string
  default     = "labdb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

# variable "db_password" {
#   description = "password for the database"
#   type        = string
#   default     = "123password"
#   sensitive   = true
# }

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  # Example default:
  default = ["10.14.1.0/24", "10.14.2.0/24"]
}

variable "azs" {
  description = "List of Availability Zones to use"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  # Example default:
  default = ["10.14.11.0/24", "10.14.12.0/24"]
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access. Empty string disables SSH access."
  type        = string
  default     = ""

  validation {
    condition     = var.ssh_allowed_cidr == "" || can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "Must be a valid CIDR block or empty string to disable SSH."
  }
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_port" {
  description = "MySQL port"
  type        = number
  default     = 3306
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for RDS (free-tier: 20)"
  type        = number
  default     = 20
}

variable "alert_emails" {
  description = "Email address for alarm notifications (requires confirmation)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.alert_emails : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All items must be a valid email address or empty string to skip email subscription."
  }
}

variable "domain_name" {
  description = "The root domain name purchased in Route 53"
  type        = string
  default     = "daequanbritt.com"
}

variable "subdomain_name" {
  description = "The subdomain for the application"
  type        = string
  default     = "app"
}

variable "project_name" {
  description = "The name of the project, used for resource naming"
  type        = string
  default     = "daequan" # change this in terraform.tfvars
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "manage_route53_in_terraform" {
  description = "If true, create/manage Route53 hosted zone in Terraform."
  type        = bool
  default     = true
}

variable "route53_hosted_zone_id" {
  description = "If manage_route53_in_terraform=false, provide existing ID."
  type        = string
  default     = ""
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logging to S3."
  type        = bool
  default     = true
}

variable "alb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs."
  type        = string
  default     = "alb-access-logs"
}

variable "waf_log_destination" {
  description = "Choose ONE destination per WebACL: cloudwatch | s3 | firehose"
  type        = string
  default     = "cloudwatch"
}

variable "waf_log_retention_days" {
  description = "Retention for WAF CloudWatch log group."
  type        = number
  default     = 14
}

variable "enable_waf_sampled_requests_only" {
  description = "If true, filter/redact fields (Placeholder toggle)."
  type        = bool
  default     = false
}
