module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  vpc_cidr      = var.vpc_cidr
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
}

module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  db_username  = var.db_username
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public ingress to the application load balancer"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []

    content {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-frontend-sg"
  description = "Allow ALB traffic to frontend ECS tasks"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow ALB traffic to backend ECS tasks"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allow MySQL only from backend ECS tasks"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
  }
}

module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  database_subnet_ids = module.network.database_subnet_ids
  security_group_ids  = [aws_security_group.database.id]
  db_name             = var.db_name
  db_username         = module.secrets.db_username
  db_password         = module.secrets.db_password
  instance_class      = var.db_instance_class
}

module "iam" {
  source = "../../modules/iam"

  project_name                      = var.project_name
  database_secret_arn               = module.secrets.secret_arn
  frontend_ecr_arn                  = module.ecr.frontend_repository_arn
  backend_ecr_arn                   = module.ecr.backend_repository_arn
  github_repository                 = var.github_repository
  create_github_oidc_provider       = var.create_github_oidc_provider
  existing_github_oidc_provider_arn = var.existing_github_oidc_provider_arn
}

resource "aws_acm_certificate" "application" {
  count = var.enable_https ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = var.enable_https ? {
    for option in aws_acm_certificate.application[0].domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "application" {
  count = var.enable_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.application[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

module "alb" {
  source = "../../modules/alb"

  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = aws_security_group.alb.id
  enable_https      = var.enable_https
  certificate_arn   = var.enable_https ? aws_acm_certificate_validation.application[0].certificate_arn : null
}

resource "aws_route53_record" "application" {
  count = var.enable_https ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

module "ecs" {
  source = "../../modules/ecs"

  project_name               = var.project_name
  create_services            = var.create_ecs_services
  application_subnet_ids     = module.network.application_subnet_ids
  frontend_security_group_id = aws_security_group.frontend.id
  backend_security_group_id  = aws_security_group.backend.id
  frontend_target_group_arn  = module.alb.frontend_target_group_arn
  backend_target_group_arn   = module.alb.backend_target_group_arn
  frontend_repository_url    = module.ecr.frontend_repository_url
  backend_repository_url     = module.ecr.backend_repository_url
  initial_image_tag          = var.initial_image_tag
  execution_role_arn         = module.iam.ecs_execution_role_arn
  task_role_arn              = module.iam.ecs_task_role_arn
  database_address           = module.rds.address
  database_port              = module.rds.port
  database_name              = module.rds.db_name
  database_secret_arn        = module.secrets.secret_arn
  frontend_desired_count     = var.frontend_desired_count
  backend_desired_count      = var.backend_desired_count

  depends_on = [module.alb]
}
