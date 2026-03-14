# Claude Code Configuration Refactoring — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor CLAUDE.md from 412 lines to ~110 lines following Anthropic's official best practices, extract rules to `.claude/rules/`, move status to `docs/STATUS.md`, and clean up auto-memory.

**Architecture:** Split monolithic CLAUDE.md into: (1) concise CLAUDE.md with instructions only, (2) 5 path-scoped rule files in `.claude/rules/`, (3) `docs/STATUS.md` for roadmap/status/checklists, (4) clean MEMORY.md index.

**Tech Stack:** Markdown, Claude Code rules system (`.claude/rules/` with YAML frontmatter `paths:` field)

---

### Task 1: Create `.claude/rules/` directory and `terraform.md`

**Files:**
- Create: `.claude/rules/terraform.md`

**Step 1: Create the terraform rules file**

```markdown
---
paths:
  - "gob/**/*"
  - "modules/**/*"
---

# Terraform Conventions

## Module Structure
- Each module wraps a single GCP resource (or tightly-coupled pair like router+NAT)
- Module files: `main.tf`, `variables.tf`, `outputs.tf` — nothing else
- Single `main.tf` contains all resources — no splitting by resource type
- Modules are simple wrappers — they receive a pre-computed `name` from the caller

## Layer Structure
- Layer files: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `providers.tf`, `backend.tf`, `versions.tf`
- Client config: `tfvars/{client}/{env}.tfvars` per layer
- Layer `main.tf` orchestrates modules with `for_each` and constructs names using `naming_prefix`
- Cross-layer data: use `terraform_remote_state` in `data.tf`

## Variables & for_each
- ALWAYS use `map(object)` with `for_each` — NEVER `list`
- Even singleton resources (e.g., VPC) use `for_each` with a single-entry map
- Cross-resource linking: use a key field (e.g., `vpc_key`) to reference via map key
- Use `optional()` with defaults in variable type definitions

## State Management
- Each layer has its own state file (layer-based isolation)
- Backend prefix is dynamic: `terraform init -backend-config="prefix=CLIENT/ENV/LAYER"`
- GCS bucket: `terraform-states-gcs`
- NEVER hardcode prefix in `backend.tf`

## Validation
- Run `terraform validate` after any code change
- Run `terraform fmt -check` to verify formatting
- Run `terraform plan` before apply — review the plan output carefully

## Design Docs
- Before modifying a layer, read its design doc in `docs/plans/`
- Networking: `docs/plans/2026-03-01-bootstrap-networking-design-v2.md`
- Database: `docs/plans/2026-03-02-data-layer-design.md`
- Compute: `docs/plans/2026-03-02-compute-layer-design.md`
- Automation: `docs/plans/2026-03-04-automation-cicd-design.md`
- Identity: `docs/plans/2026-03-08-identity-ingress-design.md`
- App Deployment: `docs/plans/2026-03-09-app-deployment-design.md`
```

**Step 2: Verify file exists**

Run: `cat .claude/rules/terraform.md | head -5`
Expected: YAML frontmatter with `paths:` field

---

### Task 2: Create `.claude/rules/git.md`

**Files:**
- Create: `.claude/rules/git.md`

**Step 1: Create the git rules file**

```markdown
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
```

---

### Task 3: Create `.claude/rules/security.md`

**Files:**
- Create: `.claude/rules/security.md`

**Step 1: Create the security rules file**

```markdown
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
```

---

### Task 4: Create `.claude/rules/documentation.md`

**Files:**
- Create: `.claude/rules/documentation.md`

**Step 1: Create the documentation rules file**

```markdown
---
paths:
  - "docs/**/*"
---

# Documentation Standards

## Design Documents
- Location: `docs/plans/YYYY-MM-DD-<topic>-design.md`
- Implementation plans: `docs/plans/YYYY-MM-DD-<topic>-implementation.md`
- Every new layer or major feature MUST have a design doc before implementation
- Design doc sections: Goal, Architecture, Resources, Verification Checklist

## STATUS.md
- `docs/STATUS.md` tracks the 7-stage roadmap and current deployment state
- Update STATUS.md after every successful apply or destroy
- Update STATUS.md when a stage transitions (e.g., "NOT APPLIED" → "APPLIED")
- Verification checklists live in STATUS.md, not in CLAUDE.md

## CLAUDE.md
- CLAUDE.md contains ONLY behavioral instructions (coding conventions, run commands, architecture decisions)
- CLAUDE.md must stay under 200 lines — if it grows, extract to `.claude/rules/`
- No resource tables, no directory trees, no status tracking in CLAUDE.md
- Test: "Would removing this line cause Claude to make mistakes?" — if no, remove it
```

