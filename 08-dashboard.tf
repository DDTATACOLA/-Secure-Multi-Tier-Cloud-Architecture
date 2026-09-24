# THE ALARM: Triggers if ALB returns 5xx errors (Server Errors)
resource "aws_cloudwatch_metric_alarm" "alb_5xx_alarm" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0" # Trigger if even 1 error occurs
  alarm_description   = "This alarm triggers if the ALB returns any 5xx errors."

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  # Link this to your existing SNS topic from 06-logging.tf
  alarm_actions = [aws_sns_topic.db_incidents.arn]
  ok_actions    = [aws_sns_topic.db_incidents.arn]
}

# THE DASHBOARD: Visual "Control Room" for daequanbritt.com
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-app-health"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: EC2 CPU Utilization
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web.id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization (%)"
        }
      },
      # Widget 2: ALB Request Count
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.region
          title  = "Total ALB Requests"
        }
      },
      # Widget 3: Target Response Time (Latency)
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60
          stat   = "Average"
          region = var.region
          title  = "Avg App Response Time (ms)"
        }
      },
      # Widget 4: ALB 5xx Errors
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
          period = 60
          stat   = "Sum"
          region = var.region
          title  = "ALB 5xx Server Errors"
          color  = "#d62728" # Red for errors
        }
      }
    ]
  })
}
