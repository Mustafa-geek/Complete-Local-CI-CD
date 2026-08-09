resource "random_password" "database" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-=?^_"
}

resource "aws_secretsmanager_secret" "database" {
  name                    = "${var.project_name}/database/credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-database-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.database.result
  })
}