---

### Task 5: Create `.claude/rules/context-management.md`

**Files:**
- Create: `.claude/rules/context-management.md`

**Step 1: Create the context management rules file**

```markdown
# Claude Code Context Management

## Session Hygiene
- Run `/clear` between unrelated tasks — don't let context accumulate
- After 2 failed correction attempts on the same issue, `/clear` and start fresh with a better prompt
- Use subagents for codebase exploration to keep main context clean

## Memory Management
- `MEMORY.md` is an INDEX only — short pointers to topic files, never full content
- Topic files in `memory/` hold detailed notes (project status, execution context, decisions)
- Don't duplicate CLAUDE.md content in memory — memory is for things Claude learns, not static rules
- Keep MEMORY.md under 50 lines (well within the 200-line load limit)

## Before Starting Work
- Read `docs/STATUS.md` to understand current deployment state
- Read the relevant design doc in `docs/plans/` before modifying a layer
- Check git log for recent changes to the files you're about to modify

## Task Tracking
- Use TodoWrite for multi-step tasks (3+ steps)
- Mark tasks complete immediately after finishing — don't batch completions
- One task in_progress at a time

## When Compacting
- Preserve: list of modified files, test commands, current task state
- Discard: exploration results, failed approaches, verbose command outputs
```

---

### Task 6: Create `docs/STATUS.md`

**Files:**
- Create: `docs/STATUS.md`

**Step 1: Extract roadmap, status, and checklists from CLAUDE.md into STATUS.md**

This file contains everything that was in CLAUDE.md sections: "7-Stage Roadmap", "Current Status" (all stages), "GCP Console Verification Checklists", "GitHub Actions Verification Checklist", and "Design Documents" list.

Content: the full current status content from CLAUDE.md lines 209-413.

---

### Task 7: Rewrite CLAUDE.md (~110 lines)

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Replace CLAUDE.md with concise version**

Keep ONLY:
- About This Project (identity + owner context)
- Architecture (decisions Claude can't infer: single codebase, per-resource modules, naming, layer isolation, file structures)
- How to Run (bash + PowerShell commands)
- Coding Conventions (brief rules)
- Tech Stack (versions + backend)

Remove ALL:
- Directory Structure tree (lines 53-131)
- 7-Stage Roadmap (lines 209-217)
- Current Status — all stages (lines 219-401)
- Design Documents list (lines 403-413)

Target: ~110 lines

---

### Task 8: Clean up MEMORY.md

**Files:**
- Modify: `~/.claude/projects/c--Users-user-Desktop-GKE-PoC-GKE-PoC/memory/MEMORY.md`

**Step 1: Replace MEMORY.md with concise index**

Replace the current 80-line file with a ~20-line index that points to topic files.
Move detailed content to topic files (project-status.md, decisions.md, user-preferences.md).

---

### Task 9: Verify and commit

**Step 1: Verify line counts**

Run: `wc -l CLAUDE.md .claude/rules/*.md docs/STATUS.md`
Expected: CLAUDE.md < 130 lines, each rule < 60 lines

**Step 2: Verify rules frontmatter**

Run: `head -4 .claude/rules/terraform.md .claude/rules/documentation.md`
Expected: YAML frontmatter with `paths:` field

**Step 3: Commit**

```bash
git add CLAUDE.md .claude/rules/ docs/STATUS.md
git commit -m "refactor(docs): restructure CLAUDE.md per Anthropic best practices

- Reduce CLAUDE.md from 412 to ~110 lines (target: <200)
- Extract rules to .claude/rules/ (terraform, git, security, docs, context)
- Move roadmap/status/checklists to docs/STATUS.md
- Clean up MEMORY.md to index-only format"
```
