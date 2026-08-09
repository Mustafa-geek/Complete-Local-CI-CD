# Terraform infrastructure

This directory provisions the AWS infrastructure used by the three-tier application.

## Architecture

- VPC across two Availability Zones.
- Public subnets for the Application Load Balancer and NAT Gateway.
- Private application subnets for ECS Fargate tasks.
- Isolated private database subnets for Amazon RDS MySQL.
- Separate security groups for ALB, frontend, backend, and database tiers.
- Amazon ECR repositories for frontend and backend images.
- AWS Secrets Manager for database credentials.
- ECS Fargate cluster, task definitions, and services.
- Application Load Balancer path routing:
  - `/api/*` -> backend target group.
  - everything else -> frontend target group.
- Optional ACM + Route53 HTTPS configuration.
- GitHub Actions OIDC role for short-lived AWS credentials.
- S3 remote state with native S3 state locking (`use_lockfile=true`).

## Directory layout

```text
terraform/
├── bootstrap/              # Creates the remote-state S3 bucket
├── environments/
│   └── dev/                # Composes reusable modules
└── modules/
    ├── alb/
    ├── ecr/
    ├── ecs/
    ├── iam/
    ├── network/
    ├── rds/
    └── secrets/
```

## 1. Create the state bucket

The state bucket must exist before the dev stack can use it.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit state_bucket_name to a globally unique value.
terraform init
terraform plan
terraform apply
```

Keep the bootstrap state safe. The bucket has versioning, encryption, public-access blocking, and `prevent_destroy` enabled.

## 2. Configure the dev backend

```bash
cd ../environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Update:

- `backend.hcl`: state bucket name and AWS region.
- `terraform.tfvars`: `github_repository` and any desired AWS settings.

Then initialize:

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

The first application-stack apply should keep:

```hcl
create_ecs_services = false
```

This creates the network, ECR, IAM/OIDC, RDS, Secrets Manager, ALB, and ECS cluster without trying to start tasks before images exist.

## 3. Bootstrap the first ECR images

After the first apply, set the Terraform output `github_actions_role_arn` as the GitHub repository variable `AWS_ROLE_ARN`.

Run the **Deploy to ECS** GitHub Actions workflow manually with `push_only=true`. The workflow builds both images and publishes a commit-SHA tag to ECR without updating ECS.

Copy the published SHA from the workflow summary.

## 4. Create ECS services

Set in `terraform.tfvars`:

```hcl
create_ecs_services = true
initial_image_tag   = "<SHA-PUBLISHED-IN-STEP-3>"
```

Apply again:

```bash
terraform plan
terraform apply
```

After ECS is healthy, create the GitHub repository variable:

```text
ENABLE_AWS_DEPLOYMENT=true
```

Successful CI runs on `main` will then trigger the deployment workflow automatically.

## 5. Optional HTTPS

If you own a Route53-hosted domain, set:

```hcl
enable_https  = true
domain_name   = "app.example.com"
hosted_zone_id = "Z1234567890"
```

Terraform creates an ACM certificate, DNS validation record, HTTPS listener, HTTP-to-HTTPS redirect, and Route53 alias record.

## GitHub repository variables

After the first infrastructure apply, configure the deployment workflow with:

```text
AWS_ROLE_ARN=<github_actions_role_arn output>
AWS_REGION=us-east-1
PROJECT_NAME=three-tier
ENABLE_AWS_DEPLOYMENT=true   # only after ECS services exist
```

No long-lived AWS access key is required by GitHub Actions; the workflow assumes the Terraform-created IAM role through GitHub OIDC.

## Cost note

The demo uses a NAT Gateway and RDS instance, both of which incur hourly charges. Destroy the dev application stack when it is not needed. The remote-state bucket is deliberately protected from accidental destruction.

## Terraform CI checks

The `Terraform Checks` GitHub Actions workflow runs `terraform fmt -check` and `terraform validate` for infrastructure changes. Infrastructure `plan`/`apply` remains an explicit operator action in this project so the GitHub deployment role can stay narrowly scoped to ECR/ECS deployment rather than receiving broad infrastructure-administration permissions.
