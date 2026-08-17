**Feature ID:** MAP-001
**Status:** Ready for Development — resolved via grill-me session
**Triage:** ready-for-agent
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript
---
## Problem Statement
The playable map is currently a small, static square lake (a 50×50 water plane sitting inside an 80×80 land plane), with the shape and extent of both hardcoded independently in four different files (`danger_manager.gd`, `zone_manager.gd`, `rock_manager.gd`, `world_setup.gd`). It doesn't read as an ocean, and there's no distinct "island" for players to stand on and fish from — land is just whatever's outside the water square. This needs to change before the Reel Pull mechanic lands on top of the same casting/movement code, so that work isn't thrown away or built against geometry that's about to be replaced.
## Solution
The lake becomes a large, effectively boundless ocean surrounding a small circular island at the center, sized to contain today's existing spawn points, shop hut, and storage box without moving any of them. The island sits visibly above the ocean's surface with a hard shoreline edge; players are physically confined to it, and walking off the edge drops them into the ocean, which is treated as a lethal fall that routes through the game's existing death/respawn flow — the same one the shark attack already uses. Fishing zones and the shark's spawn/patrol behavior keep operating at exactly the same range from shore as they do today, so day-one fishing feel doesn't change, only the world around it. All of the map's geometry (island size, fishable range, ocean extent, and center point) is consolidated into one small shared config that the four affected systems read from, instead of each keeping its own independent copy.
## User Stories
1. As a developer, I want the shop hut moved to `(0, 0, -14)` on the island, so that it isn't stranded in open ocean now that `ISLAND_RADIUS = 10.0` no longer reaches its old position at `(5, 0, 5)`.
2. As a player, I want to see a clear island of land surrounded by ocean, so that the map actually looks and feels like the ocean setting the game is going for.
3. As a player, I want the ocean to feel like it goes on forever, so that the world feels bigger than a small enclosed pond.
4. As a player, I want to walk right up to the island's shoreline without any invisible wall stopping me, so that the space feels open rather than artificially boxed in.
5. As a player, I want to fall into the ocean and suffer a real consequence if I walk off the island's edge, so that the shoreline has actual stakes rather than being purely decorative.
6. As a player, I want falling into the ocean to put me into the same down/spectate state as being attacked by the shark, so that failure states feel consistent across the game rather than introducing a brand-new mechanic.
7. As a player, I want my existing spawn point, the shop hut, and the storage box to still be exactly where they are today, so that this map change doesn't disorient me or break my mental map of the space.
8. As a player, I want fishing zones to still appear at the same range from shore I'm used to, so that casting and finding a bite doesn't suddenly feel farther away or harder to reach.
9. As a player, I want the shark to still spawn and approach from roughly the same distance it does today, so that danger pacing doesn't change just because the ocean got bigger.
10. As a player, I want to be able to find and pick up rocks anywhere across the island, so that repelling the shark stays just as viable as it is today.
11. As a player in multiplayer, I want to see a teammate visibly fall into the ocean and go down, so that I understand what happened to them without needing to see their screen.
12. As a developer, I want a single shared source of truth for the map's island/fishable/ocean radii and center point, so that the four systems that depend on map geometry can never silently drift out of sync with each other.
13. As a developer, I want the island's visual mesh and its walkable collision shape to match exactly, so that players never see land they can't actually stand on, or a gap where they can walk on what looks like open water.
14. As a developer, I want the ocean's far edge to be visually hidden (fog/skybox) rather than requiring an actual unbounded/streaming mesh, so that "neverending" is achieved without introducing new per-frame rendering complexity.
15. As a developer, I want fall-into-ocean detection to run on the client that owns the player and report to the server via RPC, so that it follows the same client-detects/server-applies authority pattern the rest of the multiplayer code already uses (e.g. rock-throw repel).
16. As a developer, I want the existing fishing-zone boundary test's hardcoded expectations to keep passing unmodified, so that this change doesn't require touching test literals that already correctly encode today's fishing range.
17. As a developer, I want the rock-placement annulus logic (land-ring-outside-water) removed entirely in favor of a single island-radius check, so that the old two-plane topology's placement math doesn't linger as dead complexity after the redesign.
18. As a developer, I want the new map constants named for what they actually represent (radii of a circular topology), so that the next person reading the code isn't misled by names like "half-size" describing what is now a radius.
19. As a developer, I want the shared map config to be a plain constants-only script rather than a new autoload, so that it has no lifecycle, no `project.godot` registration, and no runtime state to reason about.
## Implementation Decisions
### Decision 1: Real Geometry Change, Not a Visual Reskin
This is a genuine topology inversion — small island at the center, large ocean surrounding it — not a re-texturing of the existing square lake. It requires edits to the boundary-dependent logic in `DangerManager` (shark spawn/retreat), `ZoneManager` (fishing-zone placement), `RockManager` (land placement), and `world_setup.gd` (mesh/collision), not just their materials or scale.
### Decision 2: Centralized Map Config
A new constants-only module holds `MAP_CENTER`, `ISLAND_RADIUS`, `FISHABLE_BAND_RADIUS`, and `OCEAN_RADIUS`. All four systems read from this single source instead of each keeping an independently duplicated copy, which is the drift risk that exists in the current code today (e.g. `rock_manager.gd`'s ground size and `world_setup.gd`'s ground mesh size are already the same number in two unlinked places).
### Decision 3: Island Sized to Contain the Existing Layout
The island is circular, centered at today's existing water-center point, and sized to comfortably contain the current player spawn row and storage box without moving either of them. The shop hut is the one exception: at its current position `(5, 0, 5)` it sits `13.0` units from `MAP_CENTER (0, 0, -7)` — outside `ISLAND_RADIUS = 10.0` — so it is relocated to `(0, 0, -14)` (`7.0` units from center, ~1.9 units of margin including its roof footprint) as part of this work. No other entity transform in the main scene, and no spawn-position array, needs to change.
### Decision 4: Large-but-Finite Ocean, Not a Truly Unbounded Mesh
"Neverending" is achieved with a much larger (but still finite) ocean plane combined with fog/skybox hiding the horizon — not a camera-relative recentering mesh or a shader-based infinite ocean. This keeps every boundary-dependent system's existing distance-based math working unmodified, just against bigger numbers.
### Decision 5: Distinct Fishable-Band Radius
Fishing zones are placed within their own explicitly-named radius — the "fishable band" — distinct from both the island's footprint and the ocean's full visual extent, rather than being derived arithmetically from either. This reflects that island size, fishing range, and ocean extent are three genuinely independent gameplay concerns.
### Decision 6: Shark Perimeter Reuses the Fishable Band
The shark's spawn and retreat perimeter is rebased onto the fishable-band radius (not a new, separate "danger ring"), preserving today's approach-to-attack pacing and distance-based repel logic without introducing a fourth independent radius.
### Decision 7: Rocks Scatter Across the Full Island
Rock placement becomes a single "within island radius" check, replacing the old land-annulus-outside-water logic entirely. The annulus concept and its associated ground-size constant are removed, not just resized.
### Decision 8: Fishable Band Anchored to Today's Existing Values
The fishable band's radius and center point are kept at today's values (radius `25.0`, center `(0, 0, -7)`) specifically so the existing fishing-zone boundary test's hardcoded literals remain correct without any test edits. Island radius and ocean radius are the two genuinely new numbers this change introduces.
### Decision 9: Circular Island Mesh + Collision, Square Ocean Plane
The island gets an actual circular mesh and a matching circular collision shape, since players walk directly up to its edge and any square-vs-circle mismatch there would be immediately visible and would let players stand somewhere that looks like land but fails placement/collision checks. The ocean stays a simple square plane at its much larger scale, since a mismatch at that edge is far beyond where players ever go and is already hidden by fog/skybox per Decision 4.
### Decision 10: Island Sits Above Sea Level, Hard Edge, No Beach Slope
The island is a flat-topped disc positioned above the ocean plane's surface, with a hard vertical drop at its edge — no beveled or sloped beach transition. This inverts today's layering (where land sits fractionally below the water plane) and is the minimal fix needed to make the island read as dry land rather than being submerged under the now-dominant ocean plane.
### Decision 11: Players Confined to the Island
Walkable collision only covers the island; there is no floor under the ocean. This differs from today's behavior, where collision spans the full land+water footprint and players can freely walk over water. Casting already works via arc/raycast physics without requiring a player to stand in the water, so this costs nothing mechanically.
### Decision 12: Falling Off the Island Routes Through Existing Death/Spectate Flow
Rather than an invisible boundary wall or an unhandled indefinite fall, crossing a Y-position threshold below the island triggers the same `HealthComponent` death path (and subsequent spectate state) that a shark attack already uses. No new wall geometry or new player-state enum is introduced.
### Decision 13: Client-Detects, Server-Applies RPC Pattern
Fall detection runs inside the existing owner-gated block of the player's physics process (the same gating already used for interact/rock raycasts). On crossing the threshold, the owning client calls a new any-peer RPC to the server, which applies the damage — mirroring the existing `_throw_rock()` → `repel()` pattern exactly. The no-multiplayer-peer (offline/single-player) case calls the damage method directly, matching that same existing branch structure.
### Decision 14: Shared Config Is a Constants-Only Script, Not an Autoload
The map config is implemented as a plain `class_name` script holding only `const`s — no `project.godot` autoload registration, no `_ready()`, no runtime state. This matches what the data actually is (static configuration) rather than introducing a service-like singleton for something that never changes at runtime.
### Decision 15: New Shared Island-Geometry Helper
A second small module extracts the "is this point within radius X of the map center" check that would otherwise be reimplemented independently in `rock_manager.gd`, `zone_manager.gd`, and `danger_manager.gd`. This is the one piece of genuinely new, deep, testable-in-isolation logic this change introduces, on top of the config module itself.
### Decision 16: Constants Renamed to Match New Semantics
The old square-topology names (`WATER_HALF_SIZE`, `GROUND_HALF_SIZE`) are replaced with names describing the new circular topology (`ISLAND_RADIUS`, `FISHABLE_BAND_RADIUS`, `OCEAN_RADIUS`, `MAP_CENTER`). None of the existing tests reference these constants by name directly, so the rename carries no test risk.
### Final Values
- `MAP_CENTER = Vector3(0, 0, -7)` — unchanged from today
- `ISLAND_RADIUS = 10.0` — clears the existing spawn row and storage box footprint with margin; the shop hut is relocated (see Decision 3) rather than accommodated in place
- `FISHABLE_BAND_RADIUS = 25.0` — unchanged from today's water extent (see Decision 8)
- `OCEAN_RADIUS = 120.0` — roughly 5x the fishable band, large enough that its edge is well outside where fog/skybox already hide it
- Shop hut relocated to `(0, 0, -14)` in `scenes/main.tscn` (was `(5, 0, 5)`) as the one entity-position change this PRD requires
## Testing Decisions
Consistent with this project's existing precedent (`test_zone_manager.gd`, `test_rock_manager.gd`, `test_danger_manager.gd`): tests exercise external behavior — state transitions, distance/boundary checks, signals emitted — not rendering, physics feel, or hardware input.
- **Covered:** the new shared island-geometry helper gets dedicated unit tests covering boundary conditions (exactly at radius, just inside, just outside) for both the island and fishable-band checks — this is the one genuinely new piece of testable-in-isolation logic in this change.
- **Covered:** the new fall-off-island RPC path on the player is tested at the handler level (mirroring the existing `sync_yelling`/`sync_carrying` RPC-handler tests in `test_player.gd`) — asserting the report call fires correctly in both the multiplayer-peer and no-peer branches, not the actual gravity/fall trajectory.
- **Unchanged, should keep passing without edits:** `test_zone_manager.gd`'s existing fishing-zone boundary test, since Decision 8 anchors the fishable band to today's exact radius and center.
- **Not covered by automated tests, per existing project precedent:** the visual island/ocean mesh rendering, the beach edge appearance, and the actual fall physics/trajectory feel — validated through manual playtesting, consistent with how this project already excludes rendering and physics-feel from its test suite.
- **No dedicated test needed:** the map config module itself, since it holds only constants with no behavior to exercise.
## Out of Scope
- The Reel Pull fishing mechanic itself — this PRD is explicitly a prep pass ahead of it, not a combined change.
- A beveled/sloped beach edge or a non-circular (organic) island shape — considered and deferred as an art-pass upgrade that doesn't affect any gameplay logic in this PRD.
- A truly unbounded/shader-scrolled ocean mesh or a camera-relative recentering system — deferred as a possible future upgrade if the fixed-radius ocean ever feels too obviously bounded in playtesting.
- An independent "danger spawn ring" decoupled from the fishable band — deferred until shark pacing specifically needs its own tuning dial separate from fishing-zone range.
- Restricting rock placement to a shoreline ring rather than the full island interior — a stylistic upgrade, not a functional requirement.
- Any new traversal mechanics (swimming, boats) to reach fishing zones beyond casting range — out of scope entirely; casting range and fishable-band radius are assumed compatible as-is.
- Any art/shader polish beyond what's needed to sell the flat-disc-above-plane island geometry (final skybox/fog tuning, water shader, island texturing).
- Making the map config runtime-adjustable (e.g. a difficulty or map-size setting) — would require promoting it to an autoload, which nothing in this PRD calls for.
## Further Notes
### Design Origin
This PRD was resolved through an extended grill-me-style interview walking 16 sequential, dependency-ordered branches — starting from the open-ended request to "turn this lake-like structure into a neverending ocean with an island in the center" and narrowing through scope, shared config strategy, island sizing, ocean boundedness, fishing-zone placement, shark pacing, rock placement, test-literal preservation, mesh/collision fidelity, vertical layering, player confinement, fall-death handling, RPC authority, and config implementation, in that order.
### Relationship to Reel Pull (RP-001)
This map change is deliberately sequenced *before* Reel Pull specifically because Reel Pull's tug-of-war mechanic pulls the player's own character toward the fish, and depends on the same casting/movement/water-boundary code this PRD touches. Reel Pull's `max_cast_range` and pull dynamics should be sanity-checked against the final `FISHABLE_BAND_RADIUS`/`ISLAND_RADIUS` values once both features exist, though no changes to those constants are anticipated as a result.
### Relationship to Full Playable Cycle (RSK-001)
The existing land-annulus rock placement and square lake/ground geometry described in that document's original implementation are superseded by Decisions 7, 9, and 10 above. That document remains the historical record of what shipped previously; this PRD does not edit it directly.