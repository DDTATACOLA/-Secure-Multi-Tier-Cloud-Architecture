# IAM policy document for EC2 assume role. 
# This a "Trust" policy 
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"    # A label for this statement (Statement ID)
    effect  = "Allow"            # We are allowing an action
    actions = ["sts:AssumeRole"] # The action is "Assuming a Role" (putting on the identity)

    principals {
      type        = "Service"             # We are trusting an AWS Service...
      identifiers = ["ec2.amazonaws.com"] # ...specifically the EC2 service.
    }
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-role"
  description = "IAM role for EC2 instances to access Secrets Manager and SSM"

  # This links back to block #1. It applies the "Trust Policy" we just wrote.
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

# ================================================================ #

# IAM policy **DOCUMENT** for Secrets Manager access - least privilege
data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid    = "GetDBSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue" # The specific permission to READ a secret
    ]
    # CRITICAL: This restricts access to ONLY the specific DB credential secret.
    # It cannot read other secrets in your account.
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }
}

# IAM **POLICY** for Secrets Manager access
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-${var.environment}-secrets-access"
  description = "Allow EC2 to read database credentials from Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_access.json

  tags = {
    Name = "${var.project_name}-${var.environment}-secrets-access"
  }
}

# ================================================================ #

# Attach secrets access policy to EC2 role
resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.ec2.name             # The Role from block #2
  policy_arn = aws_iam_policy.secrets_access.arn # The Policy from block #4
}

# Instance profile to attach role to EC2
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name # Wraps the role from block #2

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-profile"
  }
}

# ================================================================ #

# Core SSM Functionality (Managed Policy)
# Required for Session Manager to work (Core heartbeat, inventory, etc.)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Tightened Policy (Secrets + Parameters + KMS + Logs)
data "aws_iam_policy_document" "custom_private_access" {
  # Secrets Manager: Scoped to specific ARN
  statement {
    sid       = "RestrictedSecretAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }

  # SSM Parameter Store: Scoped to specific Path
  statement {
    sid       = "RestrictedParamAccess"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/lab/db/*"]
  }

  # KMS: Decryption (Required if Secrets Manager uses Customer Managed Keys)
  statement {
    sid     = "KMSDecrypt"
    effect  = "Allow"
    actions = ["kms:Decrypt"]
    # Ideally scope this to the specific KMS Key ARN
    resources = ["*"]
  }

  # CloudWatch Logs: Allow pushing logs
  statement {
    sid    = "AllowLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "custom_private_access" {
  name        = "${var.project_name}-${var.environment}-private-access"
  description = "Least privilege access for Private EC2"
  policy      = data.aws_iam_policy_document.custom_private_access.json
  tags = {
    Name = "${var.project_name}-${var.environment}-private-access"
  }
}

resource "aws_iam_role_policy_attachment" "custom_private_attach" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.custom_private_access.arn
}

# Helper to get Account ID for ARNs
data "aws_caller_identity" "current" {}
