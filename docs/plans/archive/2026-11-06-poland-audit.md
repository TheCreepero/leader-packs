# Poland pack: audit fixes

Status: DONE
Pack: poland (POL, prefix lp_pol)
Kind: audit fixes
Created: 2026-11-06
Snapshot: data/poland/game-characters.json refreshed 2026-11-06
Dossiers: research/poland/2026-11-06-dossier.md
Review page: https://claude.ai/artifact/BaSBMpQQiXYTajdYY9VJQW

## For the implementer

Carry out "Implementation steps" in order with `.claude/agents/lp-implementer.md`. Everything the steps write is in this file: the `json leaders` block is the whole `source/poland/leaders.json` (it equals the current file), the `markdown fact-sheets` block holds the three sections for `source/poland/fact-sheets.md`, and the `json showcase` block holds the two card entries for `source/poland/showcase.json`. The photos, the portrait rounds and the owner's picks were recorded while planning (`photos.json`, `portraits.json`, `portraits/`); do not touch them. Decide nothing; stop and report when something does not fit.

## Context

Audit of the released pack "Commanders Pack: Poland" (4 generals, first release in commit 3d4e0b9), run on 2026-11-06 by the `leader-pack-audit` skill, the same day the pack was built. It rechecked the photo licences, refreshed the game and Road to 56 snapshot, rechecked every fact behind the four leaders against its source, and had the Workshop intro judged by `workshop-editor`. Nothing in `source/` or `packs/` was changed by the audit itself; this plan carries out the fixes the owner approved. The two Minor sourcing slips the first plan's implementation review left open (Duch's start year 1942 and Okulicki's years 1941-1942) are settled here.

## Audit report

Commands run: `-Audit -Pack poland` (0 errors, 4 warnings), `Test-WorkshopText.ps1 -Mod "Leader Packs" -Pack poland` (no problem found), `-RefreshGameData -Pack poland` then `git diff --stat data/poland/` (no change at all: the game and Road to 56 have not moved), `-Check -Pack poland` (Check OK, the same 4 warnings), `-FetchPhoto ... -DryRun` for the two photos the researcher marked RECHECK (both `ACCEPTED`), `lp-audit-researcher` (facts and photo pages), `workshop-editor` in mod mode (intro).

### Critical

None.

- Every photo in use still reads PD on Commons, and the dry-run fetches of `boleslaw_duch` and `leopold_okulicki` print `ACCEPTED`. No licence changed, none left its source.
- No person appears twice: the fresh snapshot (63 vanilla, 169 Road to 56 characters of POL) holds none of Rowecki, Chruściel, Duch or Okulicki under any spelling or nickname (Grot, Monter, Kobra searched too); no `sameAs` to add.

### Important

1. **Fact to FIX (Rowecki, fact 3), `stefan_rowecki`.** The Polish Wikipedia article on the Warsaw Armoured-Motorized Brigade gives no "10 June to 20 September" command span: Rowecki was offered the post on 10 June, accepted on 12 June, was formally appointed around 20 June, and the article gives only the brigade's dissolution on 20 September. It also does not call 17-20 September "its last battle": it names the first Battle of Tomaszow, and says that on 20 September the heavy equipment was ordered destroyed and the units broke out on their own.
   - Stats resting on it: `attack 2` (13 September attack toward Annopol, still sourced) and `defense 2` (fought at Tomaszow Lubelski, encircled). Both stay supported; no stat or trait changes. The showcase card line stays true.
