data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.frontend_cpu)
  memory                   = tostring(var.frontend_memory)
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true

      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.backend_cpu)
  memory                   = tostring(var.backend_memory)
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true

      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
      }]

      environment = [
        {
          name  = "DB_HOST"
          value = var.database_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.database_port)
        },
        {
          name  = "DB_NAME"
          value = var.database_name
        },
        {
          name  = "DB_OPTIONS"
          value = "?sslMode=REQUIRED"
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${var.database_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.database_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "backend"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "frontend" {
  name             = "${var.project_name}-frontend"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.frontend.arn
  desired_count    = var.frontend_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.frontend_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_service" "backend" {
  name             = "${var.project_name}-backend"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.backend.arn
  desired_count    = var.backend_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.backend_security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}
