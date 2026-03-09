# Stage 5: Identity & Ingress — Design Document

## Context

Stage 5 bridges the infrastructure layers (networking, database, compute) with the application layer (Stage 6).
Two things are needed before deploying the Online Boutique app:

1. **Workload Identity (WI) bindings** — allow Kubernetes Service Accounts (KSAs) to impersonate Google Service Accounts (GSAs), so pods can securely access Cloud SQL without JSON keys
2. **Static Regional IP** — reserve an external IP for the Regional Application Load Balancer (L7) that will front the Online Boutique

**Scope:** Terraform only. K8s manifests (BackendConfig, FrontendConfig, Ingress) deferred to Stage 6.

## Architecture Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Static IP placement | `gob/networking/` layer | It's a network resource; must exist before cluster |
| WI bindings placement | New `gob/identity/` layer | Separation of concerns; doesn't belong in networking or compute |
| IP type | Regional External | Matches proxy-only subnet (Regional ALB with NEGs) |
| WI module pattern | Per-binding (single resource) | Consistent with per-resource module convention |
| K8s manifests | Deferred to Stage 6 | Cluster not yet deployed; keeps Terraform pure |

## How Workload Identity Works (GCP Internals)

```
Pod (KSA: boutique-sql-proxy)
  → GKE Metadata Server (GKE_METADATA mode on node pool)
    → IAM check: is KSA annotated with GSA?
      → IAM binding exists? (roles/iam.workloadIdentityUser)
        → YES → Short-lived access token for GSA (orel-gob-dev-euw1-sa-btq-sql)
          → Pod can now call Cloud SQL with GSA permissions
```

The `google_service_account_iam_member` resource creates the trust link:
- **Principal:** `serviceAccount:orel-bh-sandbox.svc.id.goog[NAMESPACE/KSA_NAME]`
- **Role:** `roles/iam.workloadIdentityUser`
- **On:** the GSA resource

The KSA annotation (`iam.gke.io/gcp-service-account=GSA_EMAIL`) is set in K8s manifests (Stage 6).

## How the Proxy-Only Subnet Integrates with Regional ALB

```
Client → Regional External IP (orel-gob-dev-euw1-ip-ingress)
  → Google Cloud Proxy (runs in proxy-only subnet 10.0.16.0/23)
    → NEG (Container-native, targets Pod IPs directly from 10.4.0.0/14)
      → Pod (no NodePort needed!)
```

The proxy-only subnet (`REGIONAL_MANAGED_PROXY`) is already created in networking.
The `allow-proxy-to-backends` firewall rule already allows traffic from this subnet to GKE pods.
The `allow-health-checks` firewall rule already allows Google health check probes.

**No additional firewall rules needed** — Stage 1 already configured everything.

## Container-Native Load Balancing with NEGs

Traditional GKE LB uses NodePort → kube-proxy → Pod (double hop, extra latency).
Container-native LB uses Network Endpoint Groups (NEGs) to target Pod IPs directly:

1. GKE automatically creates NEGs when a Service has `cloud.google.com/neg: '{"ingress": true}'` annotation
2. The LB health-checks pods directly (not nodes)
3. Traffic goes: Client → LB → Pod IP (single hop, lower latency)
4. Works because GKE pods use VPC-native IPs from the secondary range (10.4.0.0/14)

## New Modules

### `modules/static_ip/`
- Wraps `google_compute_address`
- Variables: name, project_id, region, address_type (default EXTERNAL), network_tier (default STANDARD)
- Outputs: id, address, self_link, name

### `modules/wi_binding/`
- Wraps `google_service_account_iam_member`
- Variables: gsa_name, project_id, k8s_namespace, ksa_name
- Outputs: id

## Layer Changes

### `gob/networking/` — +1 resource (static IP)
- New `static_ips` variable (map(object))
- New `module.static_ips` with for_each
- Resource: `orel-gob-dev-euw1-ip-ingress` (Regional External, STANDARD tier)

### `gob/identity/` — new layer, 1 resource
- Reads `terraform_remote_state` from database (for GSA names)
- `wi_bindings` variable (map(object) with gsa_key, k8s_namespace, ksa_name)
- Binding: KSA `boutique/boutique-sql-proxy` → GSA `orel-gob-dev-euw1-sa-btq-sql`

## Workflow Changes

### Updated Dependency Graph
```
Apply:   networking → database → compute → identity
Destroy: identity → compute → database → networking
```

- New input: `layer_identity` (boolean checkbox)
- New resolve output: `run_identity`
- Identity depends on database (for GSA names via remote_state)
- Destroy: identity destroyed first (before compute)

## Resource Summary

| Layer | Before | After | Delta |
|-------|--------|-------|-------|
| Networking | 15 | 16 | +1 (static IP) |
| Identity | — | 1 | +1 (WI binding) |
| **Total** | **15** | **17** | **+2** |
