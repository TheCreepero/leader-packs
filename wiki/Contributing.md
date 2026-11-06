# Contributing to Leader Packs

The packs are built from the sources in the repository by `build.ps1`; nothing under `packs/<pack>/` except `descriptor.mod` is written by hand, and its `thumbnail.png` is rendered from `assets/thumbnail.json` by the Modding Manager's `New-HoiThumbnail.ps1`. `docs/source-format.md` describes the source files and every switch.

## Development Workflow
1. Clone the repository.
2. Run `build.ps1 -DevLink -Pack <pack>` to link one pack directly to your Hearts of Iron IV launcher.
3. Change the sources under `source/<pack>/`, then run `build.ps1 -Generate -Pack <pack>` and `build.ps1 -Check -Pack <pack>`.
4. Execute validation with `build.ps1 -ValidateOnly` and tests with `build.ps1 -Test`.

## The bundle
- `packs/all/` is the bundle "Immersive Commanders Expanded": only its `descriptor.mod`, `thumbnail.png` and generated Workshop description are files of its own; the build engine adds every member pack's content (`members` in `tools/HoiModBuild.json`). `source/all/workshop-intro.bbcode` is its hand-written intro.
- `build.ps1 -NewPack` adds a new pack to the members; `build.ps1 -Check` fails for a pack that is not one.
- `build.ps1 -DevLink -Pack all` builds the git-ignored `.devlink/` folder of hard links and points the launcher at it; `build.ps1 -DevLink -CheckLinks -Pack all` reports links broken by a checkout, pull, stash or rebase, and running `-DevLink -Pack all` again rebuilds the folder.
- The bundle and a single pack of the same release can be enabled together (the shared files load once, [LOAD-022]); the Workshop page still asks players to pick one. A pack of another release beside the bundle has not been checked.

## Photos and portraits
- Photos come from Wikimedia Commons under public domain, CC0 or CC BY only, fetched with `build.ps1 -FetchPhoto`, which checks the licence.
- Portraits are made from those photos with a local ComfyUI and picked by the maintainer; no image from the game is ever committed.
