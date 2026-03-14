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
