---
name: leader-pack-release
description: >-
  Use when publishing one Leader Packs country pack to the Steam Workshop as "Commanders Pack: <Country>":
  a first upload, an update or a Workshop description change. Extends the shared hoi4-mod-release skill with
  the per-pack preflight, the thumbnail with the country's flag and a row of the pack's portraits over the
  shared background, the photo credits on the wiki, the generated Workshop description and its
  portrait licence statement.
disable-model-invocation: true
---

# Leader Pack: release a pack

Each pack is its own Workshop item. Follow the shared `hoi4-mod-release` skill, section "Repos with packages", with these additions. Every command names the pack: `-Pack <pack>`.

## 1. Preflight
1. The pack's last plan is `DONE` and shipped (archived and committed), and its game check is recorded in the plan's "Outcome" (`leader-pack-implement` section 4). A pack without a game check waits for one, on the owner's word.
2. `powershell -NoProfile -File "<Manager root>\Scripts\Publish-Mod.ps1" "Leader Packs" -Pack <pack> -PreflightOnly`. Done when no row is FAIL.
3. `powershell -File .\build.ps1 -Audit -Pack <pack>`: no `[ERROR]`. A `[WARN]` that a photo's licence was last read over 180 days ago: fetch it again for real with the command of its `source` (`-File "<its commonsTitle>"`, or `-Source <source> -Id "<its sourceId>"`; `docs/source-format.md`, "Photo sources") and `-Key <its key>`, then `-Check -Pack <pack>`, and commit before the release; a `REJECTED` stops the release and goes to `leader-pack-audit`. A manual photo is not fetched again here: the audit has just looked up its quote on the archive's page, and an `[ERROR]` that the owner has not confirmed it stops the release. A `[WARN]` that a used photo's source or archive page could not be read means its licence was not read again: run the audit again later, and do not release until it reads.
4. The snapshot is current: `data/<pack>/game-characters.json` was refreshed after the last Road to 56 update the owner installed (its `refreshed` date). If not, run `leader-pack-audit` Phase 1 first [RT56-011].
5. `Test-HoiKnowledge.ps1 -Repo leader-packs -Detailed` (the `hoi4-modding-knowledge` skill): the sweep queue is empty.

## 2. Thumbnail
A pack with fewer than 2 portrait paths under `packs.<pack>.portraits` of `assets/thumbnail.json` (its `-NewPack` thumbnail shows the flag only, or the plain `assets/thumbnail_master.png` when the Manager was not found) gets its own thumbnail before its first upload; with fewer than 2 chosen portraits the release stops and the owner is told. A pack that has its portraits keeps its thumbnail unless the owner asks, or a leader it shows has had a new portrait picked since: a recorded `source/<pack>/portraits/<key>.png` whose last commit (`git log -1 --format=%cI -- <file>`) is newer than that of `packs/<pack>/thumbnail.png`.

Every pack's thumbnail is drawn by the Manager's `New-HoiThumbnail.ps1` (skill `hoi4-workshop-showcase`) in the one Commanders Pack layout: `COMMANDERS PACK` in the plate at the bottom with the country under it, the flag at the top right, the pack's portraits in a row, over the shared loading screen of `assets/thumbnail.json`. The tool fixes the layout, the colours and the flag; a pack chooses only its portraits.

1. The portraits: the paths under `packs.<pack>.portraits` of `assets/thumbnail.json`. A pack without them: propose its 3 best-known leaders with a chosen portrait (2 when it has only 2), in the order they are to stand left to right, and on the owner's word, which may swap them, write them there as `source/<pack>/portraits/<key>.png`, in that order.
2. Preview: `powershell -NoProfile -File "<Manager root>\Scripts\Showcase\New-HoiThumbnail.ps1" "Leader Packs" -Pack <pack>`. Its line ends with `new`, `changed` or `unchanged` against the committed file and the preview's path under the Manager's `Artifacts\thumbnails\leader-packs\<pack>\`; a `Warning:` line is fixed in the data, not accepted. Look at the preview with the Read tool, then show it to the owner.
3. On the owner's word, run the same command with `-Apply`: it writes `packs/<pack>/thumbnail.png`. The loading screen, the flag and the game's frames, plates and fonts it draws are read from the game install at render time and ship only inside that file. Never copy, convert or save any of them anywhere else; the gallery images of section 2b stay git-ignored under `artifacts/`.
4. `powershell -File .\build.ps1 -ValidateOnly` ends `Validation succeeded.`, then commit the thumbnail, and `assets/thumbnail.json` when its portraits are new, on the owner's word.

## 2b. Gallery images
1. Every leader the release adds has card lines in `source/<pack>/showcase.json` (`docs/source-format.md`). A leader without them: propose 3 or 4 lines and the years from his fact-sheet section, and write them only on the owner's word.
2. `powershell -File .\build.ps1 -RenderShowcase -Pack <pack>` writes the roster and one card per leader to `artifacts/workshop-images/<pack>/`. A `Warning:` line (a text cut short, a missing sprite or flag) is fixed in the data, not accepted. Look at every image, then show them to the owner.
3. After the upload of section 4, the owner adds or replaces them on the pack's Workshop page ("Add/edit images & videos"); the upload carries only the thumbnail.

## 3. Change note, credits and description
1. The change note names the leaders added or changed, by name, and any leader set to `skip` with the reason.
2. The photo credits are on the pack's wiki page (`wiki/Commanders-Pack-<Country>.md`, generated), which the Workshop description does not link to (it carries no Wiki or GitHub links): run `powershell -File .\wiki\push-wiki.ps1` before the upload, so the page is live and complete.
3. The description on Steam is the generated `packs/<pack>/WORKSHOP_DESCRIPTION_GUIDELINES.md`. Check that it holds the sentence that the portraits are repaints of period photographs under the photos' licences: that licence statement is never removed or shortened, and no sentence about how the portraits were made beyond it is added. When the Event Packs repository (`../event-packs/packs/<country>/descriptor.mod`) has a published pack for the same country (`remote_file_id` set), check that the description links it right after the opening sentences as a `[h2]Companion mod: ...[/h2]` line, with the name and id of that descriptor; a missing or stale link is added to `source/<pack>/workshop-intro.bbcode` and the pack generated again (`-Generate -Pack <pack>`, then `-Check -Pack <pack>`). A first upload, or a description changed since the pack's last tag (`git diff workshop-<pack>-<date>..HEAD --stat -- packs/<pack>/WORKSHOP_DESCRIPTION_GUIDELINES.md`), takes `-UpdateDescription`.

## 4. Upload and tag
1. `Publish-Mod.ps1 "Leader Packs" -Pack <pack> -DryRun -ChangeNote "<note>"`: show the owner the VDF (title `Commanders Pack: <Country>`) and the file list (only that pack's `common`, `interface`, `gfx` and `localisation`, its descriptor and thumbnail).
2. Give the owner the upload command for their own terminal: `powershell -NoProfile -File "<Manager root>\Scripts\Publish-Mod.ps1" "Leader Packs" -Pack <pack> -ChangeNote "<note>"`, with `-UpdateDescription` per step 3.3.
3. A first upload writes the new id into `packs/<pack>/descriptor.mod`: ask the owner to commit it. The command tags `workshop-<pack>-<date>`; pushing the tag is the owner's call.
