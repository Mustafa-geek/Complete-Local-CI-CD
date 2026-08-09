# AWS Three-Tier Application CI/CD Pipeline

A portfolio project that takes a simple three-tier web application from local Docker Compose development to an automated AWS deployment using GitHub Actions, SonarQube, Terraform, Amazon ECR, ECS Fargate, RDS MySQL, Secrets Manager, and an Application Load Balancer.

## Application architecture

```text
Browser
   |
   v
Nginx frontend
   |
   | POST /api/employees
   v
Java backend API
   |
   | JDBC
   v
MySQL
```

The application provides:

- `GET /api/health` for backend/database health.
- `POST /api/employees` for employee registration.
- Nginx static frontend.
- Java 17 backend.
- MySQL database.

## CI/CD architecture

```text
Push / Pull Request
        |
        v
GitHub-hosted runner
        |
        +--> Maven Wrapper -> JUnit -> JaCoCo
        |
        +--> Ephemeral SonarQube container
        |       |
        |       +--> static analysis
        |       +--> security/reliability quality gate
        |
        +--> Docker image builds (only after quality passes)

Successful main CI run
        |
        v
GitHub OIDC -> AWS
        |
        v
Build + push commit-SHA images to ECR
        |
        v
Register new ECS task revisions
        |
        v
Update ECS Fargate services
```

The SonarQube server intentionally runs inside each GitHub-hosted runner for this learning project. It demonstrates automated static analysis and quality-gate enforcement without maintaining a permanent SonarQube server. Because the runner is ephemeral, SonarQube history is not retained between runs.

## AWS target architecture

```text
Internet
   |
   v
Application Load Balancer
   |-------------------------------|
   | /                             | /api/*
   v                               v
Frontend ECS Fargate          Backend ECS Fargate
(Nginx :80)                   (Java :8080)
                                   |
                                   v
                              RDS MySQL :3306
```

- ALB is deployed in public subnets.
- ECS tasks run in private application subnets.
- RDS runs in isolated private database subnets.
- Only the backend security group can connect to RDS on port 3306.
- Database credentials are delivered to ECS from AWS Secrets Manager.
- GitHub Actions uses AWS OIDC instead of long-lived AWS access keys.

## Repository layout

```text
.
├── .github/
│   ├── scripts/
│   │   ├── deploy-ecs.sh
│   │   └── start-sonarqube.sh
│   └── workflows/
│       ├── ci.yml
│       ├── deploy.yml
│       └── terraform.yml
├── backend/
│   ├── .mvn/
│   ├── src/main/java/
│   ├── src/test/java/
│   ├── Dockerfile
│   ├── mvnw
│   ├── mvnw.cmd
│   └── pom.xml
├── frontend/
│   ├── Dockerfile
│   ├── index.html
│   ├── nginx.conf
│   └── nginx.local.conf
├── terraform/
│   ├── bootstrap/
│   ├── environments/dev/
│   └── modules/
├── .env.example
├── docker-compose.yml
├── sonar-project.properties
└── README.md
```

## Run locally

### Prerequisites

- Docker Desktop / Docker Engine.
- Docker Compose v2.
- Java is optional for Docker-only use; Maven Wrapper can be used when running tests locally.

Create the local environment file:

```bash
cp .env.example .env
```

Change the example passwords in `.env`, then start the stack:

```bash
docker compose up --build
```

Open:

```text
http://localhost:8081
```

Test the complete frontend -> backend -> database path:

```bash
curl http://localhost:8081/api/health
```

Expected response:

```json
{"status":"healthy","database":"connected"}
```

The default host mapping in `.env.example` exposes MySQL on `localhost:3333`; containers still communicate internally with `database:3306`.

Stop and remove the local stack:

```bash
docker compose down
```

To also remove local MySQL data:

```bash
docker compose down -v
```

## Run backend tests

From the backend directory:

```bash
cd backend
./mvnw clean verify
```

The build runs JUnit and generates JaCoCo output under:

```text
backend/target/site/jacoco/
```

## CI pipeline

`.github/workflows/ci.yml` runs on pushes and pull requests to `main`:

1. Checkout source.
2. Select Java 17.
3. Run Maven Wrapper tests.
4. Generate JaCoCo coverage.
5. Start a temporary SonarQube Community Build container on the GitHub runner.
6. Create a temporary SonarQube project and quality gate.
7. Run repository static analysis.
8. Fail the workflow if security or reliability rating is worse than A.
9. Build frontend and backend Docker images only after the quality job succeeds.

No SonarCloud account or persistent SonarQube server is required.

## Infrastructure and deployment

See [`terraform/README.md`](terraform/README.md) for the complete provisioning and first-deployment sequence.

At a high level:

1. Bootstrap the S3 Terraform state bucket.
2. Apply the dev infrastructure with ECS services disabled.
3. Add the Terraform-created GitHub OIDC role ARN to GitHub repository variables.
4. Run the deployment workflow once with `push_only=true` to seed ECR.
5. Enable ECS service creation using the published Git SHA as the initial image tag.
6. Enable automated AWS deployment after CI succeeds.

## Security choices

- No database password is committed to source control.
- Local credentials live in an ignored `.env` file.
- AWS database credentials are generated by Terraform and stored in Secrets Manager.
- RDS is not publicly accessible.
- RDS accepts MySQL only from the backend ECS security group.
- GitHub Actions uses OIDC/STS temporary credentials for AWS deployment.
- SonarQube quality-gate failure prevents Docker image build/deployment progression.

## Resume-aligned project summary

**AWS Three-Tier Application CI/CD Pipeline — GitHub Actions, Terraform, Docker, ECS Fargate, ECR, RDS, SonarQube**

- Designed an end-to-end CI/CD pipeline using GitHub Actions with automated push and pull-request triggers, Maven/JUnit testing, SonarQube static analysis, and quality-gate enforcement before container builds.
- Developed reusable Terraform modules for VPC networking, IAM, ECR, RDS, ECS Fargate, Secrets Manager, and Application Load Balancer, with remote state and native locking in Amazon S3.
- Built multi-stage Docker images for the Nginx frontend and Java backend, published commit-SHA-tagged images to ECR, and automated ECS task revision/service updates.
- Configured ALB path-based routing, separate frontend/backend target groups, health checks, and optional ACM-backed HTTPS listeners.
- Removed hardcoded production database credentials by injecting AWS Secrets Manager values into ECS tasks and used GitHub OIDC for temporary AWS credentials.
