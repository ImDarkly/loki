## "Catch & Chaos" MVP Specification

**Version:** 3.0  

**Date:** June 29, 2026 (Revised: Networking & Voice Chat Strategy)  

**Status:** APPROVED FOR DEVELOPMENT  

**Target Release:** 8 weeks (Early Access on Steam)  

**Owner:** Solo Developer  

---

## Problem Statement

Multiplayer party games (friendslop) like Lethal Company and Sea of Thieves are successful because they create **emergent chaos through shared goals and forced communication under pressure**. However, most fishing games are quiet, solo, or purely competitive—missing the opportunity to create a multiplayer experience where **communication is required but has a cost**.

**Current Gap:** No multiplayer fishing game exists where yelling to warn teammates actually has a mechanical consequence (scares fish away). This creates genuine strategic tension that doesn't exist in existing co-op games.

**Target Player:** Friends playing remotely (Discord/voice chat) who love chaos, coordination challenges, and emergent moments from shared failure.

---

## Solution

Build a **4-player cooperative fishing game** where:

1. **Players must yell warnings** when danger appears (sharks)
2. **Yelling has a cost:** all nearby fish flee when you warn teammates
3. **Core tension:** yelling saves crew but loses fish; not yelling saves fish but loses caught quota
4. **Shared goal:** catch enough fish before time runs out (quota system)
5. **Emergent chaos:** real-time coordination, proximity-based sound, fish behavior

**Why it works:**

- Fishing mechanic = relaxing baseline (proven fun in Stardew Valley, Animal Crossing)
- Danger + yelling = forced communication stress
- Shared quota = collective failure/success (like Lethal Company)
- No hidden roles or deception = pure coordination challenge

---

## User Stories

### Core Gameplay Loop

1. As a **player**, I want to **cast a fishing line** into the water, so that **I can begin the fishing sequence**
2. As a **player**, I want to **see my fishing line in the water** with visual feedback, so that **I know my cast was successful**
3. As a **player**, I want to **wait for a fish to bite**, so that **I have a moment-to-moment objective**
4. As a **player**, I want to **feel tension when a fish bites** (visual twitches, sound effect), so that **I know I need to act immediately**
5. As a **player**, I want to **perform a reel mechanic** (hold input, manage a strength meter), so that **landing a fish feels like skill, not luck**
6. As a **player**, I want to **successfully catch fish** and see them added to my team quota, so that **I feel rewarded for successful mechanics**
7. As a **player**, I want to **fail to land fish** if I release too early or lose the reel, so that **fishing has real stakes**
8. As a **player**, I want to **see how many fish I've caught so far**, so that **I understand progress toward the quota**

### Danger System

1. As a **player**, I want to **see/hear a warning** when danger (shark) is approaching, so that **I have time to react**
2. As a **player**, I want to **experience a 3-5 second telegraph phase** before the shark actually attacks, so that **I can decide whether to yell**
3. As a **player**, I want to **yell "SHARK!" when danger appears**, so that **I can warn my teammates**
4. As a **player**, I want to **understand that yelling causes all nearby fish to flee**, so that **there's a real cost-benefit decision**
5. As a **player**, I want to **experience the consequence of yelling:** all my active catches in the area escape, so that **yelling feels like a genuine sacrifice**
6. As a **player**, I want to **watch fish gradually return after yelling stops**, so that **there's a rhythm to the danger-safety-recovery cycle**
7. As a **player**, I want to **understand the penalty for NOT yelling:** the shark bites and the team loses 3 caught fish from quota, so that **there's real urgency to communicate**
8. As a **player**, I want to **experience multiple danger events per game** (every 3-5 minutes), so that **the pressure feels constant but not overwhelming**

### Team Coordination

1. As a **player**, I want to **hear my teammates speaking in real-time**, so that **I feel like we're working as a crew**
2. As a **player**, I want to **see other players' fishing lines and catches**, so that **I understand the team's progress**
3. As a **player**, I want to **experience emergent chaos moments** where miscommunication or simultaneous fish catches create funny situations, so that **the game feels unpredictable and memorable**
4. As a **player**, I want to **feel responsible for the team's outcome**, so that **failure feels shared**

### Quota & Progression

1. As a **player**, I want to **see a clear quota goal** (e.g., "Catch 20 fish in 15 minutes"), so that **I understand the win condition**
2. As a **player**, I want to **watch a real-time timer counting down**, so that **I feel pressure as time runs out**
3. As a **player**, I want to **succeed in a round** when the team catches ≥20 fish before time expires, so that **I feel accomplishment**
4. As a **player**, I want to **fail gracefully** when we miss the quota, so that **I can immediately restart without punishment**
5. As a **player**, I want to **restart the game instantly** after a failure, so that **the loop stays fast and replayable**

