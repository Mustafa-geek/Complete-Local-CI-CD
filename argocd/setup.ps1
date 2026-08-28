# ==============================================================================
# setup.ps1  –  One-time local setup for Kind cluster + ArgoCD
#
# Run this script ONCE on your Windows machine (PowerShell as Administrator):
#   .\argocd\setup.ps1
#
# Prerequisites (must be installed first):
#   1. Docker Desktop  – https://docs.docker.com/desktop/install/windows-install/
#   2. kind CLI        – winget install Kubernetes.kind
#   3. kubectl CLI     – winget install Kubernetes.kubectl
#   4. helm CLI        – winget install Helm.Helm
#
# After this script runs:
#   - ArgoCD UI  → http://localhost:8080   (admin / printed password)
#   - App URL    → http://localhost:30080
# ==============================================================================

param(
    [string]$ClusterName  = "three-tier",
    [string]$ArgocdNs     = "argocd",
    [string]$ArgocdVersion = "stable"    # or pin a version e.g. "v2.12.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helper ────────────────────────────────────────────────────────────────────
function Write-Step { param([string]$msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  ✓ $msg"  -ForegroundColor Green }

# ── 1. Check prerequisites ────────────────────────────────────────────────────
Write-Step "Checking prerequisites..."
foreach ($tool in @("docker","kind","kubectl","helm")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Missing tool: '$tool'. Please install it and re-run."
    }
    Write-OK "$tool found"
}

# ── 2. Create Kind cluster with port mapping ──────────────────────────────────
Write-Step "Creating Kind cluster '$ClusterName'..."

$kindConfig = @"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $ClusterName
nodes:
  - role: control-plane
    extraPortMappings:
      # Frontend NodePort → http://localhost:30080
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      # ArgoCD NodePort → http://localhost:8080
      - containerPort: 30081
        hostPort: 8080
        protocol: TCP
"@

$configFile = [System.IO.Path]::GetTempFileName() + ".yaml"
$kindConfig | Set-Content -Path $configFile -Encoding UTF8

$existing = kind get clusters 2>&1 | Select-String -SimpleMatch $ClusterName
if ($existing) {
    Write-Host "  Cluster '$ClusterName' already exists, skipping creation." -ForegroundColor Yellow
} else {
    kind create cluster --config $configFile
    Write-OK "Kind cluster created"
}

Remove-Item $configFile -ErrorAction SilentlyContinue

# ── 3. Set kubectl context ────────────────────────────────────────────────────
Write-Step "Setting kubectl context..."
kubectl config use-context "kind-$ClusterName"
Write-OK "Context set to kind-$ClusterName"

# ── 4. Install ArgoCD ────────────────────────────────────────────────────────
Write-Step "Installing ArgoCD into namespace '$ArgocdNs'..."
kubectl create namespace $ArgocdNs --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n $ArgocdNs `
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ArgocdVersion/manifests/install.yaml"

Write-Step "Waiting for ArgoCD pods to be ready (this takes ~2 minutes)..."
kubectl wait --for=condition=available --timeout=300s `
    deployment/argocd-server -n $ArgocdNs
Write-OK "ArgoCD is running"

# ── 5. Expose ArgoCD on localhost:8080 via NodePort ──────────────────────────
Write-Step "Patching ArgoCD server service to NodePort 30081..."
kubectl patch svc argocd-server -n $ArgocdNs `
    -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":8080,"nodePort":30081,"name":"http"}]}}'
Write-OK "ArgoCD exposed at http://localhost:8080"

# ── 6. Apply the ArgoCD Application manifest ─────────────────────────────────
Write-Step "Applying ArgoCD Application manifest..."
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
kubectl apply -f (Join-Path $scriptDir "application.yaml")
Write-OK "ArgoCD Application 'three-tier' applied"

# ── 7. Print credentials ──────────────────────────────────────────────────────
Write-Step "Retrieving ArgoCD admin password..."
Start-Sleep -Seconds 5   # give the secret a moment to populate

$b64pass = kubectl get secret argocd-initial-admin-secret `
    -n $ArgocdNs `
    -o jsonpath="{.data.password}" 2>$null

if ($b64pass) {
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64pass))
} else {
    $password = "(secret not yet available — run: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) })"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  LOCAL CI/CD SETUP COMPLETE" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  ArgoCD UI   →  http://localhost:8080"
Write-Host "  Username    →  admin"
Write-Host "  Password    →  $password"
Write-Host ""
Write-Host "  App URL     →  http://localhost:30080  (after first CI run)"
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Add GitHub secrets to your repo:"
Write-Host "       DOCKERHUB_TOKEN  = your Docker Hub access token"
Write-Host "       GH_PAT           = your GitHub Personal Access Token (repo write)"
Write-Host "  2. Push a commit to 'main' to trigger the CI pipeline"
Write-Host "  3. Watch ArgoCD auto-deploy at http://localhost:8080"
Write-Host ""
Write-Host "  To delete the cluster later:"
Write-Host "    kind delete cluster --name $ClusterName"
Write-Host "============================================================" -ForegroundColor Magenta
