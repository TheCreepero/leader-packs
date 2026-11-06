# Leader Packs Wiki

Historical generals, field marshals and admirals for Hearts of Iron IV that the game leaves out, one Workshop item per country (`Commanders Pack: <Country>`) and one bundle item with all of them. Every portrait is an AI-assisted repaint of a period photograph from Wikimedia Commons; each pack's page lists the photographs with their source, author and licence.

## Packs
- [Commanders Pack: Finland](Commanders-Pack-Finland)
- [Commanders Pack: France](Commanders-Pack-France)
- [Commanders Pack: Poland](Commanders-Pack-Poland)

## The bundle
- "Immersive Commanders Expanded" holds every country's pack in one Workshop item. Subscribe to it or to single packs, not both.
- Loading it from the repository: `build.ps1 -DevLink -Pack all` links the packs' files into one git-ignored `.devlink` folder; `build.ps1 -DevLink -CheckLinks -Pack all` reports links that a checkout or pull broke.

## About the packs
- Each pack works alone and beside any other pack.
- Each pack needs a new game [SCR-077].
- With The Road to 56, a commander that mod already gives is left out, so nobody appears twice.

## Developers
- [Contributing](Contributing)
