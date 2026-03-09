# Stage 6: Application Deployment Design

**Date:** 2026-03-09
**Status:** Approved
**Scope:** Deploy Online Boutique (reduced) via custom Helm chart through GitHub Actions

**Update (implementation):** Switched from GKE Ingress (`gce` class) to Gateway API
(`gke-l7-regional-external-managed`) because our Static IP is STANDARD tier Regional,
which is incompatible with the Global LB created by GKE Ingress. Gateway API resources
(Gateway, HTTPRoute, HealthCheckPolicy) replace BackendConfig, FrontendConfig, and Ingress.

## Overview

Deploy a reduced Online Boutique (frontend + cartservice + redis) to GKE using a custom Helm chart.
Include GKE-native Ingress with Static IP, BackendConfig/FrontendConfig, and a Cloud SQL Auth Proxy
sidecar to demonstrate the Workload Identity flow built in stages 2-5.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Services to deploy | frontend, cartservice, redis | Minimal set to demo Ingress + WI + SQL Proxy |
| Cart database | Redis (original) | cartservice doesn't natively support PostgreSQL |
| WI demo | SQL Proxy sidecar on cartservice pod | Proves E2E WI chain without custom app code |
| Helm approach | Custom chart from scratch | Only 3 services; learning value; full control |
| Ingress type | GKE Ingress (`gce-regional-external`) | Matches STANDARD tier Static IP |
| HTTPS redirect | Disabled (no TLS cert/domain in dev) | Can enable when domain is configured |

## Architecture

### Helm Chart Structure

```
helm/online-boutique/
├── Chart.yaml
├── values.yaml                    # Defaults
├── values-orel-dev.yaml           # Client/env overrides (TF outputs)
└── templates/
    ├── _helpers.tpl               # Template helpers
    ├── namespace.yaml             # boutique namespace
    ├── service-account.yaml       # KSA with WI annotation
    ├── frontend-deployment.yaml
    ├── frontend-service.yaml
    ├── cartservice-deployment.yaml # Includes SQL Proxy sidecar
    ├── cartservice-service.yaml
    ├── redis-deployment.yaml
    ├── redis-service.yaml
    ├── backend-config.yaml        # GKE BackendConfig
    ├── frontend-config.yaml       # GKE FrontendConfig (HTTP→HTTPS off)
    └── ingress.yaml               # GKE Ingress with Static IP + NEGs
```

### Kubernetes Resources

| Resource | Name | Purpose |
|----------|------|---------|
| Namespace | boutique | Isolation for all app resources |
| ServiceAccount | boutique-sql-proxy | KSA with WI annotation → GSA btq-sql |
| Deployment | frontend | 1 replica, port 8080, HTTP health checks |
| Service | frontend | ClusterIP:80 → 8080, NEG annotation, BackendConfig ref |
| Deployment | cartservice | 1 replica + SQL Proxy sidecar |
| Service | cartservice | ClusterIP:7070, gRPC |
| Deployment | redis-cart | 1 replica, port 6379 |
| Service | redis-cart | ClusterIP:6379 |
| BackendConfig | frontend-config | Health check (HTTP /_healthz:8080), connection draining 30s |
| FrontendConfig | frontend-config | HTTP→HTTPS redirect (disabled in dev) |
| Ingress | frontend | Regional External LB, Static IP, NEG backend |

### GKE Custom Resources

**BackendConfig** configures backend behavior for the Load Balancer:
- Health check: HTTP GET `/_healthz` on port 8080
- Connection draining: 30 seconds (graceful shutdown)

**FrontendConfig** configures frontend behavior:
- HTTP to HTTPS redirect: disabled (no TLS cert in dev)

**Ingress** with `gce-regional-external` class:
- Binds to Static IP `orel-gob-dev-euw1-ip-ingress`
- Routes all traffic to frontend Service
- Uses NEG-based load balancing (pod-level, not node-level)

### NEG (Network Endpoint Group) Explanation

When a Service has the annotation `cloud.google.com/neg: '{"ingress": true}'`, GKE creates a
NEG that registers Pod IPs directly with the Load Balancer. The LB talks **directly to Pods**
instead of going through Node → kube-proxy → iptables → Pod. Benefits:
- No extra hop through the Node
- Pod-level health checks (not Node-level)
- More accurate load balancing
- Lower latency

### Static IP Compatibility

The Static IP (`orel-gob-dev-euw1-ip-ingress`) is Regional External, STANDARD tier. This requires
a **Regional External Application Load Balancer**, not the default Global LB. We use the
`networking.gke.io/v1` GCE Ingress with regional class annotation to match.

## Workload Identity Flow

