output "audit_bucket_name" { value = aws_s3_bucket.audit_logs.id }
output "cloudtrail_name" { value = aws_cloudtrail.main.name }
output "security_alert_topic_arn" { value = aws_sns_topic.security_alerts.arn }
