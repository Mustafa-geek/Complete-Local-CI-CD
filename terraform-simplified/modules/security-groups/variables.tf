variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_security_group_id" {
  type    = string
  default = null
}
