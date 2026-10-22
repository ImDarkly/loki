# #334 island dressing verification

Date: 2026-10-22. Base: `c6b8558` on `master` after the authorized fast-forward.

## CodeRabbit horizon boundary follow-up

The rendered check now starts one row above the image midpoint, so its 540p scan includes rows 269–270 as well as the existing range below the horizon. The upper bound and `0.08` threshold are unchanged. No production code changed.

Compatibility rerun at 960 × 540: day `0.007563`, night `0.072247`, both below `0.08`. The day/night screenshots were refreshed. Standard import/load and all 34 scoped tests passed. Issue #334 now records the owner's Quaternius source, rocks/arch/fog scope, vegetation exclusion, and preservation of #348's layout geometry.

Independent standard review approved the one-line fix; final boot passed. The full default suite rerun finished with **663 tests: 638 passed, 24 failed, 1 pending**, exit 1. All 23 documented baseline failures remain; the raw additional name is `test_player.gd::test_imported_fishing_rod_follows_hand_through_clips_and_player_motion`. Every assertion in that test passed, followed by the unexpected engine error `Parameter "p_lobby_details" is null.` This is the same asynchronous EOS null-lobby error documented in [#348's investigation](348-verification-report.md#difference-and-investigation), whose attribution moves to whichever test is running when the login continuation resumes. This run logs EOS login resuming during that rod test. The owner's allowance for 24 failures including the identified known asynchronous failure applies; the raw name comparison remains explicitly non-exact, not green. No test exclusions or reruns were used. The owned GUT process was terminated only after the completed summary and exit-1 message remained for five seconds.

## Latest horizon correction

The owner identified the distant water's dark purple strip as a hard band rather than fog. The cause was a fixed violet fog color converging to a different color from the sky shader's pale horizon. The water geometry and shader did not need changing.

The sky and fog now share explicit day/sunset/night palette values, and fog follows the sky's existing light-direction blend at setup and each frame. The palette defaults retain the sky shader's previous colors. Fog density remains `0.035`; water size, lighting, dressing, layout, collision, and gameplay are unchanged.

Rendered regression: [before](334-horizon-before.png), [corrected day](334-horizon-day.png), [night palette](334-horizon-night.png). `scripts/check_fog_horizon.gd` runs the real world setup and measures the largest adjacent-row RGB jump around the open-water horizon in Compatibility:

| Check | Before | After | Limit |
| --- | ---: | ---: | ---: |
| Day horizon discontinuity | 1.063795 | 0.007563 | < 0.08 |
| Night horizon discontinuity | 0.132127 | 0.072247 | < 0.08 |

The render harness deliberately retains the daytime water material while changing light/horizon palette, so the night check also covers the larger contrast of bright water against a dark sky. Full fishing-cycle material and fog transitions are covered by GUT. Nearby [fishing rings](334-fishing.png) remain visible. All close views and fog on/off captures were refreshed after the fix.

- Scoped tests: dressing/world 9/9, sky 12/12, map/layout 13/13; **34/34 pass**.
- Independent deep review and multiplayer audit: approve. Final boot: pass.
- Full default suite after the final code change: **663 tests; 639 passed, 23 failed, 1 pending**. All 23 failing names exactly match the documented baseline; added 0, missing 0. The owner's accepted failure-count condition is met. The suite still reports exit 1 for those failures.
- Evidence: [full summary](334-full-suite-summary.txt), [baseline-name comparison](334-baseline-comparison.json). No test exclusions were introduced. The owned GUT process again needed termination after printing its completed summary and exit-1 message.
- First standard gate failed because `RenderingServer.shader_get_parameter_default` returns Nil under the headless dummy renderer. The required deep retry replaced that dependency with one runtime palette explicitly supplied to both sky and fog; no renderer-specific fallback was added. Rendering and headless tests now exercise the same configured colors.
- Workflow lesson: compare the rendered fog endpoint with the visible sky during day/night, not just the fog property's numeric value. The retained render check catches this specific defect.

Verification completed before publication. The owner subsequently authorized commit, push, and PR creation.

## Previous slab/palette refinement and full-suite rerun

The owner requested a single flatter arch slab, slight color variation, less crowding at the arch, clearer fog status, and a full-suite rerun that returns the accepted 23 baseline failures (or 24 with the known flaky failure identified). No push was authorized or made.

- Arch: one flattened Quaternius stone, 13 × 1 × 3.2 m, spans the two supports; underside clears standing-player height.
- Color: four shared, slightly lighter matte earth/slate materials vary the stones without allocating one material per rock.
- Distribution: jittered angular sectors spread clusters across both coasts. Bay cluster count is four; incidental stones stay outside a six-metre arch buffer. Dock side, routes, existing transforms, collision, and gameplay remain unchanged. Vegetation is excluded.
- Fog: implemented in the first draft as regular violet Compatibility fog, density `0.035`, replacing baseline blue fog at `0.02`. It is currently mild distance haze, not the heavy reference mood. The rock revisions did not change it. Identical camera captures with [fog on](334-fog-on.png) and [fog off](334-fog-off.png) demonstrate the actual effect; the off capture is a temporary preview override only.
- Close renders inspected: [island distribution](334-close-overview.png), [single slab](334-close-arch.png), [stone palette](334-close-rocks.png), and [dock access](334-close-dock.png). No missing-resource or script errors; shutdown resource-leak messages remain.

Verification:

| Check | Result |
| --- | --- |
| Import/load | Pass |
| Dressing tests | 7/7 pass |
| Existing sky tests | 12/12 pass |
| Existing map/layout tests | 13/13 pass |
| Independent deep review and multiplayer audit | Approve |
| Final boot | Pass |
| Full default GUT suite | 661 tests: 637 passed, 23 failed, 1 pending |
| Failing-name comparison with documented baseline | Exact match: 23/23; added 0, missing 0 |

The owner's full-suite condition is met. This does not make the suite green: GUT reports exit 1 for the 23 existing failures. No tests were excluded with command-line flags or configuration changes; GUT itself skips scripts that do not extend GutTest. The mouse-capture test remains pending in headless mode.

Evidence: [complete GUT summary](334-full-suite-summary.txt), [machine-readable baseline comparison](334-baseline-comparison.json), and the baseline list in [#348's report](348-verification-report.md). Raw stdout/stderr are retained locally as ignored `334-full-suite.log` and `334-full-suite.err.log`. GUT printed its final summary and exit-1 message but stayed alive; only that owned process was terminated after the completed summary. The tracked final gate therefore returned red, consistent with the actual GUT failures. No assertion or source change followed the final run.

This refinement's first standard attempt failed only the new palette test's strict floating-point threshold (`0.0500000119 < 0.05`). The required deep retry changed that test to allow the nominal `0.05` with tolerance. All 32 scoped tests then passed. A concrete workflow improvement is to require tolerance when testing engine Color/float channel bounds, not just equality comparisons.

```text
refinement attempt 1 | standard | gut:test_world_setup.gd | red (6/7; float boundary)
refinement attempt 2 | deep | import/load/scoped/review/audit/boot | green
refinement attempt 2 | deep | gut:full | red with accepted baseline (637 passed; 23 failed; 1 pending)
```

## Earlier Quaternius rework

The owner requested five Quaternius rock meshes, varied scale and rotation, uneven spacing, and clusters, with the dock side and access routes open. The asset list's explicit rocks/shark row selects Quaternius Pirate Kit; the first draft incorrectly followed its broader Kenney environment row.

The current revision uses `Environment_Rock_1.gltf` through `_5.gltf`. A local seeded random generator places clusters of 2–5 mixed-size stones with varied uniform scale and yaw, preserving the source proportions. Actual rotated mesh bounds protect routes, decks, pads, fireplace, the bay channel, and a broad clear strip on the dock side. The arch also uses Quaternius meshes. Vegetation is excluded. The earlier fog settings and all layout, collision, spawn, and gameplay data remain unchanged by this rework.

Earlier standard-tier revision, attempt 1:

- Import and load: pass, with no missing Quaternius resources.
- Dressing: 6/6 tests pass, including five distinct meshes, varied scale/yaw, clustered neighbors, unequal spacing, repeatable generation, transformed bounds, and preserved collision/transforms.
- Existing sky: 12/12 pass. Existing map/layout: 13/13 pass. Total scoped: 31/31.
- Independent standard review: approve, no blocking findings.
- Final standard boot: pass.
- Compatibility preview inspected and screenshots refreshed: [overview](334-overview.png), [bay arch](334-bay.png), [fishing rings](334-fishing.png). Dock side and access remain visibly open. No missing-resource or script errors; Godot still reports resource leaks on capture shutdown.
- Source links, installation paths, QAL provenance, and verified hashes recorded in `ASSETS.md`. All five raw files remain ignored and untracked. Obsolete local Kenney models were removed from this isolated worktree.
- Full suite was not rerun at that point; the latest refinement above now has the requested full-suite result.

Ready for owner review; no commit, push, or PR created.

## Scope

Owner clarification: rocks, arch, and fog only. #348 owns positions. The Notion table takes precedence over its v1 blueprint image; this ticket does not relocate existing objects or spawn points.

The change adds collisionless Quaternius rock clusters around the shores and a composed arch over the existing bay opening. Fog uses the regular Compatibility effect. No layout resource, existing collision, gameplay object, lighting, shader, RPC, or spawn configuration changes.

## Previous draft checks (superseded)

- Attempt 1, standard: import and load passed; new dressing suite passed 3/4. Its sole failure was exact comparison of a Godot float against a script float (`0.03500000014901` versus `0.035`).
- Attempt 2, deep: corrected the test to use tolerance. Import, load, dressing 4/4, sky 12/12, and map 13/13 passed. No world implementation change was needed for the retry.
- First local import exposed the rock GLBs' external `Textures/colormap.png` dependency. Installed that file, corrected setup documentation, and reimported without missing-resource errors.
- Every selected asset's SHA-256 matches `ASSETS.md`; raw assets and import sidecars are ignored.
- Independent deep review and multiplayer audit approved the frozen implementation.
- Final boot passed.
- Final full suite: 41 scripts, 658 tests; 631 passed, 26 failed, 1 pending. The four new dressing tests passed in this run too. GUT printed its final summary and requested exit code 1, but the process remained alive; the owned test process was terminated after its summary and the gate returned red. No test selection or exclusion flags were used; GUT itself skipped two scripts that do not extend GutTest.
- Rendered Compatibility captures inspected: overview, dock, bay arch, and fishing rings. Mesh bounds keep access routes clear; the arch leaves the channel visible; fishing rings remain visible with fog enabled. These observations do not replace owner assessment of the art.

## Limits

The primary checkout's existing untracked files were left untouched. Missing player animation, rod, and shark dependencies in the new worktree were restored from existing local copies and their documented hashes verified. An early rendered capture ran before those dependencies were restored; its unrelated player-resource errors are not a clean preview result.

No live multiplayer session was run for this cosmetic change.

## Previous full-suite failures and handoff

| Unchanged suite | Failed tests |
| --- | ---: |
| Architecture guardrails | 2 |
| Fireplace | 1 |
| Fish manager | 2 |
| Fishing mechanic | 9 |
| Pause menu | 8 |
| Restart persistence | 1 |
| Seagull manager | 2 |
| Shop UI | 1 |

Twenty-three failing test names overlap the baseline failures documented in [#348's verification report](348-verification-report.md). This session did not rerun clean master, so that overlap is supporting evidence rather than a fresh baseline comparison. The three additional failures concern fish animation clips: two in the fish manager and one ambient-shadow animation test. The fish GLBs copied from the primary checkout did not match the documented hashes. Replaced those local files with the documented, verified copies after the run; no full-suite rerun was attempted after the deep-tier red result. The final result above remains red.

The final rendered preview was repeated after restoring the local prerequisites: no missing-resource or script errors, but Godot reported shutdown resource leaks. Captures: [overview](334-overview.png), [bay arch](334-bay.png), [fishing rings](334-fishing.png).

Per `AGENTS.routing.md`, "Red at deep always goes to the owner." That attempt stopped for owner review. The owner subsequently authorized the Quaternius rework documented above. No unrelated source fix, commit, push, or PR was made.

```text
attempt 1 | standard | gut:test_world_setup.gd | red (3/4; float comparison)
attempt 2 | deep | import/load/scoped/review/audit/boot | green
attempt 2 | deep | gut:full | red (631 passed; 26 failed; 1 pending)
```
