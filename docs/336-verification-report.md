# #336 — sourced world props

Branch: `feature/336-sourced-world-props`, based on clean `master` / `origin/master` at `93a3caa`. Prerequisites #325 (PR #327) and #348 (PR #352) were verified merged before planning. The issue had no comments.

## Asked and implemented

Replace the four placeholder props while preserving gameplay. Storage now loads Kenney Watercraft's blue small fishing boat beside the ship deck on the water; the shop loads Mini Forest's blue canopy with wooden posts; the fireplace loads Survival Kit's pit/log model under its existing ownership-controlled flames; pickups cycle through all five already installed Quaternius Pirate rock meshes. Gameplay roots, collision shapes/layers, prompts, labels, seat anchors, ownership logic, pickup cooldowns, and RPC snapshots are unchanged. Only cosmetic children are calibrated.

The owner initially approved a red tent substitute, then identified Mini Forest as the correct source of the blue canopy shelter. The owner also confirmed that fishing spots keep relocating and any future lantern reveal uses their current positions. Lantern gameplay remains outside this ticket.

Raw packs remain outside the checkout. Selected models and their required color textures are locally installed in ignored directories. `ASSETS.md` records provenance, paths, hashes, and setup; `git ls-files` reports no tracked GLB, glTF, or ZIP assets.

## Verification

- Attempt 1, standard: import and scene load passed. The new fireplace regression failed on exact comparison of Godot float shape properties (`1.1000000238` versus `1.1`, `0.8000000119` versus `0.8`). Changed those two assertions to tolerance comparisons; no product changes.
- Attempt 2 escalated to deep according to repository routing: import, scene load, and 39/39 scoped tests passed (fireplace 12, rock manager 15, shop 1, storage 11; 215 assertions). Independent deep review approved with no blocking findings.
- Rendered the existing island dev scene on OpenGL 3.3 Compatibility, AMD Radeon graphics, at 960 × 540. Inspected the boat/count label, tent, sourced pit/flames/seats, and rock pickup. No missing-resource or script errors were emitted. The ad hoc capture runner emitted an ObjectDB leak warning and seven resources still in use at shutdown; this is not a clean-teardown claim.
- Multiplayer audit approved with no findings. Final boot and full suite passed: 43 scripts, 673 tests, 672 passing, zero failures, one existing pending mouse-capture/display test; 10,059 assertions, 110.518 seconds, normal exit code 0. Voice-bus and other fixture warnings remain in the logs.

Attempt summary:

```text
attempt 1 | standard | gut:test_fireplace.gd | red (new exact-float assertion)
attempt 2 | deep | import/load/scoped/review/audit/boot/full | green
```

Rendered evidence is outside Git in `../asset-cache-336/`: [initial rowboat storage](../../asset-cache-336/storage.png), [initial red-tent shop](../../asset-cache-336/shop.png), [fireplace](../../asset-cache-336/fireplace.png), [rock](../../asset-cache-336/rock.png). The existing `scenes/dev/dev_island_flow.tscn` remains the interactive preview; use its documented controls to judge prompts and traversal in play.

## Owner-requested storage revision

The owner selected `boat-fishing-small.glb` after inspection identified several blue boats in the Watercraft pack. It replaces the rowboat. The model alone moves waterward of the ship deck, with its long axis parallel to the edge and keel 0.15 m below the configured water surface. The root, collider, prompt, count label, and hint stay on the reachable pier. Placement uses layout-relative coordinates so the parent's later storage placement does not move the boat back onto the deck. No physics, gameplay movement, or ownership behavior is added.

This continuation routes to standard tier. Import, load, 12/12 storage tests (39 assertions), independent standard review, and final boot passed on the first attempt. The new regression checks unchanged collider/label/hint transforms, deck reachability after the parent places storage, the full boat footprint beyond the deck edge, and shallow hull immersion. The full-suite result above applies to the prior four-prop revision.

The updated [storage render](../../asset-cache-336/storage-blue-fishing-boat.png) was inspected at 960 × 540 in Compatibility. It shows the boat beside the deck with the original storage labels still above the pier; capture logged interaction root `(-17, 0, 0)`. There were no missing-resource or script errors; the same capture shutdown leak/resource warnings remain. `ASSETS.md` now records the chosen model and hash; model and texture files remain ignored.

## Owner-requested Mini Forest shop revision

Downloaded the official Mini Forest 1.0 ZIP outside the checkout and inspected its tent, roof, and bare-frame models. `building-roof.glb` is the requested blue canopy with its wooden posts already included. Installed only that model and its referenced `Textures/colormap.png` in the ignored `entities/shop/assets/kenney_miniforest/` directory. `ASSETS.md` records the official source, CC0 provenance, archive hash, model hash, and texture hash.

Only the existing shop visual loader and model transform changed: uniform scale 2.2, local Y -1. No scene, root, collision, prompt, interaction, or hint behavior changed. Standard import, load, 2/2 shop tests (23 assertions), independent review, and final boot passed on the first attempt. The [updated shop render](../../asset-cache-336/shop-miniforest-canopy.png) was inspected at 960 × 540 in Compatibility: the blue canopy and wooden posts are grounded, with the existing Shop label visible. Capture logged the unchanged root `(-6, 1, 10.4)`. No script or missing-resource errors occurred; the same ad hoc capture shutdown resource warnings remain.

