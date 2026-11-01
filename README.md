# Leader Packs

Historical generals, field marshals and admirals for each nation, with portraits painted from period photographs.

## Overview

- **Game**: Hearts of Iron IV
- **Supported Version**: `1.19.*`
- **Mod Version**: `1.0`
- **Tags**: Historical,Military,Gameplay


---

## Directory Architecture

One source repository, published as one Workshop item per country ("Commanders Pack: <Country>"). The file formats and switches are in `docs/source-format.md`.

```
leader-packs/
|-- build.ps1                       # Lifecycle commands and the pack switches (-Generate, -Check, -MakePortraits, ...)
|-- packs/<pack>/                   # One complete mod root per country: descriptor.mod, thumbnail.png, generated content
|-- source/<pack>/                  # leaders.json, fact sheets, photos.json, portraits.json, chosen portraits
|-- data/                           # Game snapshots, start traits, stat bands, card geometry, Workshop links
|-- assets/                         # Master art assets
|-- artifacts/                      # Packaged release archives (git-ignored)
|-- tests/                          # Automated Pester test suites
|-- tools/                          # LeaderPacks.ps1, convert_portraits.py and the shared build engine
\-- wiki/                           # GitHub documentation wiki
```

---

## Development & Automation Commands

All lifecycle tasks are managed through `build.ps1`:

```powershell
# 1. Deploy mod to local Paradox Interactive Hearts of Iron IV mod folder
.\build.ps1 -Deploy

# 2. Configure zero-copy DevLink (the launcher loads this folder itself; restart the game to see a change)
.\build.ps1 -DevLink

# 3. Validate syntax and bracket balance without deploying
.\build.ps1 -ValidateOnly

# 4. Run automated test suites (Pester)
.\build.ps1 -Test

# 5. Package clean release zip archive
.\build.ps1 -Package

# 6. Publish to Steam Workshop (Dry Run preview)
.\build.ps1 -PublishSteam -DryRun

# 7. Clean deployed mod files and temporary archives
.\build.ps1 -Clean
```

---

## Automated Testing

Unit tests are written with [Pester](https://pester.dev) and located in `tests/`. Execute tests using:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

---

## Author & License

- **Author**: TheCreepero