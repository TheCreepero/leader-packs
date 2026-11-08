---
name: leader-pack-implement
description: >-
  Use when carrying out a finished Leader Packs plan file from docs/plans (Status READY or IN PROGRESS):
  "implement", "apply", "continue" or "ship" a pack plan, or a plan path given as the argument. Dispatches the
  lp-implementer subagent, verifies its result and the converted portraits, has lp-reviewer review it, offers
  the owner's game check, and ships on the owner's word. Does no research and makes no portraits; for those
  use leader-pack-create or leader-pack-audit.
---

# Leader Pack: implement a plan

Carries out one plan written by `leader-pack-create` or `leader-pack-audit`. The plan holds every leader, stat, trait and fact sheet, and the planning already fetched the photos and recorded the owner's portrait picks, so the work is mechanical: `lp-implementer` does it in a fresh context, and this session verifies and ships.

## Rules
- **The plan is the only source.** No new leader, no other stat or trait, no other photo or portrait, no research. A plan that looks wrong goes back to its planner (section 5).
- **The pack changes only through `build.ps1`**, run by the implementer.
- `build.ps1`, `tools/`, `data/`, the tests, the skills, the agents, `AGENTS.md` and `docs/` other than the plan are not edited.
- **The game starts only on the owner's word.** Offer the game check; never start the game or ask an agent to.
- The commit and the wiki push wait for the owner's word (section 6).

## 1. Find the plan
1. Take the plan path from the request. With none, `Grep -n '^Status:'` across `docs/plans/` for `READY` or `IN PROGRESS`; with more than one or none, ask the owner which.
2. `PLANNING`: stop; the plan belongs to its planning skill. `READY` or `IN PROGRESS`: section 2. `DONE`: section 3.

## 2. Dispatch
Dispatch `lp-implementer` with the prompt `Carry out docs/plans/<file>.md` and nothing else. One plan per dispatch. It writes `leaders.json` and the fact sheets from the plan, then runs `-Generate`, `-ConvertPortraits`, `-Check`, `-ValidateOnly` and `-Test`; a plan with a `-ApplyPortraitReview -Withdraw` step also has it delete that leader's chosen PNG and withdraw his portrait record. Antigravity: pass the brief's path to `invoke_subagent`; where no subagent can be dispatched, read the brief and follow it yourself.

## 3. Verify
The report is a claim. Check:
1. `powershell -File .\build.ps1 -Check -Pack <pack>` ends `Check OK`, and every `[WARN]` is in the plan's "Kept on judgment".
2. `powershell -File .\build.ps1 -ValidateOnly` ends `Validation succeeded.`; `powershell -File .\build.ps1 -Test` has no failed test.
3. `git status --short` lists only `source/<pack>/`, `packs/<pack>/`, `data/<pack>/` (a snapshot the planning refreshed), `research/<pack>/` (the plan's dossier and its `Used:` marks), `wiki/Commanders-Pack-<Country>.md` and the plan, and, from `-Generate`, the bundle's `packs/all/WORKSHOP_DESCRIPTION_GUIDELINES.md` (its country list and portrait licences follow the packs; `-Check -Pack all` ends `Check OK`). For a new pack `tools/HoiModBuild.json` also lists it (the pack's own entry and the bundle's `members`).
4. The plan says `Status: DONE`, every box but the ship and game-check steps is ticked.
5. Look at the converted portraits: `powershell -File .\build.ps1 -PreviewPortraits -Pack <pack>` writes PNG copies of the pack's large portraits and small cards, and a sheet, to `scratch/preview/<pack>/`. Open the sheet with the Read tool. A face cut by the card's photo window, or a card that is blank, goes back to the planner; the picks themselves are the owner's and are not judged here.

Then dispatch `lp-reviewer` for an implementation review, with the task as the owner asked it, the plan path and the summary lines of the three commands; the `-Test` line of check 2 goes to every implementation review, because the reviewer runs no `-Test` itself. Fix nothing yourself: Critical or Important findings go back to the planner (section 5).

## 4. The owner's game check
Offer it, and run nothing until the owner says to:
1. `powershell -File .\build.ps1 -DevLink -Pack <pack>`: the launcher loads `packs/<pack>/` from the repository. To see the pack inside the bundle, offer `powershell -File .\build.ps1 -DevLink -Pack all` instead: it links every pack's files into the git-ignored `.devlink/immersive_commanders_expanded/` folder and points the launcher at it. The bundle and the single pack of the same release load together without a duplicate [LOAD-022]. After a `git checkout` or `pull` run `powershell -File .\build.ps1 -DevLink -CheckLinks -Pack all`: it reports broken links and changes nothing; `-DevLink -Pack all` again rebuilds the folder.
2. The owner starts a **new** game as the pack's country with the pack enabled, once on vanilla and, when they play it, once on their Road to 56 playset. A loaded save shows nothing: the pack recruits only in a new game [SCR-077] [CHR-003].
3. What the owner looks at:
   - the Officer Corps: each `new` general and field marshal with his name, large portrait, skill levels and traits as the plan gives them;
   - the navy's admiral list: each `new` admiral with his portrait [CHR-015];
   - the small cards in the advisor list and the leader lists, for every `new` leader and for each `addRole` advisor, whose small card stays the vanilla one [CHR-013] [CHR-005];
   - each `addRole` advisor: still hireable as an advisor, and now a unit leader with the new large portrait;
   - on Road to 56: nobody appears twice (a `skip` or renamed person) [RT56-011].
4. Then read `Documents\Paradox Interactive\Hearts of Iron IV\logs\error.log` for lines naming `lp_<tag>` files. One warning line per `recruit_character` in `common/on_actions/lp_<tag>_on_actions.txt` is expected [CHR-014]; count them against the `new` leaders. Any other line naming a pack file is a finding.
5. Record what the owner saw and the log result in the plan's "Outcome", and tick the game-check step.

## 5. When it stops
The implementer reported `STOPPED`, a check failed, the reviewer found a problem, or the game check showed one. Leave the files, report to the owner (the step, the exact output, what the plan would need), and stop. Once the plan is corrected, dispatch again: the implementer resumes at the first unticked step.

## 6. Report and ship
Report: the `-Check` line, the files changed, the reviewer's verdict, the game-check result, and that the plan is ready to ship. Then stop.

On the owner's word:
1. Tick the ship box.
2. Move the plan to `docs/plans/archive/`: `git mv` when tracked, `Move-Item` and `git add` when new.
3. Commit the files from section 3.3 with the plan at its archived path, with the message the ship step gives.
4. `powershell -File .\wiki\push-wiki.ps1`. If it fails, report the output; the commit stands.
5. Report the commit and the wiki push, and end with: "Start `/leader-pack-release` in a new session; the shipped plan and the pack hold everything." Do not start the release in this session.

Publishing to the Workshop is a separate decision: `leader-pack-release`.
