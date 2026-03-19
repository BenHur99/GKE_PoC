# Module Track Decision Framework

## Purpose

This framework helps determine which Terraform module strategy to use
at the start of a new GCP project. The decision affects maintainability,
compliance, and delivery speed.

## Three Tracks

### Track A: Custom Per-Resource Modules
- Each module wraps exactly one GCP resource
- Maximum control and transparency
- Team learns GCP internals deeply
- Best for: teams with GCP expertise, unique architectures, learning engagements

### Track B: Official Google Terraform Modules
- Community-maintained, Google-backed (github.com/terraform-google-modules)
- Pre-built best practices (labels, logging, security)
- Faster time-to-market
- Best for: enterprise compliance requirements, small teams, standard architectures

### Track C: Hybrid
- Official modules for complex resources (VPC, GKE, Cloud SQL)
- Custom modules for simple/unique resources (WIF, project APIs)
- Best for: most production projects

## Decision Criteria

| Factor | Custom (A) | Official (B) | Hybrid (C) |
|--------|-----------|-------------|-----------|
| Team GCP experience | Deep | Any | Moderate+ |
| Compliance requirements | Flexible | Strict (auditors want "official") | Standard |
| Timeline | Longer | Fastest | Medium |
| Customization needs | High | Low-Medium | Medium |
| Long-term maintenance | Team owns | Community owns | Shared |
| Team size | 3+ DevOps | 1-2 DevOps | 2+ DevOps |

## Decision Flow

1. Does the client require "Google-approved" modules for compliance? -> Track B
2. Does the project have highly custom architecture? -> Track A
3. Is the team small (<3) AND timeline tight? -> Track B
4. Default -> Track C (Hybrid)

## Key Official Modules

| Module | GitHub | Use Case |
|--------|--------|----------|
| terraform-google-network | terraform-google-modules/terraform-google-network | VPC, subnets, firewall, NAT, routes |
| terraform-google-kubernetes-engine | terraform-google-modules/terraform-google-kubernetes-engine | GKE clusters, node pools, workload identity |
| terraform-google-sql-db | terraform-google-modules/terraform-google-sql-db | Cloud SQL instances, databases, users |
| terraform-google-iam | terraform-google-modules/terraform-google-iam | Service accounts, IAM bindings |
| terraform-google-project-factory | terraform-google-modules/terraform-google-project-factory | Project creation, API enablement |
