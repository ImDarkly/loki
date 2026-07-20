**Feature ID:** PVC-001

**Status:** Ready for Development — ready-for-agent

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, ENet, TwoVoip addon

---

## Problem Statement

Voice chat currently broadcasts flat: `VoiceChatNetwork.send_voice_packet` is an
unreliable RPC received identically by every connected peer regardless of
distance, via a plain `AudioStreamPlayer` with no positional attenuation.
Friendslop-genre research (comparing this project against Lethal Company,
R.E.P.O., and other extraction/danger co-op games) identifies proximity voice
as the single most load-bearing hook in the genre — the mechanic that makes
"someone yells and the shark backs off" also carry atmospheric tension (not
knowing where a teammate is, hearing them panic from a distance, going silent
mid-scream). Without distance falloff, the yelling-repels-shark mechanic
still functions, but the emergent panic/coordination moments the genre relies
on for player-generated chaos and clippable content don't happen.

## Solution

Make each player's voice audible only within a limited radius, falling off
with distance, by moving voice playback onto a 3D-positional audio node
instead of a flat one. `VoiceChatNetwork` is already instanced as a per-player
child scene (`entities/player/player.tscn`), and remote player instances
already receive authoritative position updates via the existing
`Player._sync_transform` RPC. This means positional playback can be achieved
by changing the *type* of node the TwoVoip speaker plays through — from
`AudioStreamPlayer` to `AudioStreamPlayer3D` — with no new position-sync
plumbing required, since the node inherits its parent `Player`'s transform
automatically via the scene tree.

A compatibility audit of the TwoVoip addon's `TwoVoipSpeaker` component
confirmed this is a drop-in swap: the addon only calls `.stream`, `.playing`,
`.play()`, and `.get_stream_playback()` on its parent audio node, all of
which exist identically on `AudioStreamPlayer3D`. It does not reference
`.bus`, `.volume_db`, or any 2D-specific API. No addon modification or proxy
layer is required.

## User Stories

1. As a player, I want to hear a teammate's voice grow fainter as they move
   further away from me, so that distance and separation feel real during a
   round.
2. As a player, I want a teammate's voice to be inaudible past a tunable
   maximum distance, so that far-away chatter doesn't leak into moments where
   I should feel isolated (e.g. alone on a fishing zone while others are
   elsewhere on the map).
3. As a player, I want the existing yelling-scares-the-shark mechanic to keep
   working exactly as it does today, so that this change doesn't regress an
   already-shipped system.
4. As a player, I want voice position to update smoothly as a teammate moves,
   consistent with how their visible character already moves, so that audio
   and visual position never noticeably desync.
5. As a developer, I want the positional falloff radius to be a tunable
   exported variable, so that I can rebalance it against the water plane's
   scale (50×50) and character height without touching code.
6. As a developer, I want to confirm the TwoVoip addon requires no
   modification for this change, so that the slice stays small and doesn't
   risk destabilizing voice transmission itself.
7. As a developer, I want to verify remote player instances position their
   voice audio correctly without any new per-frame sync code, so that I'm not
   duplicating the transform-sync work `Player._sync_transform` already does.

## Implementation Decisions

### Decision 1: Swap Playback Node Type, Not Playback Logic

`voice_chat_network.tscn`'s `AudioStreamPlayer` node (parent of
`TwoVoipSpeaker`) is changed to `AudioStreamPlayer3D`. No changes are made to
`TwoVoipMic`, packet transmission (`send_voice_packet` RPC), or decoding
logic — this slice touches playback positioning only, not capture or
network transport.

### Decision 2: No New Position-Sync Code

Positional audio is derived for free from the existing scene hierarchy:
`VoiceChatNetwork` is already a child of `Player`, and remote `Player`
instances already receive `global_position` updates via the existing
`_sync_transform` RPC (throttled to every 2 physics ticks, per current
code). `AudioStreamPlayer3D` inherits this transform automatically as a
descendant node. No `RemoteTransform3D`, no manual per-frame position
assignment, and no new RPC are introduced for this feature.

### Decision 3: Tunable Attenuation Exports

