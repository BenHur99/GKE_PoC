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
