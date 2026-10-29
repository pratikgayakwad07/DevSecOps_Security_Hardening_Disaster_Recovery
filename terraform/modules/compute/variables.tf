variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "instance_type" { type = string }
variable "ami_id" { type = string }
variable "allowed_app_cidr" { type = string }
variable "root_volume_size" {
  type    = number
  default = 20
}
variable "enable_detailed_monitoring" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
