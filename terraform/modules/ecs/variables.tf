variable "project_name" {
  type = string
}

variable "create_services" {
  description = "Create ECS task definitions and services after initial images exist in ECR."
  type        = bool
  default     = false
}

variable "application_subnet_ids" {
  type = list(string)
}

variable "frontend_security_group_id" {
  type = string
}

variable "backend_security_group_id" {
  type = string
}

variable "frontend_target_group_arn" {
  type = string
}

variable "backend_target_group_arn" {
  type = string
}

variable "frontend_repository_url" {
  type = string
}

variable "backend_repository_url" {
  type = string
}

variable "initial_image_tag" {
  description = "Existing ECR image tag used for the first ECS deployment."
  type        = string
  default     = "latest"
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "database_address" {
  type = string
}

variable "database_port" {
  type = number
}

variable "database_name" {
  type = string
}

variable "database_secret_arn" {
  type = string
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "backend_desired_count" {
  type    = number
  default = 1
}

variable "frontend_cpu" {
  type    = number
  default = 256
}

variable "frontend_memory" {
  type    = number
  default = 512
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}
