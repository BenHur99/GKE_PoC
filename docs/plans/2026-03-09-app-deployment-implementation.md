# Stage 6: Application Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy a reduced Online Boutique (frontend + cartservice + redis) via a custom Helm chart with Gateway API ingress and Cloud SQL Proxy WI demo, deployed through GitHub Actions.

**Architecture:** Custom Helm chart in `helm/online-boutique/` with Gateway API (`gke-l7-regional-external-managed`) instead of GKE Ingress, because our Static IP is Regional External STANDARD tier which is incompatible with the global `gce` Ingress class. Gateway API is Google's recommended successor to Ingress and supports STANDARD tier regional IPs natively.

**Tech Stack:** Helm 3, Kubernetes Gateway API v1, GKE, Cloud SQL Auth Proxy 2, GitHub Actions

**Design doc:** `docs/plans/2026-03-09-app-deployment-design.md`

**Key discovery during planning:** GKE Ingress (`gce` class) creates a Global LB requiring PREMIUM tier. Our IP is STANDARD tier Regional. Switched to Gateway API (`gke-l7-regional-external-managed`) which supports STANDARD tier. BackendConfig/FrontendConfig are Ingress-only CRDs — Gateway API uses HealthCheckPolicy and HTTPRoute instead.

---

## Reference: Terraform Outputs Available

```bash
# Networking layer outputs (key = "ingress")
static_ip_addresses["ingress"]   # e.g., 34.x.x.x
static_ip_names["ingress"]       # orel-gob-dev-euw1-ip-ingress

# Database layer outputs (key = "main" for SQL, "btq-sql" for SA)
sql_connection_names["main"]     # orel-bh-sandbox:europe-west1:orel-gob-dev-euw1-sql-main
service_account_emails["btq-sql"] # orel-gob-dev-euw1-sa-btq-sql@orel-bh-sandbox.iam.gserviceaccount.com

# Compute layer outputs (key = "main")
cluster_names["main"]            # orel-gob-dev-euw1-gke-main
# Cluster zone: europe-west1-b (from tfvars, not an output)
```

---

## Task 1: Create Helm Chart Scaffold

**Files:**
- Create: `helm/online-boutique/Chart.yaml`
- Create: `helm/online-boutique/values.yaml`
- Create: `helm/online-boutique/values-orel-dev.yaml`
- Create: `helm/online-boutique/templates/_helpers.tpl`

### Step 1: Create Chart.yaml

```yaml
# helm/online-boutique/Chart.yaml
apiVersion: v2
name: online-boutique
description: Reduced Online Boutique deployment for GKE PoC (frontend + cartservice + redis)
type: application
version: 0.1.0
appVersion: "v0.10.4"
```

### Step 2: Create values.yaml (defaults)

```yaml
# helm/online-boutique/values.yaml

namespace: boutique

# --- Images ---
images:
  frontend:
    repository: us-central1-docker.pkg.dev/google-samples/microservices-demo/frontend
    tag: v0.10.4
  cartservice:
    repository: us-central1-docker.pkg.dev/google-samples/microservices-demo/cartservice
    tag: v0.10.4
  redis:
    repository: redis
    tag: alpine
  sqlProxy:
    repository: gcr.io/cloud-sql-connectors/cloud-sql-proxy
    tag: "2"

# --- Service Account (KSA with WI annotation) ---
serviceAccount:
  name: boutique-sql-proxy
  gsaEmail: ""  # Override per-env: orel-gob-dev-euw1-sa-btq-sql@...

# --- Frontend ---
frontend:
  replicas: 1
  port: 8080
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

# --- Cart Service ---
cartservice:
  replicas: 1
  port: 7070
  resources:
    requests:
      cpu: 200m
      memory: 64Mi
    limits:
      cpu: 300m
      memory: 128Mi

# --- Cloud SQL Auth Proxy (sidecar on cartservice) ---
sqlProxy:
  enabled: true
  instanceConnectionName: ""  # Override per-env: project:region:instance
  port: 5432
  resources:
    requests:
      cpu: 50m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 64Mi

# --- Redis ---
redis:
  replicas: 1
  port: 6379
  resources:
    requests:
      cpu: 70m
      memory: 100Mi
    limits:
      cpu: 125m
      memory: 128Mi

# --- Gateway (replaces Ingress) ---
gateway:
  enabled: true
  className: gke-l7-regional-external-managed
  staticIpName: ""  # Override per-env: orel-gob-dev-euw1-ip-ingress

# --- Health Check Policy ---
healthCheckPolicy:
  enabled: true
  path: /_healthz
  port: 8080
  intervalSec: 15
  timeoutSec: 5
  healthyThreshold: 2
  unhealthyThreshold: 3
```