2. **Fact to FIX (name order), `boleslaw_duch`.** The fact sheet said "Boleslaw Bronislaw Duch". The order is disputed: English and Polish Wikipedia title him "Bolesław Bronisław Duch"; the Commons record of his photograph gives, in its source field, the title of the 2010 biography by Stanisław Kamiński as "Generał dywizji Bronisław Bolesław Duch (1896-1980)". (The audit first reported that Polish Exiles of WW2 also uses "Bronisław Bolesław"; the plan review found that page names him "Bronisław Duch" only, so the order rests on one biography against two encyclopedias.) No stat, trait or card line is affected. The in-game name `Boleslaw Duch` follows English Wikipedia and is not changed by this plan (see "Intentionally unchanged"); Polish sources call him "Bronisław Duch".
3. **Years the sources do not give (card lines change only on the owner's word).**
   - `leopold_okulicki`: fact 3 and the card line said "1941-1942". The English Wikipedia page gives no years for either post, and the Commons caption of his photograph dates the 7th Division command to 1943. `skill 2` and `planning 3` rest on the two posts, not on the years.
   - `boleslaw_duch`: fact 4 and the card line said "1942" as the start of his command of the 1st Rifle Brigade. The cited source page (Polish Exiles of WW2) gives no start year; English Wikipedia does, but it is not the source of that bullet. `infantry_officer` rests on the regiment, the brigade and the division commands, not on the year.
4. **Photo licence basis, weak for three of the four photos in use (an owner decision, not a gate failure).** The shared gate prints `ACCEPTED` for all of them and Commons still says PD, but the "PD-Polish" reason covers photographs first published before 23 May 1994, and the Commons pages show a first publication for only one photo: `stefan_rowecki` (1934 regimental album) is sound; `antoni_chrusciel` (Central Military Archive copy, "before 1931"), `boleslaw_duch` (a 2010 biography) and `leopold_okulicki` (the 1943 photograph, credited to a 1991 book) show none. The researcher's reading that the 1991 book could be the Okulicki photo's first publication, which would leave an anonymous-work term unexpired, is its legal reasoning and was not confirmed.

### Minor

- Four `-Check` warnings, all "no leader uses this photo" (`antoni_szylling`, `_2`, `_3`, `leopold_okulicki_2`): unchanged since the release plan's "Kept on judgment" (`photos.json` is written only by `-FetchPhoto`).
- The Poland page's cross-link block is empty (Finland and France already link "Event Pack: Poland"): run `Sync-WorkshopCrossLinks.ps1` for Poland at the next release step. The `overview` region has no image address yet, which is allowed (the page reads as text).
- Chruściel facts "17:00 on 1 August 1944" and "promoted 14 September 1944": the source says "the following day" and gives no year in the promotion sentence; both are correct by context. Kept.
- The English Wikipedia infobox gives Duch's birth year as 1885; its text, the exile site and the Commons title say 1896. The fact sheet is right.
- Rowecki's death: the sources differ on the day (2-7 August 1944) and say the circumstances are not fully documented; the fact sheet says "murdered in Sachsenhausen in August 1944", which holds.
- Licence reads are dated 2026-11-06, so none is due for renewal.

### Intentionally unchanged

- Snapshot, ids, modes (all four `new`, `sameAs: []`), prefix `lp_pol`, character ids.
- Roles, skills, attributes and traits of all four: every one rests on a fact the researcher kept, and every value still sits inside `data/stat-bands.json` with no attribute above 4 [CHR-006] [CHR-012]. `Check OK` on the fresh snapshot, and no chosen trait is among the one start trait Road to 56 does not define [CHR-017].
- Every other fact the researcher checked: KEEP.
- The Workshop intro: `workshop-editor` returned KEEP on all three paragraphs (leader count not stated, AI-assisted sentence in full, wording equal to Finland's minus "and admirals", companion link and id confirmed). No rewrite.
- The in-game display name `Boleslaw Duch` (English Wikipedia's order, `leaders.json`): the owner approved only the fact-sheet fix; changing the display name is a separate decision the owner has not made. The key, character id and sprite names never change in any case.
- Photos and portraits: untouched (see Decisions, 4).

## Decisions

- 2026-11-06, owner: Important 1 (Rowecki fact 3): fix.
- 2026-11-06, owner: Important 2 (Duch name order): fix.
- 2026-11-06, owner: Important 3: fix both. The owner thereby approved the proposed card lines: Okulicki "Chief of staff of Anders' Army; briefly commanded the 7th Infantry Division." and Duch "Commanded the 1st Rifle Brigade of the 1st Polish Armoured Division until 1943." (the facts they restate lose the years the sources do not give).
- 2026-11-06, owner: Important 4: "Keep the photos. Ultimately, this is just a mod for a fairly niche community. While respecting licences is obviously important, in this situation I don't think there's any harm to anyone if we just assume we can use them." The owner keeps the photos on that assumption, knowing the audit found the public-domain basis weak for `antoni_chrusciel`, `boleslaw_duch` and `leopold_okulicki` (no first publication before 1994 shown on their Commons pages). No photo, portrait or `photos.json` row changes. The decision on `antoni_chrusciel` and `boleslaw_duch` of the first plan stands and now also covers `leopold_okulicki`.
- 2026-11-06, planner: the shared gate prints `ACCEPTED` for every photo and `-Audit` finds no licence change; that is the tool's finding, not a confirmation of the first-publication date, which the audit could not establish.
- 2026-11-06, planner: the plan review (round 1) found that Polish Exiles of WW2 does not use the order "Bronisław Bolesław", which the audit report had said; the order rests on the Kamiński biography as the Commons record gives it, and the plan cites that record in his fact sheet. The owner's "fix" for Important 2 was given on the audit's wording; it is reported again in the hand-off.
- 2026-11-06, planner: the fix keeps the cited source for each bullet; Duch's "1942" is dropped rather than re-sourced to English Wikipedia, as the approved proposal said.

## Leaders

Unchanged from the released pack. Stats are `skill` then `attack defense planning logistics`.

| Key | Name | Mode | Ids (target; sameAs) | Role | Stats | Traits | Photo | Portrait (round, pick) | Status |
|---|---|---|---|---|---|---|---|---|---|
| stefan_rowecki | Stefan Rowecki | new | none; none | corps_commander | 3 / 2 2 4 1 | guerilla_fighter | stefan_rowecki | r1, seed 1 | ready |
| antoni_chrusciel | Antoni Chrusciel | new | none; none | corps_commander | 2 / 2 3 2 1 | urban_assault_specialist | antoni_chrusciel | r1, seed 1 | ready |
| boleslaw_duch | Boleslaw Duch | new | none; none | corps_commander | 2 / 3 1 1 1 | infantry_officer | boleslaw_duch | r1, seed 3 | ready |
| leopold_okulicki | Leopold Okulicki | new | none; none | corps_commander | 2 / 2 1 3 1 | organizer | leopold_okulicki | r1, seed 2 | ready |

## Stat notes

No stat or trait changes. Only the wording of three notes of the released plan moves with the corrected facts:

- stefan_rowecki: `defense 2` rests on fact 3 as fixed: the brigade, encircled, fought at Tomaszow Lubelski on 17-20 September 1939 (no longer "the last stand"). `attack 2` (the 13 September attack toward Annopol, fact 3), `planning 4` (facts 4, 5), `guerilla_fighter` (facts 5, 6) and skill 3 as released.
- boleslaw_duch: `infantry_officer` rests on facts 3 and 5 of the fixed section (the full-name bullet is fact 1): the 73rd Infantry Regiment 1935-38, the 1st Rifle Brigade (until July 1943) and the 3rd Carpathian Rifle Division. Stats as released.
- leopold_okulicki: `planning 3` and `organizer` rest on fact 3 (chief of staff of Anders' Army, no years given) and fact 2 (Lwow area). `skill 2` on fact 3 (the brief 7th Infantry Division command) and fact 4 (last Home Army commander). Stats as released.

## Photos

Unchanged. The four used photos stay as recorded in `photos.json` (all `source: commons`, PD, "PD-1996-text, PD-Poland, PD-Polish", fetched 2026-11-06); the dry-run fetches of 2026-11-06 for `boleslaw_duch` and `leopold_okulicki` printed `ACCEPTED`.

| Photo key | Source and id | Licence (author or credit) | Size | Leader |
|---|---|---|---|---|
| stefan_rowecki | commons `File:Stefan Rowecki (-1934).jpg` | PD; unknown author, "55 PPP 1919-1934. Jednodniowka" | 608x822 | stefan_rowecki |
| antoni_chrusciel | commons `File:Antoni Chruściel.jpg` | PD; unknown-anonymous, Centralne Archiwum Wojskowe | 401x669 | antoni_chrusciel |
| boleslaw_duch | commons `File:GeneralDuch.jpg` | PD; unknown author, S. Kaminski, Wydawnictwo UW 2010 | 1195x1737 | boleslaw_duch |
| leopold_okulicki | commons `File:Leopold Okulicki dowódca 7 DP w 2 Korpusie Polskim gen. Andersa 1943.jpg` | PD; anonymous, Kryska-Karski and Zurakowski, Warsaw 1991 | 629x859 | leopold_okulicki |

## Review rounds

None: no portrait is remade.

## Review

- Round 1, `lp-reviewer` (2026-11-06): not ready. Important: I1 (steps 3, 7 and 8 listed generated files that do not change: now `0 file(s) written`, only the two source files, no wiki push), I2 (a failing scaffold test in `-Test`: handled under "Kept on judgment"), I3 (the Duch name-order fix cited Polish Exiles, which does not use that order: now sourced to the Commons record of the 2010 biography, and the display name left unchanged), I4 (Decision 4 paraphrased the owner and overstated policy compliance: now quoted word for word). Minor M1 (exact `-ConvertPortraits` line), M2 (Rowecki's dissolution date said twice), M3 (Polish Exiles source label). All applied.
- Round 2, `lp-reviewer` (2026-11-06): not ready. Important: I5 (the Manager's scaffold sync had modified `tools/HoiModBuild.ps1` and `tests/BuildEngine.Tests.ps1` and `-Test` now passes: steps 6 to 8 and "Kept on judgment" rewritten, step 8 stages by path). Minor M4 (Duch stat-note fact numbers), M5 (the order is disputed, not unsourced; the source field wording). All applied.
- Round 3, `lp-reviewer` (2026-11-06): ready, no Critical or Important finding. Rehearsal of steps 1 to 6 in a scratch copy: leaders file identical, `Generated pack 'poland': 4 leader(s), 0 file(s) written, 0 removed.`, `0 portrait file(s) converted, 8 up to date.`, `Check OK: 1 pack(s), 4 warning(s)`, `Validation succeeded.`; only the two source files differ from the real tree. (`-Test` in the copy failed two tests that belong to the copy, not to the plan; on the real tree `-Test` printed 362 Passed, 0 Failed.) Minor M6 (no `git commit -a`) applied.
- `workshop-editor` on the intro: KEEP on all three paragraphs (audit, Phase 2); the intro is not changed by this plan.

## Kept on judgment

`build.ps1 -Check -Pack poland` prints four warnings, all of the kind `photo <key>: no leader uses this photo`: `antoni_szylling`, `antoni_szylling_2`, `antoni_szylling_3` and `leopold_okulicki_2`. `photos.json` is written only by `-FetchPhoto`, so the rows stay as the record of what was checked (Context of the first plan). The implementer stops on any other warning.

The working tree also holds two changes that are not this plan's work: `tools/HoiModBuild.ps1` and `tests/BuildEngine.Tests.ps1`, rewritten on 2026-11-06 by the Modding Manager's scaffold sync (they equal the Manager's own copies, which carry the Manager's uncommitted work). Before that sync, `build.ps1 -Test` printed `361 Passed, 1 Failed` (the test "carries the current shared build files of the Modding Manager", `tests\BuildEngine.Tests.ps1:825`); after it, `362 Passed, 0 Failed` (run by the planner on 2026-11-06). Committing those two files belongs to the owner and the Manager's own change; this plan never stages them. If the sync is undone before the plan is carried out, the one failure above may come back: that is the same cause, and the implementer reports it and stops on any other failed test.

## READY criteria

- [x] Every approved fact fix is in the `markdown fact-sheets` block with its source.
- [x] Every `new` leader still has a photo that printed `ACCEPTED`, a chosen portrait and stats by `docs/stat-guide.md` (nothing of them changes).
- [x] Every changed card line is in the `json showcase` block, approved by the owner (Decisions, 3).
- [x] The rehearsal of steps 1 to 6 gave what each step expects (round 3 of "Review").
- [x] `lp-reviewer` returned ready on the plan (round 3).

## Implementation steps

- [x] 1. Write the leaders: replace `source/poland/leaders.json` with the `json leaders` block below, whole (it is identical to the current file; `git diff` of the file stays empty).
- [x] 2. Write the fact sheets: replace the sections `stefan_rowecki`, `boleslaw_duch` and `leopold_okulicki` of `source/poland/fact-sheets.md` with the sections of the `markdown fact-sheets` block below (the section `antoni_chrusciel` stays). Then replace the entries `boleslaw_duch` and `leopold_okulicki` under `leaders` of `source/poland/showcase.json` with the entries of the `json showcase` block below (the entries of the other two leaders stay).
- [x] 3. `powershell -File .\build.ps1 -Generate -Pack poland`: expect `Generated pack 'poland': 4 leader(s), 0 file(s) written, 0 removed.` (no generated file reads the fact sheets or the showcase cards; the dry run of the planned sources printed `0 file(s) to write, 0 to remove`). Then from the Modding Manager root (`..\..`), `powershell -File Scripts\Workshop\Test-WorkshopText.ps1 -Mod "Leader Packs" -Pack poland`: expect `no problem found`.
- [x] 4. `powershell -File .\build.ps1 -ConvertPortraits -Pack poland`: expect `Pack 'poland': 0 portrait file(s) converted, 8 up to date.` and exit 0 (no portrait changed).
- [x] 5. `powershell -File .\build.ps1 -Check -Pack poland`: expect `Check OK`, with no warning outside "Kept on judgment".
- [x] 6. `powershell -File .\build.ps1 -ValidateOnly` then `powershell -File .\build.ps1 -Test`: expect `Validation succeeded.` and `Summary: 362 Passed, 0 Failed` (or the test count of the day with 0 failed). Stop on any failed test, except the single scaffold test described under "Kept on judgment", which is reported, not fixed.
- [x] 7. `git status --short` and `git diff --stat` show changes only in `source/poland/fact-sheets.md` and `source/poland/showcase.json` (and this plan until it is archived), besides `tools/HoiModBuild.ps1` and `tests/BuildEngine.Tests.ps1`, which the Manager's scaffold sync modified before this plan and which this plan leaves as they are. Any change under `packs/`, `wiki/`, `photos.json` or `portraits.json`, or any other file, is a stop.
- [x] 8. Ship (after the owner confirms): move this plan to `docs/plans/archive/`, then stage by path only (`source/poland/fact-sheets.md`, `source/poland/showcase.json` and the archived plan; never `git add -A`, and never `tools/HoiModBuild.ps1` or `tests/BuildEngine.Tests.ps1`) and commit only what is staged (`git commit -m`, never `-a`) with the message `fix(poland): audit fixes to three fact sheets and two card lines`. The scaffold files stay uncommitted for the owner. No wiki page changes (nothing generated changed), so no `push-wiki.ps1` is needed. The game check the first plan left open (`docs/ingame-verification-pending.md` of the Modding Manager) is not part of this plan.

## Stop conditions

- `-Generate`, `-ConvertPortraits` or `-Check` prints an `[ERROR]`: stop and report it whole.
- `-ConvertPortraits` converts a portrait, or step 7 lists a file outside the expected ones: stop and report.

## Outcome

Carried out 2026-11-06 by the implementer. Steps 1 to 7 ticked; step 8 (ship) left for the caller.

- `-Generate -Pack poland`: `Generated pack 'poland': 4 leader(s), 0 file(s) written, 0 removed.`; `Test-WorkshopText.ps1`: no problem found.
- `-ConvertPortraits -Pack poland`: `Pack 'poland': 0 portrait file(s) converted, 8 up to date.`
- `-Check -Pack poland`: `Check OK: 1 pack(s), 4 warning(s).` (the four listed under "Kept on judgment").
- `-ValidateOnly`: `Validation succeeded.`
- `-Test`: `Summary: 362 Passed, 0 Failed, 0 Skipped (all suites)`.
- `git status --short`: only `source/poland/fact-sheets.md` and `source/poland/showcase.json` modified (plus this plan, untracked).
- Deviation: `tools/HoiModBuild.ps1` and `tests/BuildEngine.Tests.ps1` no longer show as modified; the Manager's scaffold sync was already committed as 2e615b3 ("chore(build): sync the build engine from the Manager"). The mentions of them in steps 7 and 8 therefore no longer apply. `source/poland/leaders.json` was rewritten with the plan's block and stayed identical (no diff).

## Fact sheets

```markdown fact-sheets
## stefan_rowecki

Stefan Pawel Rowecki "Grot" (1895-1944), Polish Army; brigade commander in 1939, then commander of the Home Army.

- Commanded the 55th Infantry Regiment in Leszno 1930-1935. Source: https://en.wikipedia.org/wiki/Stefan_Rowecki (Stefan Rowecki)
- Early 1936 commanded the KOP brigade "Podole"; 1938 deputy commander (infantry) of the 2nd Legions Infantry Division in Kielce; June 1939 formed the Warsaw Armoured-Motorized Brigade. Source: https://dzieje.pl/node/106781 (Stefan Rowecki)
- From June 1939 until the brigade's dissolution on 20 September 1939: commanded the Warsaw Armoured-Motorized Brigade (colonel, staff-college graduate) in Army Lublin; on 13 September its attack toward Annopol succeeded, then it retreated toward Lwow; encircled near Tomaszow Lubelski on 16-17 September and fought there on 17-20 September. Source: https://pl.wikipedia.org/wiki/Warszawska_Brygada_Pancerno-Motorowa (Warszawska Brygada Pancerno-Motorowa)
- Staff-college graduate (plk dypl.); lieutenant colonel dyplomowany in 1926. Sources: https://pl.wikipedia.org/wiki/Warszawska_Brygada_Pancerno-Motorowa (Warszawska Brygada Pancerno-Motorowa); https://dzieje.pl/node/106781 (Stefan Rowecki)
- October 1939: chief of staff and deputy commander of the SZP; 30 June 1940: commander-in-chief of the ZWZ; 14 February 1942: commander of the Home Army (AK). Source: https://dzieje.pl/node/106781 (Stefan Rowecki)
- 1941: organised the sabotage operation "Wachlarz" in the territory east of the pre-war borders. Source: https://en.wikipedia.org/wiki/Stefan_Rowecki (Stefan Rowecki)
- Arrested by the Gestapo on 30 June 1943 and murdered in Sachsenhausen in August 1944. Source: https://dzieje.pl/node/106781 (Stefan Rowecki)
- Virtuti Militari Gold Cross (1942); Legion of Honour (1937). Source: https://en.wikipedia.org/wiki/Stefan_Rowecki (Stefan Rowecki)

## boleslaw_duch

Bronislaw Boleslaw Duch (1896-1980), Polish Army; division commander in the Polish II Corps.

- Full name Bronisław Bolesław Duch (1896-1980), as the 2010 biography by Stanisław Kamiński is titled ("Generał dywizji Bronisław Bolesław Duch"); English Wikipedia gives the order Bolesław Bronisław. Source: https://commons.wikimedia.org/wiki/File:GeneralDuch.jpg (source field of the photograph's record)
- Born 15 November 1896; Cross of Valour eight times and the Virtuti Militari. Sources: https://www.polishexilesofww2.org/boleslaw-duch (Bronislaw Duch); https://en.wikipedia.org/wiki/Boles%C5%82aw_Bronis%C5%82aw_Duch (Bolesław Bronisław Duch)
- 1935-1938: commanded the 73rd Infantry Regiment; colonel in 1938; after the outbreak of the war infantry commander of the 39th Reserve Infantry Division, which he commanded in practice in September 1939. Sources: https://en.wikipedia.org/wiki/Boles%C5%82aw_Bronis%C5%82aw_Duch (Bolesław Bronisław Duch); https://www.polishexilesofww2.org/boleslaw-duch (Bronislaw Duch)
- Brigadier general on 5 May 1940; major general in 1945. Source: https://www.polishexilesofww2.org/boleslaw-duch (Bronislaw Duch)
- January 1940: commander of the 1st Grenadier Division in France; until July 1943: commander of the 1st Rifle Brigade, 1st Polish Armoured Division, in Scotland; from the end of July 1943: commander of the 3rd Carpathian Rifle Division, II Polish Corps, in Italy. Source: https://www.polishexilesofww2.org/boleslaw-duch (Bronislaw Duch)
- His division took the ruins of the Monte Cassino monastery and raised the national banner, took part in the liberation of Ancona, and in April 1945 of Bologna. Source: https://www.polishexilesofww2.org/boleslaw-duch (Bronislaw Duch)

## leopold_okulicki

Leopold Okulicki "Niedzwiadek", "Kobra" (1898-1946), Polish Army and Home Army; division commander and last commander of the Home Army.

- September 1939: held various posts in besieged Warsaw. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- January 1940: in the underground in the Lodz area, later in the Bialystok and Lwow areas; Rowecki tasked him with repairing the organisational breakdown in the Lwow area; arrested by the NKVD in January 1941. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- Chief of staff of Anders' Army and, for a brief period, commander of the 7th Infantry Division of the Polish forces in the East. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- July 1944: commander of the 2nd Echelon of the Home Army (Operation Tempest); chief of staff in the Warsaw Uprising; 3 October 1944: commander of the Home Army; dissolved it on 19 January 1945. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- Captain Hudson of the SOE described him as "decisive, sincere and clear-minded". Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- Virtuti Militari Gold and Silver Cross; Cross of Valour four times. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
- Arrested by the NKVD in February 1945; sentenced in the Trial of the Sixteen; died in the Butyrka prison on 24 December 1946. Source: https://en.wikipedia.org/wiki/Leopold_Okulicki (Leopold Okulicki)
```

## Showcase cards

The two card entries the owner approved on 2026-11-06 (Decisions, 3); each line restates a bullet of his fact-sheet section above. The cards of `stefan_rowecki` and `antoni_chrusciel` do not change.

```json showcase
{
    "leaders": {
        "boleslaw_duch": {
            "card": [
                "Brigadier general in May 1940.",
                "Commanded the 1st Rifle Brigade of the 1st Polish Armoured Division until 1943.",
                "His 3rd Carpathian Rifle Division took the ruins of Monte Cassino monastery.",
                "Took part in the liberation of Ancona, and of Bologna in April 1945."
            ],
            "years": [1896, 1980]
        },
        "leopold_okulicki": {
            "card": [
                "Chief of staff of Anders' Army; briefly commanded the 7th Infantry Division.",
                "Led the Home Army's 2nd Echelon in Operation Tempest, July 1944.",
                "Commander of the Home Army from 3 October 1944.",
                "An SOE officer called him \"decisive, sincere and clear-minded\"."
            ],
            "years": [1898, 1946]
        }
    }
}
```

## Leaders source

```json leaders
{
    "pack": "poland",
    "tag": "POL",
    "prefix": "lp_pol",
    "displayName": "Poland",
    "leaders": [
        {
            "key": "stefan_rowecki",
            "name": "Stefan Rowecki",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 3,
            "attack": 2,
            "defense": 2,
            "planning": 4,
            "logistics": 1,
            "traits": ["guerilla_fighter"],
            "factSheet": "stefan_rowecki",
            "portrait": {
                "photo": "stefan_rowecki",
                "role": "Polish colonel",
                "headwear": "bareheaded",
                "uniform": "khaki-olive Polish Army tunic with a high stiff collar, silver zig-zag collar embroidery with small eagles, a leather shoulder strap, silver shoulder cords, a row of medal ribbons and several crosses and medals on the chest",
                "uniformColour": "eng_army_khaki",
                "avoidHeadwear": "cap, hat, helmet",
                "notes": "short dark hair brushed up, clean-shaven, stern direct look",
                "born": 1895,
                "photoYear": 1934
            }
        },
        {
            "key": "antoni_chrusciel",
            "name": "Antoni Chrusciel",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 2,
            "defense": 3,
            "planning": 2,
            "logistics": 1,
            "traits": ["urban_assault_specialist"],
            "factSheet": "antoni_chrusciel",
            "portrait": {
                "photo": "antoni_chrusciel",
                "role": "Polish colonel",
                "headwear": "bareheaded",
                "uniform": "khaki-olive Polish Army tunic with a high collar, silver zig-zag collar embroidery with a small eagle, a leather cross strap, shoulder boards with a star and bars, a row of medal ribbons and a Virtuti Militari cross on the chest",
                "uniformColour": "eng_army_khaki",
                "avoidHeadwear": "cap, hat, helmet",
                "notes": "short dark hair combed back, clean-shaven, calm look",
                "born": 1895,
                "photoYear": 1931
            }
        },
        {
            "key": "boleslaw_duch",
            "name": "Boleslaw Duch",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 3,
            "defense": 1,
            "planning": 1,
            "logistics": 1,
            "traits": ["infantry_officer"],
            "factSheet": "boleslaw_duch",
            "portrait": {
                "photo": "boleslaw_duch",
                "role": "Polish general",
                "headwear": "wearing a stiff four-cornered Polish rogatywka cap with a dark band, a silver eagle badge and a general's silver zig-zag embroidery on the band and visor",
                "uniform": "khaki British battledress with a black collar patch bearing a silver eagle, a POLAND shoulder title, general's rank insignia on the shoulder strap and rows of medal ribbons and crosses on the chest",
                "uniformColour": "eng_army_khaki",
                "avoidHeadwear": "helmet, beret, bareheaded, soft cap",
                "notes": "clean-shaven, heavy face, serious look over his shoulder",
                "born": 1896,
                "photoYear": 1945
            }
        },
        {
            "key": "leopold_okulicki",
            "name": "Leopold Okulicki",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 2,
            "defense": 1,
            "planning": 3,
            "logistics": 1,
            "traits": ["organizer"],
            "factSheet": "leopold_okulicki",
            "portrait": {
                "photo": "leopold_okulicki",
                "role": "Polish colonel",
                "headwear": "bareheaded",
                "uniform": "light khaki Polish Army tunic with an open collar, shirt and khaki tie, a black collar patch with a small silver eagle, shoulder straps with small silver pips",
                "uniformColour": "eng_army_khaki",
                "avoidHeadwear": "cap, hat, helmet",
                "notes": "slicked-back brown hair, clean-shaven, a slight smile",
                "born": 1898,
                "photoYear": 1943
            }
        }
    ]
}
```
