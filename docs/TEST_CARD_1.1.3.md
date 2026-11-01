# Test card: Party Picker 1.1.3 (TEST build)

What 1.1.3 changes (docs/PLAN_1.1.3_dead_member_notice.md): a dead party member still cannot be unticked (the game
blocks dismissing the dead), but clicking their box now explains why, the box stays ticked, and the label reads
"(dead)" instead of "(dead, dead)". The same goes for a member the game holds right now (downed, in a conversation,
in combat with that setting on). Downed shows even for the character you control. The tab also follows recruiting
and dismissing in the game's own conversations, a change of the character you control, and the engine's own hold
on movement. Everything else is 1.1.2. Pak size and SHA-256: RUN_CARD.md. Install only with
the game closed, and check the hash. Record what you see in docs/TESTING.md (your own words are quoted there).

Use a throwaway save, with Companion Permadeath off (it takes the dead out of the party, docs/TESTING.md
2026-10-31). The console lines are under "Console helpers" below.

| # | Do | Expect |
|---|---|---|
| 1 | Load a save. Open the Script Extender log. | `[PartyPicker] server loaded (v1.1.3). ...` and `[PartyPicker] client loaded (v1.1.3) ...` |
| 2 | Open MCM > Party Picker > Party. Kill a companion who is in the party. | Within about 2 seconds they show as "Gale  (dead)", ticked, with grey text. |
| 3 | Click their box. | It stays ticked. A small "Party Picker - Message" window and the status line say: "Gale is dead. Dead party members cannot be removed from the party here. Revive them first (a scroll, a spell, or Withers once he is at your camp), or ask Withers to dismiss them." Close the window with OK. |
| 4 | Untick a living companion and press Apply. | The living one goes to camp; the dead one stays in the party. |
| 5 | Bring the dead companion back (console "Bring back" line, a scroll, or Withers). | Within about 2 seconds the "(dead)" tag goes and their box can be unticked as usual. |
| 6 | (If it comes up) A long rest with a dead party member and 5 or more in the party. | In the "keep four" window the dead member is ticked; clicking them keeps the tick and the window's status line gives the same reason; the count does not change. |
| 7 | (Optional) Your own character dead, if a save allows it. | "(you, dead)", box greyed and not clickable, as before (Party Picker never moves your own characters). |
| 8 | MCM open on the Party tab: down a companion (console "Down" line). | Within about 2 seconds: "Gale  (downed, can't leave now)", ticked, grey text. Clicking the box keeps the tick, and the window and status line say "Gale is downed, so they can't leave the party right now. Press Refresh once that has changed." |
| 9 | Get them up (healing or the two console lines). | Within about 2 seconds the tags go and the box can be unticked (also when the engine holds them a moment longer after getting up). |
| 10 | Take control of a companion, then down that companion. | "(downed, you are controlling them)". Switch to another character: within about 2 seconds the "you are controlling them" lock moves with you. |
| 11 | With MCM open, dismiss a companion in a camp conversation, then recruit them again the same way. | The list follows each change within about 2 seconds, without Refresh. |
| 12 | (If it comes up) A fight with the Party tab open, with "block in combat" on (the default). | Every party member shows "can't leave now", stays ticked and greyed, and a click explains "... is in combat, so they can't leave the party right now ...". This is new in 1.1.3: an untick made during (or just before) the fight is not kept; untick again once the fight is over. |

Steps 2-8 of docs/TEST_CARD_1.1.2.md and steps 2-7 of docs/TEST_CARD_1.1.1.md still apply to 1.1.3.

## Console helpers
In the Script Extender console press Enter, type `server` and press Enter (the prompt reads `S >>`), then paste one
line at a time. Copy only the line that starts with `Osi.`. Replace the ID with one from the list.

Kill:

Osi.Die("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")

Bring back (worked in game 2026-11-01):

Osi.Resurrect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")

Down (worked in game 2026-10-31 and 2026-11-01):

Osi.ApplyStatus("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "DOWNED", -1, 1)

Get up again (two lines, one after the other):

Osi.RemoveStatusesWithType("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "DOWNED", "NULL_00000000-0000-0000-0000-000000000000")

Osi.SetHitpoints("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", 1)

Companion IDs: Shadowheart `S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679`;
Lae'zel `S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12`; Gale `S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604`;
Astarion `S_Player_Astarion_c7c13742-bacd-460a-8f65-f864fe41f255`; Wyll `S_Player_Wyll_c774d764-4a17-48dc-b470-32ace9ce447d`;
Karlach `S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c`; Jaheira `S_Player_Jaheira_91b6b200-7d00-4d62-8dc9-99e8339dfa1a`;
Minsc `S_Player_Minsc_0de603c5-42e2-4811-9dad-f652de080eba`; Halsin `S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323`;
Minthara `S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b`.
