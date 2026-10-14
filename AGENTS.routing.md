## Pipeline (append to AGENTS.md; keep short, it is the shared prefix)

Rationale for every rule: docs/workflow-design-rules.md. Do not edit this section mid-task; batch edits between tasks.

### Tier = risk, set by these triggers (not by agent judgment)
Run with `codex -p <profile>`. The highest tier touched wins. Never raise a tier "to be safe"; only escalation or a trigger raises it.

| Tier | Triggers |
|---|---|
| deep | network authority; lobby lifecycle (`scenes/lobby.gd`, `autoloads/game_manager.gd`, `autoloads/network_manager.gd`); peer sync (`@rpc`, `multiplayer.is_server()`, `_sync_*`, `_apply_synced_state`, MultiplayerSpawner); session cleanup (`disconnect_to_lobby`, `close_lobby`, restart/reset flows); EOS/EOSG/voice; internals of `player.gd`, `fishing_mechanic.gd` |
| standard | features, bug fixes, single-system changes |
| cheap | renames, text/UI tweaks, boilerplate, docs, formatting |

Cheap guard: a rename of an identifier used under `tests/unit/` is standard.
Task size: one behavior, about 3 files, about 150 lines. The planner splits; the implementer never does.

### Stages (a skipped stage spawns no agent)
1. planner (low effort). Runs the architecture checklist itself when no architect is spawned.
2. architect, only if the plan adds a node, signal, autoload, or network code, or adds a new system.
3. implementer, writes tests too. Effort follows the task tier.
4. `scripts/verify.ps1 -Tier <t>` (pre-check, scripted, zero tokens): import once, load check, scoped GUT. Red = stop here, no model review of broken code.
5. reviewer: skip on cheap; low effort on standard; high effort on deep.
6. auditor: deep only.
7. `scripts/verify.ps1 -Tier <t> -Final`: boot (standard, deep) and full GUT suite (deep only).
8. owner reviews.

Cheap = steps 1, 3, 4. Standard = 1, 3, 4, 5, 7. Deep = all.
Steps 5 and 6 may run in parallel, on a frozen diff only, and only after concurrency is confirmed in this Codex install; otherwise serial. Steps 4 and 7 are always serial.
If the diff changes after step 5/6: re-run step 4, and re-run only the reviewer/auditor whose scope the change touched (auditor only if network code changed).

### Verify gate (scripts/verify.ps1)
Order, fail-fast: import (once) -> load -> scoped GUT, one file at a time (tests bind fixed ports) -> boot -> full suite.
Scoped tests are derived from `git diff --name-only master` (file `x` maps to `tests/unit/test_x.gd`).
Exit codes: 0 green, 1 red (code defect), 2 environment problem.
UNVERIFIED: GUT exit codes, load-error detection, and `--quit-after` boot without EOS credentials. Try it once by hand.

### Handoffs: artifacts, never transcripts
Each stage passes one note, max about 150 words plus trimmed logs (max 40 lines):
```
HANDOFF <from> -> <to> | Tier | Branch
Task: one line
Acceptance: max 5 bullets
Files: max 5 paths
Decided: max 5 bullets (do not re-derive)
Open: max 3 bullets
Logs: trimmed failing output only
```
Agents read only the files and excerpts their handoff names. No repo-wide reads.

### Knowledge Base read (once per task)
The orchestrator fetches it once, filtered by Systems-touched tag, engineering entries only, max 5 entries. `applied` entries are rules, `idea` entries are hints. It passes the excerpt down. Subagents do not search Notion. Pillars and Ideas are not in the pipeline read path.

### Failure and escalation
Classify first:
- code defect (exit 1, reviewer/auditor "send back"): escalate.
- environment (exit 2: missing Godot, missing addons, import failure): fix it; this does not use up an attempt.
- ambiguity (acceptance criteria unclear): stop and ask the owner.

Red = non-zero exit, script parse error, failed assertion, crash, run over 90 s (full suite 600 s), or a blocking review finding.
Attempt = one implementer pass plus the gate for the current tier. Each retry runs exactly one tier above the previous attempt, keeps the working tree (no reset, no revert), and receives the previous diff plus trimmed failing output, never the plan again. No same-tier retries, no flake re-runs.

| Routed tier | Attempt 1 | Retry 1 | Retry 2 | Still red |
|---|---|---|---|---|
| cheap | cheap | standard | deep | owner |
| standard | standard | deep | n/a | owner |
| deep | deep | n/a | n/a | owner |

Red at deep always goes to the owner. On hand-off print one line per attempt: `attempt N | tier | check ID | green/red`, plus the failing output.

### Learning loop (PR rejection -> Notion)
Trigger, only this: the owner says a PR is rejected, changes are requested, it is closed unmerged, or a revert is requested. Not CodeRabbit comments, not gate failures.
`lesson_logger`: ask why once (quote verbatim); search the KB for the same rule, append "Seen again: PR #n, date" if found, else create an entry; fields: Date, PR/issue, Systems touched (this is the tag), Tier, What was rejected, Why, Proposed rule (one sentence), Stage that should have caught it, Status = idea. Never set `applied`; never edit Overview, Ideas, Roadmap. No Notion MCP: append to `docs/lessons-inbox.md`.

### Measure
After each task append a row to `docs/pipeline-metrics.csv` (date, task, tier, attempts, tokens from /status, result). Change one tier mapping at a time from this data and revert if cost or failures rise. If a stage uses over about 2x its estimated tokens, review its prompt and inputs before changing its tier.
