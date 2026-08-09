output "state_bucket_name" {
  description = "S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.id
}

output "backend_configuration" {
  description = "Values to copy into the dev backend configuration."
  value = {
    bucket       = aws_s3_bucket.terraform_state.id
    key          = "three-tier/dev/terraform.tfstate"
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}
