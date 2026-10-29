variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "task5-secops"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,25}$", var.project_name))
    error_message = "Use 3-26 lowercase letters, digits, or hyphens; begin with a letter."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.11.0/24", "10.40.12.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "github_repository" {
  type        = string
  description = "Exact owner/repository allowed to assume the GitHub Actions role."
}

variable "github_ref" {
  type        = string
  default     = "main"
  description = "Protected branch allowed to assume the GitHub Actions role."
}

variable "state_bucket_arn" {
  type        = string
  description = "ARN of the pre-created Terraform state bucket."
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "allowed_app_cidr" {
  type        = string
  default     = "10.40.0.0/16"
  description = "Trusted source CIDR for app port 8080; use a narrow CIDR appropriate to your topology."
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "enable_detailed_monitoring" {
  type    = bool
  default = true
}

variable "audit_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for CloudTrail logs."
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "audit_log_retention_days" {
  type    = number
  default = 2555
}

variable "audit_noncurrent_retention_days" {
  type    = number
  default = 365
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Optional security alert email; confirm SNS subscription."
}

variable "tags" {
  type    = map(string)
  default = { Environment = "sandbox", Owner = "platform-team" }
}

