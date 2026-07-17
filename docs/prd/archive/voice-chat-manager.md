**Feature ID:** VCM-001

**Status:** Ready for Development

**Target Completion:** 1 week

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, GD-Sync

---

## Problem Statement

The Danger System requires a mechanism to detect when a player is yelling into a microphone, so the shark responds to voice input rather than keyboard-only input. Currently, no voice amplitude detection layer exists. `Player.is_yelling` is never set — there is no keyboard fallback and no audio bus wiring.

GD-Sync is already installed and configured with API keys, but its VoiceChat node is not wired into any scene. The `"GDRecord"` audio bus that both GD-Sync and VoiceChatManager expect does not exist at runtime, so VoiceChatManager's lazy init finds nothing and `is_yelling` remains permanently false.

The integration seam is correct (`DangerManager` reads `player.is_yelling`, never touches voice chat code), but the pipeline from microphone -> `is_yelling` is incomplete.

## Solution

Implement a VoiceChatManager node that hosts its own recording bus, reads voice amplitude from it, and updates `Player.is_yelling`. The manager creates a `"GDRecord"` audio bus with an `AudioEffectCapture` and routes an `AudioStreamMicrophone` through it, then queries `AudioServer.get_bus_peak_volume_left_db()` every frame. Hysteresis (ON at -12 dB, OFF at -14 dB) prevents audio jitter near the threshold from fluttering the yelling state.

The implementation is built in two phases:

1. **Phase 1 (now):** VoiceChatManager self-hosts the recording bus. On first `_process()`, if `"GDRecord"` bus doesn't exist, it creates it, adds an `AudioEffectCapture`, creates an `AudioStreamPlayer` with an `AudioStreamMicrophone` routed to that bus, and starts playback. Real microphone input is live; `is_yelling` updates in real time; the bus index is cached for O(1) lookup.

2. **Phase 2 (later):** Add GD-Sync's `VoiceChat` node as a sibling for multiplayer voice transmission (sending audio between players). Its `_configure_bus()` finds the existing `"GDRecord"` bus. VoiceChatManager's auto-creation can be disabled via export. No architectural changes, no test rewrites, and the `Player.is_yelling` seam point is untouched.

## User Stories

### Voice Detection (Developer/QA)

1. As a **developer**, I want to **detect voice amplitude from a local audio bus**, so that **I can measure when a player is yelling without requiring a GD-Sync server connection.**
2. As a **developer**, I want to **auto-create the recording bus on first process if it doesn't exist**, so that **the system works out of the box with no manual setup.**
3. As a **developer**, I want to **apply hysteresis to voice detection** (ON at -12 dB, OFF at -14 dB), so that **audio jitter near the threshold doesn't cause rapid state fluttering.**
4. As a **developer**, I want to **update Player.is_yelling automatically**, so that **existing game logic (DangerManager, etc.) doesn't need to change.**
5. As a **developer**, I want to **emit `yelling_state_changed` signal only on real state transitions**, so that **subscribers (DangerManager) don't re-process redundant events.**
6. As a **developer**, I want to **disable auto bus creation via export when GD-Sync VoiceChat is present**, so that **both systems coexist without conflict.**

### Playtesting & Tuning

1. As a **QA tester**, I want to **adjust amplitude thresholds in the Inspector**, so that **I can find the right sensitivity without recompiling code.**
2. As a **QA tester**, I want to **change the audio bus name via export**, so that **I can target different recording buses without touching code.**
3. As a **QA tester**, I want to **see a warning if the microphone is unavailable**, so that **I know voice detection is disabled and can debug the issue.**

### Integration & Fallback

1. As a **developer**, I want to **phase in GD-Sync VoiceChat without breaking existing tests**, so that **I can verify voice detection works with self-hosted bus first, then swap to GD-Sync VoiceChat for multiplayer.**
2. As a **developer**, I want to **handle microphone unavailability gracefully**, so that **the game continues running (with `is_yelling = false`) instead of crashing if no mic is found.**
3. As a **developer**, I want to **maintain the `Player.is_yelling` seam point**, so that **if voice input methods change (self-hosted bus -> GD-Sync VoiceChat -> future), only the manager internals change, not DangerManager logic.**

