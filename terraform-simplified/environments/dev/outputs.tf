output "application_url" {
  description = "HTTP URL exposed by the Application Load Balancer."
  value       = "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "frontend_service_name" {
  value = module.ecs.frontend_service_name
}

output "backend_service_name" {
  value = module.ecs.backend_service_name
}

output "frontend_ecr_repository_url" {
  value = data.aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_repository_url" {
  value = data.aws_ecr_repository.backend.repository_url
}

output "backend_security_group_id" {
  description = "Useful when allowing backend-to-database traffic outside Terraform."
  value       = module.security_groups.backend_security_group_id
}
