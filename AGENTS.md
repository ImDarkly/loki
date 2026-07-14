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

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Project-specific

- Godot executable: `E:\Godot\Godot_v4.6.2-stable_win64.exe`

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

### Testing (GUT)
- `.gutconfig.json`: dirs `["res://tests/unit"]`, prefix `test_`, suffix `.gd`
- Pattern: `extends GutTest`, `before_each()` creates + adds child nodes, `autofree()`
- `watch_signals(obj)` + `assert_signal_emitted` / `assert_signal_emit_count`
- Test file per system: `test_health_component.gd`, `test_player.gd`

### Branch naming
- `feature/` for normal features, `feat/` for smaller, `codex/` for AI branches
- `chore/`, `prefactor/`, `slice-` for maintenance

### Running tests
- `E:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd`

## Startup Workflow

Before implementing any task:

1. Read the full task
2. Decide which GodotPrompter skills are relevant (check skill list)
3. Use the `skill` tool to load relevant skills
4. Switch to `master` branch: `git checkout master`
5. Fetch remote: `git fetch origin`
6. Create a new branch from master with a descriptive name: `git checkout -b <branch-name>`

If anything is unclear, ask me before proceeding.

## PowerShell encoding trap

When writing markdown with backticks (`` ` ``) to files in PowerShell:
- **NEVER use `@"..."@` here-strings** — PowerShell interprets backticks as escape characters (`` `t `` → tab, `` `r `` → CR, `` `n `` → newline), corrupting `` `code` `` into garbage.
- **ALWAYS use the `write` tool** to create any file containing backticks, even temp files.
- If you must use a shell string, use `@'...'@` (single-quoted here-string) which disables all escape processing.
- For `gh pr create --body`, write the body to a file via `write` tool, then pass `--body-file <path>`.