`unit_size`, `max_distance`, and `attenuation_model` are set on the
`AudioStreamPlayer3D` node as inspector-tunable values, following this
project's established tunable-exports pattern (see `DangerManager`,
`ZoneManager`). Starting defaults are chosen relative to the water plane's
50×50 scale and average character spacing during a round, with the explicit
expectation that these will be adjusted after playtesting, not treated as
final.

### Decision 4: Reference Path Updates Only

`voice_chat_network.gd`'s two `$AudioStreamPlayer`-relative path references
(the `@onready` speaker reference and the stream-type assignment in
`_enter_tree`) are updated to match the renamed/retyped node. No other
logic in the script changes.

### Decision 5: No Bus Routing Changes

The TwoVoip addon does not reference `.bus` on its parent node, and this
feature does not introduce any bus routing changes. Voice audio continues
to use the default/master bus unless a future, separate feature decides to
route it otherwise.

## Testing Decisions

Consistent with this project's existing precedent for audio-hardware-adjacent
features (`test_voice_chat_manager.gd`, which explicitly excludes
`AudioServer.add_bus()`, `AudioStreamMicrophone` creation, and mic permission
prompts from automated coverage since they require a real audio runtime),
this feature has very limited automated-test surface:

- **Not covered by automated tests:** actual positional audio falloff
  behavior, `TwoVoipSpeaker` packet playback through `AudioStreamPlayer3D`,
  and perceived audio quality/distance feel — these require a live audio
  runtime and multiple connected instances, validated through manual
  multi-instance playtesting per this project's established convention for
  networked/audio plumbing (see Danger System and Voice Chat Manager PRDs).
- **Covered, if useful:** a lightweight scene-instantiation test confirming
  `voice_chat_network.tscn` still instantiates without error post-node-type
  change, and that the renamed node references resolve (`get_node_or_null`
  checks don't return null) — mirrors the low-cost "does it wire up"
  assertions already used elsewhere in this codebase rather than testing
  audio behavior itself.

No new GUT test file is expected to carry meaningful weight here; this is
primarily a manual-playtest-validated change.

## Out of Scope

- **Changing voice capture/transmission** (mic input, Opus encoding,
  amplitude-based yelling detection in `VoiceChatManager`) — unaffected by
  this feature; `is_yelling` detection and the danger system's yell-response
  behavior are untouched.
- **Bus routing or voice mixing changes** — not introduced by this feature.
- **Dynamic/contextual attenuation** (e.g. muffling through walls, underwater
  voice effects) — a possible future feature, not part of this slice.
- **Rebalancing `max_distance` beyond initial playtested defaults** — initial
  values are a starting point, not a tuned final balance; further tuning is
  expected as a fast follow-up after playtesting, not blocking this PRD.
- **Any change to `Player._sync_transform`'s sync rate or reliability** —
  this feature depends on that existing system as-is and does not modify it.

## Further Notes

### Scope Rationale

This slice was deliberately chosen as the smallest, most isolated fix
identified from a broader design review against friendslop-genre convention
(proximity voice was flagged as the single highest-impact missing mechanic
relative to genre peers). Several other findings from that review — a
swimming/reelable fish rework, a solo-play design decision, and additional
skill/variety layers to replace the removed reel-meter — were deliberately
parked out of this PRD to avoid scope creep, per this project's own
established build-order convention of shipping and playtesting one slice at
a time.

### Compatibility Audit Summary

A pre-implementation audit of `addons/twovoip/voiphelper/two_voip_speaker.tscn`
confirmed no addon-side blockers: the speaker component's public surface
(`.stream`, `.playing`, `.play()`, `.get_stream_playback()`) is available
identically on both `AudioStreamPlayer` and `AudioStreamPlayer3D`, with no
2D-specific dependencies found. This means the swap is expected to be a
same-day, low-risk change rather than requiring an adapter/proxy layer.

### Publishing Note

This repository has no connected issue tracker. Following this project's
established convention (see the 4-Player Multiplayer, Round Structure
Rework, and Shop Upgrades PRDs), this document is published as
`docs/prd/proximity-voice-chat.md` and should be mirrored to Notion under
Project Loki's Specification section if that workflow is still in use.
