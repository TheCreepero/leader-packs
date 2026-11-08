# Leader Packs - Agent Rules

Shared rules for every mod in this tree (file encodings, build commands, engine knowledge, git) are in the Modding Manager's `../../AGENTS.md`. `CLAUDE.md` and `GEMINI.md` import this file.

## What this mod is
- Historical generals, field marshals and admirals that the game leaves out, one pack per country, each published as its own Steam Workshop item "Commanders Pack: <Country>", and all packs together as one bundle item "Immersive Commanders Expanded". Every portrait is painted from a real period photograph by the Manager's local ComfyUI recipe (skill `hoi4-leader-portraits`) and picked by the owner.
- One repository, many packs: `tools/HoiModBuild.json` lists them under `packages`, and every pack action takes `-Pack <pack>`. `packs/<pack>/` is a complete mod root (descriptor, thumbnail, generated content) and stands alone: no pack requires or names another (the bundle holds them all, and a pack's own files do not name it).
- One more Workshop item, the bundle "Immersive Commanders Expanded", holds every pack: package `all` in `tools/HoiModBuild.json` with a `members` list. `packs/all/` has only `descriptor.mod`, `thumbnail.png` and the generated `WORKSHOP_DESCRIPTION_GUIDELINES.md`; its content comes from the members at build time (nothing is committed twice), and `source/all/workshop-intro.bbcode` is its one hand-written file. A pack upload through `Publish-Mod.ps1` also uploads the bundle in the same run (the Manager's `hoi4-mod-release` skill, "A pack that belongs to a bundle"). The lifecycle switches (`-Deploy`, `-Package`, `-DevLink`, `-Clean`, `-PublishSteam`) leave the bundle out unless `-Pack all` names it. The bundle's thumbnail is rendered like a pack's (`New-HoiThumbnail.ps1 -Pack all`).
- Hand-written source in `source/<pack>/` (`leaders.json`, `fact-sheets.md`, `workshop-intro.bbcode`); tool-written records beside it; everything a pack ships except `descriptor.mod` and `thumbnail.png` is generated. Layout, fields and switches: `docs/source-format.md`. `artifacts/`, `scratch/` and `sources-cache/` are git-ignored.
- The historical researcher's dossiers stay in `research/<pack>/`, every candidate with its sourced facts, used or not: a pack's next leaders start from them. Never delete or trim one.

## Mod invariants
- `packs/<pack>/` changes only through `build.ps1 -Generate` and `-ConvertPortraits`, its `thumbnail.png` only through the Manager's `New-HoiThumbnail.ps1 -Apply` in the release skill; `photos.json` only through `-FetchPhoto`; `portraits.json` and `portraits/*.png` only through `-MakePortraits`, `-ApplyPortraitReview` and `-RefinishPortraits -Apply` (the last on the owner's word after its sheet); the snapshots under `data/<pack>/` only through `-RefreshGameData`; `data/portrait-card.json` and `assets/thumbnail.json` only on the owner's word. A hook refuses hand edits of all but `assets/thumbnail.json`, whose portrait paths the release skill writes.
- The prefix `lp_<tag>`, every character id `lp_<tag>_<key>` and every sprite name never change after a release: saves made with a pack refer to them [CHR-016]. A leader who must go becomes `skip`.
- A pack works only in a new game: it recruits from `on_startup` [SCR-077] [CHR-003]. One `error.log` warning per recruitment is expected [CHR-014].
- Nobody appears twice: each leader is `new`, `addRole` or `skip`, decided against the committed snapshot of vanilla and Road to 56; `sameAs` holds every id the person has [RT56-011] [SCR-035]. `addRole` keeps the advisor role and its small card [CHR-013].
- Stats stay within `data/stat-bands.json` [CHR-006] [CHR-012], traits within `data/<pack>/start-traits.json`, both chosen from the fact sheet by `docs/stat-guide.md`.
- Photos are licensed public domain (with its stated reason), CC0, CC BY or CC BY-SA (2.0 or later), and come only through `-FetchPhoto`, which decides the licence with the Manager's shared gate (`tools/HoiImageSources.ps1`, a synced copy). It reads the licence itself from Wikimedia Commons, Finna or Europeana; from an archive's own page, it checks a quoted rights sentence, and the owner confirms the licence with `-ConfirmLicence`, run only on the owner's word. It refuses an "own work" licence on a photo from before 1960. Agents may search anywhere for a photo, but propose only records in these sources. A portrait from a CC BY or CC BY-SA photo is credited as an adaptation on the pack's generated wiki page, and one from a CC BY-SA photo is itself licensed CC BY-SA 4.0; the Workshop descriptions say nothing about how the portraits were made beyond the repaint and licence sentence the generator writes.
- No vanilla image is ever committed, uploaded or shown on a review page: no vanilla portrait, card art or loading screen, nor anything converted from one. Two exceptions, both read from the game install when they are rendered and never kept as files of their own:
  - a pack's Workshop thumbnail, with the loading screen `assets/thumbnail.json` names, the country's flag and its frame, the game's metal window border, loading-screen tip plate, label plate and leader frame, and its Orator and Ubuntu bitmap fonts, committed and uploaded only inside `packs/<pack>/thumbnail.png`;
  - its Workshop gallery images from `-RenderShowcase`, with that loading screen, the flag, the game's interface frames, icons and bitmap fonts, written only to the git-ignored `artifacts/workshop-images/<pack>/` and uploaded by the owner on the Workshop page.

  Style references are read from the game install at run time and kept as numbers only.
- A showcase card line restates a sourced bullet of the leader's fact sheet; `source/<pack>/showcase.json` changes only on the owner's word.
- The owner picks every portrait on the review page; no agent picks or rejects one. The picked PNG is committed, because generation is not reproducible.
- An agent that starts ComfyUI stops it at the end of its run; a ComfyUI the owner opened stays running.
- Every claim behind a leader's role, stats and traits is in his fact-sheet section with a source; the `lp-reviewer` agent passes every plan before it is READY.
- Nothing sits in a pack folder that the source does not account for: `-Check` fails on any other file. The same holds for `packs/all/`: only its descriptor, thumbnail and generated description.
- Every pack is a member of the bundle, and the bundle's `supported_version` equals its members'; `-NewPack` adds a new pack to the members and `-Check` fails for a pack that is not one. `source/all/workshop-intro.bbcode` names every member. `packs/all/WORKSHOP_DESCRIPTION_GUIDELINES.md` is generated (`-Generate`, also when a pack is generated), `packs/all/descriptor.mod` and `source/all/workshop-intro.bbcode` are hand-written.
- The bundle ships only released members and no other member's unreleased change (the release preflight fails on one). A bundle and a pack of it of the same release load together without a duplicate, the shared paths once [LOAD-022]; the Workshop page still asks players to pick one, and a pack of another release beside the bundle has not been checked.
- Work goes plan first: `leader-pack-create` writes a READY plan in `docs/plans/`, `leader-pack-implement` carries it out, the commit waits for the owner.

## Commands beyond build.ps1
- Pack switches: `-NewPack -Pack <pack> -Tag <TAG> -DisplayName "<Country>"`, `-RefreshGameData [-Pack]`, `-FindPhoto -Query "<name>[,<name>...]" [-Source commons,finna,europeana] [-Limit 10]` (several names: a block per name, then a photo column), `-ListCharacters -Pack [-Name <spelling>,<spelling>]` (reads the snapshot: one line per character, `<set> | <id> | <name> | <roles>`; without `-Name` leaves out characters whose only role is `country_leader`; with it, every character whose id or name holds a spelling, diacritics folded; use it instead of parsing `game-characters.json`), `-ApplyPlan -Plan <plan> [-DryRun]` (writes the plan's `json leaders`, `markdown fact-sheets` and `json showcase` blocks into `source/<pack>/`, the pack taken from the plan's header; refuses a plan whose blocks do not parse; `docs/source-format.md`, "Applying a plan"), `-RehearsePlan -Plan <plan>` (applies the plan in a copy under `scratch\`, runs `-Generate`, `-ConvertPortraits`, `-Check` and the RepoData tests there, prints the Leaders, Photos and Review rounds tables from the source files and flags a plan row that differs, and always removes the copy), `-FetchPhoto -Pack -Key <photo key> (-File "File:<title>" | -Source finna|europeana|commons -Id <id> | -Evidence scratch\evidence-<key>.json) [-DryRun]`, `-ConfirmLicence -Pack -Key <photo key>` (owner's word only), `-MakePortraits -Pack [-Leader <key>] [-StartComfyUI]`, `-ReviewPage -Pack [-PageUrl <url>]`, `-ApplyPortraitReview -Pack -Leader <key> (-Pick <seed> | -Reject "<reason>" | -Withdraw "<reason>")` (`-Withdraw` only for a leader who has left `leaders.json`: it deletes his chosen PNG and keeps his rounds), `-RefinishPortraits -Pack [-Leader <key>] [-StartComfyUI] [-Apply]` (the Manager's finish stage on the chosen portraits made before it existed: a before-and-after sheet first, with ComfyUI for the person masks, `-Apply` on the owner's word), `-Generate [-Pack] [-DryRun]`, `-ConvertPortraits [-Pack] [-Force]`, `-PreviewPortraits [-Pack]`, `-Check [-Pack]`, `-Audit -Pack`, `-RenderShowcase [-Pack]`, `-SyncMirrors`. The bundle: `-Generate -Pack all`, `-Check -Pack all`, `-DevLink -Pack all` (a git-ignored `.devlink/` folder of hard links, so the pack and the bundle can be seen together), `-DevLink -CheckLinks -Pack all` (reports links a checkout or pull broke; run `-DevLink -Pack all` again to rebuild), `-ValidateOnly -Pack all`. `Get-Help .\build.ps1` lists the parameters.
- Run the tools; don't read `tools/LeaderPacks.ps1` or `tools/HoiModBuild.ps1` (a read asks the user first). If one seems broken, report the command and its output.
- `-MakePortraits`, `-RefinishPortraits` and the small cards of `-ConvertPortraits` need the Modding Manager and its ComfyUI venv (`Config/comfyui.json`), `-RefinishPortraits` also the game for the style numbers; `-RefreshGameData` needs the game; `-ConvertPortraits`, `-PreviewPortraits` and `-ReviewPage` need Python 3 with Pillow; `-RenderShowcase` needs the Modding Manager (`Scripts/Showcase`, skill `hoi4-workshop-showcase`), the game and Python 3 with Pillow.

## Agents and skills
| Name | Kind | Does |
|---|---|---|
| `leader-pack-create` | skill | Plans a pack or new leaders: snapshot, roster, modes, photos, the portrait review loop, stats; a READY plan |
| `leader-pack-implement` | skill | Carries out a READY plan, verifies it, offers the game check, ships on the owner's word |
| `leader-pack-audit` | skill | Licences, snapshot drift and facts of a released pack; a report, then a fix plan |
| `leader-pack-release` | skill | Thumbnail, credits, description and upload of one pack and its bundle in one run (with the shared `hoi4-mod-release`) |
| `lp-historical-researcher` | agent | Roster dossier of a country's missing commanders, with sourced facts and their ids elsewhere |
| `lp-photo-researcher` | agent | Commons photos per leader, with headwear, uniform and insignia for the portrait fields |
| `lp-portrait-creator` | agent | One round of candidates (`-MakePortraits`) and the review page (`-ReviewPage`); decides nothing |
| `lp-implementer` | agent | Runs a READY plan's steps |
| `lp-reviewer` | agent | Gate for a plan and for an implementation |
| `lp-audit-researcher` | agent | Rechecks a released pack's facts and photo pages |

Skills are edited under `.claude/skills/` only; `build.ps1 -SyncMirrors` (and a hook) copies them to `.agents/skills/`.

## Read when
| Task | Read |
|---|---|
| A new pack or new leaders | skill `leader-pack-create` |
| Checking a released pack | skill `leader-pack-audit` |
| Carrying out a READY plan | skill `leader-pack-implement` |
| Publishing a pack (and its bundle) | skill `leader-pack-release` (and the shared `hoi4-mod-release`) |
| Making or reviewing portraits | skill `leader-pack-create`, Phase 4, and the Manager's `hoi4-leader-portraits` |
| Choosing stats and traits | `docs/stat-guide.md` |
| The source files, the switches and what is generated | `docs/source-format.md` |
| Writing a plan | `docs/plans/TEMPLATE-pack.md` |

## Compacting
Keep: the pack, the plan path and its `Status:`, the current phase or step, the open review round per leader and the review page address, the last `-Check` line. Drop: dossier contents, raw search results, contact sheets, reviewer reports once applied to the plan.

## Engine Knowledge
- Engine facts live in the Modding Manager's register, reached through the user-level `hoi4-modding-knowledge` skill: search it before a new kind of file and before asking for a game launch, cite ids here, never write a fact into this repository.
- Topics this mod leans on: `characters`, `script-language`, `loading-and-overrides`, `localisation`, `gui-sprites-and-fonts`, `mods/rt56`.
- `tests/Knowledge.Tests.ps1` runs the register's audit for this repository; it is a copy the Manager keeps current.
