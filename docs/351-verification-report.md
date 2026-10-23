# Issue #351 verification

Date: 2026-10-23. Base: master `9605533c04111d76b742eb7e5ecf746df6e6c02b`, including the merged [#350 fish-tug repair](https://github.com/ImDarkly/loki/issues/350). Branch: `codex/351-suite-health`. Tier: deep.

## Scope and provenance

This continuation carries forward the owner-approved changes in local commits `74025eb`, `7bf367a`, and `1e3b498`, without modifying their original worktree. The prior owner decisions approved nine individually verified external export readers, wiring danger return intervals with unchanged 45–90 second defaults, removing the unused rock-manager setting while retaining the player's 3.0 range, and guarding the shop's root lookup. The additional repair retains the verification child-process handle before waiting for its exit.

## Fresh baseline and triage

Godot 4.6.2, GUT 9.6.0, EOSG 2.3.0. Ignored assets/addons were installed from the already verified #350 worktree; both fish-model hashes match `ASSETS.md`. No credentials or third-party assets enter the diff.

| Run | Scripts | Tests | Passed | Failed | Pending |
| --- | ---: | ---: | ---: | ---: | ---: |
| Initial baseline, missing local EOS credentials | 42 | 669 | 644 | 24 | 1 |
| Configured baseline, unchanged test/gameplay sources | 42 | 669 | 645 | 23 | 1 |
| Final deep gate, repaired sources | 42 | 669 | 668 | 0 | 1 |

The configured baseline reproduces every one of the issue's 23 named failures, with zero added or missing names. The initial run adds only the lobby test's missing-credentials error and is not the comparison baseline. Both runs use the default ordered suite and `-glog=1`; no test exclusions or configuration edits. The issue's historical 645-test comparison is separate evidence and is not rewritten by these 669-test results.

| Slice | Recorded failures | Cause and repair |
| --- | ---: | --- |
| Pause menu | 8 | Supply and restore an offline peer so fixtures have a valid local ID and authority. |
| Fishing mechanic | 8 | Supply and restore an offline fixture peer for zone occupancy; preserve explicit no-peer and ENet cases. |
| Fireplace and shop UI | 2 | Give successful purchase-notification cases a valid offline peer; retain notification and coin assertions. |
| Restart persistence | 1 | Scope the offline peer to the pause-close case; retain other no-peer restart coverage. |
| Seagull | 2 | Instantiate the real player scene, including its required slap component. |
| Architecture | 2 | Guard the nullable shop root lookup; retain strict export checks with nine exact declaration/reader exceptions; use danger exports and remove the unused manager range. |
| Lobby isolation | Separate asynchronous defect | Intercept candidate joining at the network boundary; verify one handoff and duplicate-click rejection; restore script, state, and connections. |

## Verification runner

Under redirected Windows PowerShell, `WaitForExit()` can return true while `ExitCode` is null. The old `$null -ne 0` comparison then reports a successful process as red. Retaining `Handle` before waiting preserves the exit code. The regression script exercises the real check function with child processes and retains master's positive-execution and skip safeguards.

## Current verification

| Check actually run | Result |
| --- | --- |
| `scripts/test_verify.ps1` under Windows PowerShell 5.1 | Before: exit 1, two successful cases falsely red; after: exit 0, all ten cases passed. |
| `scripts/verify.ps1 -Tier deep` | Exit 0; import, load, and all ten scoped suites passed: 211/211 tests. |
| Independent deep review | Approved; no blocking findings. |
| Multiplayer audit | Approved; no introduced authority, synchronization, or cleanup regressions found. |
| `scripts/verify.ps1 -Tier deep -Final` | Exit 0; boot and full GUT passed: 42 scripts, 669 tests, 668 passed, zero failed, one pending, 10,029 assertions, 99.034 seconds. Normal process exit; no forced termination. |
| `git diff --check` | Passed. |

Scoped suites: architecture 2/2, danger 32/32, fireplace 11/11, fishing 73/73, lobby 12/12, pause 19/19, restart 6/6, rocks 14/14, seagull 27/27, shop 15/15. Neither the default test configuration nor project settings changed.

## Process lifetime and limits

The configured baseline completed its GUT summary at 80.54 seconds, then exited at 137.63 seconds with Windows access-violation status `-1073741819` (`0xC0000005`). It was not force-killed. That process status is distinct from the 23 failed tests. The original lobby fixture starts a real asynchronous EOS join with an empty lobby; earlier retained #351 diagnostics reproduced the delayed null-lobby-details error and hanging shutdown. The repaired boundary spy prevents that work from starting. Real EOS joining remains outside this unit-test coverage.

The pending `test_player.gd::test_vertical_mouse_motion_looks_in_the_same_world_direction_in_each_player_state` requires a rendered display with mouse capture. It remains a manual/rendered coverage requirement. Existing resource-leak and engine warnings must be reported separately from passing assertions.

The final run has no script/parse errors or delayed null-lobby-details errors. Its only `ERROR:` is the deliberately asserted missing-animation diagnostic from `test_player_fishing_animation.gd::test_a_missing_tools_asset_keeps_locomotion_available`; the test restores the model/import sidecar, and the restored model's hash matches `ASSETS.md`. Lobby connection-failure, colinear-camera, and absent voice-bus warnings remain. Scoped runs emit resource/RID/ObjectDB leak diagnostics; those are not claimed repaired. The final full run emitted no such leak diagnostics.

All 42 test scripts execute, including fish-tug. The same non-test voice-manager helper and inner slap-component class are ignored in baseline and final runs because they do not extend `GutTest`; no test script failed compilation or was silently skipped. A separate existing mouse-look assertion also reports that its input path cannot execute without headless mouse capture; this is not rendered-input coverage.

## Evidence

Exact local stdout/stderr, process results, the baseline ordered hash manifest, and the issue-to-baseline failure-name comparison are retained under ignored `.godot/351-evidence/`. Baseline commands use `.godot/run-351-evidence.ps1` with `--headless --path . -s addons/gut/gut_cmdln.gd -glog=1`; raw files are `baseline-full.log*` (missing credentials) and `baseline-configured.log*` (comparison baseline). The helper retains the process handle and records timeout, actual exit status, arguments, and elapsed time independently of GUT totals.

Gate evidence: `precheck.log`, `precheck-result.json`, `scoped-results.json`, `final-gate.log`, `final-gate-result.json`, and `chum_verify_*.log` / `.log.err`. Regression command: `powershell.exe -NoProfile -File scripts/test_verify.ps1`; before/after output is `verify-regression-{before,after}.log` (the before file is explicitly labeled captured tool output). Review summaries are in `reviews.txt`. At the owner-review checkpoint, all source changes were uncommitted. The owner subsequently authorized commit, push, and PR creation; this report records the verification completed before publication.

Attempt 1 | deep | precheck / regression / review / audit / final | green.

## Report

Asked: restore #351 suite health; shipped: all 23 failures repaired, runner exit capture fixed, 668 passing and one rendered-only pending test.
Retried: installed missing local EOS credentials before the comparison baseline; no implementation or gate retry.
Missed: initial intake overlooked an existing #351 worktree, and the first baseline lacked an ignored credential prerequisite.
Suggestion for AGENTS.md: check all existing ticket worktrees and ignored prerequisites before creating a continuation worktree or running its baseline.
