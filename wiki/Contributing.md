# Contributing to Leader Packs

The packs are built from the sources in the repository by `build.ps1`; nothing under `packs/<pack>/` except `descriptor.mod` is written by hand, and its `thumbnail.png` is rendered from `assets/thumbnail.json` by the Modding Manager's `New-HoiThumbnail.ps1`. `docs/source-format.md` describes the source files and every switch.

## Development Workflow
1. Clone the repository.
2. Run `build.ps1 -DevLink -Pack <pack>` to link one pack directly to your Hearts of Iron IV launcher.
3. Change the sources under `source/<pack>/`, then run `build.ps1 -Generate -Pack <pack>` and `build.ps1 -Check -Pack <pack>`.
4. Execute validation with `build.ps1 -ValidateOnly` and tests with `build.ps1 -Test`.

## Photos and portraits
- Photos come from Wikimedia Commons under public domain, CC0 or CC BY only, fetched with `build.ps1 -FetchPhoto`, which checks the licence.
- Portraits are made from those photos with a local ComfyUI and picked by the maintainer; no image from the game is ever committed.