### DangerManager Integration

1. As a **player**, I want to **yell into my microphone and have the shark respond**, so that **voice becomes a valid game mechanic.**
2. As a **player**, I want to **experience stable yell detection without mic flutter**, so that **the shark doesn't twitch when I pause speaking briefly.**
3. As a **player**, I want to **adjust my microphone volume and have voice detection work reliably**, so that **different hardware/mic setups don't break yelling detection.**

## Implementation Decisions

### Decision 1: Architecture -- VoiceChatManager as Player Child

**Placement:** VoiceChatManager is a child node of Player (one per player in multiplayer).

**Reasoning:**
- Voice input is player-local (each player has a microphone).
- Parenting to Player makes ownership explicit and matches Godot's authority model.
- Multiplayer: each player's VoiceChatManager hosts its own bus, reads its own mic, emits signals locally. DangerManager (on main scene) subscribes to all players' signals.
- Testing is isolated: instantiate a Player with a VoiceChatManager, no global state.

**Interface:**
- Child node, no parent-facing API except signal emissions
- Parent (Player) reads `player.is_yelling` bool directly in game logic
- DangerManager subscribes to `yelling_state_changed` signal for event-driven reactions

### Decision 2: Audio Input -- Self-Hosted Recording Bus

**Method:** VoiceChatManager creates a dedicated recording bus on first `_process()` if it doesn't exist, then queries `AudioServer.get_bus_peak_volume_left_db(bus_index)` every frame.

**Bus creation:**
1. Call `AudioServer.add_bus()` to create a new bus at the end of the chain
2. Set bus name to `voice_bus_name` (default `"GDRecord"`)
3. Mute the bus so the player doesn't hear their own mic
4. Add an `AudioEffectCapture` effect for potential future use
5. Create an `AudioStreamPlayer` with an `AudioStreamMicrophone` as a child of VoiceChatManager
6. Route the player's bus to `voice_bus_name`
7. Start playback

**Reasoning:**
- Self-hosting means zero external dependencies -- works immediately on any system with a microphone
- Uses the same `"GDRecord"` bus name that GD-Sync's VoiceChat node expects, so Phase 2 migration is seamless
- Peak volume (not RMS) responds immediately to voice onset (good for responsiveness)
- Single call per frame is cheap CPU-wise
- When GD-Sync VoiceChat is added in Phase 2, its `_configure_bus()` finds the existing bus and reuses it

**Fallback:** If `AudioStreamMicrophone` cannot be created (no mic device, permissions denied), log one-time warning and return silently. Voice detection remains disabled (`is_yelling` stays false) but game continues.

### Decision 3: Threshold & Hysteresis

- **ON Threshold:** -12 dB (elevated voice, not quite yelling but clearly speaking up)
- **OFF Threshold:** -14 dB (drops below elevated voice level)
- **Hysteresis:** Two-threshold design prevents audio jitter near boundary from causing rapid ON/OFF/ON cycles

**Reasoning:**
- -12 dB is tunable for different microphones but is a solid starting point
- Hysteresis (2 dB deadband) is industry-standard for Voice Activity Detection
- Tunable via `@export` so QA can adjust without recompile
- Tests verify both thresholds independently

### Decision 4: State Update & Signal Emission

**Logic:** Simple boolean state machine.

```
if not is_yelling AND amplitude >= -12 dB:
    is_yelling = true
    emit yelling_state_changed(true)
elif is_yelling AND amplitude < -14 dB:
    is_yelling = false
    emit yelling_state_changed(false)

player.is_yelling = is_yelling
```

**Guard:** Only emit signal if state actually changes (prevents duplicate events on rapid re-evaluation).

**Reasoning:**
- One-to-one mapping to hysteresis logic; readable and maintainable
- Boolean avoids over-abstraction (not a complex state machine)
- Guard prevents DangerManager from re-processing the same state multiple times
- Matches existing codebase style (simple conditionals, not enums)

### Decision 5: Bus and Mic Lifecycle

**On first _process():** Check if `_bus_index == -1`. If so:
1. Call `_ensure_bus()` which creates the `"GDRecord"` bus (if missing) and the mic player
2. If successful, cache `_bus_index` and store a reference to the mic player
3. If mic creation fails, log one-time warning, `is_yelling` stays false

