---
name: leader-pack-audit
description: >-
  Use when auditing an existing Leader Packs country pack, before a release or after a Road to 56 or game
  update: the licence recheck of every photo, a fresh game-data snapshot checked for duplicates and renamed
  ids, a recheck of the facts behind each leader's role and stats, the Workshop intro against the page standard,
  and a report by severity for the owner's approval. The approved fixes become a READY plan for leader-pack-implement.
---

# Leader Pack: audit a pack

Finds what an existing pack needs: photos whose licence changed or that left their source, leaders that a game or Road to 56 update now duplicates or whose ids moved, facts that no longer hold, stats and traits that no longer fit the stat guide. It writes a report, waits for the owner, then plans only the approved fixes.

## Rules
- The audit changes nothing in `source/` or `packs/`. Fixes reach the pack only through a plan and `leader-pack-implement`. The one exception is the snapshot under `data/<pack>/`, which `-RefreshGameData` writes in Phase 1.
- A photo outside the licence policy or gone from its source, a manual photo whose quoted rights sentence is gone from the archive's page, and a manual photo the owner has not confirmed are always Critical: a pack must not ship a portrait painted from it.
- A person who now appears twice (a `new` leader the snapshot has as a unit leader, or a `sameAs` id that moved) is always Critical.
- Character ids and the prefix never change in a fix: saves made with the pack refer to them [CHR-016]. A leader who must go becomes `skip` in a fix plan, with the reason.
- Ask the owner only in Phase 3.

## Phase 0: licences
1. `powershell -File .\build.ps1 -Audit -Pack <pack>`: the table of leaders (mode, role, character, skills, traits, photo licence, portrait), every licence read again from its source (Commons, Finna or Europeana; for a manual photo, the quoted rights sentence looked up again on the archive's page), and every `[ERROR]` and `[WARN]`. A `[WARN]` that a licence was last read over 180 days ago is fixed at release by fetching the photo again.
2. For each photo whose licence the audit reports changed or unreadable, dry-run its fetch with the command of its `source` in `photos.json` (`docs/source-format.md`, "Photo sources"): `-File "<its commonsTitle>"`, `-Source <source> -Id "<its sourceId>"`, or for a manual photo a fresh evidence file from its `evidence` block. `REJECTED` is Critical.
3. `powershell -File ..\..\Scripts\Workshop\Test-WorkshopText.ps1 -Mod "Leader Packs" -Pack <pack>`: the Workshop page as a whole (wording, page order, shared lines, images, regions). A line it reports for a published pack is Important.
4. The bundle: the pack is a member of the package `all` (`members` in `tools/HoiModBuild.json`), and `powershell -File .\build.ps1 -Check -Pack all` ends `Check OK`: the bundle page names the pack in its country list with the pack's commander count, its portraits paragraph covers the pack's photo licences, its intro `source/all/workshop-intro.bbcode` names the pack, and the bundle's `supported_version` equals the pack's. A pack that is not a member, or a bundle page that lacks the pack, is Important (Critical when the pack is released and the bundle is published).

## Phase 1: snapshot
1. `powershell -File .\build.ps1 -RefreshGameData -Pack <pack>` (needs the game and the Road to 56 files). `git diff --stat data/<pack>/` shows whether the game or Road to 56 moved.
2. `powershell -File .\build.ps1 -Check -Pack <pack>`: on the fresh snapshot, an error that a `new` leader's name or `sameAs` id is now a unit leader, that a `sameAs` or `target` id is gone, or that an `addRole` target gained a unit-leader role, is Critical [RT56-011]. A trait gone from `start-traits.json` is Important, and so is a warning that Road to 56 no longer defines a chosen trait [CHR-017].
3. Read the `git diff` of `game-characters.json` for persons the pack has under another spelling (for each leader, `powershell -File .\build.ps1 -ListCharacters -Pack <pack> -Name <surname>,<other spelling>` lists every id he has in both sets): a new id for one of them belongs in his `sameAs` [SCR-035].

## Phase 2: facts
1. Dispatch `lp-audit-researcher` with the fact-sheet sections of the pack's leaders (pasted from `source/<pack>/fact-sheets.md`) and one row per photo from `source/<pack>/photos.json` (key, source, title, page URL, licence, author).
2. For each photo it marks `RECHECK`, run the `-FetchPhoto ... -DryRun` of Phase 0: `REJECTED` is Critical.
3. For each fact it marks `FIX` or `DROP`, judge the stats and traits that rest on it against `docs/stat-guide.md`: a stat or trait left without a fact is Important.
4. Dispatch `workshop-editor` in mod mode (the Modding Manager's `docs/workshop-text-style.md` (`..\..\docs\workshop-text-style.md`), section "Auditing a page") with the mod folder (the repository root) and `source/<pack>/workshop-intro.bbcode` as the text, so that the intro is judged against `source/<pack>/leaders.json` and `photos.json`: the number of leaders, the portraits licence sentence (it is never removed or shortened), a claim the files do not show, a wording that differs from the other packs' intros. Every REWRITE or REJECT is Important.

## Phase 3: report
Write the report into a new plan, `docs/plans/<YYYY-MM-DD>-<pack>-audit.md` from `docs/plans/TEMPLATE-pack.md` with `Kind: audit fixes`, under an `## Audit report` heading placed after "Context":
- **Critical**: failing checks, photos outside the policy or gone from their source, manual licences that lost their quote or were never confirmed, persons who now appear twice.
- **Important**: facts to `FIX` or `DROP` with the stats or traits they carried, ids to add to `sameAs`, traits gone from the start traits, editor rewrites and rejects of the Workshop intro.
- **Minor**: warnings, licence reads due for renewal, wording.
- **Intentionally unchanged**: what was considered and is fine.

Show the owner the report and stop until they say which fixes to make. Record their answer in "Decisions".

## Phase 4: plan the fixes
1. Build the plan's `json leaders` block from the current `source/<pack>/leaders.json` with only the approved fixes; corrected facts go into the `markdown fact-sheets` block with their sources.
2. A replaced photo follows Phase 3 of `leader-pack-create`, and its leader goes through the review loop of Phase 4 there until the owner picks a new portrait.
3. Changed stats or traits follow Phase 5 of `leader-pack-create`.
4. A fix of the Workshop intro is a plan step that edits `source/<pack>/workshop-intro.bbcode` (never the generated `packs/<pack>/WORKSHOP_DESCRIPTION_GUIDELINES.md`) and runs `-Generate`, then `Sync-WorkshopRegions.ps1` and the `Test-WorkshopText.ps1` check run again; the changed intro goes through `workshop-editor` until KEEP, as in `leader-pack-create` Phase 6. A third round that is not KEEP goes into the report, not into a question.
5. A fix that adds the pack to the bundle is a plan step: `build.ps1 -NewPack` does it for a new pack, and for an existing one the plan adds the name to the `members` of the package `all` in `tools/HoiModBuild.json` (an owner-approved edit of that file) and runs `-Generate -Pack all`.
6. Gate as in `leader-pack-create` Phase 6 (the rehearsal runs no `-Test`; the implementation review gets the `-Test` line of the verify in `leader-pack-implement`), set `Status: READY`, and hand off to `leader-pack-implement`. A re-review continues the same reviewer with `SendMessage` and its agent id, never a fresh dispatch.
