# Third-party assets

## Godot prerequisites

The project enables GUT 9.6.0 (`res://addons/gut/plugin.cfg`) and Epic Online Services Godot (EOSG) 2.3.0 (`res://addons/epic-online-services-godot/plugin.cfg`). These addons are ignored by Git; install the matching versions through the Godot Asset Library, then reopen the project and let Godot import it before building or running.

## Quaternius Cute Fish Pack

- **Pack:** Animated Cute Fish Pack (Quaternius)
- **Source:** <https://quaternius.com/packs/cutefish.html>
- **License:** Quaternius Asset License (QAL) v1.0 governs assets obtained after 2026-08-28. The pack page still displays a stale CC0 label. QAL permits commercial use with no credit required, but prohibits redistributing the raw assets as standalone files. Section 7 says the version in effect when the assets were obtained governs; see the saved [QAL v1.0 license](docs/licenses/quaternius-license.html). The pack page offers FBX, OBJ, and Blend files, not GLB files.
- **Local install paths:** `systems/fishing/assets/Goldfish.glb` and `systems/fishing/assets/Clownfish.glb`

### Setup after cloning

Choose either option below. Both install the GLBs at `systems/fishing/assets/Goldfish.glb` and
`systems/fishing/assets/Clownfish.glb`. The GLBs and Godot-generated `.import` sidecars are ignored
by Git. After installing them, open the project in Godot and allow the assets to import before
building or running the game.

#### Option 1: Convert the source FBX files

Download and extract the pack from its [source page](https://quaternius.com/packs/cutefish.html).
Keep the extracted pack outside the repository. From the repository root, set `$pack` to the
extracted pack directory and run these commands in PowerShell. Blender must be available as
`blender` on `PATH`. These local commands are not part of CI.

```powershell
$pack = 'C:\path\to\extracted\pack'
blender --background --python-expr 'import bpy, sys; args = sys.argv[sys.argv.index("--") + 1:]; bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); bpy.ops.import_scene.fbx(filepath=args[0]); bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", export_animations=True)' -- "$pack\FBX\Goldfish.fbx" "systems/fishing/assets/Goldfish.glb"
blender --background --python-expr 'import bpy, sys; args = sys.argv[sys.argv.index("--") + 1:]; bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); bpy.ops.import_scene.fbx(filepath=args[0]); bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", export_animations=True)' -- "$pack\FBX\Clownfish.fbx" "systems/fishing/assets/Clownfish.glb"
```

#### Option 2: Install team-verified GLB files

Copy the team-verified files to the local install paths above, then check their SHA-256 hashes:

| File | SHA-256 |
| --- | --- |
| `Goldfish.glb` | `028B880BF2DF64237748D1173D6DF1EAA1B23B3C01D35E936C3B76CF032CB35B` |
| `Clownfish.glb` | `D1D0B1F83848337299EF163B7EC5B207B5C34E3933DA1367000E1DCD6D856BF1` |

## KayKit Adventurers

- **Pack:** KayKit - Character Pack: Adventurers, Free 2.0
- **Source:** <https://kaylousberg.itch.io/kaykit-adventurers>
- **License:** CC0 1.0 Universal. The free pack includes the standard characters as GLTF files.
- **Selected body:** `Knight.glb`, the stock/default Knight character from the free pack.
- **Local install paths:** `entities/player/assets/kaykit_adventurers/Knight.glb` and `entities/player/assets/kaykit_adventurers/knight_texture.png`

### Setup after cloning

Download the free Adventurers pack from its [source page](https://kaylousberg.itch.io/kaykit-adventurers), then copy its stock Knight GLB and texture to the local install paths above. Keep the raw pack outside version control. The player asset directory and Godot-generated import sidecars are ignored by Git. Open the project in Godot after copying the files so Godot imports `Knight.glb` before loading the player scene.

## KayKit Character Animations

- **Pack:** KayKit Character Animations 1.1
- **Source:** <https://kaylousberg.itch.io/kaykit-character-animations>
- **License:** CC0 1.0 Universal.
- **Local install paths:** `entities/player/assets/kaykit_animations/Rig_Medium_General.glb`, `entities/player/assets/kaykit_animations/Rig_Medium_MovementBasic.glb`, and `entities/player/assets/kaykit_animations/Rig_Medium_Tools.glb`
- **Used clips:** `Idle_A`, `Walking_A`, `Jump_Start`, `Jump_Idle`, `Jump_Land`, `Fishing_Cast`, `Fishing_Bite`, `Fishing_Catch`, `Fishing_Idle`, `Fishing_Reeling`, `Fishing_Struggling`, and `Fishing_Tug`.
- **Deferred clip:** `Running_A` is installed in `Rig_Medium_MovementBasic.glb` but intentionally unused; #339 A-lite does not add sprint state or controls.

### Setup after cloning

Download `KayKit_Character_Animations_1.1.zip` from the source page and extract only these GLBs from `Animations/gltf/Rig_Medium/` into the local install path above. The assets and Godot-generated import sidecars are ignored by Git. Open the project in Godot after copying them so Godot imports the scenes before loading the player.

| File | SHA-256 |
| --- | --- |
| `KayKit_Character_Animations_1.1.zip` | `65882F31F905AD2E953819648A59287CDEAB8F623908D5EF701971D3758BE20F` |
| `Rig_Medium_General.glb` | `5F725C0F745F36078C7238968CD5C04843CBC6260689EB6E7F5E2BBD7FFDD7AD` |
| `Rig_Medium_MovementBasic.glb` | `11422AFD50ABF7E8C92EA107E2E0BC94ABD38023D6D15F55AD580347EFBFA29E` |
| `Rig_Medium_Tools.glb` | `E3B62DC122C5073373376A846E354137ADD2088DDCCE8731C389FC5C20734AAD` |

## Audit note

The repository audit found no Pirate Kit or Kenney asset files or references in this checkout.
No pack names, source URLs, or install steps are recorded for them because none could be verified.