### Step 3: Create values-orel-dev.yaml (client/env overrides)

```yaml
# helm/online-boutique/values-orel-dev.yaml
# Overrides for orel/dev — values injected from Terraform outputs at deploy time.
# The gateway.staticIpName, sqlProxy.instanceConnectionName, and serviceAccount.gsaEmail
# are passed via --set flags from the CI/CD workflow.
```

### Step 4: Create _helpers.tpl

```yaml
# helm/online-boutique/templates/_helpers.tpl
{{- define "online-boutique.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "online-boutique.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "online-boutique.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
```

### Step 5: Verify Helm chart scaffold lints

Run: `helm lint helm/online-boutique/`
Expected: "1 chart(s) linted, 0 chart(s) failed"

### Step 6: Commit

```bash
git add helm/online-boutique/Chart.yaml helm/online-boutique/values.yaml \
        helm/online-boutique/values-orel-dev.yaml helm/online-boutique/templates/_helpers.tpl
git commit -m "feat(helm): scaffold online-boutique chart with values and helpers"
```

---

## Task 2: Create Namespace and ServiceAccount Templates

**Files:**
- Create: `helm/online-boutique/templates/namespace.yaml`
- Create: `helm/online-boutique/templates/service-account.yaml`

### Step 1: Create namespace.yaml

```yaml
# helm/online-boutique/templates/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}
  labels:
    {{- include "online-boutique.labels" . | nindent 4 }}
```

### Step 2: Create service-account.yaml

The KSA must have the `iam.gke.io/gcp-service-account` annotation for Workload Identity.
GKE sees this annotation and injects an OIDC token into pods using this KSA.

```yaml
# helm/online-boutique/templates/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "online-boutique.labels" . | nindent 4 }}
  {{- if .Values.serviceAccount.gsaEmail }}
  annotations:
    iam.gke.io/gcp-service-account: {{ .Values.serviceAccount.gsaEmail }}
  {{- end }}
```

### Step 3: Verify templates render

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=test@test.iam.gserviceaccount.com`
Expected: Namespace and ServiceAccount YAML rendered with correct annotation

### Step 4: Commit

```bash
git add helm/online-boutique/templates/namespace.yaml \
        helm/online-boutique/templates/service-account.yaml
git commit -m "feat(helm): add namespace and KSA with WI annotation"
```

---

## Task 3: Create Redis Deployment and Service

**Files:**
- Create: `helm/online-boutique/templates/redis-deployment.yaml`
- Create: `helm/online-boutique/templates/redis-service.yaml`

### Step 1: Create redis-deployment.yaml

```yaml
# helm/online-boutique/templates/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-cart
  namespace: {{ .Values.namespace }}
  labels:
    app: redis-cart
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.redis.replicas }}
  selector:
    matchLabels:
      app: redis-cart
  template:
    metadata:
      labels:
        app: redis-cart
    spec:
      containers:
        - name: redis
          image: "{{ .Values.images.redis.repository }}:{{ .Values.images.redis.tag }}"
          ports:
            - containerPort: {{ .Values.redis.port }}
          readinessProbe:
            tcpSocket:
              port: {{ .Values.redis.port }}
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: {{ .Values.redis.port }}
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: {{ .Values.redis.resources.requests.cpu }}
              memory: {{ .Values.redis.resources.requests.memory }}
            limits:
              cpu: {{ .Values.redis.resources.limits.cpu }}
              memory: {{ .Values.redis.resources.limits.memory }}
          volumeMounts:
            - name: redis-data
              mountPath: /data
      volumes:
        - name: redis-data
          emptyDir: {}
