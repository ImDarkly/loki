## Catch & Chaos MVP

**Feature ID:** CFM-001

**Status:** Ready for Development

**Target Completion:** Week 1-2 (14 days)

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript

---

## Problem Statement

Players need a responsive, skill-based fishing input loop that feels satisfying to repeat 20+ times per round. The baseline mechanic must be simple enough to prototype solo in 2 weeks, yet engaging enough that playtests show "I want to play again."

Current gap: No core loop exists. Player experience starts at zero.

---

## Solution

Implement a three-step fishing mechanic inspired by Stardew Valley:

1. **Cast:** Player clicks to cast line into water (instant, visual feedback)
2. **Wait:** Fish bite after 3-8 seconds (random, audio + visual telegraph)
3. **Reel:** Player holds button while managing a Stardew-style meter (10-20 seconds, success/failure feedback)

Success = fish added to quota counter. Failure = silent escape, back to step 1.

This loop is designed to:

- Be testable in isolation (no networking, no UI, no danger system)
- Generate minimal feedback (no juicy animations, just clear success/failure)
- Support high repetition (20+ catches per 15-minute round)
- Teach players the core tension (hold steady, don't lose focus)

---

## User Stories

### Casting

1. As a **player**, I want to **click once to cast my fishing line**, so that **I can begin fishing without complex inputs**
2. As a **player**, I want to **see visual feedback that my cast was successful** (line appears in water), so that **I know I'm ready to fish**
3. As a **player**, I want to **cast instantly without animation delays**, so that **the game feels responsive and snappy**

### Waiting for Bite

1. As a **player**, I want to **wait for a fish to bite my line**, so that **there's a moment of anticipation before I act**
2. As a **player**, I want to **wait between 3-8 seconds for a bite**, so that **the timing feels natural and not too fast**
3. As a **player**, I want to **see visual feedback when a fish bites** (line twitches), so that **I notice the bite instantly**
4. As a **player**, I want to **hear audio feedback when a fish bites** (distinctive sound), so that **I don't miss the bite even if looking at Discord**
5. As a **player**, I want to **experience random bite timing** (not predictable), so that **each cast feels fresh and unpredictable**

### Reeling Mechanic

1. As a **player**, I want to **hold down a button when a fish bites**, so that **I can reel in the fish**
2. As a **player**, I want to **manage a reel meter while holding the button**, so that **landing a fish requires some skill, not just luck**
3. As a **player**, I want to **see a meter showing my progress reeling** (my strength vs fish strength), so that **I understand how close I am to success**
4. As a **player**, I want to **maintain my bar in the green zone for 10-20 seconds**, so that **the challenge feels achievable but requires focus**
5. As a **player**, I want to **fail to reel if my bar leaves the zone**, so that **fishing has real stakes and I care about my inputs**
6. As a **player**, I want to **experience increasing tension as I reel** (sound intensifies), so that **landing a fish feels dramatic**

### Success Feedback

1. As a **player**, I want to **see clear feedback when I catch a fish** (text appears, sound plays, quota updates), so that **I feel rewarded for successful inputs**
2. As a **player**, I want to **see my quota counter increment by 1**, so that **I understand progress toward the win condition**
3. As a **player**, I want to **hear a satisfying "ding!" sound when I catch**, so that **catching fish is aurally rewarding**

### Failure Feedback

1. As a **player**, I want to **see clear feedback when a fish escapes** (text appears, fish disappears), so that **I understand I failed and need to try again**
2. As a **player**, I want to **automatically return to casting state after escape**, so that **I can immediately try again without extra clicks**
3. As a **player**, I want to **hear a "whoosh" sound when a fish escapes**, so that **failure is audiologically distinct from success**

### Solo Playtesting

1. As a **developer**, I want to **test the fishing loop solo without networking**, so that **I can validate the mechanic works before adding multiplayer**
2. As a **developer**, I want to **play 10 consecutive fishing rounds**, so that **I can verify the loop is repeatable and not boring**
3. As a **developer**, I want to **verify I can catch 20 fish in 15 minutes**, so that **I know the difficulty pacing is right for the quota**
4. As a **developer**, I want to **debug reel meter behavior easily**, so that **I can tune difficulty if needed**

### Post-MVP (Out of Scope)

1. As a **player**, I want to **see different fish types visually**, so that **the game feels less repetitive** *(POST-MVP)*
2. As a **player**, I want to **see different fish have different reel difficulties**, so that **I can choose between easy safe fish or risky big fish* *(POST-MVP)*
3. As a **player**, I want to **see satisfying catch animations** (fish arc, particles, camera shake), so that **catching feels exciting** *(POST-MVP)*

---

## Implementation Decisions

### Decision 1: Casting Mechanic

**Input:** Single click (no aim, no drag)

**Behavior:** Line appears in water at random distance (visual feedback only)

**Timing:** Instant (no animation)

**Why:** Fastest to implement, matches user story #3 (responsive feel)

---

### Decision 2: Fish Spawn & Bite Timing

**Spawn Logic:** Fish spawn at random positions in fishing zone (within camera view)

**Bite Delay:** Random between 3-8 seconds after successful cast

**Telegraph:** Both visual (line twitch) AND audio (bite sound) trigger simultaneously

**Why:** Matches Stardew Valley (player reference point), provides clear signal that action is required

---

### Decision 3: Reel Meter Mechanic

**Design:** Exact Stardew Valley copy (green zone, player bar, hold to stay in zone)

**Duration:** 10-20 seconds per fish (varies slightly per fish)

**Success Condition:** Player bar stays in green zone for entire duration

**Failure Condition:** Player bar leaves green zone (fish escapes immediately)

**Visual Feedback:**

- Player bar fills/depletes based on input
- Green zone shrinks slightly as time passes (increasing difficulty)
- Color changes: green (safe) → yellow (warning) → red (failure zone)

**Why:** Proven mechanic (Stardew works), requires skill under pressure, teaches focus

---

### Decision 4: Feedback & Audio

**Catch Success:**

- Text: "+1 Fish" appears briefly at center
- Sound: Single "ding!" (50ms, satisfying tone)
- Visual: Subtle screen flash (white, 100ms)
- Quota updates instantly

**Catch Failure:**

- No text feedback (silence = failure)
- Sound: "Whoosh" (200ms, fish escaping)
- Visual: Line goes slack (slight color change)
- Automatic return to casting state

**Bite Telegraph:**

- Visual: Line twitches (quick animation, 200ms)
- Audio: Low rumble (300ms, unmistakable)

**Why:** Minimal implementation (no animation overhead), maximizes clarity (success ≠ failure)

---

### Decision 5: Difficulty Parameters (Tunable via Config)

**Fish Bite Delay:** 3-8 seconds (randomized per cast)

**Reel Duration:** 10-20 seconds (varies by fish size, post-MVP)

**Reel Difficulty:** Medium (green zone stays roughly 40% of meter width)

**Spawn Frequency:** Fish despawn after 2 minutes of no action, new spawn available

**Why:** Allows playtesting + rapid iteration if difficulty is too hard/easy

---

### Decision 6: Solo Testing Protocol

**Test Setup:**

- No networking (single player only)
- No UI except quota counter and timer
- Simple scene: player character, fishing zone, water shader

**Success Metric:**

- Can a solo player catch 20 fish in 15 minutes?
- If yes → difficulty is balanced
- If no → adjust reel duration or bite delay

**Why:** Validates core loop before networking complexity

---

### Decision 7: Godot Architecture

**Scene Structure:**

- Root: FishingGameScene (main game loop)
    - Player (input handler)
    - FishingMechanic (fishing state machine)
    - FishManager (spawn/despawn fish)
    - UIManager (quota counter, feedback)

**FishingMechanic Module (Deep Module):**

- **Interface:**
    - `cast()` → returns success/failure
    - `on_bite()` → triggers reel state
    - `update_reel(input_value: float)` → updates meter position
    - `check_reel_success()` → returns true/false
- **Responsibility:** Manages state machine (Idle → Casting → Waiting → Reeling → Success/Failure), no UI updates, no networking
- **Testability:** Pure GDScript state logic, no Godot nodes required

**FishManager Module:**

- **Interface:**
    - `spawn_fish()` → creates fish at random position
    - `get_active_fish()` → returns current fish
    - `despawn_fish()` → removes fish from scene
- **Responsibility:** Manages fish lifecycle (spawn, despawn, respawn timing)

**UIManager Module:**

- **Interface:**
    - `update_quota(count: int)` → displays quota counter
    - `show_catch_feedback()` → triggers catch animation
    - `show_escape_feedback()` → triggers escape animation
- **Responsibility:** All visual/audio feedback, responds to FishingMechanic signals

**Why:** Deep modules are testable in isolation. FishingMechanic has zero dependencies on UI/networking.

---

### Decision 8: Input Handling

**Casting Input:** Mouse click or Spacebar

**Reeling Input:** Hold Spacebar (player must maintain constant input)

**No Controller Support (MVP):** Keyboard only, rebindable post-MVP

**Why:** Fastest implementation, players testing via keyboard

---

### Decision 9: Performance Target

**Frame Rate:** 60 FPS (locked)

**Fish Count:** Max 10 simultaneous fish (fisherman has only 1 active line, but despawned fish may linger visually)

**Build Size:** <500 MB (Godot baseline ~150MB)

**Why:** Godot is lightweight; 60 FPS is standard for indie co-op; 500MB is acceptable for Steam

---

### Decision 10: State Machine

**Fishing Mechanic States:**

```
Idle → (on_cast) → Casting
  → (on_cast_complete) → Waiting
  → (on_bite) → Reeling
  → (on_reel_success) → Success → Idle
  → (on_reel_failure) → Failure → Idle
```

**Waiting State Behavior:**

- Timer ticks from 3-8 seconds
- On timeout → trigger bite event

**Reeling State Behavior:**

- Green zone position updates randomly every 100ms
- Player input moves their bar up/down
- Every frame: check if bar is in green zone
- On timeout (duration expires) → check_reel_success()

---

## Testing Decisions

### What Makes a Good Test

A good test validates **external behavior** (inputs → outputs), not implementation details. For fishing mechanic:

- ✅ Good: "Cast → Bite triggers after 3-8 seconds" (observable outcome)
- ❌ Bad: "BiomeManager.spawn_fish() called 5 times" (internal detail)

### Modules to Test

**FishingMechanic (Deep Module)**

- Test cast success (state transitions: Idle → Casting → Waiting)
- Test bite delay (3-8 seconds)
- Test reel success (bar stays in zone → success)
- Test reel failure (bar leaves zone → escape)
- Test state recovery (Failure → Idle → can cast again)

**FishManager (Deep Module)**

- Test fish spawn at valid positions
- Test fish despawn after 2-minute timeout
- Test max 10 concurrent fish limit

**UIManager (Shallow, signals only)**

- Test quota counter increments on catch
- Test feedback signals trigger (catch_success, catch_failure)
- No animation testing (too brittle)

### Prior Art

Stardew Valley source code has reel meter tests (private repo, but pattern is well-known):

- Assert meter position updates with input
- Assert success/failure conditions trigger correctly
- No animation frame counting

### Testing Framework

Use GDUnit4 (Godot's native testing framework):

- Test FishingMechanic methods in isolation
- Mock FishManager and UIManager (no actual spawning/UI in tests)
- Run tests before each merge

### Test Execution for MVP

**Week 1:** Write basic tests for FishingMechanic states (cast, bite, reel success/failure)

**Week 2:** Playtest solo (manual, 15-minute sessions) to validate difficulty

**Week 7-8:** Run full test suite before shipping

---

## Out of Scope

**NOT in this feature (deferred to post-MVP or other features):**

- Fish visuals (different types, animations) → Post-MVP Visual Polish
- Difficulty tiers (easy/normal/hard) → Post-MVP Features
- Catch animations (particles, camera shake) → Post-MVP Polish
- Different fish sizes with variable difficulties → Post-MVP Features
- Fishing rod upgrades or variants → Post-MVP Economy
- Seasonal fish availability → Post-MVP Features
- Environmental effects (weather, time of day) → Post-MVP Polish
- Multiplayer syncing → Separate feature (Networking)
- Danger system integration → Separate feature (Danger System)
- Quota tracking → Separate feature (Quota System)

---

## Further Notes

### Iteration Strategy

If playtests show "fishing is boring" or "can't catch 20 in 15 min":

1. **Too hard:** Increase reel success window (green zone wider)
2. **Too easy:** Decrease reel duration (less time to reel)
3. **Not engaging:** Add catch feedback (post-MVP) or adjust reel meter dynamics

### Solo Developer Sanity Check

This feature has NO external dependencies:

- No networking needed
- No UI system needed
- No asset loading complexity
- Pure GDScript state machine + basic spawning

**Estimated implementation time:** 3-5 days for full feature + tests

### Claude Code Integration

When implementing, use Claude to:

- Generate FishingMechanic state machine boilerplate
- Debug reel meter math (player bar vs zone position calculations)
- Generate test cases for state transitions
- Profile and optimize if needed

---

## Approval & Sign-Off

**Status:** READY FOR DEVELOPMENT

**Tech Lead:** Solo Developer

**Date:** June 28, 2026

**Next Step:** Create Godot project, set up GDUnit4 testing framework, begin FishingMechanic implementation.

---

## Appendix: Success Criteria (Week 2 Validation)

Before moving to Week 3 (Danger System), this feature is done when:

- ✅ Cast → Bite → Reel → Success/Failure loop works solo
- ✅ Player can catch 20 fish in 15 minutes (difficulty is balanced)
- ✅ All feedback (visual + audio) triggers correctly
- ✅ FishingMechanic module is tested and passes all tests
- ✅ Solo playtester says "I want to play again"

If any of these fail, iterate on difficulty/feedback before moving forward.
