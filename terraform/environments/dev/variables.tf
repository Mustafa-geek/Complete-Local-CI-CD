variable "aws_region" {
  description = "AWS region for the application stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for application resources."
  type        = string
  default     = "three-tier"
}

variable "vpc_id" {
  description = "Existing VPC ID supplied by the environment/platform team."
  type        = string
}

variable "alb_subnet_ids" {
  description = "Existing subnets for the public Application Load Balancer. Use subnets in at least two Availability Zones."
  type        = list(string)
}

variable "ecs_subnet_ids" {
  description = "Existing subnets where ECS Fargate tasks will run."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Set true when ECS tasks run in public subnets without NAT. Set false for private subnets with NAT/VPC endpoints."
  type        = bool
  default     = true
}

variable "frontend_ecr_repository_name" {
  description = "Name of an existing ECR repository containing the frontend image."
  type        = string
  default     = "three-tier-frontend"
}

variable "backend_ecr_repository_name" {
  description = "Name of an existing ECR repository containing the backend image."
  type        = string
  default     = "three-tier-backend"
}

variable "image_tag" {
  description = "Existing image tag used by the initial ECS task definitions."
  type        = string
  default     = "latest"
}

variable "ecs_execution_role_name" {
  description = "Name of an existing ECS task execution IAM role."
  type        = string
  default     = "ecsTaskExecutionRole"
}

variable "database_host" {
  description = "Hostname of the existing MySQL/RDS database."
  type        = string
}

variable "database_port" {
  description = "Database port."
  type        = number
  default     = 3306
}

variable "database_name" {
  description = "Database/schema name."
  type        = string
  default     = "mydb"
}

variable "database_secret_name" {
  description = "Name of an existing Secrets Manager secret containing JSON keys username and password."
  type        = string
  default     = "three-tier/database/credentials"
}

variable "database_security_group_id" {
  description = "Existing database security group ID. When set, Terraform adds MySQL ingress from the backend ECS security group."
  type        = string
  default     = null
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}

variable "backend_desired_count" {
  type    = number
  default = 1
}
