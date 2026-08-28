# Three-Tier CI/CD — Local Kubernetes Setup

A three-tier web application (nginx frontend · Java backend · MySQL database)
with a **fully local CI/CD pipeline** using GitHub Actions, Docker Hub, Kind, and ArgoCD.

---

## Architecture

```
GitHub push → GitHub Actions CI → Docker Hub → ArgoCD → Kind Cluster
                                                           ├─ frontend (nginx)
                                                           ├─ backend  (Java)
                                                           └─ mysql    (StatefulSet)
```

| Layer | Technology |
|---|---|
| CI | GitHub Actions |
| Registry | Docker Hub (`khazimustafa/three-tier-*`) |
| CD | ArgoCD (GitOps) |
| Cluster | Kind (Kubernetes-in-Docker) |
| Manifests | Helm chart (`helm/three-tier/`) |

---

## Repository Structure

```
.
├── .github/workflows/
│   └── ci.yml              ← CI: test → build → push → update Helm values
├── backend/                ← Java HTTP server (port 8080)
├── frontend/               ← nginx serving static HTML
├── helm/three-tier/        ← Helm chart for all K8s resources
│   ├── Chart.yaml
│   ├── values.yaml         ← image tags auto-updated by CI
│   └── templates/
│       ├── namespace.yaml
│       ├── mysql/          (Secret, PVC, StatefulSet, Service)
│       ├── backend/        (Deployment, Service)
│       └── frontend/       (Deployment, Service)
└── argocd/
    ├── application.yaml    ← ArgoCD Application CRD
    └── setup.ps1           ← One-time Windows setup script
```

---

## One-Time Local Setup

### Prerequisites

Install these tools first:

```powershell
winget install Docker.DockerDesktop
winget install Kubernetes.kind
winget install Kubernetes.kubectl
winget install Helm.Helm
```

> Make sure Docker Desktop is running before proceeding.

### Run the Setup Script

```powershell
# From the repo root (run as Administrator or normal user with Docker access)
.\argocd\setup.ps1
```

This will:
1. Create a Kind cluster with port mappings
2. Install ArgoCD into the cluster
3. Apply the ArgoCD Application (watches this repo)
4. Print the ArgoCD admin password

After setup:
- **ArgoCD UI** → http://localhost:8080 (admin / printed password)
- **App** → http://localhost:30080 *(available after first CI run)*

---

## GitHub Secrets Required

Add these to your GitHub repository (`Settings → Secrets and variables → Actions`):

| Secret | Description |
|---|---|
| `DOCKERHUB_TOKEN` | Docker Hub access token (create at hub.docker.com → Account Settings → Security) |
| `GH_PAT` | GitHub Personal Access Token with `repo` scope (needed to commit image tags back) |

---

## CI Pipeline (`ci.yml`)

Triggered on every push to `main` (except when CI itself updates `values.yaml`):

1. **Tests** — Maven unit tests
2. **SonarQube** — code quality analysis (ephemeral container)
3. **Docker build + push** — builds frontend and backend images, tags with commit SHA
4. **Tag retention** — keeps only the **3 most recent** tags on Docker Hub per image
5. **Helm update** — rewrites `helm/three-tier/values.yaml` with the new SHA, commits back to `main`

ArgoCD detects the commit and auto-deploys the new images to the Kind cluster.

---

## CD Flow (ArgoCD)

- ArgoCD polls this repo every 3 minutes (or you can configure a webhook)
- On detecting a change in `helm/three-tier/values.yaml`, it syncs the Helm release
- New pods are rolled out; old pods are terminated
- `prune: true` ensures removed resources are deleted from the cluster

---

## Local Development

The app can still be run and tested locally without Kubernetes using Docker directly:

```bash
# Build and test backend
cd backend && ./mvnw clean verify

# Build images manually
docker build -t three-tier-frontend:local ./frontend
docker build -t three-tier-backend:local  ./backend
```

---

## Cleanup

```powershell
# Delete the entire Kind cluster
kind delete cluster --name three-tier
```
