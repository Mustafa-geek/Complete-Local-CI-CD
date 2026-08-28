# Three-Tier CI/CD Project — Runbook & Troubleshooting Guide

This document serves as your permanent reference guide for the Three-Tier CI/CD project. It contains step-by-step setup instructions and a Q&A section covering all the underlying concepts and "why" behind the code.

---

## Part 1: Step-by-Step Execution Guide

### Phase 1: GitHub Secrets Setup
1. Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**.
2. Add `DOCKERHUB_TOKEN`: Your Docker Hub Access Token (created at hub.docker.com → Account Settings → Security).
3. Add `GH_PAT`: Your GitHub Personal Access Token (classic) with `repo` scope.

### Phase 2: Local Cluster Setup (One-Time)
Open Windows PowerShell and run the following to create your local Kubernetes cluster:
```powershell
kind create cluster --config kind-config.yaml
```

### Phase 3: Install ArgoCD Manually
In the same PowerShell window, run these commands sequentially to install the CD tool:
```powershell
# 1. Create a namespace for ArgoCD
kubectl create namespace argocd

# 2. Download and install ArgoCD software
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# 3. Expose ArgoCD to your Windows browser on port 8080
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":8080,"nodePort":30081,"name":"http"}]}}'
```

### Phase 3.5: Create MySQL Secrets Manually
Secrets are **never** stored in GitHub. You create them directly inside the Kubernetes cluster using `kubectl`. The `.env` file in the project root contains the passwords for your reference (it is gitignored).

