output "application_url" {
  description = "Application URL. HTTPS uses the configured domain; HTTP uses the ALB DNS name."
  value       = var.enable_https ? "https://${var.domain_name}" : "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "frontend_ecr_repository" {
  value = module.ecr.frontend_repository_url
}

output "backend_ecr_repository" {
  value = module.ecr.backend_repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "github_actions_role_arn" {
  description = "Set this as the GitHub Actions repository variable AWS_ROLE_ARN."
  value       = module.iam.github_actions_role_arn
}

output "database_secret_arn" {
  value     = module.secrets.secret_arn
  sensitive = true
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}
