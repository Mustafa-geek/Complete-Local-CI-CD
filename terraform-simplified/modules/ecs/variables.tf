variable "project_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "assign_public_ip" {
  type    = bool
  default = true
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

variable "frontend_image" {
  type = string
}

variable "backend_image" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "database_host" {
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
