# The Security Group for the VPC Endpoints (The "Door")
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  description = "Allow HTTPS from private subnets to AWS Services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr] # Allow resources inside VPC to talk to endpoints
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  }
}

# ================================================================ #

# EC2 Security Group (No SSH)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for private EC2 instance"
  vpc_id      = aws_vpc.main.id

  # # OUTBOUND: Allow instance to talk to the Nat Gateway
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "HTTP from ALB ONLY"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb_sg.id
  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-from-alb"
  }
}

# ================================================================ #

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS MySQL - allows access only from EC2 SG"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Inbound: MySQL from EC2 security group only (SG-to-SG reference)
resource "aws_vpc_security_group_ingress_rule" "rds_mysql_from_ec2" {
  security_group_id = aws_security_group.rds.id
  description       = "MySQL from EC2 security group"
  ip_protocol       = "tcp"
  from_port         = var.db_port
  to_port           = var.db_port

  # SG-to-SG reference - this is the critical security pattern
  referenced_security_group_id = aws_security_group.ec2.id

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-mysql-from-ec2"
  }
}

# ================================================================ #

# New ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow all inbound HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}
