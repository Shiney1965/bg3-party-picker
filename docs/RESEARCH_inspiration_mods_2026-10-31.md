# Research: other Inspiration mods - their methods and the conflicts reported (2026-10-31)

The author, 2026-10-31: "Please resume work on the incorporation of the inspiration limit settings. Please review
the existing [Inspiration] limit mods to see what methods they are using to control inspiration and what
incompatibilities if any have been noted with those mods."

Rule for this work (the author, 2026-10-24): other mods are read only to learn what they touch and where they clash.
None of their code, structure, setting names or labels goes into Party Picker. "Method" below means which game data
or engine call a mod changes, as stated on its page or seen in a file list; no code was copied.

## How the mods were found
- Nexus public GraphQL API (no login), BG3 = gameId 3474: name contains "inspiration" (19 mods), and description
  search for "inspiration point", "inspiration cap", "inspiration limit".
- The author's own Mods folder: all 2,664 paks scanned for text files that mention Inspiration (4 paks unreadable:
  ASTRL_Lifelike, ArcaneHuntress, KaiLimeUI_C, SD_BT1). Each hit was matched to its module UUID from the pak's own
  meta.lsx and checked against modsettings.lsx.
- Each page's bug reports and comments were read in a browser on 2026-10-31.

## The game's own definition (for reference)
`ActionResourceDefinitions`, `InspirationPoint`, UUID `a9c98304-08e7-44b5-aaf9-da2ef5a50672`, MaxValue 4,
`PartyActionResource` true, ReplenishType Never (as re-declared unchanged in Astarion's Book of Hungers' pak, and in
the plan docs/PLAN_inspiration_and_30.md from the game's Shared data).

## Methods in use

| Mod (Nexus id) | Method | Needs SE |
|---|---|---|
| No Inspiration Point Cap (629), 303,939 downloads | Overrides the InspirationPoint definition with MaxValue 999999; nothing else changed (two commenters who unpacked it, 2023-10-09 and 2024-05-08) | No |
| Reduced Inspiration Point Cap (738) | Same family: definition override with MaxValue 3/2/1/0 (page) | No |
| Inspiration Cap (12967) | Definition override, MaxValue 99 or 16; "This MOD merely overrides the game's default settings" (author, 2026-07-17) | No |
| Inspirations Uncapped (mod.io only) | Definition override with MaxValue 999999 **and a changed UUID** (commenters on 12967, 2026-03-04/05) | No |
| Restorable Inspiration Points (3154) | Add-on: definition override (100000/20/10/5/3/2/1). Main file: SE script that refills points after a long rest | Main file only |
| Dynamic Inspiration (24633), 2026-09-01 | Definition override (MaxValue 9999, seen in the pak on this PC) plus SE + MCM: `Osi.PartyGetActionResourceValue` / `Osi.PartyIncreaseActionResourceValue`, `Ext.StaticData.Get`, mod variables; Osiris listeners on dialog, lockpicking, trap-disarm and trade start/end (its per-check spending limit) and LevelGameplayStarted; grants extra goal points by changing the goal reward data, not by hooking the reward event | Yes |
| Configurable Party Limit (11172) 1.2.0+ | SE changes the cap at runtime to follow the party size or the party limit (changelog 1.2.0; "dynamically adjusts the game's default settings via the Script Extender", 12967's author, 2026-07-17) | Yes |
| True Consequences (23725) | SE; MCM option that disables Inspiration rerolls | Yes |
| No Inspiration Cost (615), Unlimited ReRoll (21425) | Reroll cost set to 0 (pages; method not stated) | No |
| EasyCheat (installed, active) | Console/MCM cheat: `Osi.PartyIncreaseActionResourceValue(entity, "InspirationPoint", n)` | Yes |

Party Picker's parked code (branch `inspiration-feature`, Server/Inspiration.lua) is in the Configurable Party Limit
family: it writes `MaxValue` on the `Ext.StaticData` "ActionResource" entry at runtime, and changes points with
`Osi.PartyIncreaseActionResourceValue`. It ships no definition override.

## Conflicts and problems reported

1. **Two mods that set the cap fight; the last writer wins.**
   - Configurable Party Limit 1.2.0-1.2.1 forced the cap back to 4 even with its option off. Dynamic Inspiration's
     author: "I can confirm that this mod does conflict with Dynamic Inspiration" (2026-09-05). Same with Inspiration
     Cap (12967 comments, 2026-07-17/20; one user went back to CPL 1.1.0).
   - CPL 1.2.2 (changelog): disabling the option "does not do anything to the inspiration cap, so other mods can take
     over. It would previously set it to 4." It does not restore the cap when switched off.
   - True Consequences: a Dynamic Inspiration user reported it as the cause of the cap staying at 4 (2026-09-10).
   - So a runtime SE write beats a data override, and two SE writers race. Same-family data overrides (629, 738,
     12967, Inspirations Uncapped) simply replace each other by load order; 12967's author lists them as conflicts.
2. **Changing the UUID breaks saves.** Inspirations Uncapped changed the definition's UUID. Reported: rerolls not
   offered (12967 author, 2024-11-12, 2026-03-19), and after uninstalling, the counter "hard set to 0" for the rest
   of the game (commenter, 2026-03-23); points "reset to zero" and new events give none (Dynamic Inspiration
   comment, 2026-09-01). One commenter could reroll at 84 points with it, so the reroll report is disputed.
3. **Stored points at exactly 10, 20, ... act as 0** (629 bug, 2023-09-01): no reroll until the next point. The mod
   author: "Possibly a game bug". Not re-tested since 2023.
4. **Points that never arrive or show only on some characters** (629 bugs, 2023-2024): "All my followers get
   unlimited inspiration, but my Durge ... gets none"; "getting the alerts but no points being added". One commenter
   (2024-05-08) saw the reroll option missing after a failed roll and judged it a vanilla issue.
5. **The cap snaps back to 4** after a reload or long rest (Dynamic Inspiration comment, 2026-09-05: cause was CPL)
   and after game patches with old paks (629 comments, 2023).
6. **A lower cap does not cut points already held**, and a raised cap gives no points (12967 author, 2024-11-13;
   3154 author, 2023-10-11).
7. **Multiplayer:** 629 "seem to trigger a version mis-match or infinite loading screen" for the joining player
   after Hotfix 27 (bug, 2024-10-06), together with other mods.
8. **Granting points from the reward event** makes the popup show a number out of step with the inventory
   (Dynamic Inspiration author, 2026-09-05), which is why that mod changes the goal reward data instead.

## The author's load order (modsettings.lsx, 1,620 modules, 2026-10-31)
- Active and touching Inspiration: **EasyCheat** (position 55; adds points with PartyIncreaseActionResourceValue),
  **HT Lesser Restoration** (757; story fix that grants 4 points at Ebon Lake), **Community Library** (8; ID table
  only), Hope Once More (flags only).
- Installed but **not active**: Dynamic Inspiration (override MaxValue 9999), Astarion's Book of Hungers (re-declares
  MaxValue 4), DnD 5.5e All-in-One BEYOND, Ancient Mega Pack + REL, Ultimate Cheat Spells.
- Configurable Party Limit, True Consequences and Inspiration Cap: not installed.
- Raphael Joins the Party (the author's own mod) defines its own resource `RJTP_InfernalCharge` and does not touch
  InspirationPoint (src/Public/.../ActionResourceDefinitions.lsx and Stats/Generated/Data/Passive.txt).
- So no active mod changes the cap. The 2026-10-28..31 reports (points only on Raphael, counter 0) are not explained
  by another Inspiration mod in the load order.

## What this means for Party Picker (options, most likely first)
1. **Ship a definition override for the cap, choose the value at build time** (like 629/738/12967, same UUID, only
   MaxValue changed). Most reports of it working; no SE involved; but a fixed number, not an MCM slider, and it is
   replaced by any later definition override in the load order.
2. **Runtime SE cap (the parked design) but write only when the player turns it on, and never write 4 when off**
   (the lesson of CPL 1.2.0 -> 1.2.2). Keeps the MCM slider; still races any other SE writer (CPL with its option on,
   True Consequences).
3. **Leave the cap to other mods and only offer the point controls / a warning.** Lowest risk; the least feature.

Any option: never change the definition's UUID (finding 2); never write the cap when the player has not asked; detect
CPL's Inspiration option and the definition overrides above and warn; and first settle why the author's points
landed only on Raphael (finding 4 is the same pattern on other PCs), before trusting any point count.

## Open questions to test
- Does the game keep a party resource on one character, and which one? (The author's probe found one entity with an
  InspirationPoint entry, Raphael.) Test: a save without Raphael Joins the Party, grant 1 point with the game's own
  `GiveInspirationPoints`, read every party member's entry.
- Do the 10/20/... display bug and the missing reroll still happen in Patch 8 with a definition override alone?

Sources: nexusmods.com/baldursgate3/mods/629, 738, 12967, 3154, 24633, 11172 (changelog tab), 23725, 615, 21425,
6337, 5883, 9382, 16653, 15928, 22493 (descriptions, posts and bugs tabs, read 2026-10-31).