### Multiplayer Experience

1. As a **player**, I want to **join a lobby with 3 friends online**, so that **we can play remotely**
2. As a **player**, I want to **wait for all 4 players to connect**, so that **the game doesn't start until everyone is ready**
3. As a **player**, I want to **see other players' names and catch counts**, so that **I can track team progress**
4. As a **player**, I want to **experience synchronized danger events** across all players, so that **we all face the same challenge at the same time**
5. As a **player**, I want to **hear other players' voices in real-time with minimal lag**, so that **communication feels immediate**

### First-Time Experience

1. As a **new player**, I want to **understand how to cast, wait, and reel** without reading a manual, so that **the game is intuitive**
2. As a **new player**, I want to **be told what the quota is** before the game starts, so that **I understand the objective**
3. As a **new player**, I want to **experience my first danger event** early (within first 5 minutes), so that **I learn the yelling mechanic quickly**
4. As a **new player**, I want to **see visual feedback** (particles, text, icons) when yelling causes fish to flee, so that **I understand the mechanic's impact**

### Accessibility & Feedback

1. As a **player**, I want to **see clear UI indicators** (quota counter, timer, catch count), so that **I always know the game state**
2. As a **player**, I want to **hear satisfying sounds** when I catch a fish, so that **success feels rewarding**
3. As a **player**, I want to **see particles/visual effects** when fish are caught or flee, so that **the game feels responsive**
4. As a **player**, I want to **experience screen shake or audio cues** when a shark appears, so that **I feel urgency**
5. As a **player**, I want to **read in-game text explaining the controls**, so that **I don't need to read a manual**

---

## Implementation Decisions

### Core Architecture

**Decision 1: GD-Sync for Multiplayer + Voice Chat (REVISED)**

- Use **GD-Sync** as the complete multiplayer backend for 4-player online multiplayer, proximity voice chat, lobbies, and matchmaking
- GD-Sync includes built-in spatial audio (3D proximity voice with automatic attenuation by distance)
- GD-Sync manages all networking via global relay server network (no port forwarding needed)
- Server-authoritative gameplay: GD-Sync PropertySynchronizer syncs position, catch_count, is_yelling, fishing state
- Voice chat automatic: players hear each other via GD-Sync's built-in proximity audio
- Game reacts to player yelling by monitoring `is_yelling` flag (when volume amplitude exceeds threshold, GD-Sync detects voice activity)
- Free tier: 200 MB/day data transfer + 4-player lobbies = covers entire MVP

**Why GD-Sync instead of ENet + TwoVoip:**

- GD-Sync initial setup from downloading plugin to creating first lobby typically takes less than 15 minutes
- GD-Sync's free plan is free forever with no hidden costs. It includes the native Godot 4 plugin, global relay network, and built-in proximity voice chat with full 2D/3D spatial audio support
- ENet + TwoVoip would require 4-6 weeks (audio infrastructure + networking implementation)
- GD-Sync frees up 5+ weeks for core fishing gameplay and playtesting
- No vendor lock-in risk: if GD-Sync fails, migration to ENet is painful but possible post-MVP
- GD-Sync does not charge per player or per concurrent user (CCU). Data plans are based purely on data transfer capacity, lobby size, and cloud storage limits

---

**Decision 2: Single Static Location for MVP**

- One fishing location (tropical island boat)
- Identical map for all players, every game
- No procedural generation, no location rotation
- Fish spawn positions: randomized within safe zone, same for all players

**Rationale:** Reduces art/design burden, allows focus on core mechanic. Can add locations post-MVP. Learnable map = faster gameplay loops.

---

**Decision 3: Two-Step Fishing Mechanic**

- Step 1: Cast (click to initiate, animation plays)
- Step 2: Wait for bite (random delay 3-15 seconds)
- Step 3: Reel (hold input, manage strength meter for 10-20 seconds)
- Success: fish caught, +1 quota
- Failure: fish escapes, back to waiting

**Rationale:** Skill-based (reel meter), not pure RNG. Matches Stardew Valley fishing feel (familiar to target players). Multiple fail points create tension.

---

**Decision 4: Shark as Primary Danger (with Explicit Penalty for Not Yelling)**

