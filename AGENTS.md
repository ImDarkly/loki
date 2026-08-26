Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

## 5. Ground Every Claim

**Uncertainty and unverified are different problems. Check for both.**

Before naming any file path, class name, addon, or API in a plan or diff:
- Have you `view`'d, `grep`'d, or `cat`'d it in this session? If not, don't name it — write "UNVERIFIED: need to check X" instead.
- If citing a GitHub issue, quote the actual body from `gh issue view`, not a paraphrase from the title.
- `addons/` is gitignored (see .gitignore) — never assume an addon exists or has a given path without listing the directory first.

The test: every file path or class name in a plan should trace to a tool call you actually ran, not to what a similar project would plausibly have.

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Project-specific

- Godot executable: `C:\Godot\Godot_v4.6.2-stable_win64.exe`

## Project Conventions

### Structure
- `entities/` — player, game objects
- `systems/` — domain systems (fishing, health, quota, round, zones, danger, voice_chat)
- `autoloads/` — singletons: `game_manager` (player tracking), `NetworkManager` (ENet host/join)
- `tests/unit/` — GUT tests, prefix `test_`, `extends GutTest`

### Code Style
- snake_case for variables, functions, signals
- PascalCase for class_name, autoload names, node paths
- `_` prefix for private members (`_held_fish`, `_clear_carry()`)
- `@export` for inspector-exposed vars, `const` for constants
- Signals emit typed args: `signal health_changed(old_value: int, new_value: int)`
- No comments unless explaining non-obvious intent

### Multiplayer
- `NetworkManager` (autoload) — ENet host/join via `host_game()`/`join_game()`
- `game_manager` (autoload) — player list, `Player_<id>` naming
- Server-gated: `if not multiplayer.is_server(): return`
- RPC: `@rpc("authority", "reliable", "call_remote")` for server→client, `@rpc("any_peer", "unreliable", "call_remote")` for client→server

### Manual/Dev Testing (Isolated System Scenes)

Every system with timers, state transitions, or player-triggered feedback (spawn/attack/return
cycles, shop purchases, interactables) gets a standalone dev scene under `scenes/dev/`, so its
feel/timing/visuals can be checked without booting lobby → host → full round flow.

**This is not a substitute for GUT tests.** Correctness (did the quota actually decrease, did the
signal actually fire) is proven in `tests/unit/`. Dev scenes are only for judging things tests
can't assert on: does the timing feel right, does the rock throw visually land, does 10s of
circling feel too long. If you're manually re-checking something a unit test already covers,
that's a sign the dev scene isn't needed for that check.

**Convention** (see `scenes/dev/dev_seagull_flow.tscn` + `.gd` as the reference implementation):

- Naming: `scenes/dev/dev_<system>_flow.tscn` / `.gd`
- Instantiate the target manager scene(s) directly — skip lobby/NetworkManager entirely, single
  instance, no peer.
- Wire only the minimal neighbor nodes the manager looks up via `get_node_or_null` (e.g.
  `StorageBox`, `RockManager`, `QuotaManager`) — don't drag in the rest of `main.tscn`.
- Include one `Player` instance if the system involves player interaction (throwing rocks,
  right-click interact), so those code paths are actually exercised.
- Add a debug HUD `Label` showing current state, timers, and relevant counters.
- Shorten the manager's timers/intervals *in the dev script*, not in the manager's own
  `@export` defaults — production values stay untouched.
- Add keyboard shortcuts to force-trigger transitions instead of waiting (see F5/F6/G/R in
  `dev_seagull_flow.gd`), and document them in a sibling `README.md` (see
  `scenes/dev/README.md`).

**When to add one:** when a new `systems/<name>/<name>_manager.gd` is introduced with its own
state machine or timers, add its `dev_<name>_flow.tscn` in the same slice/PR — don't defer it to
"later" once it becomes annoying to test.

### Testing (GUT)
- `.gutconfig.json`: dirs `["res://tests/unit"]`, prefix `test_`, suffix `.gd`
- Pattern: `extends GutTest`, `before_each()` creates + adds child nodes, `autofree()`
- `watch_signals(obj)` + `assert_signal_emitted` / `assert_signal_emit_count`
- Test file per system: `test_health_component.gd`, `test_player.gd`

### Branch naming
- `feature/` for normal features, `feat/` for smaller, `codex/` for AI branches
- `chore/`, `prefactor/`, `slice-` for maintenance

### Running tests
- `C:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd`

## Startup Workflow

Trigger: any message that references a GitHub issue, PR, or feature by number, name, or link (e.g. "work on issue #123", "start feature X"). You do not need the issue body pasted in — fetch it yourself.

Before implementing any task:

1. **Fetch the issue** (don't wait for the body to be pasted):
   `gh issue view <number>` (add `--repo <owner>/<repo>` if working outside the current repo's default remote)
   Read the full issue, including comments, before proceeding.
2. Decide which GodotPrompter skills are relevant (check skill list)
3. Use the `skill` tool to load relevant skills
4. Switch to `master` branch: `git checkout master`
5. Fetch remote: `git fetch origin`
6. Create a new branch from master with a descriptive name, following the Branch naming convention above: `git checkout -b <branch-name>`
7. If the feature adds a new `systems/<name>/<name>_manager.gd` with its own state machine or
   timers, include a `scenes/dev/dev_<name>_flow.tscn` per the Manual/Dev Testing convention
   above as part of the same slice.

If anything is unclear — ambiguous requirements, missing acceptance criteria, conflicting instructions — stop and ask before proceeding. Do not guess and continue.

### GitHub issue relationships
Whenever creating multiple issues with dependencies between them, use the `addBlockedBy` GraphQL mutation via `gh api graphql` to link them immediately after creation. The mutation takes `issueId` (the blocked issue) and `blockingIssueId` (the blocker). Get issue node IDs via a `repository(owner:, name:) { issue(number:) { id } }` query first.

## PowerShell encoding trap

When writing markdown with backticks (`` ` ``) to files in PowerShell:
- **NEVER use `@"..."@` here-strings** — PowerShell interprets backticks as escape characters (`` `t `` → tab, `` `r `` → CR, `` `n `` → newline), corrupting `` `code` `` into garbage.
- **ALWAYS use the `write` tool** to create any file containing backticks, even temp files.
- If you must use a shell string, use `@'...'@` (single-quoted here-string) which disables all escape processing.
- For `gh pr create --body`, write the body to a file via `write` tool, then pass `--body-file <path>`.

### Addons
- `addons/` is gitignored — not guaranteed to exist locally or match what's installed elsewhere. Always `view addons/` before referencing any addon path, plugin name, or class it provides.
