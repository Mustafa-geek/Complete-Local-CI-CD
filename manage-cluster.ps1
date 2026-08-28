# ==============================================================================
# manage-cluster.ps1  –  Safely Pause or Resume your Kind cluster
#
# USAGE:
#   .\manage-cluster.ps1 stop     <-- Freezes the cluster at the end of the day
#   .\manage-cluster.ps1 start    <-- Wakes it back up exactly where you left off
# ==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop")]
    [string]$Action
)

$ContainerName = "three-tier-control-plane"

# Check if the container actually exists
$exists = docker ps -a -q -f name=^/${ContainerName}$
if (-not $exists) {
    Write-Host "Cluster container '$ContainerName' not found. Is the cluster created?" -ForegroundColor Red
    exit 1
}

if ($Action -eq "stop") {
    Write-Host "Freezing cluster state..." -ForegroundColor Cyan
    # We use PAUSE instead of STOP. 
    # 'docker stop' breaks Kubernetes networking upon restart.
    # 'docker pause' freezes CPU/RAM but keeps the network safely intact!
    docker pause $ContainerName
    Write-Host "Cluster safely paused! You can now close Docker/shut down your PC." -ForegroundColor Green
} 
elseif ($Action -eq "start") {
    Write-Host "Waking cluster back up..." -ForegroundColor Cyan
    
    # Check if Docker desktop is running first
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker is not running! Please start Docker Desktop first." -ForegroundColor Red
        exit 1
    }

    docker unpause $ContainerName
    Write-Host "Cluster resumed!" -ForegroundColor Green
    
    Write-Host "Wait about 10 seconds, then ArgoCD will be available again at http://localhost:8080" -ForegroundColor Yellow
}