- Sharks spawn every 3-5 minutes (scheduled with variance, not random)
- Telegraph phase: 3-5 seconds (visual ripples + sound) before attack
- **If players yell during telegraph:** all fish in 30-meter radius flee instantly (everyone loses active catches, crew survives unharmed)
- **If players DON'T yell:** shark bites successfully. **Team loses 3 caught fish from the quota** (penalty, not death/game-over). This creates genuine urgency without a "health" mechanic.
- Single danger type for MVP (simplifies balancing)

**Rationale:** Iconic, immediately understandable threat. Telegraph phase = skill moment (can players react in time?). Explicit penalty = clear cost-benefit decision. Post-MVP: add storms, krakens, other creatures.

---

**Decision 5: Voice Chat Triggers Yelling (Via Amplitude Detection)**

- Player speaks into microphone during gameplay
- GD-Sync monitors microphone amplitude in real-time
- When amplitude exceeds tunable threshold, `is_yelling` flag is set to true
- `is_yelling = true` broadcasts to all players (server-authoritative)
- Fish in 30-meter radius flee instantly when any player is yelling
- Server checks `is_yelling` flags during shark telegraph to prevent shark attack penalty

**Rationale:** Proximity chat IS core mechanic. Amplitude detection simple but tunable. Players naturally yell when panicked (no extra UI button needed). Post-MVP: can upgrade to Voice Activity Detection (RnNoise) for accuracy.

---

**Decision 6: Shared Quota (All-or-Nothing Team)**

- 4 players, ONE shared goal
- Catch ≥20 fish in 15 minutes to succeed
- Success = restart with same quota (post-MVP: escalate)
- Failure = instant restart, no penalty
- No individual scoring, no PvP elements

**Rationale:** Matches Lethal Company's "crew succeeds together or fails together" design. Eliminates blame (communal failure). Fast restart loop = high replayability.

---

**Decision 7: Pixel Art or Gray-Box Prototype (No Complex 3D)**

- MVP art: use pixel art asset packs (Kenney.nl, itch.io) OR gray-box placeholder models
- Defer custom 3D art to post-MVP or post-launch
- Simple water shader (flat, calm, not distracting)
- 4-5 fish species (visual variety, no mechanical difference)

**Rationale:** Solo dev timeline (8 weeks). 3D modeling = 50% of time if done custom. Asset packs = fast iteration. Mechanics first, art second.

---

**Decision 8: No Economy, No Upgrades in MVP**

- Fish are caught for quota only
- No selling mechanic
- No upgrade system
- Single difficulty level

**Rationale:** Scope control. Post-MVP roadmap exists, but MVP must ship core loop first. Validated by playtesting before adding systems.

---

### UI/UX Decisions

**Decision 9: Always-Visible HUD**

- Top-left: Quota counter ("15 / 20 fish")
- Top-center: Timer ("8:32 remaining")
- Bottom-left: Player status (4 names, catch count each)
- Center: Reel meter (during active reel only)
- Center: "SHARK!" text (during danger telegraph)

**Rationale:** Constant awareness of progress + pressure. Minimal cognitive load. No hidden information = supports cooperation.

---

**Decision 10: Immediate Feedback on Actions**

- Catch fish: particle explosion, "ding!" sound, quota updates instantly
- Yell: "YELL!" text appears, sound effect plays, fish flee animation
- Danger telegraph: screen shake, rumble, shark dorsal fin visible
- Round end: success/failure screen with catch count

**Rationale:** Matches Sea of Thieves/Lethal Company feedback style. Reinforces player actions. Satisfying = replayable.

---

### Networking Decisions (REVISED)

**Decision 11: GD-Sync PropertySynchronizer for State Sync**

- GD-Sync PropertySynchronizer syncs: position (always), catch_count (on change), is_fishing (on change), is_yelling (on change)
- Sync rate: 10 updates/sec default (0.1 second interval)
- Bandwidth per player: ~4-5 Kbps (voice + state)
- Latency tolerance: up to 200ms acceptable (fishing is not twitch-based)
- Server authority: GD-Sync enforces single source of truth for catch validation

**Rationale:** GD-Sync PropertySynchronizer replaces MultiplayerSynchronizer. Server authority prevents cheating. Built-in interpolation for smooth movement.

---

**Decision 12: GD-Sync Proximity Voice Chat (Built-In)**

- Players hear each other automatically via GD-Sync proximity audio
- Spatial audio: voice volume decreases with distance (30-meter radius default)
- Voice Activity Detection: GD-Sync monitors amplitude to detect when players are speaking
- Bandwidth: ~1 Kbps voice compression per player (built-in, no TwoVoip needed)
- Yelling detection: when amplitude > threshold, `is_yelling` flag broadcast to server
- No manual audio bus setup, no TwoVoip compilation, no Opus integration needed

