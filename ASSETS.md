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

### Fishing rod

The same Cute Fish Pack includes the selected `FBX/FishingRod_Lvl2.fbx`, governed by the QAL v1.0 license above. Install its converted GLB at `entities/player/assets/quaternius/FishingRod_Lvl2.glb`. This directory, including import sidecars, is ignored by Git; keep the raw pack outside the repository.

Create the destination directory, then convert the existing FBX with Blender (the verified conversion used Blender 5.2.1):

```powershell
New-Item -ItemType Directory -Force entities/player/assets/quaternius
blender --background --factory-startup --offline-mode --python-expr 'import bpy, sys; args = sys.argv[sys.argv.index("--") + 1:]; bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False); bpy.ops.import_scene.fbx(filepath=args[0]); [setattr(node.inputs["Alpha"], "default_value", 1.0) for material in bpy.data.materials if material.use_nodes for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"]; bpy.ops.export_scene.gltf(filepath=args[1], export_format="GLB", export_animations=False)' -- "$pack\FBX\FishingRod_Lvl2.fbx" "entities/player/assets/quaternius/FishingRod_Lvl2.glb"
```

Alternatively copy the team-verified GLB to that path. Open Godot and let it import before running. Missing or unimported rods log installation instructions; the hand pivot and line marker remain available.

The FBX importer sets the wood material's Principled BSDF alpha to zero. The conversion restores alpha to one before export so the rod is opaque; geometry and colors remain unchanged.

The source grip is at the origin. Averaging the six unique vertices on the source tip endcap gives a tip center that imports at Godot `(0, 4.9471223, -0.23781153)` meters. `PlayerVisualRig` first rotates only `RodModel` by approximately +2.7521 degrees around X to align its shaft with +Y, then rotates it -90 degrees around that aligned +Y axis so the reel and line guides face the player's casting direction. It scales the model uniformly by approximately 0.161524, aligning its tip with `RodTip` at `(0, 0.8, 0)` along the rod pivot's +Y axis. Separately, the rod pivot rotates +8 degrees around the hand slot's local X axis to remove the visible left lean in the neutral first-person waiting pose while retaining the authored hand animation. The character rig, eye height, and collision dimensions are halved while the physics root stays at unit scale. The rod pivot compensates with uniform scale 2, keeping the grip-to-tip length at 0.8 world meters and making the rod larger relative to the character. Tension bends the pivot relative to this calibrated grip and restores it when tension ends. The raw GLB remains unchanged.

| File | SHA-256 |
| --- | --- |
| `FishingRod_Lvl2.fbx` | `54CC6F070BDC8684BDF7A286C6219A2517EA0AA7FCD3C7322FBE434E6ED42382` |
| `FishingRod_Lvl2.glb` | `9451DD5C356A49B3F6D1F1C0BC41860EDE1569619AC6B532AADB53D2C695872B` |

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

Download `KayKit_Character_Animations_1.1.zip` from the source page and extract only these GLBs from `Animations/gltf/Rig_Medium/` into the local install path above. Fishing animation playback expects `res://entities/player/assets/kaykit_animations/Rig_Medium_Tools.glb`; if it is absent or has not been imported, locomotion remains available and Godot logs these installation instructions. The assets and Godot-generated import sidecars are ignored by Git. Open the project in Godot after copying them so Godot imports the scenes before loading the player.

| File | SHA-256 |
| --- | --- |
| `KayKit_Character_Animations_1.1.zip` | `65882F31F905AD2E953819648A59287CDEAB8F623908D5EF701971D3758BE20F` |
| `Rig_Medium_General.glb` | `5F725C0F745F36078C7238968CD5C04843CBC6260689EB6E7F5E2BBD7FFDD7AD` |
| `Rig_Medium_MovementBasic.glb` | `11422AFD50ABF7E8C92EA107E2E0BC94ABD38023D6D15F55AD580347EFBFA29E` |
| `Rig_Medium_Tools.glb` | `E3B62DC122C5073373376A846E354137ADD2088DDCCE8731C389FC5C20734AAD` |

## Quaternius Pirate Kit shark

- **Pack:** Pirate Kit (Quaternius)
- **Source:** <https://quaternius.com/packs/piratekit.html>
- **Selected model:** `glTF/Characters_Shark.gltf`, acquired 2026-10-20.
- **License:** QAL v1.0, saved in [the license record](docs/licenses/quaternius-license.html), governs this acquisition. The pack page still displays a stale CC0 label. Keep raw assets outside version control; QAL prohibits standalone raw-asset redistribution.
- **Local install path:** `systems/danger/assets/quaternius/Characters_Shark.gltf`
- **Used clip:** `Swim`, looped cosmetically. `Swim_Bite` and `Swim_Fast` are unused; gameplay timing remains in the danger manager.

### Setup after cloning

Open the source page's Google Drive download, then its `glTF` folder and download `Characters_Shark.gltf`. The verified [pack folder](https://drive.google.com/drive/folders/1KjMzhVsDcyvYMWeVjZcRfuu8auBLpNi2), [glTF folder](https://drive.google.com/drive/folders/11paA9BQwPiV5Xj2JJKgsBSR59S4m5JuC), and [selected file](https://drive.google.com/file/d/1vvH5IE8jvg3TIJnlcXr-ZSpuhtyxUP1h/view) identify the exact source. This glTF embeds its texture and geometry; no conversion or companion files are needed.

From the repository root, copy the downloaded file and check its hash:

