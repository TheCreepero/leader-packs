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

## Picture credits

The thumbnail and the gallery images use period photographs, colourised, then cropped and resized. Each picture links to its source record.

| Picture | Shows | Used for | Credit and licence |
|---|---|---|---|
| [JR 16:n komentopaikka. Tykistötukea suunnitellaan karttapöydän ääre...](https://www.finna.fi/Record/sa-kuva.sa-kuva%2F87891) | Finnish officers planning artillery fire over a map on a table in a forest | thumbnail of Immersive Commanders Expanded | SA-kuva-arkisto (M. J. Vuorela), CC BY 4.0 |
| [The Operations Room at RAF Fighter Command's No. 10 Group Headquart...](https://commons.wikimedia.org/wiki/File:The_Operations_Room_at_RAF_Fighter_Command%27s_No._10_Group_Headquarters,_Rudloe_Manor_(RAF_Box),_Wiltshire,_showing_WAAF_plotters_and_duty_officers_at_work,_1943._CH11887.jpg) | women of the Women's Auxiliary Air Force around the plotting table of an RAF operations room | cover of Immersive Commanders Expanded | Royal Air Force official photographer (F/O A. Goodchild), public domain |
