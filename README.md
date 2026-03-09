# AKS Production Cluster — Zone-Resilient Kubernetes Platform

> **IaC Tool:** Azure Bicep  
> **Cloud:** Microsoft Azure  
> **Pipeline:** Azure DevOps YAML (CI on TFS + CD Release)  
> **Containerisation:** Docker, Helm 3, Azure Container Registry

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                           │
│                                                                     │
│  ┌──────────────── Resource Group: rg-akscluster-{env} ──────────┐  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐  │  │
│  │  │               Virtual Network  10.0.0.0/16               │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌──────────────┐ ┌───────────┐ ┌───────────────────┐  │  │  │
│  │  │  │ AKS Subnet   │ │ App GW    │ │ Internal LB       │  │  │  │
│  │  │  │ 10.0.0.0/20  │ │ Subnet    │ │ Subnet            │  │  │  │
│  │  │  │              │ │ .16.0/24  │ │ .17.0/24          │  │  │  │
│  │  │  └──────┬───────┘ └───────────┘ └───────────────────┘  │  │  │
│  │  └─────────┼────────────────────────────────────────────────┘  │  │
│  │            │                                                   │  │
│  │  ┌────────▼─────────────────────────────────────────────────┐  │  │
│  │  │         Azure Kubernetes Service (AKS)                   │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌─────────────────────────────────────────────────────┐ │  │  │
│  │  │  │       ZONE-SPANNED (Default Active Config)          │ │  │  │
│  │  │  │                                                     │ │  │  │
│  │  │  │  System Pool    Workload Pool                       │ │  │  │
│  │  │  │  ┌──────────┐   ┌──────────┐                       │ │  │  │
│  │  │  │  │ Zone 1   │   │ Zone 1   │                       │ │  │  │
│  │  │  │  │ Zone 2   │   │ Zone 2   │  ← Nodes across all  │ │  │  │
│  │  │  │  │ Zone 3   │   │ Zone 3   │    3 AZs              │ │  │  │
│  │  │  │  └──────────┘   └──────────┘                       │ │  │  │
│  │  │  └─────────────────────────────────────────────────────┘ │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌─────────────────────────────────────────────────────┐ │  │  │
│  │  │  │     ZONE-ALIGNED (Commented Alternative)            │ │  │  │
│  │  │  │                                                     │ │  │  │
│  │  │  │  Pool-Zone1    Pool-Zone2    Pool-Zone3             │ │  │  │
│  │  │  │  ┌────────┐   ┌────────┐   ┌────────┐             │ │  │  │
│  │  │  │  │Zone 1  │   │Zone 2  │   │Zone 3  │  ← 1 pool  │ │  │  │
│  │  │  │  │ only   │   │ only   │   │ only   │    = 1 AZ   │ │  │  │
│  │  │  │  └────────┘   └────────┘   └────────┘             │ │  │  │
│  │  │  └─────────────────────────────────────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  │  ┌──────────────────┐   ┌────────────────────────────────────┐ │  │
│  │  │ Azure Container  │   │ Log Analytics Workspace            │ │  │
│  │  │ Registry (ACR)   │   │ (Container Insights)               │ │  │
│  │  │ Docker images     │   │ Logs, metrics, alerts              │ │  │
│  │  └──────────────────┘   └────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔁 CI/CD Pipeline Flow

```
 Developer Push                Azure DevOps Pipelines
─────────────────        ──────────────────────────────────────────
                        
  git push main   ──►   ┌──────────────────────────────────────┐
                         │   CI Pipeline (ci-build.yaml)        │
                         │                                      │
                         │  Stage 1: Validate Bicep             │
                         │    • az bicep build                  │
                         │    • Template lint & validation      │
                         │                                      │
                         │  Stage 2: Build Docker Image         │
                         │    • az acr build (multi-stage)      │
                         │    • Push to ACR with build ID tag   │
                         │                                      │
                         │  Stage 3: Package Helm Chart         │
                         │    • helm lint                       │
                         │    • helm package                    │
                         │    • Publish as pipeline artifact    │
                         └──────────────┬───────────────────────┘
                                        │
                                        ▼
                         ┌──────────────────────────────────────┐
                         │   CD Pipeline (cd-release.yaml)      │
                         │                                      │
                         │  Stage 1: Deploy Infra → DEV         │
                         │    • az deployment group create      │
                         │    • Bicep → AKS, ACR, VNet          │
                         │                                      │
                         │  Stage 2: Deploy App → DEV           │
                         │    • az aks get-credentials          │
                         │    • helm upgrade --install          │
                         │    • kubectl verify pods/svc         │
                         │                                      │
                         │  ──── Manual Approval Gate ────      │
                         │                                      │
                         │  Stage 3: Deploy → PRODUCTION        │
                         │    • Bicep infra deploy (prod)       │
                         │    • Helm deploy (prod overrides)    │
                         │    • HPA + PDB + topology spread     │
                         └──────────────────────────────────────┘
```

