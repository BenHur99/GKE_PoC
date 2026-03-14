---
paths:
  - ".github/**/*"
---

# CI/CD Workflow Rules

## Workflow Architecture
- Single unified workflow: `.github/workflows/terraform.yml`
- Trigger: `workflow_dispatch` with inputs for action (plan/apply/destroy) and layer selection
- Dependency resolution: `resolve` job auto-adds required base layers (networking → database → compute)
- Fail-fast: if a layer fails, all downstream layers are skipped

## Execution Order
- Apply: networking → database → compute → deploy-app
- Destroy: destroy-app → compute → database → networking (reverse order)
- Plan: networking → database → compute (sequential, fail-fast)

## GitHub Actions Conventions
- Pin ALL actions by SHA, not tag (e.g., `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`)
- Current pinned versions: checkout@v4.2.2, auth@v2.1.13, setup-terraform@v3.1.2, setup-gcloud@v2.1.2, setup-helm@v4.2.0
- When updating action versions: update BOTH the SHA and the version comment
- Always use `environment: ${{ inputs.client }}-${{ inputs.env_name }}` for secret scoping

## Authentication
- Workload Identity Federation (WIF) — NEVER use service account JSON keys
- Required secrets: `GCP_PROJECT_ID`, `WIF_PROVIDER`, `SERVICE_ACCOUNT`
- Permissions: `id-token: write`, `contents: read`

## Terraform in CI
- Always use `-auto-approve` in apply/destroy jobs (manual trigger already provides approval)
- Always use `-var-file=${{ env.TF_VAR_FILE }}` — never hardcode tfvars path
- Init with dynamic backend: `-backend-config="prefix=${{ inputs.client }}/${{ inputs.env_name }}/LAYER"`
- Use `terraform_wrapper: false` only in jobs that parse terraform output (deploy-app)

## Deploy Jobs
- Helm deploy reads Terraform outputs from state (networking + database layers)
- Values injected via `--set` flags, not values files — keeps coupling explicit
- Always run `kubectl get` verification after deploy
- Namespace adoption: `kubectl create --dry-run=client -o yaml | kubectl apply` for idempotent namespace handling

## Adding New Layers/Jobs
- Follow existing pattern: plan job, apply job, destroy job per layer
- Wire dependencies via `needs:` with fail-fast `always()` + result check pattern
- Update `resolve` job to handle new layer's dependencies
- Add new layer checkbox to `workflow_dispatch.inputs`
