data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_ecr_repository" "frontend" {
  name = var.frontend_ecr_repository_name
}

data "aws_ecr_repository" "backend" {
  name = var.backend_ecr_repository_name
}

data "aws_iam_role" "ecs_execution" {
  name = var.ecs_execution_role_name
}

data "aws_secretsmanager_secret" "database" {
  name = var.database_secret_name
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name               = var.project_name
  vpc_id                     = data.aws_vpc.selected.id
  database_security_group_id = var.database_security_group_id
}

module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  vpc_id            = data.aws_vpc.selected.id
  subnet_ids        = var.alb_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
}

module "ecs" {
  source = "../../modules/ecs"

  project_name               = var.project_name
  subnet_ids                 = var.ecs_subnet_ids
  assign_public_ip           = var.assign_public_ip
  frontend_security_group_id = module.security_groups.frontend_security_group_id
  backend_security_group_id  = module.security_groups.backend_security_group_id
  frontend_target_group_arn  = module.alb.frontend_target_group_arn
  backend_target_group_arn   = module.alb.backend_target_group_arn

  frontend_image     = "${data.aws_ecr_repository.frontend.repository_url}:${var.image_tag}"
  backend_image      = "${data.aws_ecr_repository.backend.repository_url}:${var.image_tag}"
  execution_role_arn = data.aws_iam_role.ecs_execution.arn

  database_host       = var.database_host
  database_port       = var.database_port
  database_name       = var.database_name
  database_secret_arn = data.aws_secretsmanager_secret.database.arn

  frontend_desired_count = var.frontend_desired_count
  backend_desired_count  = var.backend_desired_count

  depends_on = [module.alb]
}
