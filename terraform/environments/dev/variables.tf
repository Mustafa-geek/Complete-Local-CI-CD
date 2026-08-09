variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "three-tier"
}

variable "github_repository" {
  description = "GitHub repository in owner/name format, for example owner/Three-Tier-Project."
  type        = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "db_name" {
  type    = string
  default = "mydb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "create_ecs_services" {
  description = "Enable after the initial frontend and backend images have been pushed to ECR."
  type        = bool
  default     = false
}

variable "initial_image_tag" {
  description = "Existing ECR image tag used for the first ECS service deployment."
  type        = string
  default     = "latest"
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "backend_desired_count" {
  type    = number
  default = 1
}

variable "enable_https" {
  description = "Create ACM validation, HTTPS listener, and Route53 alias when true."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "DNS name for the application when HTTPS is enabled."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted-zone ID containing domain_name."
  type        = string
  default     = null
}

variable "create_github_oidc_provider" {
  description = "Set false when the AWS account already has the GitHub Actions OIDC provider."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN when create_github_oidc_provider is false."
  type        = string
  default     = null
}
