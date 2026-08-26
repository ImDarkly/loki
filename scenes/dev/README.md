# Seagull Test — Quick Guide

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