```

### Step 2: Create redis-service.yaml

```yaml
# helm/online-boutique/templates/redis-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-cart
  namespace: {{ .Values.namespace }}
  labels:
    app: redis-cart
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    app: redis-cart
  ports:
    - port: {{ .Values.redis.port }}
      targetPort: {{ .Values.redis.port }}
      protocol: TCP
      name: redis
```

### Step 3: Verify templates render

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com | grep -A 50 "kind: Deployment" | head -60`
Expected: Redis Deployment with correct image, ports, probes, and resource limits

### Step 4: Commit

```bash
git add helm/online-boutique/templates/redis-deployment.yaml \
        helm/online-boutique/templates/redis-service.yaml
git commit -m "feat(helm): add redis-cart deployment and service"
```

---

## Task 4: Create CartService Deployment with SQL Proxy Sidecar

**Files:**
- Create: `helm/online-boutique/templates/cartservice-deployment.yaml`
- Create: `helm/online-boutique/templates/cartservice-service.yaml`

### Step 1: Create cartservice-deployment.yaml

The cartservice pod has two containers:
1. **cartservice** — talks to Redis on `redis-cart:6379` (normal operation)
2. **cloud-sql-proxy** sidecar — authenticates to Cloud SQL via WI to prove the identity chain

The pod uses the KSA `boutique-sql-proxy` which has the WI annotation.
GKE auto-injects a projected OIDC token. The proxy reads it to exchange for a GCP access token
via STS API, then connects to Cloud SQL using the GSA's `roles/cloudsql.client` permission.

```yaml
# helm/online-boutique/templates/cartservice-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cartservice
  namespace: {{ .Values.namespace }}
  labels:
    app: cartservice
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.cartservice.replicas }}
  selector:
    matchLabels:
      app: cartservice
  template:
    metadata:
      labels:
        app: cartservice
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      terminationGracePeriodSeconds: 5
      containers:
        # --- Main container: cartservice (talks to Redis) ---
        - name: cartservice
          image: "{{ .Values.images.cartservice.repository }}:{{ .Values.images.cartservice.tag }}"
          ports:
            - containerPort: {{ .Values.cartservice.port }}
          env:
            - name: REDIS_ADDR
              value: "redis-cart:{{ .Values.redis.port }}"
          readinessProbe:
            grpc:
              port: {{ .Values.cartservice.port }}
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            grpc:
              port: {{ .Values.cartservice.port }}
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: {{ .Values.cartservice.resources.requests.cpu }}
              memory: {{ .Values.cartservice.resources.requests.memory }}
            limits:
              cpu: {{ .Values.cartservice.resources.limits.cpu }}
              memory: {{ .Values.cartservice.resources.limits.memory }}
        {{- if .Values.sqlProxy.enabled }}
        # --- Sidecar: Cloud SQL Auth Proxy (WI demo) ---
        # Authenticates via Workload Identity: KSA → GSA → Cloud SQL
        # Does NOT serve cartservice traffic — demonstrates E2E WI chain
        - name: cloud-sql-proxy
          image: "{{ .Values.images.sqlProxy.repository }}:{{ .Values.images.sqlProxy.tag }}"
          args:
            - "--structured-logs"
            - "--port={{ .Values.sqlProxy.port }}"
            - "{{ .Values.sqlProxy.instanceConnectionName }}"
          ports:
            - containerPort: {{ .Values.sqlProxy.port }}
              protocol: TCP
          resources:
            requests:
              cpu: {{ .Values.sqlProxy.resources.requests.cpu }}
              memory: {{ .Values.sqlProxy.resources.requests.memory }}
            limits:
              cpu: {{ .Values.sqlProxy.resources.limits.cpu }}
              memory: {{ .Values.sqlProxy.resources.limits.memory }}
          securityContext:
            runAsNonRoot: true
        {{- end }}
```

### Step 2: Create cartservice-service.yaml

```yaml
# helm/online-boutique/templates/cartservice-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: cartservice
  namespace: {{ .Values.namespace }}
  labels:
    app: cartservice
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    app: cartservice
  ports:
    - port: {{ .Values.cartservice.port }}
      targetPort: {{ .Values.cartservice.port }}
      protocol: TCP
      name: grpc
```

