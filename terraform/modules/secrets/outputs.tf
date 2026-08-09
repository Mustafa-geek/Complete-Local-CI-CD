output "secret_arn" {
  value = aws_secretsmanager_secret.database.arn
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value     = random_password.database.result
  sensitive = true
}
