# Dev Scenes — Quick Guides

## Shark Bait Placement — Water Test (`dev_shark_bait_flow.tscn`)

**What it does:** Isolated placement without lobby → host → round. Tests `SharkBaitManager` server-authoritative placement: owned-gate (`shark_bait_owned`), `is_placed` single-bait guard, `MapConfig.ISLAND_RADIUS` water check (red torus at radius 10), `request_place_shark_bait → _sync_placed` broadcast + `shark_bait_placed` signal, and red `SharkBait` box at `placed_position`.

**Prod values stay untouched:** `shark_bait_cost` is `15`, `ISLAND_RADIUS` is `10.0` (`scripts/map_config.gd`), bait cost/placement live in `systems/shark_bait/shark_bait_manager.gd` / `entities/shark_bait.tscn`. This dev scene overrides them *in the dev script only* to `0` cost and shows the island ring at `10` for instant testing (per Manual/Dev Testing convention — shorten in dev script, not `@export` defaults).

**How to open and move:**
1. In Godot FileSystem go to `scenes/dev/dev_shark_bait_flow.tscn`
2. Click **Play** (▶) — no lobby, single instance, no peer (`multiplayer.has_multiplayer_peer()==false` → server path).
3. Click inside game window to capture mouse, **W/A/S/D + Mouse** to look (Player at `0,1,-7`).

**What you see:** Top HUD shows `Owned / Cost / Coins / Fish | Placed / Pos / Dist to center / inside? | BaitVisible / BaitPos / PlayerPos / Fwd | Last`. Red torus = island boundary (`ISLAND_RADIUS`), brown box = island (`20×20`), blue box = water (`120×120`), red box appears at placed water pos.

**Controls:**
- **C** — Buy Shark Bait (`request_buy_shark_bait()` — cost `0` in dev, sets owned, grants hold to buyer)
- **Right-Click** — Place held Shark Bait 3m ahead at water (`_try_place_shark_bait()`)
- **P** — Place via dev shortcut
- **I** — Try place at island center (`MAP_CENTER + (ISLAND_RADIUS-0.5)`) — should be **rejected** ✓
- **O** — Toggle `shark_bait_owned` (`_sync_shark_bait` + signal)
- **R** — Reset (manually clears `is_placed`/`placed_position`/instance/fill, coins 0, owned `false`, fish 3)
- **B** — +5 coins
- **G** — +5 fish (`QuotaManager.shared_quota`)
- **H** — 1x / 2x speed toggle

**Full flow to watch:** Press **C** → Owned `yes` → **P** while looking at water (outside red ring) → red bait box spawns at `Last: Placed ✓` → **P** again → `Already placed` → **R** → back to `(none)` → **C** (re-acquire owned after reset) → **I** → `correctly rejected ✓` → look at water → **P** → places again. Production remains `15` cost / `10` radius — close window when done.

---

## Shop Test — Shark Bait (`dev_shop_flow.tscn`)

**What it does:** Isolated Shop without lobby → host → round. Tests `CoinManager` purchase flow for Shark Bait / Fireplace: `Owned / Buy / "N coins"` disabled states, `coins_updated` / `shark_bait_updated` signals, and `NotificationLabel` toast.

**Prod values stay untouched:** `shark_bait_cost` and `fireplace_cost` are `15` and `round_duration` is `900` in `CoinManager`/`RoundManager`. This dev scene overrides them *in the dev script only* to `0` / `0` / `15s` for fast testing (per Manual/Dev Testing convention — shorten in dev script, not `@export` defaults).

**How to open and move:**
1. In Godot FileSystem go to `scenes/dev/dev_shop_flow.tscn`
2. Click **Play** (▶) — no lobby, single instance, no peer.
3. Click inside game window to capture mouse, **W/A/S/D + Mouse** to look.

**What you see:** Top-left HUD shows `Coins / Fish | Bait: owned/cost state | Fire: owned/cost state | Fishing: true/false Timer`.

**Controls:**
- **O** — Open Shop (`ShopUI` — verify Shark Bait row alongside Fireplace, text cycles `Owned` / `Buy` / `"0 coins"` at 0 cost)
- **C** — Buy Shark Bait (`request_buy_shark_bait()` — deducts `0`, sets owned, broadcasts `_sync_shark_bait` + `coins_updated`)
- **F** — Buy Fireplace
- **B** — +5 coins
- **G** — +5 fish (`QuotaManager.shared_quota`)
- **R** — Reset (coins 0, owned `false`, costs back to `0`, round 15s, `fishing_active true`)
- **T** — Toggle `fishing_active` (ShopHut gating pattern)
- **H** — 1x / 2x speed toggle

**Full flow to watch:** Press **O** → Shop shows both rows `Buy` at `0` cost → **C** → Shark Bait flips to `Owned`, coins unchanged, toast `bought Shark Bait` → **R** → back to `Buy`. Production remains `15` / `900` — close window when done.

---

## Seagull Test — Quick Guide

**What it does:** Shows the full seagull story — it appears high above the storage box, circles for **10 to 15 seconds**, dives to steal a fish, then hides and comes back.

**How to open and move:**
1. Open Godot, in FileSystem go to `scenes/dev/dev_seagull_flow.tscn`
2. Click **Play** (▶) at top right.
3. **To move around:** Click anywhere inside the game window once it starts (this captures your mouse), then use **W/A/S/D** to walk and **Mouse** to look around.

**What you see:**
- Top-left text tells you what the seagull is doing (`ROAMING`, `APPROACHING`, `WAITING`), how much time is left, and how many fish are in storage.
- White bird circles high above the brown box for 10–15s, then dives low.

**Buttons & Controls:**
- **W/A/S/D + Mouse** — Walk around and look
- **Left-Click (when looking at a rock on the ground)** — Pick up a rock
- **Left-Click (when holding a rock)** — Throw the rock (try hitting the seagull while it's roaming or approaching!)
- **F5** — Start a new seagull right now
- **F6** — Skip circling, make it dive immediately
- **G** — Add 5 fish to storage
- **R** — Reset
- **H** — Speed up / slow down (2x speed toggle)

**Full flow to watch:** Press **F5** → bird circles high (~10-15 sec) → dives to box → message “Seagull stole 1 fish!” + fish count drops by 1 → bird disappears → after ~5 sec it comes back.

That’s the whole seagull, sped up for testing. Close the window when done — nothing changes in the real game.