---

## 📐 Zone-Spanned vs Zone-Aligned

| Aspect | Zone-Spanned | Zone-Aligned |
|---|---|---|
| **Node Placement** | Nodes distributed across all 3 zones automatically | Separate node pool per zone (1 pool = 1 zone) |
| **Scheduler** | Kubernetes spreads pods across zones via scheduler | Explicit pool-per-zone, fine-grained zone control |
| **Latency** | Cross-zone traffic possible | Workloads pinned to a single zone for lowest latency |
| **Cost** | Simpler, fewer pools to manage | More pools means more management overhead |
| **Use Case** | General HA workloads | Latency-sensitive, data-locality, compliance |
| **This Repo** | **Active configuration** in `aks.bicep` | **Commented example** in `aks.bicep` |

### When to Use Zone-Aligned

- **Data locality**: Keep compute in the same zone as storage to eliminate cross-zone data transfer costs.
- **Ultra-low-latency**: Sub-millisecond services that can't tolerate cross-zone hops.
- **Regulatory compliance**: Data must not leave a specific availability zone.

---

## 📁 Project Structure

```
aks-production-cluster/
├── infra/
│   ├── main.bicep                  # Orchestrator — wires all modules
│   ├── modules/
│   │   ├── networking.bicep        # VNet, 3 subnets
│   │   ├── acr.bicep               # Azure Container Registry
│   │   ├── aks.bicep               # AKS cluster (zone-spanned + zone-aligned)
│   │   └── monitoring.bicep        # Log Analytics for Container Insights
│   └── parameters/
│       ├── dev.bicepparam          # Dev: B-series, 1-3 nodes
│       └── prod.bicepparam         # Prod: D-series, 3-10 nodes, private
├── src/
│   └── SampleApi/
│       ├── Program.cs              # .NET 8 minimal API (/health, /ready)
│       ├── SampleApi.csproj        # SDK project file
│       └── Dockerfile              # Multi-stage build, alpine, non-root
├── helm/
│   └── sample-api/
│       ├── Chart.yaml              # Helm chart metadata
│       ├── values.yaml             # Defaults: replicas, HPA, PDB, topology
│       └── templates/
│           ├── deployment.yaml     # Pod spec with probes, resources, spread
│           ├── service.yaml        # ClusterIP service
│           ├── hpa.yaml            # Horizontal Pod Autoscaler (3→20)
│           ├── ingress.yaml        # NGINX Ingress Controller
│           └── pdb.yaml            # Pod Disruption Budget (minAvailable: 2)
├── pipelines/
│   ├── ci-build.yaml              # Validate, build Docker, package Helm
│   └── cd-release.yaml            # Deploy infra + Helm to DEV → PROD
└── README.md
```

---

## 🧱 Infrastructure Components

| Resource | Module | Dev SKU | Prod SKU |
|---|---|---|---|
| **VNet** | `networking.bicep` | 10.0.0.0/16 | 10.0.0.0/16 |
| **AKS Cluster** | `aks.bicep` | Standard_B2ms, 1-3 nodes | Standard_D4s_v5, 3-10 nodes |
| **System Pool** | `aks.bicep` | Standard_B2ms, 1-3 nodes | Standard_D4s_v5, 3-10 nodes |
| **ACR** | `acr.bicep` | Basic | Premium (zone-redundant) |
| **Log Analytics** | `monitoring.bicep` | PerGB2018, 30d | PerGB2018, 90d |

