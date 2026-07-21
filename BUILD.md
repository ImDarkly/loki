# Building GD-EOS (Epic Online Services)

## Prerequisites

| Tool | How to get |
|------|-----------|
| **Visual Studio Build Tools 2022** | `winget install Microsoft.VisualStudio.2022.BuildTools` — or download from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022). When installing, select the **Desktop development with C++** workload. |
| **EOS C SDK** | Download from [Epic Dev Portal](https://dev.epicgames.com/portal) → Your Product → **Epic Online Services SDK**. Extract to `thirdparty/eos-sdk/` so that `thirdparty/eos-sdk/SDK/Include/eos_version.h` exists. |
| **Python 3.11+** | [python.org](https://python.org) |
| **SCons** | `pip install SCons` |

## Clone

```powershell
git clone --recurse-submodules <repo-url>
cd loki
```

If you already cloned without `--recurse-submodules`:

```powershell
git submodule update --init --recursive
```

## Build

From the project root, run:

```powershell
powershell build/build_gd_eos.ps1
```

The script will:

1. Verify MSVC, SCons, and EOS SDK are available
2. Create a junction so GD-EOS can find the EOS SDK at `build/gd-eos/thirdparty/eos-sdk/`
3. Initialize GD-EOS's own `godot-cpp` submodule
4. Compile `template_debug` and `template_release` DLLs
5. Copy the compiled addon to `addons/gd-eos/`
6. Clean up build artifacts from the submodule

## What gets created

```
addons/gd-eos/
├── gd-eos.gdextension       # Godot extension manifest (auto-loaded)
├── bin/
│   └── windows/
│       ├── libgdeos.windows.template_debug.x86_64.dll
│       ├── libgdeos.windows.template_release.x86_64.dll
│       ├── EOSSDK-Win64-Shipping.dll
│       └── x64/xaudio2_9redist.dll
├── doc/                     # GD-EOS documentation
├── LICENSE
└── README.md
```

Both `thirdparty/` and `addons/` are gitignored — these files stay local.

## Rebuilding

Re-run `build/build_gd_eos.ps1` after:
- Updating the EOS SDK (re-download and re-extract to `thirdparty/eos-sdk/`)
- Updating the GD-EOS submodule (`git submodule update --remote build/gd-eos`)
- Switching Godot versions (the build binds against godot-cpp, which targets a specific Godot version)

## CI

The same script can run in CI. It exits with code 0 on success, non-zero on failure.