**Rationale:** GD-Sync handles voice entirely. No platform-specific bugs (Windows 11, USB mics). Spatial audio automatic. Saves 4-6 weeks vs TwoVoip + ENet + manual integration.

---

**Decision 13: Synchronized Global Events**

- Shark spawns happen at same in-game time for all players
- Yelling event broadcast to all (via GD-Sync is_yelling flag)
- Timer is server-authoritative (prevents desync)

**Rationale:** All players experience same pressure at same moment = true cooperation. No player-side manipulation of timing.

---

### Data/Schema Decisions

**Decision 14: Catch Data Structure**

- Each catch tracked: player_id, fish_type, timestamp, value (post-MVP)
- Quota counter: sum of all catches since round start (server-authoritative)
- Round reset: clear catch list when round ends
- Shark penalty: subtract 3 from quota counter when unmitigated attack occurs

**Rationale:** Simple, extensible. Post-MVP economy can leverage fish_type and value. Penalty system tracks loss events.

---

**Decision 15: Player State (GD-Sync Synced)**

- Per-player (synchronized via GD-Sync): name, position, current_line_state (idle/casting/waiting/reeling), catch_count, is_yelling, is_fishing
- Synchronized every 0.1 seconds (10 updates/sec)

**Rationale:** Minimal state, high sync frequency = responsive feel without high bandwidth.

---

## Testing Strategy

### Philosophy

**Good tests validate external behavior** (what happens when a player casts, reels, yells), not implementation details (how the reel meter is calculated internally).

**For an 8-week solo dev timeline:** Write PlayMode tests for deterministic code (Quota, DangerSystem state machine). Don't waste time on complex automated integration tests for 4-player networking—rely on Week 6-7 playtesting instead.

### What Gets Tested

- Core mechanics (fishing input → catch feedback)
- Danger system (shark spawn → player reaction → fish flee)
- Yelling mechanic (yelling → GD-Sync broadcast → fish flee radius)
- Quota system (catch count → success/failure condition, shark penalty application)
- Networking (4 players sync catches, danger events, penalty triggers via GD-Sync)

### Modules to Test

1. **FishingMechanic**
    - Input: cast action, reel action with timing
    - Output: successful catch (with feedback), failed catch (escape)
    - Edge cases: input during wrong state, rapid retries, simultaneous casts from multiple players
2. **DangerSystem**
    - Input: time elapsed, spawn schedule
    - Output: shark spawns at correct intervals, telegraph plays, yelling triggers fish flee
    - Edge cases: danger spawn during active reel, multiple simultaneous yells, unmitigated attack penalty applies correctly
3. **YellingMechanic (GD-Sync is_yelling flag)**
    - Input: amplitude detection from microphone
    - Output: is_yelling broadcast to all clients, fish flee in 30m radius, 10-second recovery
    - Edge cases: yelling during own reel, yelling far from own fish, network lag during flag broadcast
4. **QuotaSystem**
    - Input: fish caught, timer expires, shark penalty triggered
    - Output: success/failure determination, round restart, penalty application correct
    - Edge cases: catch exactly at quota, penalty brings quota below zero (cap at 0), quota change during round
5. **GD-Sync Networking**
    - Input: 4 players connecting via GD-Sync lobby
    - Output: all clients receive synchronized events, no desyncs after 10+ minutes
    - Edge cases: player disconnect mid-round, high latency (150ms+), penalty event sync

---

## Out of Scope

**Not in MVP. Not in this PRD. Deferred to post-MVP/post-launch:**

- Economy system (selling fish, money)
- Upgrades or progression (better reels, boats, equipment)
- Multiple locations or maps
- Day/night cycle or seasonal mechanics
- Cosmetics, skins, or cosmetic shops
- Leaderboards or competitive scoring
- Advanced voice chat features (voice encryption, noise cancellation beyond GD-Sync)
- Difficulty tiers (easy/normal/hard)
- Campaign mode (escalating quotas across multiple rounds)
- New danger types (storms, krakens, rival players)
- Tutorial system or onboarding campaign
- Accessibility options (color-blind modes, remappable controls)
- Mobile version or console ports
- Single-player mode or AI teammates
- Sandbox/creative mode

**Reason:** 8-week MVP timeline. These features dilute focus on core mechanic (fishing + yelling + cooperation). Validate core first, add depth post-launch based on playtest feedback.

---

## Playtesting Strategy

**Week 6-7 Execution:**

