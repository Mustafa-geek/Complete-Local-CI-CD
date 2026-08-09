# What changed from the original Terraform design

## Original design

The original archive managed almost the entire AWS environment:

- `modules/network` created a new VPC, Internet Gateway, public/private/database subnets, route tables, NAT Gateway, and EIP.
- `modules/ecr` created frontend/backend ECR repositories and lifecycle policies.
- `modules/secrets` generated a database password and stored it in Secrets Manager.
- `modules/rds` created the MySQL RDS instance and DB subnet group.
- `modules/iam` created ECS execution/task roles, GitHub OIDC provider, and GitHub deployment role.
- `modules/alb` created the ALB, target groups, HTTP/HTTPS listeners, health checks, and path routing.
- `modules/ecs` created the ECS cluster, task definitions, services, and log groups.
- `environments/dev/main.tf` wired every module together and also created security groups, ACM, and Route53 records.

That design is valid but large for a learning project because Terraform owns every layer.

## Simplified design

The new design deliberately separates platform prerequisites from application infrastructure.

Terraform now owns:

1. S3 state backend bootstrap.
2. Security groups for ALB/frontend/backend.
3. Optional MySQL ingress rule on an existing DB security group.
4. ALB, target groups, health checks, and HTTP path routing.
5. ECS cluster, task definitions, Fargate services, and log groups.

Terraform references but does not create:

1. VPC/subnets.
2. ECR repositories.
3. ECS task execution role.
4. RDS/MySQL.
5. Secrets Manager secret.

ACM/Route53/HTTPS were removed from this project scope.

## File-by-file explanation

### `bootstrap/versions.tf`
Pins the Terraform and AWS provider versions used to create the state bucket.

### `bootstrap/providers.tf`
Configures which AWS region the bootstrap resources are created in.

### `bootstrap/variables.tf`
Declares the region, project name, and globally unique S3 state bucket name.

### `bootstrap/main.tf`
Creates the state bucket and protects it with versioning, server-side encryption, blocked public access, and `prevent_destroy`.

### `bootstrap/outputs.tf`
Prints the bucket name and the backend settings used by the dev environment.

### `bootstrap/terraform.tfvars.example`
Template for the real bootstrap input values. The copied `terraform.tfvars` should not contain values you do not want committed.

### `environments/dev/versions.tf`
Declares the S3 backend and AWS provider requirement for the application stack.

### `environments/dev/providers.tf`
Sets the AWS region for the application stack.

### `environments/dev/backend.hcl.example`
Template telling Terraform where the remote state object and lockfile live in S3.

### `environments/dev/variables.tf`
Defines all external dependencies and application settings: existing VPC/subnets, ECR repo names, role name, DB endpoint, Secrets Manager secret name, image tag, and desired task counts.

### `environments/dev/main.tf`
This is the composition layer. It looks up existing ECR/IAM/Secrets resources with data sources and then calls the security-groups, ALB, and ECS modules.

### `environments/dev/outputs.tf`
Shows useful deployment values such as the ALB URL, ECS cluster/service names, ECR URLs, and backend security-group ID.

### `environments/dev/terraform.tfvars.example`
Concrete example of the values that must be supplied before plan/apply.

### `modules/security-groups/main.tf`
Creates the three application security groups and, optionally, the inbound MySQL rule on an existing database security group.

Traffic model:

```text
Internet -> ALB SG :80
ALB SG -> Frontend SG :80
ALB SG -> Backend SG :8080
Backend SG -> existing DB SG :3306
```

### `modules/alb/main.tf`
Creates one internet-facing ALB, two IP target groups, one HTTP listener, and a listener rule that sends `/api/*` to the backend. Everything else goes to the frontend.

### `modules/ecs/main.tf`
Creates the ECS Fargate cluster, frontend/backend task definitions, services, and CloudWatch log groups. It uses the existing ECR image URLs and existing ECS execution role. The backend receives DB host/name as normal environment variables and DB username/password from Secrets Manager.