### Step 3: Verify templates render with SQL proxy

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com --set sqlProxy.instanceConnectionName=proj:region:inst | grep -A 80 "name: cartservice" | head -90`
Expected: Pod with 2 containers (cartservice + cloud-sql-proxy), serviceAccountName set

### Step 4: Verify templates render WITHOUT SQL proxy

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com --set sqlProxy.enabled=false | grep -A 50 "name: cartservice" | head -60`
Expected: Pod with only 1 container (no cloud-sql-proxy sidecar)

### Step 5: Commit

```bash
git add helm/online-boutique/templates/cartservice-deployment.yaml \
        helm/online-boutique/templates/cartservice-service.yaml
git commit -m "feat(helm): add cartservice with Cloud SQL Proxy sidecar for WI demo"
```

---

## Task 5: Create Frontend Deployment and Service

**Files:**
- Create: `helm/online-boutique/templates/frontend-deployment.yaml`
- Create: `helm/online-boutique/templates/frontend-service.yaml`

### Step 1: Create frontend-deployment.yaml

```yaml
# helm/online-boutique/templates/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    app: frontend
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.frontend.replicas }}
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      serviceAccountName: {{ .Values.serviceAccount.name }}
      terminationGracePeriodSeconds: 5
      containers:
        - name: frontend
          image: "{{ .Values.images.frontend.repository }}:{{ .Values.images.frontend.tag }}"
          ports:
            - containerPort: {{ .Values.frontend.port }}
          env:
            - name: PORT
              value: "{{ .Values.frontend.port }}"
            - name: PRODUCT_CATALOG_SERVICE_ADDR
              value: "productcatalogservice:3550"
            - name: CURRENCY_SERVICE_ADDR
              value: "currencyservice:7000"
            - name: CART_SERVICE_ADDR
              value: "cartservice:{{ .Values.cartservice.port }}"
            - name: RECOMMENDATION_SERVICE_ADDR
              value: "recommendationservice:8080"
            - name: SHIPPING_SERVICE_ADDR
              value: "shippingservice:50051"
            - name: CHECKOUT_SERVICE_ADDR
              value: "checkoutservice:5050"
            - name: AD_SERVICE_ADDR
              value: "adservice:9555"
            - name: SHOPPING_ASSISTANT_SERVICE_ADDR
              value: ""
            - name: ENABLE_PROFILER
              value: "0"
          readinessProbe:
            httpGet:
              path: /_healthz
              port: {{ .Values.frontend.port }}
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /_healthz
              port: {{ .Values.frontend.port }}
            initialDelaySeconds: 10
            periodSeconds: 15
          resources:
            requests:
              cpu: {{ .Values.frontend.resources.requests.cpu }}
              memory: {{ .Values.frontend.resources.requests.memory }}
            limits:
              cpu: {{ .Values.frontend.resources.limits.cpu }}
              memory: {{ .Values.frontend.resources.limits.memory }}
```

**Note:** The frontend env vars reference backend services that don't exist in our reduced deployment.
The frontend will show errors for those services (product catalog, recommendations, etc.) but the
main page will still load. This is expected and acceptable for the PoC — the goal is to prove
Ingress + Static IP + NEGs work, not to run a full e-commerce flow.

### Step 2: Create frontend-service.yaml

The Service needs the `cloud.google.com/neg` annotation for container-native load balancing.
This tells GKE to create a NEG (Network Endpoint Group) that registers Pod IPs directly with
the Load Balancer — traffic goes LB → Pod, skipping the Node kube-proxy hop.

```yaml
# helm/online-boutique/templates/frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    app: frontend
    {{- include "online-boutique.labels" . | nindent 4 }}
  annotations:
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: {{ .Values.frontend.port }}
      protocol: TCP
      name: http
```

### Step 3: Verify templates render

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com --set sqlProxy.instanceConnectionName=p:r:i`
Expected: Full chart renders without errors, frontend Service has NEG annotation

### Step 4: Commit

```bash
git add helm/online-boutique/templates/frontend-deployment.yaml \
        helm/online-boutique/templates/frontend-service.yaml