```
Pod (KSA: boutique-sql-proxy)
  │
  ├── ① GKE injects OIDC token (projected volume)
  │     Token claims: sub=system:serviceaccount:boutique:boutique-sql-proxy
  │
  ├── ② Cloud SQL Proxy reads token, calls STS API
  │     "Exchange this OIDC token for a GCP access token"
  │
  ├── ③ STS validates IAM binding (from identity layer):
  │     "KSA boutique/boutique-sql-proxy → GSA btq-sql"
  │     Checks: roles/iam.workloadIdentityUser on GSA
  │
  ├── ④ STS returns short-lived access token (~1h)
  │     Identity: orel-gob-dev-euw1-sa-btq-sql@orel-bh-sandbox.iam.gserviceaccount.com
  │
  └── ⑤ Proxy connects to Cloud SQL via PSA (10.16.x.x)
        Authenticates with IAM (GSA has roles/cloudsql.client)
```

The cartservice container itself talks to Redis normally. The SQL Proxy sidecar runs alongside
to **prove** the WI chain works end-to-end. Verification: `kubectl logs <pod> -c cloud-sql-proxy`
should show "Listening on 127.0.0.1:5432" with no auth errors.

## Resource Budget

| Component | CPU Req | CPU Limit | Mem Req | Mem Limit |
|-----------|---------|-----------|---------|-----------|
| frontend | 100m | 200m | 64Mi | 128Mi |
| cartservice | 200m | 300m | 64Mi | 128Mi |
| cloud-sql-proxy | 50m | 100m | 32Mi | 64Mi |
| redis-cart | 70m | 125m | 100Mi | 128Mi |
| **Total** | **420m** | **725m** | **260Mi** | **448Mi** |

Fits comfortably on a single e2-medium Spot node (2 vCPU, 4GB RAM).

### Cost Estimate (Ephemeral, ~10h/day)

| Resource | 24/7 Cost | Ephemeral (~10h/day) |
|----------|-----------|---------------------|
| Spot e2-medium node | ~$8/month | ~$3-4/month |
| Cloud SQL db-f1-micro | ~$8/month | ~$4/month |
| Static IP (attached) | $0 | $0 |
| GKE management fee | $0 (Zonal) | $0 |
| **Total** | ~$16/month | ~$7-8/month |

Well within the $70/month budget.

## Workflow Integration

New `deploy-app` job in `.github/workflows/terraform.yml`:

```yaml
deploy-app:
  needs: [resolve, identity-apply]
  if: |
    always() &&
    inputs.action == 'apply' &&
    needs.resolve.outputs.run_identity == 'true' &&
    (needs.identity-apply.result == 'success' || needs.identity-apply.result == 'skipped')
```

Steps:
1. Checkout code
2. Authenticate to GCP via WIF
3. Install gke-gcloud-auth-plugin
4. Get GKE cluster credentials
5. Read Terraform outputs from GCS state (init + output)
6. `helm upgrade --install` with values from TF outputs

### Terraform Output Injection

```bash
# Init layers to read outputs
terraform -chdir=gob/networking init -backend-config="prefix=${CLIENT}/${ENV}/networking"
terraform -chdir=gob/database init -backend-config="prefix=${CLIENT}/${ENV}/database"
terraform -chdir=gob/compute init -backend-config="prefix=${CLIENT}/${ENV}/compute"

# Extract values
STATIC_IP_NAME=$(terraform -chdir=gob/networking output -json static_ip_names | jq -r '.ingress')
SQL_CONNECTION=$(terraform -chdir=gob/database output -json sql_connection_names | jq -r '.main')
GSA_EMAIL=$(terraform -chdir=gob/database output -json service_account_emails | jq -r '."btq-sql"')
CLUSTER_NAME=$(terraform -chdir=gob/compute output -json cluster_names | jq -r '.main')

# Deploy
helm upgrade --install online-boutique ./helm/online-boutique \
  -f ./helm/online-boutique/values-orel-dev.yaml \
  --set ingress.staticIpName=$STATIC_IP_NAME \
  --set sqlProxy.instanceConnectionName=$SQL_CONNECTION \
  --set serviceAccount.gsaEmail=$GSA_EMAIL \
  --namespace boutique
```

### Destroy Flow

Add `destroy-app` job that runs `helm uninstall` before Terraform destroy of identity layer.

## Container Images

| Service | Image | Version |
|---------|-------|---------|
| frontend | `us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend` | v0.10.4 |
| cartservice | `us-central1-docker.pkg.dev/google-samples/microservices-demo/cartservice` | v0.10.4 |
| redis | `redis:alpine` | latest |
| cloud-sql-proxy | `gcr.io/cloud-sql-connectors/cloud-sql-proxy` | 2 |

## Verification Checklist

After deployment:
1. **Pods running:** `kubectl get pods -n boutique` → all Running, all containers Ready
2. **SQL Proxy auth:** `kubectl logs <cartservice-pod> -c cloud-sql-proxy -n boutique` → "Listening on 127.0.0.1:5432"
3. **Ingress IP:** `kubectl get ingress -n boutique` → ADDRESS matches Static IP
4. **Frontend accessible:** `curl http://<STATIC_IP>` → 200 OK, HTML response
5. **Health checks:** GCP Console → Load Balancing → Backend healthy
6. **NEGs:** GCP Console → Network Endpoint Groups → Pod IPs registered
