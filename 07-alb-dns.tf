# Look up your existing Hosted Zone (since you bought it via Console)
data "aws_route53_zone" "main" {
  name = var.domain_name
  # zone_id      = "Z04376043T34812BLBEDG" # This is here for debugging
  private_zone = false
}

# Request an SSL Certificate from ACM
resource "aws_acm_certificate" "cert" {
  domain_name       = local.app_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS records to validate that you own the domain
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for the certificate to be issued
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# The Application Load Balancer (ALB)
resource "aws_lb" "main" {
  # Industry Standard: project-env-resource
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  # Enable ALB Access Logging to S3: 1C Bonus D
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for your Flask App
resource "aws_lb_target_group" "flask_app" {
  name     = "flask-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Attach your EC2 instance to the Target Group
resource "aws_lb_target_group_attachment" "flask_app" {
  target_group_arn = aws_lb_target_group.flask_app.arn
  target_id        = aws_instance.web.id
  port             = 80
}

# ALIAS Record: app.daequanbritt.com -> ALB
# This is the sign pointing users to your secure entry point.
resource "aws_route53_record" "app_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# HTTPS Listener (Port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"

  # Updated policy for enterprise deployments and secure entry patterns
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # Use the certificate directly
  certificate_arn = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }

  depends_on = [
    aws_acm_certificate_validation.cert
  ]
}

# HTTP Redirect Listener (Port 80 -> 443)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
