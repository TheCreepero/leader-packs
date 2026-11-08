# Testland pack: fixture plan

Status: READY
Pack: testland (TST, prefix lp_tst)
Kind: new leaders
Created: 2026-11-08
Snapshot: data/testland/game-characters.json refreshed 2026-11-08

## Context

A plan for the tests of build.ps1 -ApplyPlan and -RehearsePlan. It changes the attack of alpha_leader, replaces the fact-sheet section of alpha_leader, adds one section, and gives two showcase cards. Its tables are those of the fixture repository.

## Leaders

| Key | Name | Mode | Ids (target; sameAs) | Role | Stats | Traits | Photo | Portrait (round, pick) | Status |
|---|---|---|---|---|---|---|---|---|---|
| alpha_leader | Alpha Leader | new | none; none | corps_commander | 3 / 4 2 2 2 | infantry_officer | alpha (CC BY) | r1, seed 2 | ready |
| bravo_leader | Bravo Leader | new | none; TST_bravo_old, TST_bravo_renamed | field_marshal | 4 / 3 4 3 2 | brilliant_strategist, infantry_officer | bravo | r1, seed 2 | ready |
| charlie_leader | Charlie Leader | new | none; none | navy_leader | 2 / 1 3 2 2 | spotter | charlie | round 1, pick 2 | ready |
| delta_advisor | Delta Advisor | addRole | TST_delta_advisor; none | corps_commander | 3 / 2 3 3 2 | none | delta | r1, seed 2 | ready |
| echo_admiral | Echo Admiral | addRole | TST_echo_navy_chief; none | navy_leader | 3 / 2 2 3 3 | seawolf | echo | r1, seed 2 | ready |
| foxtrot_marshal | Foxtrot Marshal | skip | none; none | none | none | none | none | none | skip |

## Photos

| Photo key | Source and id | Licence (author or credit) | Size | Leader |
|---|---|---|---|---|
| alpha | commons `File:Calling of reservists 1939 (Numeroimaton; JOKAHBL3B J06-1).tif` | CC BY (CC BY 4.0); Hugo Sundstrom | 6588x4590 | alpha_leader |
| bravo | commons `File:Abatis at Taipale.jpg` | PD (Public domain); unknown author | 4962x3248 | bravo_leader |
| charlie | commons `File:A Finnish guard during the Battle of Salla.jpg` | CC0 (CC0); Finnish Wartime Photograph Archive | 3412x4959 | charlie_leader |
| delta | commons `File:Abatis at Taipale.jpg` | PD (Public domain); unknown author | 4962x3248 | delta_advisor |
| echo | commons `File:A Finnish guard during the Battle of Salla.jpg` | CC0 (CC0); Finnish Wartime Photograph Archive | 3412x4959 | echo_admiral |

## Review rounds

| Leader | Round | Seeds | Decision | Change for the next round |
|---|---|---|---|---|
| alpha_leader | 1 | 1-4 | pick 2 | none |
| bravo_leader | 1 | 1-4 | pick 2 (owner: "good") | none |
| charlie_leader | 1 | 1-4 | pick 2 | none |
| delta_advisor | 1 | 1-4 | pick 2 | none |
| echo_admiral | 1 | 1-4 | pick 2 | none |

## Implementation steps

- [ ] 1. `powershell -File .\build.ps1 -ApplyPlan -Plan docs\plans\testland-plan.md`

## Fact sheets

```markdown fact-sheets
## alpha_leader

- A corps commander of the fixture country, now with a second fact. Source: https://example.org/alpha
- He held the line at the bridge. Source: https://example.org/alpha-2

## bravo_leader

- A field marshal of the fixture country, known under two ids. Source: https://example.org/bravo

## foxtrot_marshal

- A skip leader with a note of his own. Source: https://example.org/foxtrot
```

## Showcase cards

