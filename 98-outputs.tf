output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "alb_dns_name" {
  description = "The DNS name of the Load Balancer"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "The final URL to access your application"
  value       = "https://${var.subdomain_name}.${var.domain_name}"
}

output "alb_arn" {
  description = "The ARN of the ALB (Required for CLI verification)"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "The ARN of the Target Group (Required for CLI verification)"
  value       = aws_lb_target_group.flask_app.arn
}

output "acm_certificate_status" {
  description = "The status of the SSL certificate"
  value       = aws_acm_certificate.cert.status
}

output "route53_zone_id" {
  description = "The Hosted Zone ID for your domain verification"
  # References the dynamic lookup from 07-alb-dns.tf
  value = data.aws_route53_zone.main.zone_id
}

output "app_url_https" {
  description = "The final secure URL for your application"
  value       = "https://${local.app_fqdn}"
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.cert.arn
}

output "daequan_apex_url_https" {
  description = "The root domain URL"
  value       = "https://${var.domain_name}"
}

output "alb_logs_bucket_name" {
  description = "The S3 bucket storing access logs"
  value       = var.enable_alb_access_logs ? aws_s3_bucket.alb_logs.bucket : null
}

output "waf_log_destination" {
  value = var.waf_log_destination
}

output "waf_cw_log_group_name" {
  value = var.waf_log_destination == "cloudwatch" ? try(aws_cloudwatch_log_group.waf_log_group[0].name, null) : null
}
