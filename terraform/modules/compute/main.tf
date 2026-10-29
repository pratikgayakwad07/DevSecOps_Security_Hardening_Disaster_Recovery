# 1. Security Group allowing public SSH (port 22) and HTTP (port 8080)
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Application ingress for HTTP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "Application HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_app_cidr]
  }

  ingress {
    description = "Allow SSH from GitHub Actions runner"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# 2. IAM Role & Profile (for general AWS APIs / SSM if needed later)
resource "aws_iam_role" "instance" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.instance.name
}

# 3. Create an SSH Key Pair resource automatically
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = tls_private_key.pk.public_key_openssh
}

# 4. EC2 Instance in a Public Subnet with Key Pair & Public IP
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_ids[0] # <--- CRITICAL: Must be a public subnet
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true                       # <--- CRITICAL: Must have a public IP
  key_name                    = aws_key_pair.generated_key.key_name # <--- CRITICAL: Injects SSH key
  monitoring                  = var.enable_detailed_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted             = true
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  ebs_optimized             = true
  disable_api_termination   = false

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y unattended-upgrades amazon-ssm-agent auditd ufw
    systemctl enable --now amazon-ssm-agent
    systemctl enable --now auditd
  EOF

  tags = merge(var.tags, { Name = "${var.project_name}-app", Role = "application" })

  lifecycle {
    ignore_changes = [ami]
  }
}