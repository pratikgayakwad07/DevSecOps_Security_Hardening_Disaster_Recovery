data "aws_caller_identity" "current" {}

# Canonical's current Ubuntu 22.04 LTS AMI for the selected AWS region.
# This avoids committing a region-specific, stale AMI ID.
data "aws_ami" "ubuntu_lts" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# This configuration is intended for a new environment. If it is applied to
# existing state, move the addresses to module.security_monitoring first.

module "vpc" {
  source                  = "./modules/vpc"
  project_name            = var.project_name
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  availability_zones      = var.availability_zones
  enable_nat_gateway      = var.enable_nat_gateway
  flow_log_retention_days = var.log_retention_days
  tags                    = var.tags
}

module "iam_oidc" {
  source            = "./modules/iam_oidc"
  project_name      = var.project_name
  github_repository = var.github_repository
  github_ref        = var.github_ref
  state_bucket_arn  = var.state_bucket_arn
  tags              = var.tags
}

module "compute" {
  source                     = "./modules/compute"
  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_type              = var.instance_type
  ami_id                     = data.aws_ami.ubuntu_lts.id
  allowed_app_cidr           = var.allowed_app_cidr
  root_volume_size           = var.root_volume_size
  enable_detailed_monitoring = var.enable_detailed_monitoring
  tags                       = var.tags
}

module "security_monitoring" {
  source                          = "./modules/security_monitoring"
  project_name                    = var.project_name
  aws_region                      = var.aws_region
  audit_bucket_name               = var.audit_bucket_name
  log_retention_days              = var.log_retention_days
  audit_log_retention_days        = var.audit_log_retention_days
  audit_noncurrent_retention_days = var.audit_noncurrent_retention_days
  alert_email                     = var.alert_email
  monitored_instance_id           = module.compute.instance_id
  tags                            = var.tags
}
