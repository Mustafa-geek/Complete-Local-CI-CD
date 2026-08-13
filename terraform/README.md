# Simplified Terraform scope for the Three-Tier Project

This Terraform configuration intentionally manages only the application-specific resources that are useful to demonstrate in this project.

## Terraform creates

- S3 bucket for remote Terraform state, versioning, encryption, public-access blocking, and native S3 lockfile support.
- Three application security groups: ALB, frontend ECS, backend ECS.
- Optional ingress rule on an existing database/RDS security group so only the backend ECS security group can reach MySQL on port 3306.
- Application Load Balancer.
- Frontend and backend target groups.
- HTTP listener and `/api/*` path routing.
- ECS Fargate cluster.
- Frontend and backend ECS task definitions and services.
- CloudWatch log groups used by the ECS task definitions.

## Terraform does NOT create

These are treated as platform/prerequisite resources and are referenced by Terraform:

- VPC and subnets.
- ECR repositories.
- IAM roles.
- RDS/MySQL database.
- Secrets Manager database secret.
- ACM certificate / Route53 / HTTPS.

This split is deliberate: in many organizations an application team consumes networking, IAM, registry, database, and certificate resources created by a central platform or security team.

## Runtime architecture

```text
Internet
   |
   v
Application Load Balancer :80
   |-------------------------------|
   |                               |
   | /                             | /api/*
   v                               v
Frontend target group         Backend target group
   |                               |
   v                               v
Frontend ECS :80              Backend ECS :8080
                                   |
                                   v
                              Existing RDS/MySQL :3306
```

The backend receives database credentials from an existing AWS Secrets Manager secret with this JSON shape:

```json
{
  "username": "appuser",
  "password": "your-password"
}
```

## Why VPC creation was removed

ECS Fargate still requires a VPC, subnets, and security groups. This configuration simply does not create the VPC. You pass existing IDs through `terraform.tfvars`.

For a simple lab, existing/default public subnets can be used with `assign_public_ip = true`. For a production-style environment, use existing private subnets with NAT or VPC endpoints and set `assign_public_ip = false`.

## Why ECR and IAM creation were removed

The application still uses them; Terraform just references existing resources:

- Existing ECR repositories are looked up by name.
- Existing ECS task execution IAM role is looked up by name.

The execution role must be able to:

- pull images from ECR,
- write logs to CloudWatch Logs,
- read the database secret from Secrets Manager.

## Why ACM was removed

The project uses HTTP on the ALB for now. A certificate can be added later either as an existing certificate ARN or as Terraform-managed ACM resources. HTTPS is not required to demonstrate ECS, ALB routing, security groups, Terraform modules, and remote state.

## Directory structure

```text
terraform/
├── bootstrap/
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
├── environments/
│   └── dev/
│       ├── backend.hcl.example
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       ├── variables.tf
│       └── versions.tf
└── modules/
    ├── alb/
    ├── ecs/
    └── security-groups/
```

## Prerequisites before applying the dev stack

You need these resources to already exist:

1. VPC.
2. At least two subnets in different Availability Zones for the ALB.
3. Subnets for ECS Fargate.
4. `three-tier-frontend` ECR repository with an image pushed.
5. `three-tier-backend` ECR repository with an image pushed.
6. ECS task execution IAM role.
7. RDS/MySQL database reachable from the ECS subnets.
8. Secrets Manager secret containing `username` and `password` JSON keys.
9. The database/RDS security group ID if Terraform should add the backend-to-MySQL rule.

## Step 1 - Create the Terraform state bucket

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `state_bucket_name`, then:

```bash
terraform init
terraform plan
terraform apply
```

## Step 2 - Configure the dev stack

```bash
cd ../environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

Fill in the real VPC, subnet, ECR, IAM, database, secret, and security-group values.

Then:

```bash
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Step 3 - Test

Terraform outputs an ALB URL:

```bash
terraform output -raw application_url
```

Open that URL in a browser. The ALB routes:

- `/` and normal frontend paths to the frontend ECS service.
- `/api/*` to the backend ECS service.

The backend health check uses `/api/health`.