First, create the `three-tier` namespace (if it doesn't exist yet):
```powershell
kubectl create namespace three-tier
```

Then create the secret:
```powershell
kubectl create secret generic mysql-secret `
  --namespace=three-tier `
  --from-literal=root-password=rootpassword `
  --from-literal=database=mydb `
  --from-literal=username=appuser `
  --from-literal=password=apppassword
```

> **How this works:** ArgoCD deploys the MySQL StatefulSet from GitHub. The StatefulSet YAML says "I need a secret called `mysql-secret`". It doesn't care WHO created that secret. Since YOU already created it via `kubectl`, Kubernetes finds it and injects the passwords into the MySQL container. ArgoCD never sees the actual password values.

### Phase 4: Deploy Your Application
1. **Push your code to GitHub**: This triggers the `.github/workflows/ci.yml` pipeline, which builds the Docker images and updates `helm/three-tier/values.yaml` with the new image tags.
   ```powershell
   git add .
   git commit -m "Add Helm chart, ArgoCD app, Kind config, and CI pipeline"
   git push origin main
   ```
2. **Apply the ArgoCD App Manifest**:
   ```powershell
   kubectl apply -f argocd/application.yaml
   ```
3. **Log in to ArgoCD**: Go to `http://localhost:8080`. (Username: `admin`. Get the password by running:)
   ```powershell
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
   ```

### Phase 4.5: Branch Protection Rules (When Adding Contributors)
When adding a collaborator (e.g., a friend or teammate) to the GitHub repo, protect the `main` branch so no one can push directly without a review.

1. Go to your GitHub repo → **Settings** → **Branches**
2. Click **"Add branch protection rule"**
3. In **Branch name pattern**, type: `main`
4. Enable the following options:
   - ✅ **Require a pull request before merging** — nobody (including you) can push directly to `main`
     - ✅ **Require approvals: 1** — at least one person must review and approve the PR
   - ✅ **Require status checks to pass before merging** — the CI pipeline (`ci.yml`) must pass before merge is allowed
     - Search for and add your workflow name (e.g., `CI Pipeline`) in the status checks box
   - ✅ **Do not allow bypassing the above settings** — applies the rules to admins too (recommended)
5. Click **Save changes**

> **How this protects you:** Your friend must open a Pull Request for any change. The CI pipeline runs automatically. Only after CI passes AND you approve can the code merge to `main`. ArgoCD then picks up the change and deploys it.
4. **Access your App**: Once ArgoCD finishes deploying, open `http://localhost:30080`.

### Phase 5: Pausing the Cluster (End of Day)
Because a Kind cluster runs inside Docker, running `docker stop` will corrupt its internal networking. To safely "freeze" your work at the end of the day without losing state, use the included management script:

**To Freeze:**
```powershell
.\manage-cluster.ps1 stop
```
**To Resume:**
```powershell
.\manage-cluster.ps1 start
```

---

## Part 2: Q&A and Conceptual Deep Dives

### 1. GitHub Actions & CI Pipeline

**Q: Why do we use `paths-ignore: - 'helm/three-tier/values.yaml'` at the top of `ci.yml`?**
**A:** To prevent an infinite loop. The CI pipeline's final step is to commit an update to `values.yaml`. If we didn't ignore this file, that commit would trigger the CI pipeline to run again, which would make another commit, triggering the pipeline again, forever.

**Q: Why do we use `GH_PAT` in the checkout step instead of the default `GITHUB_TOKEN`?**
**A:** GitHub has a strict security rule: commits pushed using the default automated `GITHUB_TOKEN` will **not** trigger webhooks or other actions. Because we want our final commit (updating the image tags) to notify ArgoCD immediately, we use a Personal Access Token (`GH_PAT`). This makes the commit look like it came from a real human, allowing webhooks to fire normally.

**Q: What does `cache-from: type=gha` do?**
**A:** `gha` stands for GitHub Actions. Building Java and Docker images is slow. This setting tells Docker to save its intermediate build steps into GitHub's cache storage. On the next run, Docker pulls from this cache instead of building from scratch, making the pipeline significantly faster.

**Q: What is the bash script doing with `yq` at the end of the pipeline?**
**A:** `yq` is a command-line tool for editing YAML files. The script downloads `yq`, then uses it to open `values.yaml` and overwrite the `.frontend.image.tag` and `.backend.image.tag` fields with the brand new commit SHA (the ID of the code change). It then uses standard Git commands to stage, commit, and push that modified file back to GitHub.

---

### 2. Docker Concepts

**Q: What does `khazimustafa/three-tier-frontend` mean?**
**A:** This is the standard Docker Hub naming convention. `khazimustafa` is the namespace (your account), and `three-tier-frontend` is the name of the repository (the specific image).

**Q: In the Dockerfile, what does `context: ./frontend` mean, and how does `COPY` know where to pull files from?**
**A:** `context` tells Docker where to pretend its "root directory" is during the build. By saying `context: ./frontend`, we restrict Docker to only look at files inside the `frontend` folder. 
When we write `COPY index.html /usr/share/nginx/html/index.html`:
- The source (`index.html`) looks for that file *inside* the context directory.
- The destination (`/usr/share/nginx/html...`) is the hardcoded path inside the Linux container where Nginx expects to find website files.

**Q: How does the backend Dockerfile `COPY` work?**
**A:** The backend uses a "multi-stage build". Stage 1 compiles the Java code into a `.jar` file using Maven. Stage 2 starts a fresh, empty container that only has Java. `COPY --from=builder /app/target/...` tells Docker to grab the compiled `.jar` file from the *first* container and put it into the *second* container. This keeps the final image tiny and secure.

---

### 3. Kubernetes, Helm & ArgoCD

**Q: Why do we have `templates/`, `values.yaml`, and `Chart.yaml`? What does Helm do?**
**A:** Helm is a package manager. Instead of hardcoding IPs, passwords, and image tags across a dozen Kubernetes files, we write "templates" with placeholders (like `{{ .Values.image.tag }}`). `values.yaml` acts as the control panel where all the real values live. Helm reads `values.yaml`, injects the values into the templates, and outputs the final configuration for Kubernetes. `Chart.yaml` is just the ID card (name and version) of your package.

**Q: What is the difference between a Deployment and a Service?**
**A:** 
- A **Deployment** manages the actual containers (Pods). It ensures the right number are running, replaces them if they crash, and handles rolling updates with zero downtime.
- A **Service** acts as a permanent load balancer and phonebook. Because Pods are constantly destroyed and recreated, their IP addresses change. A Service provides a stable internal DNS name (e.g., `http://backend:8080`) that never changes, routing traffic to whichever Pods happen to be alive at the moment.

**Q: Why does MySQL use a StatefulSet and PVC instead of a Deployment?**
**A:** Deployments are for "stateless" apps (like the frontend). If a frontend pod dies, its replacement is identical. Databases are "stateful"—if a database pod dies, you cannot just spin up a blank one; you'd lose user data. A **StatefulSet** combined with a **PVC** (Persistent Volume Claim) ensures that the database container is permanently tethered to a stable chunk of hard drive space that survives restarts.

---

### 4. Kind (Kubernetes IN Docker) & Port Mapping

**Q: Why did we need `kind-config.yaml` with `extraPortMappings`?**
**A:** The entire Kubernetes cluster runs trapped inside a single Docker container on your Windows machine. By default, it is completely isolated from your web browser. The `extraPortMappings` act as bridges, punching a hole from a port on your Windows laptop (like `30080`) directly into a port inside the cluster.

**Q: How does the cluster know that hole `30080` is meant for the frontend app?**
**A:** The `kind-config.yaml` file doesn't know anything; it just drills the empty hole. The connection happens later when we apply the Frontend's `service.yaml`. In that file, we set `nodePort: 30080`. That is the moment Kubernetes plugs the frontend application into the bridge we created.

**Q: Do I need to run `kubectl` commands inside the Docker container?**
**A:** **No.** You run `kubectl` commands in your normal Windows PowerShell window. When you created the cluster, `kind` secretly created a remote-control config file on your Windows machine (`~/.kube/config`). When you type `kubectl` in PowerShell, it uses that config file to reach across the Docker boundary and talk to the cluster automatically.

**Q: Why didn't `localhost:30080` work immediately after creating the cluster?**
**A:** Because the pipe was empty! You had drilled the hole (created the cluster with the port mapping), but ArgoCD hadn't deployed the frontend app yet to plug it into the other side of the hole.

**Q: What are the three port fields in a Kubernetes Service (`port`, `targetPort`, `nodePort`)?**
**A:** They each serve a different audience:
- `port: 80` — The Service's **internal virtual port**. Other pods inside the cluster use this to talk to the service (e.g., `http://frontend:80`).
- `targetPort: 80` — The port on the actual **Pod/container** where traffic is delivered. Must match the `containerPort` in the Deployment.
- `nodePort: 30080` — The port exposed on the **Kubernetes Node** (the Kind Docker container). This is what external traffic (your browser) hits. The Kind `extraPortMappings` then bridges this to your Windows host.

**Q: Why does `containerPort` in a Deployment YAML matter?**
**A:** It's mostly documentation — Kubernetes doesn't enforce it. But the Service's `targetPort` must match whatever port the container application is actually listening on. If these don't match, the Service routes traffic to a port where nothing is listening, and requests silently fail.

**Q: What is the difference between `kubectl port-forward` and NodePort for accessing a service?**
**A:**
- **NodePort** (what we use): A permanent change to the cluster. The service is always accessible via the node port — no terminal needs to stay open. Requires planning the port upfront in `kind-config.yaml`.
- **`kubectl port-forward`**: A temporary tunnel. Only works while the command is running in a terminal. Close the terminal and access is gone. No cluster changes needed — useful for quick one-off access.

**Q: How did ArgoCD end up on nodePort 30081 when we never chose that number?**
**A:** When we ran `kubectl patch` to change ArgoCD's service type to NodePort without specifying a port, Kubernetes automatically assigned a free port from its NodePort range (30000–32767). It happened to pick 30081. We then added `containerPort: 30081 → hostPort: 8080` to `kind-config.yaml` to bridge it to our laptop — but the cluster had already been created, so the Kind mapping was already in place and we were using `kubectl port-forward` as an alternative.

---

### 5. Kubernetes Secrets

**Q: Where does Kubernetes physically store secrets?**
**A:** All Kubernetes objects — pods, secrets, deployments, services — are stored in **etcd**, a fast distributed key-value database that is Kubernetes' internal "brain". It runs as a pod in the `kube-system` namespace. When you create a secret with `kubectl`, it gets written to etcd.

**Q: Why are secrets base64-encoded and not encrypted?**
**A:** Base64 is **encoding, not encryption**. It converts binary data to ASCII text so it can be safely stored and transmitted as a string. Anyone with `kubectl` access can decode it instantly:
```powershell
# This instantly reveals the password — base64 is NOT security:
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("YXBwcGFzc3dvcmQ="))
# Output: apppassword
```
For real security, Kubernetes secrets rely on **RBAC** (controlling who can run `kubectl get secret`) and **etcd encryption at rest** (configured at the cluster level). In production, teams also use external secret managers like **HashiCorp Vault** or **AWS Secrets Manager**. For local development, this is acceptable.

**Q: Why do we create the MySQL secret manually and not put it in the Helm chart?**
**A:** If you put credentials in your Helm chart's YAML files, they get committed to GitHub — where they are visible to everyone (and forever in git history). By creating the secret manually with `kubectl`, the password values only ever exist inside the cluster's etcd. ArgoCD deploys the StatefulSet from GitHub, which references the secret by **name** (`mysql-secret`) but never sees the actual values. This is the standard pattern for separating secret management from application deployment.

---

### 6. GitHub Collaboration & Branch Protection

**Q: Why add branch protection rules when adding a contributor?**
**A:** Without protection, anyone with write access can push directly to `main`, bypassing CI checks and code review. A bad push could break the deployment that ArgoCD is watching. Branch protection enforces a **Pull Request workflow**: all changes must go through a PR, CI must pass, and at least one person must approve — before anything reaches `main` and triggers a deployment.

**Q: What does "Require status checks to pass" mean in the context of this project?**
**A:** When a contributor opens a PR, GitHub automatically runs the CI pipeline (`ci.yml`) against their branch. The branch protection rule tells GitHub: "Do not allow this PR to be merged until that CI pipeline completes successfully." This means you can never accidentally merge code that breaks the Docker build or fails the tests.
