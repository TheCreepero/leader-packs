# Finland pack: two more generals

Status: DONE
Pack: finland (FIN, prefix lp_fin)
Kind: new leaders
Created: 2026-11-01
Snapshot: data/finland/game-characters.json refreshed 2026-11-01 (game 1.19.4.1)
Dossiers: research/finland/2026-11-01-dossier.md, research/finland/2026-11-01-dossier-2.md
Review page: https://claude.ai/artifact/WFQgqvZvYvy9xMoJ2hftUp (recorded in source/finland/review.json)

## For the implementer

Carry out "Implementation steps" in order with `.claude/agents/lp-implementer.md`. Everything the steps write is in this file: the `json leaders` block is the whole `source/finland/leaders.json`, and the `markdown fact-sheets` block holds the sections for `source/finland/fact-sheets.md`. The photos, the portrait rounds and the owner's picks were recorded while planning (`photos.json`, `portraits.json`, `portraits/`); do not touch them. Decide nothing; stop and report when something does not fit.

## Context

The released Finland pack (Workshop 3831847770) has three leaders: Armas-Eino Martola, Kaarlo Heiskanen and Oiva Koivisto. The owner asked to expand it with two more generals. Written by the `leader-pack-create` skill.

## Decisions

2026-11-01, Phase 0:
- Two leaders, both generals; no admirals.
- Role: corps_commander for both (the owner chose corps commanders only, not field marshals).
- Nothing is left out on conduct: a candidate with a war-crimes record (Einar Vihma, Saunojankangas 1941) stays eligible, and his fact sheet records the note with its source.
- The historical researcher looks for a few new army candidates beside the two usable ones of the earlier dossier (einar_vihma, paavo_paalu), so the owner chooses from four or five.

2026-11-01, Phase 2 (dossier `research/finland/2026-11-01-dossier-2.md`; modes checked against the snapshot by surname: Pajari and Svensson in neither set, Öhquist an advisor `high_command` only, as `FIN_harald_ohquist`, in both):
- Shortlist shown: aaro_pajari (new), antero_svensson (new), einar_vihma (new, earlier dossier), harald_ohquist (addRole FIN_harald_ohquist); paavo_paalu (earlier dossier, relieved June 1944) and aarne_blick (reserve) not recommended.
- Owner chose **aaro_pajari** and **antero_svensson**, both `new`, `sameAs: []`, corps_commander.
- Pajari's major-general promotion date (3 Oct 1941) was from a search snippet only (UNVERIFIED) at this point; his commands are sourced. Amended in Phase 5: the dossier's addendum confirmed the date on the fetched page, so it is in the fact sheet. His 1944 prisoner-abuse allegation (cleared, no charges) is recorded in the fact sheet with its source.
- Not chosen, kept unmarked in the dossiers for later: einar_vihma, paavo_paalu, harald_ohquist, aarne_blick.

2026-11-01, Phase 3:
- antero_svensson leaves the pack for now for want of a photo: his only single portrait on Commons (`File:Svensson Antero.jpg`) is 256x443 and colourised (`REJECTED`, under 300 px); the other Commons files are group shots that do not identify him. Single-subject frames exist only in the SA-kuva archive, not on Commons (SA-kuva nos. 88330 "Eversti Svensson, 7. div. komentaja" 1941; 136644-136647 "Kenraalimajuri A. J. Svensson komentopaikallaan" 1943; 127102 "Kenraalimajuri Svensson" 1941), checked by Commons search per number. He stays unmarked in `research/finland/2026-11-01-dossier-2.md`; an upload of one of those frames to Commons would bring him back.
- Owner chose **einar_vihma** (earlier dossier `research/finland/2026-11-01-dossier.md`; `new`, `sameAs: []`, no Vihma or Wichmann in either snapshot set) for the second slot, corps_commander. His Saunojankangas 1941 note goes into the fact sheet with its source, per the Phase 0 decision.
- The owner asked whether the Commons-only photo rule should be relaxed; the planner advised keeping it for this plan and treating a second structured source (Finna/SA-kuva, with a machine-read rights field and an `-Audit` recheck) as a separate plan if thin Commons coverage recurs. No change made.