**Caching:** Store the bus index locally. Subsequent frames use cached index (O(1) lookup). Once the bus is created, it persists for the session.

**Resilience:** If mic creation fails initially, retry is not attempted -- the mic device is unlikely to appear mid-session. If the bus is later destroyed externally (unlikely), the next `_process()` detects the stale index and recreates it.

**GD-Sync coexistence:** When `auto_create_bus` is `false`, the creation step is skipped. The bus is expected to exist (created by GD-Sync's VoiceChat node). If it's missing, fall back to warning mode.

**Reasoning:**
- Phase 1: bus doesn't exist -> VoiceChatManager creates it. Player hears nothing (bus is muted), mic routes through bus, peak volume reflects real mic input.
- Phase 2: GD-Sync VoiceChat creates the bus -> VoiceChatManager finds it on first `_process()`. If `auto_create_bus = false`, it skips creation and just reads.
- No manual setup required for either phase; the code adapts.

## Testing Decisions

Good tests here validate the two-threshold hysteresis logic and the is_yelling flag's response to amplitude inputs -- not the audio bus creation, microphone availability, or signal-wiring to DangerManager (those are integration concerns validated through playtesting).

**Hysteresis thresholds:**
- Given peak volume at -10 dB (above -12 dB ON threshold), is_yelling becomes true
- Given peak volume at -13 dB (between ON and OFF thresholds after state was ON), is_yelling stays true (hysteresis holds)
- Given peak volume drops to -15 dB (below -14 dB OFF threshold), is_yelling becomes false
- Given peak voltage was never above ON threshold, is_yelling stays false

**Signal emission guard:**
- State change (false -> true) emits `yelling_state_changed(true)`
- State change (true -> false) emits `yelling_state_changed(false)`
- No state change (already true, stays true) does NOT emit

**Bus index caching:**
- After bus creation, subsequent `_process()` calls use the cached index

**Prior art:** The danger system's state-machine tests (test_danger_manager.gd) are the closest structural match -- simple conditionals with boolean state, no async timers to bypass. Follow that pattern: instantiate the node, feed it amplitude values, assert on resulting is_yelling.

Explicitly not covered by automated tests: `AudioServer.add_bus()` call, `AudioStreamMicrophone` creation, microphone permission prompts. These require a real audio runtime and are validated through manual playtesting with a mic.

## Out of Scope

- **GD-Sync VoiceChat node integration (Phase 2)** -- deferred until multiplayer voice transmission is needed; Phase 1 covers local-only yell detection.
- **Noise gate, VAD (Voice Activity Detection) beyond amplitude thresholding** -- simple amplitude + hysteresis is sufficient for MVP; RnNoise-based VAD is an advanced consideration.
- **Multiplayer voice transmission** -- Phase 2 only; Phase 1 is local mic -> is_yelling only.
- **Push-to-talk key** -- always-on mic detection; PTT deferred to post-launch feedback.
- **Echo cancellation or acoustic echo suppression** -- not needed without voice transmission (Phase 1 sends no audio).
- **Visual mute indicator or mic check UI** -- deferred to follow-up polish pass.
- **Accessibility (text-to-speech, visual yelling indicator for deaf/hard-of-hearing players)** -- acknowledged but deferred.

## Further Notes

### Integration with Existing Code

`DangerManager` already reads `player.is_yelling` and never touches voice chat internals. This seam is unchanged. The Phase 1 implementation means DangerManager will see `is_yelling` go true for the first time as soon as VoiceChatManager is added to the Player scene and a mic is detected.

### GD-Sync Coexistence

When Phase 2 adds GD-Sync VoiceChat, no code in VoiceChatManager beyond the `auto_create_bus` guard and bus-name export needs to change. GD-Sync's `VoiceChat._configure_bus()` finds the existing `"GDRecord"` bus and reuses it. VoiceChatManager continues to read amplitude from the same bus.

### Publishing Note

Following the precedent set by the Core Fishing Mechanic and Danger System specs, this PRD is published to Notion under Project Loki's Specification section and mirrored at `docs/prd/archive/voice-chat-manager.md`, since this repository has no connected issue tracker.
