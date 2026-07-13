# Fish Carry System

On reel success, the player enters a **carrying state** instead of auto-reporting the catch to quota.

## State flow

```
REELING → (success) → CARRYING → (drop fish) → IDLE
                       CARRYING → (round restart) → IDLE
```

While carrying:
- Rod is hidden, a fish mesh appears in the player's hands
- Casting is blocked (`can_cast()` returns false)
- Pressing `F` drops the fish with no quota credit (discard)
- Deposit to quota is handled by a separate system

## Architecture

| File | Role |
|------|------|
| `systems/fishing/fishing_mechanic.gd` | Core state: `start_carrying()`, `drop_carried_fish()`, `is_carrying` property, `carry_state_changed` signal |
| `entities/player/player.gd` | Visual management: rod toggling, carried fish mesh, `drop_fish` input handling |

## Multiplayer sync

Carry state syncs via the existing `_sync_fishing_state` RPC — no new network code. Remote clients receive the `CARRYING` enum value, trigger `_handle_remote_transition`, which emits `carry_state_changed` for the player to update visuals.

## Round restart

`reset_for_restart()` in `fishing_mechanic.gd` clears the carry state back to IDLE without giving quota credit.
