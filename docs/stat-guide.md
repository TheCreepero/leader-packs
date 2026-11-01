# Stat guide

How a pack's planner chooses each leader's role, `skill`, attribute skills and traits from his fact sheet, and how the `lp-reviewer` agent judges the choice. `build.ps1 -Check` enforces the mechanical part: every value inside `data/stat-bands.json` [CHR-006] [CHR-012], every trait in `data/<pack>/start-traits.json` for the role kind. Everything else here is judgment. Game facts are cited from the Manager's register, never restated: look them up with the `hoi4-modding-knowledge` skill.

This is a living document. When the owner or the reviewer changes a leader's stats for a reason that applies to others, record the reason here as a rule.

## Inputs

- The leader's section of the plan's `markdown fact-sheets` block: his ranks, commands and the "Facts for stats". A value with no fact behind it is not chosen.
- `data/stat-bands.json`: the range of each value per role kind (`army`, `navy`).
- `data/<pack>/start-traits.json`: the traits a unit leader of that kind may start with.
- Vanilla peers of the same country: two or three unit leaders of similar rank and fame, read with `Get-HoiCharacter -Tag <TAG> -Role <role>` or `-Id <id>` of the `hoi4-vanilla-lookup` skill. The pack's leaders sit beside them in the same lists.

## Role

- `field_marshal`: commanded an army, an army group, a front or theatre, or the whole army in the period. Otherwise `corps_commander`, also for a division commander.
- `navy_leader`: commanded a fleet, a squadron, a flotilla or the coastal defence at sea. A coastal artillery or naval base commander who never led ships is a `corps_commander` only when his facts show land command.
- An `addRole` leader takes the role his facts show, of a kind the target does not have in vanilla [CHR-013].

## Skill

`skill` is the leader's overall level. Set it from the largest command he held with a sourced result, then compare it with the vanilla peers.

| Command held in the period | Skill |
|---|---|
| A division or brigade, or a regiment in the war | 1 or 2 |
| A corps, a military district, a squadron | 2 or 3 |
| An army, a front, a fleet, with a sourced record of success | 3 or 4 |
| The country's best-known commander, whose record the sources rate above his vanilla peers | 4, and 5 only on the owner's word |

- Keep to vanilla's spread [CHR-006]: most leaders of a pack are 2 or 3. A pack whose leaders average higher than the country's vanilla leaders is wrong, however famous they were.
- A pack leader does not outrank the country's top vanilla commander unless the sources clearly put him above.
- A short or failed command counts by what was achieved, not by the size of the formation.

## Attribute skills

Army roles carry `attack`, `defense`, `planning`, `logistics`; navy roles `attack`, `defense`, `maneuvering`, `coordination`. Choose them from the facts, then keep their sum near the sum of vanilla peers of the same `skill`.

| Attribute | Facts that raise it |
|---|---|
| `attack` | Offensives, breakthroughs and counterattacks led; for an admiral, surface actions and raids |
| `defense` | Positions held, delaying actions, fortification works; for an admiral, convoy escort, minefields, coastal defence |
| `planning` | General staff posts, chief of staff of a corps or army, war college teaching, operations planned |
| `logistics` | Quartermaster, supply, mobilisation and transport posts; holding a front with little supply |
| `maneuvering` | Ship commands, destroyer and torpedo boat flotillas, fast movements at sea |
| `coordination` | Fleet staff posts, combined operations with the army or air force, commands of mixed squadrons |

- The attribute his facts point at most is the highest; one with no fact behind it stays at the bottom of its band or one above.
- Avoid maxing: no attribute at the top of its band, and at most one attribute one step below the top. Vanilla keeps the top values for a handful of leaders [CHR-006] [CHR-012].
- A leader's values differ from each other: four equal attributes say nothing about him.

## Traits

- Zero to two traits per leader, each resting on a fact in his section. Write the fact beside the trait in the plan's "Stat notes".
- Only traits in `data/<pack>/start-traits.json` for the role kind. Read what a trait does with `Find-HoiDefinition -Type trait <name>` (`hoi4-vanilla-lookup`), never from memory, and pick the one whose name and effect match the fact: a branch officer trait for a career in that branch, a terrain trait for a campaign fought in that terrain, a personality trait only when a source describes that trait in him.
- A trait named after a country appears in the start traits only when the pack's own country uses it; prefer it where it fits, as vanilla does for the country's own leaders.
- Every pack supports Road to 56, which renames or drops some vanilla traits; a leader given one loses it there without a word in `error.log` [CHR-017]. `rt56.undefined` in `start-traits.json` lists them, and `-Check` warns on each one chosen. Prefer another trait that rests on the same fact. Where none fits, `rt56.counterparts` may name a Road to 56 trait whose name holds the vanilla one, found by name alone; read its definition, and when it is the same trait, as `jaeger_trait` is for `jaeger` [RT56-014], list both names: the vanilla one first, then Road to 56's, which `-Check` accepts only beside it. The game alone then drops the Road to 56 name in turn; the first pack that lists both is checked in the game on both playsets.
- No trait is better than a guessed one.

## In the plan

Each leader's "Stat notes" line names the facts behind his role, skill, highest attribute and each trait, as `skill 3 (corps commander 1941-1944, fact 4)`. The reviewer judges the values against that line and this guide.