2026-11-01, Phase 6:
- The first rehearsal's `-Check` warned on the released `armas_eino_martola` and `kaarlo_heiskanen`: `jaeger` is not defined on Road to 56, where they lose it without an `error.log` line [CHR-017] (the refreshed `start-traits.json` now lists it under `rt56.undefined`, counterpart `jaeger_trait`). By `docs/stat-guide.md` and [RT56-014] (`jaeger_trait` is Road to 56's name for the same trait), this plan adds `jaeger_trait` beside `jaeger` for both, as for `einar_vihma`; no other value of a released leader changes, and no id changes. Step 7's game check covers both playsets, as the stat guide asks for the first pack that lists both names.
- 2026-11-02, owner's word: yes, fix Martola and Heiskanen in this update (`jaeger_trait` beside `jaeger`), with the game check on both playsets.

## Leaders

One row per leader of the pack, `skip` leaders included. Stats are `skill` then the attribute skills of the role kind (army: attack/defense/planning/logistics; navy: attack/defense/maneuvering/coordination).

| Key | Name | Mode | Ids (target; sameAs) | Role | Stats | Traits | Photo | Portrait (round, pick) | Status |
|---|---|---|---|---|---|---|---|---|---|
| armas_eino_martola | Armas-Eino Martola | new | sameAs [] | corps_commander | 2; 1/2/3/2 | jaeger (+ jaeger_trait, added by this plan), infantry_officer | armas_eino_martola (PD) | released, unchanged | ready |
| kaarlo_heiskanen | Kaarlo Heiskanen | new | sameAs [] | corps_commander | 2; 3/2/1/1 | jaeger (+ jaeger_trait, added by this plan), infantry_officer | kaarlo_heiskanen (PD) | released, unchanged | ready |
| oiva_koivisto | Oiva Koivisto | new | sameAs [] | navy_leader | 2; 1/1/2/3 | navy_career_officer | oiva_koivisto (PD) | released, unchanged | ready |
| aaro_pajari | Aaro Pajari | new | sameAs [] | corps_commander | 2; 3/2/2/1 | infantry_officer, war_hero | aaro_pajari (PD) | round 2, pick 8 | ready |
| einar_vihma | Einar Vihma | new | sameAs [] | corps_commander | 2; 2/3/1/1 | jaeger (+ jaeger_trait), brave | einar_vihma (PD) | round 1, pick 3 | ready |

Status per leader: `roster`, `photo`, `portrait open`, `portrait picked`, `stats set`, `ready`, or `skip`.

## Stat notes

Vanilla peers (`Get-HoiCharacter -Tag FIN -Role corps_commander`, common/characters/FIN.txt): division-level skill 2 corps commanders sum 7 to 8 (e.g. 3/1/2/1 with `inflexible_strategist`, `infantry_officer`, `jaeger`, line 345; 1/3/2/1, line 408; 1/3/1/2 with `infantry_officer`, `ranger`, `jaeger`, line 299); skill 3 ones sum 9 to 11 (2/3/3/2, line 513; 4/3/1/2 with `winter_specialist`, line 428). The pack's three released leaders are all skill 2. Each trait was read with `Find-HoiDefinition -Type trait` before it was chosen: `war_hero` (common/unit_leader/00_traits.txt:204), `brave` (:190), `infantry_officer` (:396), `jaeger` (:870).

