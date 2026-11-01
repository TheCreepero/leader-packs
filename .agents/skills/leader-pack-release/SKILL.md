---
name: leader-pack-release
description: >-
  Use when publishing one Leader Packs country pack to the Steam Workshop as "Commanders Pack: <Country>":
  a first upload, an update or a Workshop description change. Extends the shared hoi4-mod-release skill with
  the per-pack preflight, the thumbnail with the country's flag, the photo credits on the wiki, the generated
  Workshop description and its AI-assisted portrait disclosure.
disable-model-invocation: true
---

# Leader Pack: release a pack

Each pack is its own Workshop item. Follow the shared `hoi4-mod-release` skill, section "Repos with packages", with these additions. Every command names the pack: `-Pack <pack>`.

## 1. Preflight
1. The pack's last plan is `DONE` and shipped (archived and committed), and its game check is recorded in the plan's "Outcome" (`leader-pack-implement` section 4). A pack without a game check waits for one, on the owner's word.
2. `powershell -NoProfile -File "<Manager root>\Scripts\Publish-Mod.ps1" "Leader Packs" -Pack <pack> -PreflightOnly`. Done when no row is FAIL.
3. `powershell -File .\build.ps1 -Audit -Pack <pack>`: no `[ERROR]`. A `[WARN]` that a photo's licence was last read over 180 days ago: fetch it again for real, `powershell -File .\build.ps1 -FetchPhoto -Pack <pack> -File "<its Commons title>" -Key <its key>`, then `-Check -Pack <pack>`, and commit before the release; a `REJECTED` stops the release and goes to `leader-pack-audit`.
4. The snapshot is current: `data/<pack>/game-characters.json` was refreshed after the last Road to 56 update the owner installed (its `refreshed` date). If not, run `leader-pack-audit` Phase 1 first [RT56-011].
5. `Test-HoiKnowledge.ps1 -Repo leader-packs -Detailed` (the `hoi4-modding-knowledge` skill): the sweep queue is empty.

## 2. Thumbnail
A pack whose `packs/<pack>/thumbnail.png` still has the hash of `assets/thumbnail_master.png` (`Get-FileHash`) gets its own thumbnail before its first upload; a pack that has one keeps it unless the owner asks.

1. Use the `mod-thumbnail-generator` skill, title `COMMANDERS PACK`, subtitle the country in capitals, with the country's flag (`--flag-tag <TAG>`) below the subtitle.
2. As Event Packs does with its event pictures, the background is the pack's own image: one of its chosen portraits, `source/<pack>/portraits/<key>.png`, never a vanilla loading screen or portrait: no vanilla image is uploaded. Prefer the pack's best-known leader, and a portrait painted from a public-domain or CC0 photo. The portrait is tall, so crop `top` or `center` to keep the face.
3. The flag and the colours as Event Packs does it: the flag variant is the ruling party's ideology that `Get-HoiCountryHistory -Tag <TAG> -Section politics` prints (`hoi4-vanilla-lookup`), the game root the one `Get-HoiGameInfo` prints; the main colour is the colour the flag is known by, read from the flag file the generator names as `overlay_source`, never white; the text colour is white, or black on a light main colour.
4. Write to `--out-dirs "scratch\thumbnail\<pack>"`; the JSON must say `"status": "success"` and `"workshop_limit_exceeded": false`. Show the owner the image; on their word, copy it with `Copy-Item scratch\thumbnail\<pack>\thumbnail.png packs\<pack>\thumbnail.png` as a statement of its own (a hook refuses any other shell write into `packs/`).
5. `powershell -File .\build.ps1 -ValidateOnly` ends `Validation succeeded.`, then commit the thumbnail on the owner's word.

## 3. Change note, credits and description
1. The change note names the leaders added or changed, by name, and any leader set to `skip` with the reason.
2. The photo credits are on the pack's wiki page (`wiki/Commanders-Pack-<Country>.md`, generated), which the Workshop description links to: run `powershell -File .\wiki\push-wiki.ps1` before the upload, so the page is live and complete.
3. The description on Steam is the generated `packs/<pack>/WORKSHOP_DESCRIPTION_GUIDELINES.md`. Check that it holds the sentence that the portraits are AI-assisted repaints of period photographs, with the wiki link: that disclosure is never removed or shortened. A first upload, or a description changed since the pack's last tag (`git diff workshop-<pack>-<date>..HEAD --stat -- packs/<pack>/WORKSHOP_DESCRIPTION_GUIDELINES.md`), takes `-UpdateDescription`.

## 4. Upload and tag
1. `Publish-Mod.ps1 "Leader Packs" -Pack <pack> -DryRun -ChangeNote "<note>"`: show the owner the VDF (title `Commanders Pack: <Country>`) and the file list (only that pack's `common`, `interface`, `gfx` and `localisation`, its descriptor and thumbnail).
2. Give the owner the upload command for their own terminal: `powershell -NoProfile -File "<Manager root>\Scripts\Publish-Mod.ps1" "Leader Packs" -Pack <pack> -ChangeNote "<note>"`, with `-UpdateDescription` per step 3.3.
3. A first upload writes the new id into `packs/<pack>/descriptor.mod`: ask the owner to commit it. The command tags `workshop-<pack>-<date>`; pushing the tag is the owner's call.
