resource "aws_cloudwatch_log_group" "app_logs" {
  name = "/aws/ec2/lab-rds-app"

  # Clean up logs after 7 days
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-lab-rds-app-logs"
  }
}

# THE FILTER: Looks for error patterns in the logs
resource "aws_cloudwatch_log_metric_filter" "db_failure" {
  name           = "DBConnectionFailureFilter"
  pattern        = "\"Database connection failed\"" # Search string
  log_group_name = aws_cloudwatch_log_group.app_logs.name

  metric_transformation {
    name      = "DBConnectionFailures"
    namespace = "Lab/RDSApp"
    value     = "1" # Add 1 to the count every time this pattern is found
    unit      = "Count"
  }
}

# ================================================================ #

resource "aws_sns_topic" "db_incidents" {
  name         = "lab_db_incidents"
  display_name = "Lab DB Incidents"

  tags = {
    Name = "${var.project_name}-${var.environment}-db-incidents-topic"
  }
}

# Email subscription for SNS topic (requires email confirmation)
resource "aws_sns_topic_subscription" "email_alerts" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.db_incidents.arn
  protocol  = "email"
  endpoint  = each.value
}

# ================================================================ #

# THE ALARM: Triggers if failures > 0
resource "aws_cloudwatch_metric_alarm" "db_failure_alarm" {
  alarm_name          = "lab-db-connection-failure"
  alarm_description   = "Triggers when DB connection failures occur"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  metric_name         = "DBConnectionFailures"
  namespace           = "Lab/RDSApp"
  statistic           = "Sum"
  threshold           = 0
  evaluation_periods  = 1
  period              = 60 # Check every 60 seconds
  datapoints_to_alarm = 1

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.db_incidents.arn]
  ok_actions    = [aws_sns_topic.db_incidents.arn]

  tags = {
    Name = "${var.project_name}-${var.environment}-lab-rds-app-alarm"
  }
}

# ================================================================ #
# 1C Bonus D: ALB Logging to S3 and Route 53 Apex Alias Record 
# ================================================================ #

# Automatically fetch the AWS ELB Service Account for your current region (us-east-2)
data "aws_elb_service_account" "main" {}

# The S3 Bucket for ALB Logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-${var.environment}-alb-access-logs-app"
  force_destroy = true # Allows easy lab teardown

  tags = { Name = "${var.project_name}-${var.environment}-alb-logs" }
}

# THE ALIAS RECORD: daequanbritt.com (Apex) -> ALB
# This is the "Front Gate" for users who don't type 'app.'
# Overwrites the default/cloudfront root record if it exists.
resource "aws_route53_record" "apex_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Bucket Policy: Required to allow the ALB service to write logs
resource "aws_s3_bucket_policy" "allow_alb_logging" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = data.aws_elb_service_account.main.arn
        # AWS = "arn:aws:iam::127311923021:root" # ELB Account ID for us-east-2
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.alb_logs.arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

# ================================================================ #
# 1C Bonus E: WAF Logging Configuration to CloudWatch or S3
# ================================================================ #

# 1. CloudWatch Log Group Destination (Selected by Default)
resource "aws_cloudwatch_log_group" "waf_log_group" {
  count             = var.waf_log_destination == "cloudwatch" ? 1 : 0
  name              = "aws-waf-logs-${var.project_name}-webacl"
  retention_in_days = var.waf_log_retention_days
}

# 2. S3 Bucket Destination (Optional alternative)
resource "aws_s3_bucket" "waf_s3_logs" {
  count         = var.waf_log_destination == "s3" ? 1 : 0
  bucket        = "aws-waf-logs-${var.project_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# 3. The Logging Configuration (The "Bridge")
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn = aws_wafv2_web_acl.main.arn # Links to your ACL in 09-waf.tf

  log_destination_configs = [
    var.waf_log_destination == "cloudwatch" ? aws_cloudwatch_log_group.waf_log_group[0].arn : aws_s3_bucket.waf_s3_logs[0].arn
  ]
}
