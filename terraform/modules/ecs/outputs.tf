output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "frontend_service_name" {
  value = var.create_services ? aws_ecs_service.frontend[0].name : null
}

output "backend_service_name" {
  value = var.create_services ? aws_ecs_service.backend[0].name : null
}

output "frontend_task_family" {
  value = "${var.project_name}-frontend"
}

output "backend_task_family" {
  value = "${var.project_name}-backend"
}
