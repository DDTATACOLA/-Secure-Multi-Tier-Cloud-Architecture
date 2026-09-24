# Create the Web ACL (The Firewall)
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.environment}-web-acl"
  description = "WAF for ALB to block common web attacks"
  scope       = "REGIONAL" # Use REGIONAL for ALB; CLOUDFRONT for CDN

  default_action {
    allow {}
  }

  # Add a managed rule set (ex: Core Rule Set for SQLi, XSS)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-waf"
  }
}

# Associate the WAF with your ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn # References the ALB in the 07-alb-dns.tf
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
