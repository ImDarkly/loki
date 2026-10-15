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

## Audit note

The repository audit found no Pirate Kit or Kenney asset files or references in this checkout.
No pack names, source URLs, or install steps are recorded for them because none could be verified.
