# Backend temporarily commented out due to Organization SCP restrictions
# Contact AWS Organization admin to create S3 bucket and DynamoDB table
# Then uncomment and configure this block

terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket-131"
    key          = "Disaster Recovery/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
