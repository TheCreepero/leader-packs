# <Country> pack: <what this plan adds>

Status: PLANNING
Pack: <pack> (<TAG>, prefix lp_<tag>)
Kind: new pack | new leaders | audit fixes
Created: <YYYY-MM-DD>
Snapshot: data/<pack>/game-characters.json refreshed <YYYY-MM-DD>
Dossiers: research/<pack>/<YYYY-MM-DD>-dossier.md
Review page: <url recorded in source/<pack>/review.json>

## For the implementer

Carry out "Implementation steps" in order with `.claude/agents/lp-implementer.md`. Everything the steps write is in this file: the `json leaders` block is the whole `source/<pack>/leaders.json`, and the `markdown fact-sheets` block holds the sections for `source/<pack>/fact-sheets.md`. The photos, the portrait rounds and the owner's picks were recorded while planning (`photos.json`, `portraits.json`, `portraits/`); do not touch them. Decide nothing; stop and report when something does not fit.

## Context

<Why this plan exists: a new pack, leaders added to a pack, or the fixes an audit approved. Which skill wrote it.>

## Decisions

<The owner's answers: the number of leaders, the mix of generals and admirals, anything left out, the roster chosen from the dossier, leaders dropped for want of a photo, with the date.>

## Leaders

One row per leader of the pack, `skip` leaders included. Stats are `skill` then the attribute skills of the role kind (army: attack/defense/planning/logistics; navy: attack/defense/maneuvering/coordination).

| Key | Name | Mode | Ids (target; sameAs) | Role | Stats | Traits | Photo | Portrait (round, pick) | Status |
|---|---|---|---|---|---|---|---|---|---|

Status per leader: `roster`, `photo`, `portrait open`, `portrait picked`, `stats set`, `ready`, or `skip`.

## Stat notes

<One line per new or addRole leader: the facts behind his role, skill, highest attribute and each trait, by `docs/stat-guide.md`.>

## Photos

Every row printed `ACCEPTED` from `build.ps1 -FetchPhoto` while planning; the licence column is what it printed. A `manual` row also names the date the owner confirmed it with `-ConfirmLicence`.

| Photo key | Source and id | Licence (author or credit) | Size | Leader |
|---|---|---|---|---|

## Review rounds

One line per leader and round: the round, its seeds, the owner's decision (pick `<seed>`, or reject with the reason as written), and for a rejection the `portrait` fields or the photo changed for the next round.

| Leader | Round | Seeds | Decision | Change for the next round |
|---|---|---|---|---|

## Review

<The lp-reviewer verdicts per round (plan review), the findings and what the planner did with each.>

## Kept on judgment

<Each `[WARN]` line of `build.ps1 -Check` that stays, with the reason. The implementer stops on any other warning.>

## READY criteria

- [ ] Every `new` and `addRole` leader has a fact-sheet section in the block below, with a source for each fact his role, stats and traits rest on.
- [ ] Every `new` and `addRole` leader has a photo that printed `ACCEPTED` and is recorded in `photos.json`.
- [ ] Every `new` and `addRole` leader has a portrait the owner picked, recorded as `chosen` in `portraits.json`.
- [ ] Every `new` and `addRole` leader has a role, stats and traits by `docs/stat-guide.md`, with a "Stat notes" line.
- [ ] Every `skip` leader has a reason that names the covering id.
- [ ] Every `new` and `addRole` leader has card lines and years in the `json showcase` block, each line restating a sourced fact-sheet bullet, approved by the owner.
- [ ] `build.ps1 -RehearsePlan` gave what each step expects, and no plan table row differs from the source files.
- [ ] `lp-reviewer` returned ready on the plan.

## Implementation steps

- [ ] 1. Write the source: `powershell -File .\build.ps1 -ApplyPlan -Plan docs\plans\<this plan's file name>`. It replaces `source/<pack>/leaders.json` with the `json leaders` block below, whole; replaces each section of the `markdown fact-sheets` block in `source/<pack>/fact-sheets.md` (a new key is added, the other sections stay); and replaces each entry of the `json showcase` block in `source/<pack>/showcase.json` (the file is created when the pack has none). Expect one line per file and `Plan applied to pack '<pack>'`; a block that does not parse gives exit 1, names the block and writes nothing.
- [ ] 2. `powershell -File .\build.ps1 -Generate -Pack <pack>`: expect `Generated pack '<pack>'` and, when the bundle page changed (a new pack, or a leader count or licence that changed), a `Bundle 'all'` line that wrote `packs/all/WORKSHOP_DESCRIPTION_GUIDELINES.md`. A new pack: `-NewPack` has put it in the `members` of the bundle `all`; the plan also edits `source/all/workshop-intro.bbcode` so that it names the new country.
- [ ] 3. `powershell -File .\build.ps1 -ConvertPortraits -Pack <pack>`: expect `Pack '<pack>': <n> portrait file(s) converted, <m> up to date.` and exit 0.
- [ ] 4. `powershell -File .\build.ps1 -Check -Pack <pack>`: expect `Check OK`, with no warning outside "Kept on judgment", and `Bundle 'all'` with 0 errors (the bundle that holds the pack is checked with it).
- [ ] 5. `powershell -File .\build.ps1 -ValidateOnly` then `powershell -File .\build.ps1 -Test`: expect `Validation succeeded.` and no failed test.
- [ ] 6. Game check (after the owner says to start the game): `powershell -File .\build.ps1 -DevLink -Pack <pack>` (or `-DevLink -Pack all` to see the pack inside the bundle; the bundle and a single pack of the same release load together without a duplicate [LOAD-022]), then the owner's check of `leader-pack-implement` section 4; the result goes into "Outcome".
- [ ] 7. Ship (after the owner confirms): move this plan to `docs/plans/archive/`, commit with the message `feat(<pack>): <summary>`, then `powershell -File .\wiki\push-wiki.ps1`. Publishing is separate: `leader-pack-release` uploads the pack and, in the same `Publish-Mod.ps1` run, the bundle.

## Stop conditions

- A `new` or `addRole` leader in the `json leaders` block has no pick in "Leaders": stop; the planner runs the review loop.
- `-Generate`, `-ConvertPortraits` or `-Check` prints an `[ERROR]`: stop and report it whole.

## Outcome

<Filled by the implementer: date, the `-Check` and `-Test` summary lines, deviations. Then the game check: what the owner saw, and the `error.log` lines naming `lp_<tag>` files.>

## Fact sheets

```markdown fact-sheets
## <key>

- <fact>. Source: <URL> (<page title>)
```

## Showcase cards

The owner's approved Workshop card lines (`docs/source-format.md`, `source/<pack>/showcase.json`): 3 or 4 lines per leader, each restating a bullet of his fact-sheet section above, and his years.

```json showcase
{
    "leaders": {
        "<key>": {
            "card": ["<line>", "<line>", "<line>"],
            "years": [1890, 1960]
        }
    }
}
```

## Leaders source

```json leaders
{
    "pack": "<pack>",
    "tag": "<TAG>",
    "prefix": "lp_<tag>",
    "displayName": "<Country>",
    "leaders": []
}
```