git commit -m "feat(helm): add frontend deployment and service with NEG annotation"
```

---

## Task 6: Create Gateway API Resources (Gateway + HTTPRoute + HealthCheckPolicy)

**Files:**
- Create: `helm/online-boutique/templates/gateway.yaml`
- Create: `helm/online-boutique/templates/httproute.yaml`
- Create: `helm/online-boutique/templates/health-check-policy.yaml`

### Step 1: Create gateway.yaml

The Gateway uses `gke-l7-regional-external-managed` class which creates a Regional External
Application Load Balancer. This matches our STANDARD tier regional Static IP.

Why not GKE Ingress (`gce` class)? Because `gce` creates a **Global** LB that requires
PREMIUM tier. Our Static IP is STANDARD tier Regional — incompatible.

```yaml
# helm/online-boutique/templates/gateway.yaml
{{- if .Values.gateway.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  gatewayClassName: {{ .Values.gateway.className }}
  listeners:
    - name: http
      protocol: HTTP
      port: 80
  {{- if .Values.gateway.staticIpName }}
  addresses:
    - type: NamedAddress
      value: {{ .Values.gateway.staticIpName }}
  {{- end }}
{{- end }}
```

### Step 2: Create httproute.yaml

HTTPRoute is the Gateway API equivalent of Ingress path rules. It routes traffic from the
Gateway to the frontend Service.

```yaml
# helm/online-boutique/templates/httproute.yaml
{{- if .Values.gateway.enabled }}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  parentRefs:
    - kind: Gateway
      name: frontend
  rules:
    - backendRefs:
        - name: frontend
          port: 80
{{- end }}
```

### Step 3: Create health-check-policy.yaml

HealthCheckPolicy is the Gateway API equivalent of BackendConfig health checks.
It tells the LB how to health-check the backend pods.

```yaml
# helm/online-boutique/templates/health-check-policy.yaml
{{- if .Values.healthCheckPolicy.enabled }}
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: frontend
  namespace: {{ .Values.namespace }}
  labels:
    {{- include "online-boutique.labels" . | nindent 4 }}
spec:
  default:
    checkIntervalSec: {{ .Values.healthCheckPolicy.intervalSec }}
    timeoutSec: {{ .Values.healthCheckPolicy.timeoutSec }}
    healthyThreshold: {{ .Values.healthCheckPolicy.healthyThreshold }}
    unhealthyThreshold: {{ .Values.healthCheckPolicy.unhealthyThreshold }}
    config:
      type: HTTP
      httpHealthCheck:
        port: {{ .Values.healthCheckPolicy.port }}
        requestPath: {{ .Values.healthCheckPolicy.path }}
  targetRef:
    group: ""
    kind: Service
    name: frontend
{{- end }}
```

### Step 4: Verify full chart renders

Run: `helm template test helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com --set sqlProxy.instanceConnectionName=p:r:i --set gateway.staticIpName=test-ip`
Expected: All resources render — Gateway with NamedAddress, HTTPRoute, HealthCheckPolicy

### Step 5: Run helm lint

Run: `helm lint helm/online-boutique/`
Expected: "1 chart(s) linted, 0 chart(s) failed"

### Step 6: Commit

```bash
git add helm/online-boutique/templates/gateway.yaml \
        helm/online-boutique/templates/httproute.yaml \
        helm/online-boutique/templates/health-check-policy.yaml
git commit -m "feat(helm): add Gateway API resources (Gateway, HTTPRoute, HealthCheckPolicy)"
```

---

## Task 7: Update GitHub Actions Workflow — Add deploy-app Job

**Files:**
- Modify: `.github/workflows/terraform.yml`

### Step 1: Add `deploy_app` input checkbox

Add after the `layer_identity` input (around line 33):

```yaml
      deploy_app:
        description: "Deploy: Online Boutique (Helm)"
        required: false
        type: boolean
        default: false
```

### Step 2: Update resolve job — add deploy_app output

Add output to the resolve job (around line 65):

```yaml
      run_deploy_app: ${{ steps.resolve.outputs.run_deploy_app }}
```

Add deploy_app resolution logic inside the resolve step. After the existing dependency resolution
block (after the `fi` at line 135), add:

```bash
          DEPLOY_APP="${{ inputs.deploy_app }}"

          # deploy-app requires identity (for WI) + compute (for GKE) + networking (for IP)
          if [[ "${{ inputs.action }}" != "destroy" && "$DEPLOY_APP" == "true" ]]; then
            if [[ "$IDENTITY" == "false" ]]; then
              IDENTITY="true"
              AUTO_ADDS="${AUTO_ADDS}  ⚠️  Auto-added IDENTITY (required by deploy-app)\n"
            fi
            if [[ "$COMPUTE" == "false" ]]; then
              COMPUTE="true"
              AUTO_ADDS="${AUTO_ADDS}  ⚠️  Auto-added COMPUTE (required by deploy-app)\n"
            fi
          fi

          # Re-run base dependency resolution after deploy-app additions
          if [[ "$IDENTITY" == "true" && "$DATABASE" == "false" ]]; then
            DATABASE="true"
            AUTO_ADDS="${AUTO_ADDS}  ⚠️  Auto-added DATABASE (required by identity)\n"
          fi
          if [[ "$COMPUTE" == "true" && "$DATABASE" == "false" ]]; then
            DATABASE="true"
            AUTO_ADDS="${AUTO_ADDS}  ⚠️  Auto-added DATABASE (required by compute)\n"
          fi
          if [[ "$DATABASE" == "true" && "$NETWORKING" == "false" ]]; then
            NETWORKING="true"
            AUTO_ADDS="${AUTO_ADDS}  ⚠️  Auto-added NETWORKING (required by database)\n"
          fi
```

Add to the execution order display (after identity in apply direction):

```bash
            [[ "$DEPLOY_APP" == "true" ]] && ORDER="${ORDER}deploy-app → "
```

Add output:

```bash
          echo "run_deploy_app=${DEPLOY_APP}" >> "$GITHUB_OUTPUT"
```

Update Summary step to include Deploy App row.

### Step 3: Add deploy-app job (apply direction)

Add this job after `identity-apply` (before the destroy section):

```yaml
  # ==========================================================================
  # APPLICATION DEPLOYMENT (after all Terraform layers)
  # ==========================================================================

  deploy-app:
    name: "Deploy Online Boutique (Helm)"
    needs: [resolve, identity-apply, compute-apply]
    if: |
      always() &&
      needs.resolve.outputs.run_deploy_app == 'true' &&
      inputs.action == 'apply' &&
      (needs.identity-apply.result == 'success' || needs.identity-apply.result == 'skipped') &&
      (needs.compute-apply.result == 'success' || needs.compute-apply.result == 'skipped')
    runs-on: ubuntu-latest
    environment: ${{ inputs.client }}-${{ inputs.env_name }}
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Authenticate to GCP
        uses: google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed # v2.1.13
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd # v3.1.2
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: false

      - name: Install gke-gcloud-auth-plugin
        run: |
          gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || true

      - name: Get GKE Credentials
        run: |
          CLUSTER_NAME=$(cd gob/compute && terraform init -backend-config="prefix=${{ inputs.client }}/${{ inputs.env_name }}/compute" > /dev/null 2>&1 && terraform output -json cluster_names | jq -r '.main')
          gcloud container clusters get-credentials "$CLUSTER_NAME" \
            --zone europe-west1-b \
            --project ${{ secrets.GCP_PROJECT_ID }}

      - name: Read Terraform Outputs
        id: tf-outputs
        run: |
          # Init networking to read static IP name
          terraform -chdir=gob/networking init -backend-config="prefix=${{ inputs.client }}/${{ inputs.env_name }}/networking" > /dev/null 2>&1
          STATIC_IP_NAME=$(terraform -chdir=gob/networking output -json static_ip_names | jq -r '.ingress')

          # Init database to read SQL connection and GSA email
          terraform -chdir=gob/database init -backend-config="prefix=${{ inputs.client }}/${{ inputs.env_name }}/database" > /dev/null 2>&1
          SQL_CONNECTION=$(terraform -chdir=gob/database output -json sql_connection_names | jq -r '.main')
          GSA_EMAIL=$(terraform -chdir=gob/database output -json service_account_emails | jq -r '."btq-sql"')

          echo "static_ip_name=${STATIC_IP_NAME}" >> "$GITHUB_OUTPUT"
          echo "sql_connection=${SQL_CONNECTION}" >> "$GITHUB_OUTPUT"
          echo "gsa_email=${GSA_EMAIL}" >> "$GITHUB_OUTPUT"

          echo "Static IP Name: ${STATIC_IP_NAME}"
          echo "SQL Connection: ${SQL_CONNECTION}"
          echo "GSA Email: ${GSA_EMAIL}"

      - name: Install Helm
        uses: azure/setup-helm@fe7b79cd5ee1e45176fcad797de68ecaf3ca4814 # v4.2.0
        with:
          version: v3.14.0

      - name: Helm Deploy
        run: |
          helm upgrade --install online-boutique ./helm/online-boutique \
            --namespace boutique \
            --create-namespace \
            --set gateway.staticIpName=${{ steps.tf-outputs.outputs.static_ip_name }} \
            --set sqlProxy.instanceConnectionName=${{ steps.tf-outputs.outputs.sql_connection }} \
            --set serviceAccount.gsaEmail=${{ steps.tf-outputs.outputs.gsa_email }} \
            --wait \
            --timeout 5m

      - name: Verify Deployment
        run: |
          echo "=== Pods ==="
          kubectl get pods -n boutique
          echo ""
          echo "=== Services ==="
          kubectl get svc -n boutique
          echo ""
          echo "=== Gateway ==="
          kubectl get gateway -n boutique
          echo ""
          echo "=== HTTPRoute ==="
          kubectl get httproute -n boutique
```

### Step 4: Add destroy-app job (destroy direction)

Add this before `identity-destroy` in the destroy section:

```yaml
  # Application must be uninstalled before identity destroy (WI binding removal)
  destroy-app:
    name: "Destroy Online Boutique (Helm)"
    needs: [resolve]
    if: |
      needs.resolve.outputs.run_deploy_app == 'true' &&
      inputs.action == 'destroy'
    runs-on: ubuntu-latest
    environment: ${{ inputs.client }}-${{ inputs.env_name }}
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Authenticate to GCP
        uses: google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed # v2.1.13
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd # v3.1.2
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: false

      - name: Install gke-gcloud-auth-plugin
        run: |
          gcloud components install gke-gcloud-auth-plugin --quiet 2>/dev/null || true

      - name: Get GKE Credentials
        run: |
          CLUSTER_NAME=$(cd gob/compute && terraform init -backend-config="prefix=${{ inputs.client }}/${{ inputs.env_name }}/compute" > /dev/null 2>&1 && terraform output -json cluster_names | jq -r '.main')
          gcloud container clusters get-credentials "$CLUSTER_NAME" \
            --zone europe-west1-b \
            --project ${{ secrets.GCP_PROJECT_ID }}

      - name: Install Helm
        uses: azure/setup-helm@fe7b79cd5ee1e45176fcad797de68ecaf3ca4814 # v4.2.0
        with:
          version: v3.14.0

      - name: Helm Uninstall
        run: |
          helm uninstall online-boutique --namespace boutique --wait --timeout 3m || true
          kubectl delete namespace boutique --timeout=60s || true
```

### Step 5: Update identity-destroy to depend on destroy-app

Change `identity-destroy` needs from `[resolve]` to `[resolve, destroy-app]` and add
the result check:

```yaml
  identity-destroy:
    name: "Identity (destroy)"
    needs: [resolve, destroy-app]
    if: |
      always() &&
      needs.resolve.outputs.run_identity == 'true' &&
      inputs.action == 'destroy' &&
      (needs.destroy-app.result == 'success' || needs.destroy-app.result == 'skipped')
```

### Step 6: Commit

```bash
git add .github/workflows/terraform.yml
git commit -m "feat(workflow): add deploy-app and destroy-app jobs for Helm deployment"
```

---

## Task 8: Update Design Doc and CLAUDE.md

**Files:**
- Modify: `docs/plans/2026-03-09-app-deployment-design.md` — update to reflect Gateway API instead of Ingress
- Modify: `CLAUDE.md` — add Stage 6 status

### Step 1: Update design doc

Add a note at the top of the design doc:

```markdown
**Update (implementation):** Switched from GKE Ingress (`gce` class) to Gateway API
(`gke-l7-regional-external-managed`) because our Static IP is STANDARD tier Regional,
which is incompatible with the Global LB created by GKE Ingress. Gateway API resources
(Gateway, HTTPRoute, HealthCheckPolicy) replace BackendConfig, FrontendConfig, and Ingress.
```

### Step 2: Update CLAUDE.md Stage 6 section

Add after the Stage 5 section:

```markdown
### Stage 6: Application Deployment - CODE READY, NOT APPLIED

**What's done:**
- Custom Helm chart at `helm/online-boutique/`
- Frontend + CartService + Redis deployments
- Cloud SQL Auth Proxy sidecar on cartservice (WI demo)
- Gateway API (gke-l7-regional-external-managed) with Static IP
- HealthCheckPolicy for frontend health checks
- Workflow updated with deploy-app/destroy-app jobs
- Design doc: `docs/plans/2026-03-09-app-deployment-design.md`

**Application resources:**
| Resource | Name |
|----------|------|
| Namespace | boutique |
| KSA | boutique-sql-proxy (WI → GSA btq-sql) |
| Deployment | frontend (1 replica, port 8080) |
| Service | frontend (ClusterIP:80, NEG annotation) |
| Deployment | cartservice (1 replica + SQL Proxy sidecar) |
| Service | cartservice (ClusterIP:7070) |
| Deployment | redis-cart (1 replica, port 6379) |
| Service | redis-cart (ClusterIP:6379) |
| Gateway | frontend (gke-l7-regional-external-managed, Static IP) |
| HTTPRoute | frontend (→ frontend:80) |
| HealthCheckPolicy | frontend (HTTP /_healthz:8080) |
```

### Step 3: Commit

```bash
git add docs/plans/2026-03-09-app-deployment-design.md CLAUDE.md
git commit -m "docs: update design doc and CLAUDE.md for Stage 6 app deployment"
```

---

## Task 9: Final Validation — helm template + helm lint

### Step 1: Run full helm template with all overrides

Run:
```bash
helm template online-boutique helm/online-boutique/ \
  --set serviceAccount.gsaEmail=orel-gob-dev-euw1-sa-btq-sql@orel-bh-sandbox.iam.gserviceaccount.com \
  --set sqlProxy.instanceConnectionName=orel-bh-sandbox:europe-west1:orel-gob-dev-euw1-sql-main \
  --set gateway.staticIpName=orel-gob-dev-euw1-ip-ingress
```

Expected: All 11 resources render:
1. Namespace (boutique)
2. ServiceAccount (boutique-sql-proxy with WI annotation)
3. Deployment (redis-cart)
4. Service (redis-cart)
5. Deployment (cartservice with 2 containers)
6. Service (cartservice)
7. Deployment (frontend)
8. Service (frontend with NEG annotation)
9. Gateway (with NamedAddress)
10. HTTPRoute
11. HealthCheckPolicy

### Step 2: Run helm lint

Run: `helm lint helm/online-boutique/`
Expected: "1 chart(s) linted, 0 chart(s) failed"

### Step 3: Verify resource counts

Run: `helm template online-boutique helm/online-boutique/ --set serviceAccount.gsaEmail=x@x.iam.gserviceaccount.com --set sqlProxy.instanceConnectionName=p:r:i --set gateway.staticIpName=test | grep "^kind:" | sort | uniq -c`

Expected output (11 resources):
```
3 kind: Deployment
1 kind: Gateway
1 kind: HTTPRoute
1 kind: HealthCheckPolicy
1 kind: Namespace
3 kind: Service
1 kind: ServiceAccount
```

### Step 4: Commit (if any fixes were needed)

```bash
git add -A
git commit -m "fix(helm): address lint/template issues"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Helm chart scaffold | Chart.yaml, values.yaml, values-orel-dev.yaml, _helpers.tpl |
| 2 | Namespace + KSA | namespace.yaml, service-account.yaml |
| 3 | Redis | redis-deployment.yaml, redis-service.yaml |
| 4 | CartService + SQL Proxy | cartservice-deployment.yaml, cartservice-service.yaml |
| 5 | Frontend | frontend-deployment.yaml, frontend-service.yaml |
| 6 | Gateway API | gateway.yaml, httproute.yaml, health-check-policy.yaml |
| 7 | Workflow | terraform.yml (deploy-app + destroy-app jobs) |
| 8 | Docs | design doc update, CLAUDE.md update |
| 9 | Validation | helm template + helm lint |
