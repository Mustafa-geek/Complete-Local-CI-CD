variable "project_name" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "frontend_ecr_arn" {
  type = string
}

variable "backend_ecr_arn" {
  type = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format."
  type        = string
}

variable "create_github_oidc_provider" {
  type    = bool
  default = true
}

variable "existing_github_oidc_provider_arn" {
  type    = string
  default = null
}
