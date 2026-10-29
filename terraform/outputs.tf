output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "instance_id" { value = module.compute.instance_id }
output "security_alert_topic_arn" { value = module.security_monitoring.security_alert_topic_arn }
output "cloudtrail_name" { value = module.security_monitoring.cloudtrail_name }
output "instance_public_ip" { value = module.compute.instance_public_ip } 