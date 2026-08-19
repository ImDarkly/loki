**Feature ID:** PVC-001

**Status:** CLOSED - implemented (PR #125 positional falloff; transport moved to EOS RTC via PR #166, 2026-08-18)

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, EOS RTC (via EOSG addon)

---

## Problem Statement

Voice chat broadcasts flat: `VoiceChatNetwork.send_voice_packet` is an
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
instead of a flat one. The per-player voice node is a child of `Player`, and
remote player instances already receive authoritative position updates via the
existing `Player._sync_transform` RPC. Positional playback is achieved by
playing decoded voice through an `AudioStreamPlayer3D` (fed by an
`AudioStreamGenerator`), which inherits its parent `Player`'s transform
automatically via the scene tree — no new position-sync plumbing.

The voice transport itself was re-architected during implementation: the
original design (TwoVoip addon, `send_voice_packet` unreliable RPC) was
superseded by **EOS RTC rooms** (`eos_voice_network.gd`). Capture is polled
from the `VoiceChatManager` mic bus in 10ms chunks and pushed via
`EOS.RTCAudio.send_audio`; incoming frames are routed per-participant back to
the owning player's `AudioStreamPlayer3D` generator. This supersession is
documented in Further Notes below.

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
6. As a developer, I want remote player instances to position their voice
   audio correctly without any new per-frame sync code, so that I'm not
   duplicating the transform-sync work `Player._sync_transform` already does.

## Implementation Decisions

### Decision 1: Playback on AudioStreamPlayer3D, Fed by a Generator

`eos_voice_network.gd`'s `AudioStreamPlayer3D` node plays an
`AudioStreamGenerator` (`SAMPLE_RATE = 48000`, 10ms buffer). Decoded remote
frames are pushed into the generator's playback via `push_audio()`. The node
uses `unit_size = 8.0`, `attenuation_model` set to 1 (inverse distance),
`volume_db = 24.0`, `max_distance = 0.0` — the falloff reference is tunable in
the scene file. No changes are made to capture or the RTC transport.

### Decision 2: No New Position-Sync Code

Positional audio is derived for free from the existing scene hierarchy: the
voice node is a child of `Player`, and remote `Player` instances already
receive `global_position` updates via the existing `_sync_transform` RPC
(throttled to every 2 physics ticks). `AudioStreamPlayer3D` inherits this
transform automatically as a descendant node. No `RemoteTransform3D`, no
manual per-frame position assignment, and no new RPC are introduced.

### Decision 3: Tunable Attenuation Exports

`unit_size`, `max_distance`, and `attenuation_model` are set on the
`AudioStreamPlayer3D` node in the scene as tunable values, following this
project's established tunable-exports pattern (see `DangerManager`,
`ZoneManager`). Starting defaults are relative to the 50×50 water plane scale
and average character spacing, with the explicit expectation that they will be
adjusted after playtesting, not treated as final.

### Decision 4: Transport Superseded by EOS RTC (Implemented Deviation)

The original design routed voice through the TwoVoip addon over an unreliable
RPC (`send_voice_packet`). During implementation the transport was replaced by
**EOS RTC rooms** — the host creates an RTC room alongside the EOS lobby
(`NetworkManager.lobby.rtc_room_name`); the EOSG addon handles Opus
encode/decode and NAT traversal. The per-player node:
- Sends: polls `VoiceChatManager.get_frames_available()/get_captured_frames()`
  in fixed 480-frame (10ms) chunks → `EOS.RTCAudio.send_audio`.
- Receives: registers `rtc_audio_audio_before_render`; queues frames from the
  worker thread (`_render_mutex`); drains on the main thread each `_process`
  and routes to the target player's node via `push_audio()`.
- Authoritative gating: only the node's multiplayer authority sends audio
  (`is_multiplayer_authority()`).

This keeps the positional-falloff goal while gaining EOS's relay/NAT
traversal. TwoVoip is no longer used anywhere in the project.

## Testing Decisions

Consistent with this project's existing precedent for audio-hardware-adjacent
features (`test_voice_chat_manager.gd`, which explicitly excludes
`AudioServer.add_bus()`, `AudioStreamMicrophone` creation, and mic permission
prompts from automated coverage since they require a real audio runtime),
this feature has very limited automated-test surface:

- **Not covered by automated tests:** actual positional audio falloff
  behavior, RTC packet playback through `AudioStreamPlayer3D`, and perceived
  audio quality/distance feel — these require a live audio runtime and
  multiple connected instances, validated through manual multi-instance
  playtesting per this project's established convention for networked/audio
  plumbing (see Danger System and Voice Chat Manager PRDs).
- **Covered, if useful:** a lightweight scene-instantiation test confirming
  `eos_voice_network.tscn` still instantiates without error, and that the
  node references resolve — mirrors the low-cost "does it wire up" assertions
  already used elsewhere in this codebase rather than testing audio behavior
  itself.

No GUT test file carries meaningful weight here; this is primarily a
manual-playtest-validated change.

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
relative to genre peers). Other findings from that review were parked to avoid
scope creep, per this project's own established build-order convention of
shipping and playtesting one slice at a time.

### Transport Supersession

The TwoVoip-addon design in this document's original revision was never built.
PR #125 shipped positional falloff via `AudioStreamPlayer3D` while still on
the RPC transport; PR #166 replaced that transport with EOS RTC rooms
(`eos_voice_network.gd`, `EosVoiceNetwork` scene). The positional-falloff
behavior is preserved and unchanged by the transport swap. This document
reflects the shipped implementation.

### Publishing Note

Following this project's established convention, this document lives at
`docs/prd/archive/proximity-voice.md` as the historical/spec record and is
mirrored to Notion under Project Loki's Specification section.