```json showcase
{
    "leaders": {
        "alpha_leader": {
            "card": ["Held the line at the bridge.", "A corps commander of \"Testland\"."],
            "years": [1894, 1960]
        },
        "bravo_leader": {
            "card": ["A field marshal known under two ids."],
            "years": [1892]
        }
    }
}
```

## Leaders source

```json leaders
{
    "pack": "testland",
    "tag": "TST",
    "prefix": "lp_tst",
    "displayName": "Testland",
    "leaders": [
        {
            "key": "alpha_leader",
            "name": "Alpha Leader",
            "mode": "new",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 3,
            "attack": 4,
            "defense": 2,
            "planning": 2,
            "logistics": 2,
            "traits": ["infantry_officer"],
            "factSheet": "alpha_leader",
            "portrait": { "photo": "alpha", "role": "Testland general", "headwear": "wearing a soft grey field cap", "uniform": "grey field uniform with collar patches", "avoidHeadwear": "peaked cap, helmet", "notes": "", "born": 1894, "photoYear": 1943 }
        },
        {
            "key": "bravo_leader",
            "name": "Bravo Leader",
            "mode": "new",
            "sameAs": ["TST_bravo_old", "TST_bravo_renamed"],
            "role": "field_marshal",
            "skill": 4,
            "attack": 3,
            "defense": 4,
            "planning": 3,
            "logistics": 2,
            "traits": ["brilliant_strategist", "infantry_officer"],
            "factSheet": "bravo_leader",
            "portrait": { "photo": "bravo", "role": "Testland field marshal", "headwear": "bareheaded", "uniform": "grey general's uniform", "avoidHeadwear": "cap, hat, helmet", "notes": "", "born": 1892, "photoYear": 1938 }
        },
        {
            "key": "charlie_leader",
            "name": "Charlie Leader",
            "mode": "new",
            "sameAs": [],
            "role": "navy_leader",
            "skill": 2,
            "attack": 1,
            "defense": 3,
            "maneuvering": 2,
            "coordination": 2,
            "traits": ["spotter"],
            "factSheet": "charlie_leader",
            "portrait": { "photo": "charlie", "role": "Testland admiral", "headwear": "wearing a naval peaked cap with an anchor badge", "uniform": "dark blue naval uniform", "avoidHeadwear": "field cap, helmet", "notes": "", "born": 1905, "photoYear": 1941 }
        },
        {
            "key": "delta_advisor",
            "name": "Delta Advisor",
            "mode": "addRole",
            "target": "TST_delta_advisor",
            "sameAs": [],
            "role": "corps_commander",
            "skill": 3,
            "attack": 2,
            "defense": 3,
            "planning": 3,
            "logistics": 2,
            "traits": [],
            "factSheet": "delta_advisor",
            "portrait": { "photo": "delta", "role": "Testland general", "headwear": "bareheaded", "uniform": "grey general's uniform", "avoidHeadwear": "cap, hat, helmet", "notes": "", "born": 1890, "photoYear": 1939 }
        },
        {
            "key": "echo_admiral",
            "name": "Echo Admiral",
            "mode": "addRole",
            "target": "TST_echo_navy_chief",
            "sameAs": [],
            "role": "navy_leader",
            "skill": 3,
            "attack": 2,
            "defense": 2,
            "maneuvering": 3,
            "coordination": 3,
            "traits": ["seawolf"],
            "factSheet": "echo_admiral",
            "portrait": { "photo": "echo", "role": "Testland admiral", "headwear": "wearing a naval peaked cap with an anchor badge", "uniform": "dark blue naval uniform", "avoidHeadwear": "field cap, helmet", "notes": "", "born": 1898, "photoYear": 1942 }
        },
        {
            "key": "foxtrot_marshal",
            "name": "Foxtrot Marshal",
            "mode": "skip",
            "reason": "A field marshal in Road to 56 (TST_foxtrot_marshal); the base game keeps him an advisor and addRole would make him one twice there."
        }
    ]
}
```
