# itch.io butler — deployment reference

Primary sources: [itch.io butler manual](https://itch.io/docs/butler/)

## What it is

`butler` is the official itch.io CLI for uploading builds and generating/apply
patches. It uses the open [Wharf spec](https://itch.io/docs/wharf/) and is MIT
licensed ([itchio/butler](https://github.com/itchio/butler)). The itch app
(v26.12.0+) also bundles a graphical push interface; this project uses the
standalone CLI.

## Install (Windows)

1. Download the latest stable from the permanent broth URL (stable channel, not
   the itch.io download page which uses expiring links):
   `https://broth.itch.zone/butler/windows-amd64/LATEST/archive/default`
2. Extract the `.zip` to a folder (e.g. `C:\butler`) and add it to PATH.
3. Verify: `butler version`.

> Source: https://itch.io/docs/butler/installing.html

The zip contains `butler.exe` plus two 7-zip DLLs; the DLLs are optional for
`push` but harmless to keep.

## Authentication

Run `butler login` once — it opens a browser flow and saves credentials
locally. For CI, set `BUTLER_API_KEY`; the key has source `wharf` and lives at:
- Windows: `%USERPROFILE%\.config\itch\butler_creds`
- also on the [API keys page](https://itch.io/user/settings/api-keys)

> Source: https://itch.io/docs/butler/login.html

## Push

```
butler push directory user/game:channel [--userversion X] [--if-changed]
```

- `user/game` is all lower-case, e.g. `baby-came-home/chum-demo`.
- Channel names drive tags: `windows`, `linux`, `mac`/`osx`, `android`;
  kebab-case convention. `windows` tags the build as a Windows executable.
- `--userversion X`: tag the build with your own version string (otherwise the
  backend increments an integer). `--userversion-file` reads it from a file.
- `--if-changed`: skip the push if the local files are byte-identical to the
  latest build (useful to avoid no-op patches).
- `push-preview` (without a build being created) shows what *would* change.
- `--hidden` hides a new channel's first push; pushing `--hidden` to an
  existing channel is an error.
- Backend rejects builds over 30 GB uncompressed.
- Recommended: push a folder that is *exactly* the release build (no `*.pdb`,
  no debug wrappers). `--ignore 'pattern'` exists as a fallback.

> Source: https://itch.io/docs/butler/pushing.html

## Patch model

Push is patch-based: the first push is a patch from the empty container;
subsequent pushes diff against the previous build (rsync-style blocks locally,
`bsdiff` + high-quality Brotli regenerated on the backend). Changed pushes can
save 80–95% of transfer size.

## This project's usage

`scripts/deploy-to-itch.ps1`:
- Version = `git describe --tags --always --dirty`, falling back to
  `PRODUCT_VERSION` from `eos_credentials.cfg`.
- Exports the `Windows Desktop` release preset to a clean staging dir
  (`build/itch/windows/`) so only release files are pushed.
- Pushes to `baby-came-home/chum-demo:windows` with `--userversion`.

`build/` and `eos_credentials.cfg` are gitignored; the butler API key lives
outside the repo in `%USERPROFILE%\.config\itch\butler_creds`.