- `aaro_pajari`: role `corps_commander` (division commander: 18th and 3rd Divisions, facts 6 and 8; never a corps). Skill 2: division commands with sourced results (facts 4, 6, 8, 9), level with the vanilla division-level peers and the pack's other generals. Attack 3 (highest): the Tolvajärvi attack and the 40 km advance to Aittojoki (fact 4), the Isthmus breakthrough of August 1941 and Suursaari (fact 6), Tornio (fact 9). Defense 2: the VT and VKT lines in June 1944 (fact 8). Planning 2: Staff College 1924-26, general staff officer, head of the Civil Guard training department (fact 2). Logistics 1: no supply fact (one above the bottom). Sum 8, one above the leanest peers for his staff record, as Martola. Traits: `infantry_officer` (Infantry Regiment 16, then the 18th and 3rd infantry divisions, facts 4, 6 and 8); `war_hero` (a double knight of the Mannerheim Cross, no. 12 in 1941 and again in 1944, fact 10). Not a jääkäri (fact 1; the dossier's addendum finds no Jäger service), so no `jaeger`. `winter_specialist` for Tolvajärvi was considered and left out: two traits at most, and his branch and decorations rest on more facts.
- `einar_vihma`: role `corps_commander` (brigade and division commander: 1st Brigade, 10th, 7th, 12th and 6th Divisions, facts 4 and 6). Skill 2: division commands, the 6th Division's arrival at Ihantala that stabilised the defence (fact 8) and the Mannerheim Cross (fact 9); level with the peers. Defense 3 (highest): the 6th Division at Ihantala in 1944, reinforcing a line close to breaking (fact 8). Attack 2: the 12th Division's fast push towards Terijoki in August 1941 (fact 7), and leading his men in attack (fact 10). Planning 1: the War College course of 1926 attended without the thesis and the general staff officer title (fact 2), and director of the Cadet School 1933-36 (fact 3); no staff post, chief of staff post or war-college teaching, so one above the bottom. Logistics 1: no supply fact (one above the bottom). Sum 7, as the leanest peers. Traits: `jaeger` (Jäger Battalion 27 from 1915, fact 1), listed with Road to 56's `jaeger_trait` beside it as `docs/stat-guide.md` asks, since `start-traits.json` lists `jaeger` under `rt56.undefined` with that counterpart [RT56-014]; `brave` (Mannerheim's memoirs call him "the brave Major General Vihma", fact 8; he led his men from the front, personally armed, fact 10). His harsh discipline was not made `harsh_leader`: the article flags those claims as unsourced.

## Photos

Every row printed `ACCEPTED` from `build.ps1 -FetchPhoto` while planning; the licence column is what it printed.

| Photo key | Commons file | Licence (author) | Size | Leader |
|---|---|---|---|---|
| aaro_pajari | File:Kenraalimajuri Pajarin mailla. Aaro Pajari, SAKuva-173084.jpg | PD (Public domain), Unknown author | 3467x4961 | aaro_pajari (Commons date 1941-1944; `photoYear` 1942, the middle of the range) |
| einar_vihma | File:Kenraali Vihma Einar August (SA-kuva 136624).jpg | PD (Public domain), Sot.virk. E.Nurmi | 4792x4984 | einar_vihma (Commons date 1943-09-10, Karhumäki) |

Rejected while planning: `File:Svensson Antero.jpg` (antero_svensson): `REJECTED ... 256x443 is under 300 px on its shorter side`; also colourised. Svensson's other Commons files (SAKuva-116323 to 116325, Syväri 1942; Sortavala Parade 1943) are group shots whose captions do not identify him; not tried.

## Review rounds

One line per leader and round: the round, its seeds, the owner's decision (pick `<seed>`, or reject with the reason as written), and for a rejection the `portrait` fields or the photo changed for the next round.

| Leader | Round | Seeds | Decision | Change for the next round |
|---|---|---|---|---|
| aaro_pajari | 1 | 1-4 (likeness 0.50, 0.48, 0.53, 0.55) | reject: "His eyes are looking into the wrong direction (too high up) compared to original." | Expression row of the reason table: `notes` from "clean-shaven, broad heavy jaw, stern level gaze" to "clean-shaven, broad heavy jaw, eyes looking level and straight ahead towards the viewer's left, not upward, irises centred under the lids in the shadow of the visor, stern expression". On the sheet the coloured reference keeps the level gaze and all four finals roll the eyes up towards the visor, so the repaint misreads the shaded eyes; one change only, so the round tests it. If the gaze stays wrong, next try `facePass: false` (F2 repaints the eyes). |
| aaro_pajari | 2 | 5-8 (likeness 0.50, 0.50, 0.52, 0.53) | pick 8 (owner: the gaze is still slightly high but "good enough that it likely won't be too noticeable at the smaller in-game size") | |
| einar_vihma | 1 | 1-4 (likeness 0.53, 0.56, 0.54, 0.57) | pick 3 | |

## Review

