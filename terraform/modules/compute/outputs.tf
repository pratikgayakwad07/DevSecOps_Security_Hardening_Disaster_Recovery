output "instance_id" { value = aws_instance.this.id }
output "security_group_id" { value = aws_security_group.app.id }
output "private_key_pem" {
  value     = tls_private_key.pk.private_key_pem
  sensitive = true
}

# Output Public IP for Ansible Dynamic Inventory
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.this.public_ip
}