# Git Workflow

## Commit Messages
- Follow conventional commits: `feat(scope)`, `fix(scope)`, `refactor(scope)`, `docs(scope)`, `chore(scope)`
- Scope = layer or component name: `networking`, `database`, `compute`, `automation`, `helm`, `workflow`
- Message body: explain WHY, not WHAT (the diff shows what changed)
- One logical change per commit — don't mix unrelated changes

## Branching
- `main` is the default branch
- Feature branches: `feat/<short-description>`
- Fix branches: `fix/<short-description>`
- Always create PR for non-trivial changes

## What NOT to Commit
- `.terraform/` directories (already in `.gitignore`)
- `.terraform.lock.hcl` files from local runs (CI generates its own)
- Secrets, credentials, service account keys — NEVER
- `*.tfstate` or `*.tfstate.backup` files

## PR Conventions
- Title: conventional commit format (e.g., `feat(compute): add GKE cluster module`)
- Description: summary of changes + link to design doc if applicable
- Always verify `terraform validate` passes before PR