Round 1, 2026-11-01: not ready.
- I1 (Important): step 7 did not require the Road to 56 playset, on which the `jaeger_trait` choice depends, and [CHR-017] does not yet say whether vanilla drops an undefined `jaeger_trait` silently. Fixed: step 7 requires both playsets, each with its expected result, and a stop when either shows a missing, doubled or erroring Jäger trait.
- I2 (Important): the Stat notes stated trait effects and scopes as facts. Fixed: only the trait names and their `file:line` remain, with the historical fact each rests on.
- M1 (Minor): the Phase 2 decision still called Pajari's promotion date UNVERIFIED and kept out of the fact sheet. Fixed: amended, pointing to the dossier addendum.
- M2 (Minor): Vihma's fact on Mannerheim's memoirs was paraphrased loosely, and the memoirs call him brave. Fixed: checked on the page by the planner, added to the dossier addendum with the quote, fact 8 reworded, and `brave` now rests on facts 8 and 10.
- M3 (Minor): two further Vihma facts on the page (the 12th Division's push towards Terijoki, August 1941; the 1926 War College course and the 1927 general staff officer title). Fixed: checked, added to the dossier addendum and the fact sheet (facts 7 and 2); the Stat notes cite them for attack 2 and planning 1.
- M4 (Minor): the `jaeger_trait` change to two released leaders judged sound, but the owner's word was not recorded, and the Phase 6 entry sat under Phase 3. Fixed: the entry has its own heading; the owner's word is recorded in Decisions, Phase 6.

Round 2, 2026-11-02: ready. I1, I2 and M1 to M4 confirmed fixed against the files; Vihma's facts 2, 7 and 8 confirmed on the page; the `json leaders` block is unchanged since the rehearsal. New M5 (Minor): this Review entry for M4 still said the owner's word was being asked for. Fixed.

## Kept on judgment

None: the rehearsal's `-Check -Pack finland` printed `Check OK: 1 pack(s), 0 warning(s).`

Rehearsal, 2026-11-01, in `scratch\rehearsal` (since removed), steps 1 to 6 as written: step 3 `Generated pack 'finland': 5 leader(s), 15 file(s) written, 0 removed.`, exit 0; step 4 `Pack 'finland': 4 portrait file(s) converted, 6 up to date.`, exit 0; step 5 first gave `Check OK: 1 pack(s), 2 warning(s).` (the `jaeger` Road to 56 warnings on Martola and Heiskanen, see Decisions, Phase 6); after the `json leaders` block added `jaeger_trait` for both, steps 1 and 3 to 6 were run again in the same copy: `Generated pack 'finland': 5 leader(s), 1 file(s) written, 0 removed.`; `Pack 'finland': 0 portrait file(s) converted, 10 up to date.`; `Check OK: 1 pack(s), 0 warning(s).`; `Validation succeeded.`; `-Test` `281 Passed, 0 Failed, 1 Skipped (all suites)`. In the repository, step 4 is expected to convert the 4 new DDS files (large and small for `aaro_pajari` and `einar_vihma`) and find the 6 released ones up to date.

## READY criteria

- [x] Every `new` and `addRole` leader has a fact-sheet section in the block below, with a source for each fact his role, stats and traits rest on.
- [x] Every `new` and `addRole` leader has a photo that printed `ACCEPTED` and is recorded in `photos.json`.
- [x] Every `new` and `addRole` leader has a portrait the owner picked, recorded as `chosen` in `portraits.json`.
- [x] Every `new` and `addRole` leader has a role, stats and traits by `docs/stat-guide.md`, with a "Stat notes" line.
- [x] Every `skip` leader has a reason that names the covering id. (None in this pack.)
- [x] The rehearsal of steps 1 to 6 gave what each step expects.
- [x] `lp-reviewer` returned ready on the plan.

## Implementation steps

- [x] 1. Write the leaders: replace `source/finland/leaders.json` with the `json leaders` block below, whole.
- [x] 2. Write the fact sheets: add each section of the `markdown fact-sheets` block below to `source/finland/fact-sheets.md`, replacing a section of the same key.
- [x] 3. `powershell -File .\build.ps1 -Generate -Pack finland`: expect `Generated pack 'finland'`.
- [x] 4. `powershell -File .\build.ps1 -ConvertPortraits -Pack finland`: expect `Pack 'finland': <n> portrait file(s) converted, <m> up to date.` and exit 0.
- [x] 5. `powershell -File .\build.ps1 -Check -Pack finland`: expect `Check OK`, with no warning outside "Kept on judgment".
- [x] 6. `powershell -File .\build.ps1 -ValidateOnly` then `powershell -File .\build.ps1 -Test`: expect `Validation succeeded.` and no failed test.
- [x] 7. Game check (after the owner says to start the game): `powershell -File .\build.ps1 -DevLink -Pack finland`, then the owner's check of `leader-pack-implement` section 4, on **both** playsets, each in a new game as FIN; the result of each goes into "Outcome". This plan is the first to list `jaeger` and `jaeger_trait` together, and whether vanilla drops the undefined `jaeger_trait` as silently as Road to 56 drops `jaeger` is not yet in the register [CHR-017], so the Road to 56 run is required here, not optional.
  - Vanilla: Aaro Pajari and Einar Vihma are in the army leader list with their portraits and names; Martola, Heiskanen and Vihma show the Jäger trait (one Jäger trait each, not two); `error.log` has no line naming `jaeger_trait`, `jaeger` or `lp_fin_characters.txt` beyond the one expected warning per recruitment [CHR-014].
  - Road to 56: the same, with the Jäger trait (Road to 56's `jaeger_trait`) on Martola, Heiskanen and Vihma, and no `error.log` line naming either trait name.
  - Either playset showing a missing, doubled or erroring Jäger trait: stop and report; the planner records the finding in the register and decides the trait lists again.
- [x] 8. Ship (after the owner confirms): move this plan to `docs/plans/archive/`, commit with the message `feat(finland): <summary>`, then `powershell -File .\wiki\push-wiki.ps1`.

## Stop conditions

- A `new` or `addRole` leader in the `json leaders` block has no pick in "Leaders": stop; the planner runs the review loop.
- `-Generate`, `-ConvertPortraits` or `-Check` prints an `[ERROR]`: stop and report it whole.

## Outcome

Steps 1 to 6 carried out 2026-11-02 by lp-implementer. Steps 7 (game check) and 8 (ship) are left for the caller and the owner.
- `-Generate`: `Generated pack 'finland': 5 leader(s), 15 file(s) written, 0 removed.`
- `-ConvertPortraits`: `Pack 'finland': 4 portrait file(s) converted, 6 up to date.`
- `-Check`: `Check OK: 1 pack(s), 0 warning(s).`
- `-ValidateOnly`: `Validation succeeded.`
- `-Test`: `Summary: 282 Passed, 0 Failed, 0 Skipped (all suites)` (the rehearsal had 281 Passed, 1 Skipped; no failure).
- Deviations: none.

Verification by the implementing session, 2026-11-02: the same `-Check`, `-ValidateOnly` and `-Test` lines rerun in the repository; `git status` only the expected paths; `-PreviewPortraits` sheet: five large portraits and small cards intact, both new faces inside the card window. `lp-reviewer` implementation review: ready, no findings.

Game check, 2026-11-02, after `-DevLink -Pack finland` (`Loads: ...\mods\leader-packs\packs\finland`), each a new game as FIN:
- Vanilla: the owner saw Aaro Pajari and Einar Vihma in the army leader list with their portraits, names, skills and traits as planned, the small cards right, and one Jäger trait each on Martola, Heiskanen and Vihma. `error.log` (09:24): the 5 expected `recruit_character should only happen in game/history files` warnings, `lp_fin_on_actions.txt` lines 5 to 9, one per `new` leader [CHR-014]; no line naming `jaeger`, `jaeger_trait`, `lp_fin_characters.txt`, a portrait or a sprite.
- Road to 56: the same on screen, nobody twice, one Jäger trait each on the three. `error.log` (10:12): the same 5 warnings and nothing else naming the pack, the leaders or either trait name.
- Result: listing `jaeger` and `jaeger_trait` together keeps one Jäger trait on both playsets, with no `error.log` line on either; vanilla drops the undefined `jaeger_trait` as silently as Road to 56 drops `jaeger`. Recorded in the knowledge register (see [CHR-017]).

## Fact sheets

```markdown fact-sheets
## aaro_pajari

Aaro Pajari (1897-1949), Finnish Army; division commander.

- Joined the Suojeluskunta (Civil Guard) in 1917 and fought in the Civil War as a platoon leader and company commander. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Staff College, first course 1924-1926; general staff officer from 1931; head of the Suojeluskunta training department for two years. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Head of the Pohjois-Häme Suojeluskunta district 1932-1939. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Winter War: lieutenant colonel commanding Infantry Regiment 16 (JR 16); at Tolvajärvi on 12 December 1939, then an advance of about 40 km east to Aittojoki. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Led Osasto Pajari within Ryhmä Talvela, later the whole group. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Continuation War: commander of the 18th Division 1941-1943; the breakthrough on the Karelian Isthmus in August 1941 and the capture of Suursaari in 1942. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Major general from 3 October 1941. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Commander of the 3rd Division from 21 October 1943 to 21 October 1944: the defensive battles at the VT and VKT lines on the Karelian Isthmus in June 1944. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Credited with the capture of Tornio in the Lapland War, October 1944. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Knight of the Mannerheim Cross (2nd class) no. 12 on 14 September 1941, and again on 16 October 1944 for the capture of Tornio: a double recipient. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)
- Accused of beating political prisoners (Jalkala prisoner camp, from a prisoner's memoir); the charges were found baseless and the Allied Control Commission cleared him. Detained at Päämaja in October 1944 on the Commission's orders; no charges were filed. Source: https://fi.wikipedia.org/wiki/Aaro_Pajari (Aaro Pajari)

## einar_vihma

Einar August Vihma (born Wichmann, surname changed 1936; 1893-1944), Finnish Army; division commander.

- Jääkäri: joined Jäger Battalion 27 on 7 October 1915; sent to Finland on recruiting work in spring 1916, back with the battalion in April 1917, sent to Finland again in October 1917. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Attended the first course of the War College in 1926, without completing the diploma thesis; general staff officer title 8 March 1927. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Colonel from 6 December 1933; director of the Cadet School 1933-1936; commander of the Suomen Valkoinen Kaarti 1936-1939. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Winter War: first commander of the 1st Brigade, then third commander of the 10th Division; from 9 January 1940 to the end of the war commander of the 7th Division. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Interim peace: commander of the Helsinki military district. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Continuation War: commander of the 12th Division, then of the 6th Division from 18 December 1941 until his death; major general from 18 December 1941. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- August 1941: the 12th Division under Vihma pushed fast towards Terijoki on the Karelian Isthmus. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Summer 1944: the 6th Division was moved from East Karelia to Ihantala and reinforced Lagus' Panzer Division, which was close to breaking. Mannerheim's memoirs (p. 690) call him "the brave Major General Vihma" and say the division arrived in time to stabilise the defence at Ihantala. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma), quoting Mannerheim, Muistelmat
- Knight of the Mannerheim Cross, 12 October 1941. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- Led his troops from the front, personally armed, which made him a legend among his men; reported to have been caught in a motti while leading an attack. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma), citing Kouvolan Sanomat, 22 October 2005
- Killed by mortar fire on the church hill at Ihantala on 5 August 1944, with his chief of staff Gösta Palkama. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
- August-September 1941, Saunojankangas: Soviet prisoners were shot on the order of a captain, which Vihma approved; the Supreme Court convicted the captain and treated Vihma's order as a mitigating circumstance. Source: https://fi.wikipedia.org/wiki/Einar_Vihma (Einar Vihma)
```

## Leaders source

```json leaders
{
    "pack": "finland",
    "tag": "FIN",
    "prefix": "lp_fin",
    "displayName": "Finland",
    "leaders": [
        {
            "key": "armas_eino_martola",
            "name": "Armas-Eino Martola",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 1,
            "defense": 2,
            "planning": 3,
            "logistics": 2,
            "traits": ["jaeger", "jaeger_trait", "infantry_officer"],
            "factSheet": "armas_eino_martola",
            "portrait": {
                "photo": "armas_eino_martola",
                "role": "Finnish general",
                "headwear": "wearing a grey Finnish officer's peaked cap with a round cockade, a small metal badge above the band and a braided cord above the black visor",
                "uniform": "grey Finnish M36 officer's tunic with open collar, light shirt and dark tie, collar patches with a rank rosette",
                "avoidHeadwear": "field cap, side cap, helmet, fur hat",
                "notes": "clean-shaven",
                "born": 1896,
                "photoYear": 1938
            }
        },
        {
            "key": "kaarlo_heiskanen",
            "name": "Kaarlo Heiskanen",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 3,
            "defense": 2,
            "planning": 1,
            "logistics": 1,
            "traits": ["jaeger", "jaeger_trait", "infantry_officer"],
            "factSheet": "kaarlo_heiskanen",
            "portrait": {
                "photo": "kaarlo_heiskanen",
                "role": "Finnish general",
                "headwear": "bareheaded, short hair combed back from a high forehead",
                "uniform": "grey Finnish officer's tunic with a high stand-up collar edged with a darker band, a collar patch with a small button",
                "avoidHeadwear": "peaked cap, field cap, side cap, helmet, fur hat",
                "notes": "clean-shaven, calm stern expression",
                "born": 1894,
                "photoYear": 1938
            }
        },
        {
            "key": "oiva_koivisto",
            "name": "Oiva Koivisto",
            "mode": "new",
            "sameAs": [],
            "role": "navy_leader",
            "skill": 2,
            "attack": 1,
            "defense": 1,
            "maneuvering": 2,
            "coordination": 3,
            "traits": ["navy_career_officer"],
            "factSheet": "oiva_koivisto",
            "portrait": {
                "photo": "oiva_koivisto",
                "role": "Finnish admiral",
                "headwear": "wearing a dark navy officer's peaked cap with an embroidered anchor badge and a braided cord band above the black visor",
                "uniform": "dark navy double-breasted officer's coat with brass buttons and rank shoulder boards, binoculars on a strap around the neck",
                "avoidHeadwear": "field cap, side cap, helmet, fur hat",
                "notes": "clean-shaven, grey hair, lined face",
                "born": 1904,
                "photoYear": 1963
            }
        },
        {
            "key": "aaro_pajari",
            "name": "Aaro Pajari",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 3,
            "defense": 2,
            "planning": 2,
            "logistics": 1,
            "traits": ["infantry_officer", "war_hero"],
            "factSheet": "aaro_pajari",
            "portrait": {
                "photo": "aaro_pajari",
                "role": "Finnish general",
                "headwear": "wearing a grey Finnish general's peaked cap with a round cockade on the crown, a small lion badge on the band and embroidered oak leaves on the band above the black visor",
                "uniform": "grey Finnish M36 general's tunic with a stand-up collar, general's collar patches with a lion emblem, the Mannerheim Cross at the throat, a ribbon bar and an Iron Cross on the breast, a leather cross strap",
                "avoidHeadwear": "field cap, side cap, helmet, fur hat",
                "notes": "clean-shaven, broad heavy jaw, eyes looking level and straight ahead towards the viewer's left, not upward, irises centred under the lids in the shadow of the visor, stern expression",
                "born": 1897,
                "photoYear": 1942
            }
        },
        {
            "key": "einar_vihma",
            "name": "Einar Vihma",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 2,
            "attack": 2,
            "defense": 3,
            "planning": 1,
            "logistics": 1,
            "traits": ["jaeger", "jaeger_trait", "brave"],
            "factSheet": "einar_vihma",
            "portrait": {
                "photo": "einar_vihma",
                "role": "Finnish general",
                "headwear": "wearing a soft grey Finnish M36 side cap tilted to one side, with a small round cockade at the front and buttons on the side flap",
                "uniform": "grey Finnish M36 general's tunic with a stand-up collar, general's collar patches with a lion emblem and embroidered oak leaves, the Mannerheim Cross at the throat, a ribbon bar and the Jaeger Battalion 27 badge on the breast pocket, a leather cross strap",
                "avoidHeadwear": "peaked cap, visor cap, helmet, fur hat",
                "notes": "clean-shaven, lean deeply lined face, hard stern frontal stare",
                "born": 1893,
                "photoYear": 1943
            }
        }
    ]
}
```
