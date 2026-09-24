resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway for public subnet internet access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# ================================================================ #

# Public subnets - one per AZ for EC2 instances
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]

  # Using element() we will loop back tot he first AZ if we have more subnets than AZs
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index}"
  }
}

# Private subnets - one per AZ for EC2 instances
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]

  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index}"
  }
}

# ================================================================ #

# Public route table with internet gateway route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ===================================== #

# Private route table - no internet route (isolated)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

# ROUTE: Send non-local traffic from Private Subnets to NAT Gateway
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ================================================================ #

# DB Subnet Group for RDS - requires subnets in at least 2 AZs
resource "aws_db_subnet_group" "mysql" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Subnet group for RDS MySQL in private subnets"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# ================================================================ #

# NAT GATEWAY CONFIGURATION
# Required for Private Instances to download packages (yum/pip)

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Puts it in the first public subnet

  tags = {
    Name = "${var.project_name}-${var.environment}-main-nat"
  }
  depends_on = [aws_internet_gateway.main]
}

# ================================================================ #

# ENDPOINTS

# Interface Endpoints (Powered by PrivateLink)
resource "aws_vpc_endpoint" "interface" {
  for_each = local.services

  vpc_id            = aws_vpc.main.id
  service_name      = each.value
  vpc_endpoint_type = "Interface"

  # Place endpoints in private subnets so private EC2s can reach them
  subnet_ids = aws_subnet.private[*].id

  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true # Critical: Allows AWS DNS to resolve internal IPs

  tags = {
    Name = "${var.project_name}-${var.environment}-endpoint-${each.key}"
  }
}

# Gateway Endpoint (Specific for S3)
# S3 uses a Gateway, not an Interface endpoint (usually).
# It does NOT use Security Groups; it uses Route Tables.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to the PRIVATE Route Table
  route_table_ids = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-endpoint-s3"
  }
}