```powershell
New-Item -ItemType Directory -Force systems/danger/assets/quaternius
Copy-Item -LiteralPath 'C:\path\to\Characters_Shark.gltf' -Destination systems/danger/assets/quaternius/Characters_Shark.gltf
Get-FileHash -Algorithm SHA256 systems/danger/assets/quaternius/Characters_Shark.gltf
```

| File | SHA-256 |
| --- | --- |
| `Characters_Shark.gltf` | `1F62E757F280BE1337F0EA2D0AC65D54CC448ECC20D5ED052E8012D62DE4B9EB` |

The asset directory and generated import sidecars are ignored by Git. Open the project in Godot and allow import before running or testing. Missing or unimported sharks log installation instructions; there is no procedural visual fallback.

Only the model child is calibrated: uniform scale 0.5, Y offset -0.7, and Y rotation 180 degrees to turn the source's +Z nose toward the visual pivot's -Z. The gameplay root keeps its existing transform and attack radius. The visual pivot follows world displacement on every peer, retains its last heading while stationary, and resets its position sample across hidden respawns.

## Quaternius Pirate Kit island rocks

- **Pack:** Pirate Kit by Quaternius, acquired 2026-10-22.
- **Source:** [pack page](https://quaternius.com/packs/piratekit.html), [verified glTF folder](https://drive.google.com/drive/folders/11paA9BQwPiV5Xj2JJKgsBSR59S4m5JuC).
- **License:** QAL v1.0, saved in [the license record](docs/licenses/quaternius-license.html), governs this acquisition. The pack page's CC0 label is stale. Keep raw files out of Git; QAL prohibits standalone raw-asset redistribution.
- **Selected files:** `glTF/Environment_Rock_1.gltf` through `Environment_Rock_5.gltf`. Each embeds its geometry and texture; no companion files are required.
- **Local install directory:** `world/assets/quaternius_pirate/`, ignored along with generated import sidecars.

### Setup after cloning

Download the five selected files from the glTF folder into a directory outside the repository. These direct file pages identify the verified sources:

- [Environment_Rock_1.gltf](https://drive.google.com/file/d/1Agk58yl3i7Q_reKzdSbb14YGVZxKya5g/view)
- [Environment_Rock_2.gltf](https://drive.google.com/file/d/129Oy6SIdcUgsUvSxKz-Teue6rXO_nH92/view)
- [Environment_Rock_3.gltf](https://drive.google.com/file/d/1ZgpQDme1g5STjfj0bbzq5X4Rbnn-_ZMi/view)
- [Environment_Rock_4.gltf](https://drive.google.com/file/d/1Ce6fVwQZGxleWRFnrNBOmh119FozKIwl/view)
- [Environment_Rock_5.gltf](https://drive.google.com/file/d/1cWJHr-w1QtFhxm0CpRQAUeFhbrL-o6yE/view)

From the repository root, set `$pack` to the downloaded files' directory and copy only these models:

```powershell
$pack = 'C:\path\to\downloaded\glTF'
New-Item -ItemType Directory -Force world/assets/quaternius_pirate
foreach ($variant in 1..5) {
    Copy-Item -LiteralPath (Join-Path $pack ('Environment_Rock_' + $variant + '.gltf')) -Destination world/assets/quaternius_pirate
}
Get-FileHash -Algorithm SHA256 world/assets/quaternius_pirate/*.gltf
```

| File | SHA-256 |
| --- | --- |
| `Environment_Rock_1.gltf` | `57E7BB033B0DB4842D1CADDA86AF1F3604D5504B9547FC0397001E352C89461B` |
| `Environment_Rock_2.gltf` | `06C5012110D3A513EBB05C2F9080A3232C457E19CFD4246B63311A1EE2C1518B` |
| `Environment_Rock_3.gltf` | `EE4717601B37DE40126A8D1A35E2F811F1CBE4D38BAB27C1BC51FE467D5198F2` |
| `Environment_Rock_4.gltf` | `1EEA738B93713690F3EE0805030C14AD64DB0977F256CD9AE638DB061D82ECD1` |
| `Environment_Rock_5.gltf` | `46A2B61C283527B57BF9A56884F5B34CB506E6D4F0C5420027E48C3A5A92DA9C` |

Open Godot and let the glTF models import before running. Missing or unimported rocks log installation instructions; there is no generated placeholder fallback. Only the selected meshes are copied into collisionless visual instances with four shared matte earth/slate materials. Shore rocks preserve their natural proportions, with varied uniform scale and yaw in uneven clusters of boulders and smaller stones. Cluster anchors jitter within angular sectors to distribute dressing across both coasts, while incidental stones leave a clear buffer around the arch. A local seeded random generator keeps this cosmetic layout repeatable without consuming gameplay randomness. Full rotated mesh bounds protect routes, landmarks, and the broad dock side. The bay arch is composed from Quaternius rocks with two supports outside the existing opening and one flattened rock slab spanning them. Layout resources, gameplay objects, collision, spawn points, and fog are unchanged by the rock rework.

Use `scenes/dev/dev_island_flow.tscn` to inspect dressing and toggle fog; its controls and visual checks are in `scenes/dev/README.md`. Fog uses the regular Environment fog supported by Compatibility, without volumetric fog or new shaders.

Fog now shares the sky's day, sunset, and night horizon palette and follows the existing light cycle, so distant water converges to the sky instead of a fixed purple band. Density remains `0.035`. Run the rendered regression with `C:\Godot\Godot_v4.6.2-stable_win64.exe --path . --rendering-method gl_compatibility --resolution 960x540 --script res://scripts/check_fog_horizon.gd`; it checks day/night horizon continuity and saves screenshots under `docs/`.
