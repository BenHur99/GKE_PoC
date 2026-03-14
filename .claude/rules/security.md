# Security Rules

## Secrets Management
- NEVER put secrets, passwords, API keys, or service account keys in `.tfvars`, `.tf`, or any tracked file
- Secrets belong in: environment variables, GCP Secret Manager, or GitHub Secrets
- `.tfvars` files contain ONLY non-secret configuration (CIDRs, machine types, flags)

## Network Security
- Default deny: all firewall rules start from a deny-all baseline
- No public IPs on compute resources unless explicitly justified in the design doc
- Private cluster nodes: GKE nodes must not have public IPs
- Use Cloud NAT for outbound internet access from private nodes
- PSA (Private Services Access) for managed services (Cloud SQL)

## IAM Best Practices
- Principle of least privilege: use specific roles, not `roles/owner`
- `roles/editor` is acceptable only for CI/CD service accounts with justification
- Prefer Workload Identity over service account keys (zero-trust, keyless)
- WI bindings: always specify exact namespace and KSA in the member field

## GCP-Specific
- Enable only required APIs — don't blanket-enable everything
- Use IAM conditions where possible to scope access
- Cloud SQL: enable IAM authentication, disable public IP
