output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "backend_service_name" {
  value = aws_ecs_service.backend.name
}

output "frontend_task_family" {
  value = aws_ecs_task_definition.frontend.family
}

output "backend_task_family" {
  value = aws_ecs_task_definition.backend.family
}