- Recruit 3-4 friend groups (12-15 people total)
- Each group plays 2-3 rounds (30-45 minutes per session)
- Feedback survey:
    1. Is the yelling mechanic fun?
    2. Is quota difficulty right?
    3. Do you feel like a crew?
    4. Would you play this again?
    5. What's missing?

**Success Threshold:** ≥60% say "yes" to question 4 (would play again)

**Feedback Loop:** If <60%, interview players about pain points. Focus on:

- Is the shark penalty fair/clear?
- Is the 30-meter yell radius too big/small?
- Does fishing feel responsive?
- Does proximity voice chat work? (background noise, clarity, latency)

---

## Known Risks & Mitigations

| Risk | Mitigation | Owner |
| --- | --- | --- |
| GD-Sync service downtime | Test offline LAN mode week 1; have ENet fallback documented | Dev |
| Voice amplitude detection accuracy | Playtesting week 4; calibration tool for player microphones | Dev |
| 4-player sync desync (catches) | Server authority + GD-Sync testing week 3-4 | Dev |
| Quota too easy (beaten in 5 min) | Solo playtesting week 2, adjust fish bite rates | Dev |
| Quota too hard (feel impossible) | Adjust reel success rates, danger frequency, shark penalty | Dev |
| Shark penalty too harsh (players rage-quit) | Playtesting week 6, gather feedback on fairness | Dev |
| Yelling mechanic feels unimpactful | Playtesting week 4, increase fish flee radius or penalty if needed | Dev |
| Scope creep (art, features bloat) | Refer back to PRD. Say "no" to anything not listed | Dev |
| Art assets not ready in time | Pre-buy asset packs week 1, don't rely on custom | Dev |
| GD-Sync quota exceeded (unlikely) | Monitor data usage weekly; upgrade to Indie tier ($7/mo) if needed | Dev |

---

## Success Metrics (Launch Readiness)

**Go-Live Checklist:**

- ✅ 4 players can connect online via GD-Sync without crashes
- ✅ Proximity voice chat works (players hear each other, spatial audio attenuates by distance)
- ✅ Fishing mechanic feels responsive (<100ms input lag)
- ✅ Shark penalty applies correctly (losing 3 fish when not yelling)
- ✅ Quota system works (success/failure states trigger correctly)
- ✅ Yelling (via voice amplitude) causes fish to flee visibly in 30m radius
- ✅ ≥60% of playtesters want to replay
- ✅ No game-breaking bugs found in playtesting
- ✅ GD-Sync lobbies work (create, join, invite)
- ✅ Store page written (description, screenshots, trailer)
- ✅ Build tested on multiple PCs/networks
- ✅ Offline LAN mode works (GD-Sync fallback)

---

## Post-Launch Roadmap (Informational Only)

**Priority 1 (Month 2-3 post-launch):**

- Economy system (sell fish for money)
- Basic upgrades (better reels)
- 2-3 additional locations

**Priority 2 (Month 4-5):**

- Campaign mode (escalating quotas)
- New danger types (storms, krakens)
- Cosmetics/skins

**Priority 3 (Future):**

- Leaderboards (via GD-Sync built-in)
- Seasonal events
- Console ports

**Only pursued if launch metrics support it** (player retention, DAU, reviews).

---

## Technical Debt Prevention

**During MVP development:**

- Keep FishingMechanic module decoupled from GD-Sync (easier to test)
- Write clear comments in DangerSystem (complex state machine)
- Document GD-Sync assumptions (will change post-MVP if scaling needed)
- Don't hardcode magic numbers (quota, timer, danger frequency, shark penalty) — use config

**After MVP ships:**

- Refactor for economy system (will need catch value tracking)
- Add telemetry/analytics (which danger event causes most quota failures? Do players understand the penalty?)
- Monitor GD-Sync data usage and plan Indie tier upgrade if growth justifies it

---

## Approval & Sign-Off

**Author:** Design + Development  

**Fact-Checker:** GD-Sync API (June 2026), Godot 4 Multiplayer Best Practices  

**Status:** APPROVED FOR DEVELOPMENT  

**Date Approved:** June 29, 2026  

**Next Step:** Create GitHub repo, set up Godot 4 project, download GD-Sync from Asset Library, begin Week 1 (Fishing Mechanic + GD-Sync Setup).

---

## Document History

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | June 28, 2026 | Claude | Initial PRD (Photon Fusion) |
| 1.1 | June 28, 2026 | Claude | Fact-check corrections |
| 2.0 | June 29, 2026 | Claude | Complete rewrite: Photon Fusion → Godot 4 ENet |
| 3.0 | June 29, 2026 | Claude | Major revision: ENet + TwoVoip → GD-Sync (complete multiplayer backend) |