### AKS Cluster Features

- **Private cluster** in production (API server not publicly exposed)
- **Azure CNI** networking with VNet integration
- **Calico** network policy enforcement
- **Autoscaler** enabled on all node pools
- **AcrPull** role assignment (no image pull secrets needed)
- **Container Insights** via Log Analytics OMS agent

---

## 🐳 Sample Application

A .NET 8 minimal API with three endpoints:

| Endpoint | Purpose |
|---|---|
| `GET /` | Returns hostname, version, environment |
| `GET /health` | Liveness probe — always returns `Healthy` |
| `GET /ready` | Readiness probe — returns `Ready` |

### Dockerfile Highlights

- **Multi-stage build**: SDK image for build, `aspnet:8.0-alpine` for runtime
- **Non-root user**: Runs as `app` (UID 1654) for security
- **Port 8080**: Avoids privileged port binding

---

## ☸️ Helm Chart

The `sample-api` Helm chart deploys the application with production-grade defaults:

```yaml
# Production Helm overrides (applied in cd-release.yaml)
replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
podDisruptionBudget:
  enabled: true
  minAvailable: 2
topologySpreadConstraints:
  enabled: true         # Spread pods across zones
```

### Topology Spread Constraints

```
Zone 1          Zone 2          Zone 3
┌──────────┐   ┌──────────┐   ┌──────────┐
│ Pod A    │   │ Pod B    │   │ Pod C    │
│ Pod D    │   │ Pod E    │   │ Pod F    │
└──────────┘   └──────────┘   └──────────┘
  maxSkew: 1     pods evenly distributed
```

The `topologySpreadConstraints` in the Deployment template ensure pods are evenly distributed across availability zones, complementing the zone-spanned node pool configuration.

---

## 🚀 Getting Started

### Prerequisites

- Azure CLI ≥ 2.50
- Bicep CLI ≥ 0.24
- Docker Desktop
- Helm ≥ 3.14
- kubectl

### Local Development

```bash
# Build and run the sample app locally
cd src/SampleApi
dotnet run
# → http://localhost:5000/health

# Build Docker image locally
docker build -t sample-api:local -f src/SampleApi/Dockerfile src/SampleApi/
docker run -p 8080:8080 sample-api:local

# Validate Bicep templates
az bicep build --file infra/main.bicep

# Lint Helm chart
helm lint helm/sample-api/
```

### Deploy Manually

```bash
# Deploy infrastructure
az deployment group create \
  --resource-group rg-akscluster-dev \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam

# Get AKS credentials
az aks get-credentials --resource-group rg-akscluster-dev --name aks-akscluster-dev

# Build and push image to ACR
az acr build --registry <acr-name> --image sample-api:v1 src/SampleApi/

# Deploy with Helm
helm upgrade --install sample-api helm/sample-api/ \
  --set image.repository=<acr-name>.azurecr.io/sample-api \
  --set image.tag=v1
```

---

## 🔒 Security

| Control | Implementation |
|---|---|
| **Private API Server** | Production AKS uses private cluster (no public endpoint) |
| **Network Policy** | Calico for pod-to-pod traffic control |
| **Non-root Container** | Dockerfile runs as UID 1654 |
| **ACR Integration** | Managed identity AcrPull — no stored credentials |
| **HTTPS Ingress** | NGINX Ingress with TLS termination |
| **Pod Security** | Resource limits, readiness/liveness probes |
| **Disruption Budget** | PDB ensures minimum 2 pods during rollouts |

---

## 📊 Monitoring

Container Insights collects:

- **Node metrics**: CPU, memory, disk, network per node
- **Pod metrics**: CPU/memory per pod, restart counts
- **Container logs**: stdout/stderr streamed to Log Analytics
- **Cluster events**: Node conditions, failed scheduling, OOM kills

```
AKS Cluster ──► OMS Agent ──► Log Analytics Workspace
                                     │
                                     ├── Container Insights Dashboard
                                     ├── KQL Queries
                                     └── Alert Rules
```

---

## 📝 License

MIT