## Pirate Kit pickup variety revision

The owner requested Pirate Kit rocks after asking whether every pickup looked the same. The initial swap used only `Environment_Rock_1.gltf`; pickups now cycle through all five installed models by creation index. All meshes are cached once and retain their existing collider/bounds calibration. No gameplay randomness, collision, authority, RPC, or cooldown behavior changed. Existing provenance and hashes cover all five files; no new raw assets were installed.

Standard import, load, 16/16 rock tests (211 assertions), independent review, and final boot passed on the first attempt. The [neutral comparison render](../../asset-cache-336/pirate-rock-pickup-variants.png) was inspected in Compatibility and shows five distinct sourced shapes. The comparison displays the actual pickup meshes without the island terrain hiding their lower halves. No script or missing-resource errors occurred; the same ad hoc capture shutdown resource warnings remain.

## Live-demo proportion revision

The owner found the rock pickups and fireplace too big and clarified that the blue storage boat was too small. Pickup visuals now render at 65% of their former bounds, retaining the same centered collision shapes. The sourced pit scales from 8 to 5.2; flame positions/scales and stool visuals also shrink to 65%, with stool bases grounded. Seat marker transforms, ownership feedback, collider, prompt, and hint remain unchanged.

The fishing boat scales from 0.7 to 1.1 (about 57% larger). Its existing layout-derived placement automatically moves its center farther waterward to preserve 0.3 m deck clearance; keel draft remains 0.15 m. The dry storage interaction and all gameplay anchors remain unchanged. No new assets or hashes are introduced.

Standard import, load, 42/42 focused tests (rocks 16, fireplace 14, storage 12; 321 assertions), independent review, and final boot passed on the first attempt. Fresh Compatibility renders were inspected: [boat](../../asset-cache-336/size-review-first-storage.png), [fireplace](../../asset-cache-336/size-review-first-fireplace.png), and [rocks](../../asset-cache-336/size-review-first-rocks.png). No script or missing-resource errors occurred; the same capture shutdown resource warnings remain. The live island demo was relaunched for owner review. Earlier recordings retain the pre-adjustment sizes.

## Second proportion adjustment

The owner requested a still larger boat and smaller fireplace. Boat scale increases from 1.1 to 1.43 (another 30%), giving a roughly 5.53 m hull length. Pit scale decreases from 5.2 to 3.9 (another 25%); flame and stool visual transforms also shrink by 25%, to 48.75% of the original size. Rock and shop sizes remain unchanged. Collider, seat, prompt, and hint anchors stay fixed; the boat retains its existing scale-aware water clearance and draft.

Standard import, load, 26/26 focused tests (fireplace 14, storage 12; 105 assertions), independent review, and final boot passed on the first attempt. Compatibility renders were inspected: [larger boat](../../asset-cache-336/size-review-storage.png) and [smaller fireplace](../../asset-cache-336/size-review-fireplace.png). No script or missing-resource errors occurred; the same capture shutdown warnings remain. The prior owned demo closed normally and a fresh interactive island demo launched with these proportions.

## Pipeline observations

The planner and architect approved sequential cosmetic slices. The initial orchestration incorrectly assumed storage was raised 0.3 m and that GLBs embedded all textures; source inspection corrected the boat grounding before verification and installed both external atlases. The linked repository sourcing document is absent; the Notion source was read instead. No applicable engineering KB excerpt was identified.

Suggested instruction improvement: require checking each selected model's external dependencies and the gameplay root's actual placement before prescribing visual offsets or declaring a model self-contained.

## Third proportion adjustment: preserve approved stools

The owner still found the boat too small and the fireplace too big, and explicitly liked the stools. Boat scale is now 1.859 (another 30%), giving measured visual bounds 7.194 x 3.318 m and 4.833 m total height. Pit scale is 2.925 (another 25% reduction), with measured footprint 0.812 x 0.788 m and height 0.319 m. Flames shrink by 25% to a top height of 0.468 m. All four stool transforms remain exactly at their approved size and positions. Gameplay collision, seat anchors, prompts, labels, ownership, and the dry storage interaction remain unchanged.

Standard import, load, all 26 focused fireplace/storage tests, independent review, and final boot passed on the first attempt. Fresh player comparison renders are in ../../asset-cache-336/player-comparison-boat.png and player-comparison-fireplace.png. Capture retains the existing shutdown ObjectDB/resource warnings; no script or missing-resource errors occurred. ASSETS.md records the new calibration; sources and hashes are unchanged.

## Boat waterline adjustment

The owner requested that the boat sit lower in the water. Only its visual Y offset changes, from 0.15 m draft to 0.45 source units multiplied by its existing scale (0.83655 m). Scale, horizontal clearance, storage interaction on the pier, collision, prompts, labels, fireplace, and stools remain unchanged. ASSETS.md records the new draft.

Standard import/load, 12 storage tests, independent review, and final boot passed on the first attempt. The refreshed player-comparison-boat.png was inspected and shows the hull sitting deeper in the water. The capture retains its existing shutdown ObjectDB/resource warnings, with no script or missing-resource errors.
