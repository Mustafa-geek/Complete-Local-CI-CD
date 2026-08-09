variable "aws_region" {
  description = "AWS region used for the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "project_name" {
  description = "Project tag value."
  type        = string
  default     = "three-tier"
}
