# Test card: Party Picker 1.1.2 (TEST build)

What 1.1.2 changes (docs/PLAN_1.1.2_live_roster.md): the Party tab redraws by itself when someone on it dies,
comes back, goes down, gets up or leaves a fight, and when the MCM window is opened. Ticks you have not applied yet
are kept. A companion the list still showed after they left gets a refusal with their name instead of "Unknown
character ...". Nothing runs between those events. Pak size and SHA-256: RUN_CARD.md. Install only with the game
closed, and check the hash. Record what you see in docs/TESTING.md (your own words are quoted there).

Use a throwaway save. The console lines are under "Console helpers" below. With Companion Permadeath active, a dead
companion leaves the party for good (docs/TESTING.md, 2026-10-31), so in steps 2 and 5 they **disappear** from the
list; without that mod they stay, tagged "dead" and greyed out (so they can still be resurrected), which is the
behaviour asked for on 2026-10-31.

| # | Do | Expect |
|---|---|---|
| 1 | Load a save. Open the Script Extender log. | `[PartyPicker] server loaded (v1.1.2). ...` and `[PartyPicker] client loaded (v1.1.2) ...` |
| 2 | Open MCM > Party Picker > Party and leave it open. In the console, kill a companion who is in the party. | Within about 2 seconds the list changes by itself (gone with Companion Permadeath, "dead" and greyed out without it). No Refresh needed. |
| 3 | MCM still open: down another party member. | Within about 2 seconds they are tagged "can't leave now". |
| 4 | Get them up again (the two "get up" lines). | Within about 2 seconds the tag goes. |
| 5 | Close MCM. Kill (or down) another companion. Open MCM again on the Party tab. | The list is already right when the window opens. |
| 6 | Tick or untick someone without pressing Apply, then down or get up a party member. | After the redraw your tick is still as you left it. |
| 7 | (If it comes up) A fight with the Party tab open, or opened during it. | During the fight members show "can't leave now"; shortly after it ends the tags go without Refresh. (A fight that keeps starting and ending redraws the tab once each time it ends; nothing is logged.) |
| 8 | (If it comes up) A list that still shows someone who has left, and you tick them and press Apply. | The message names them: "<Name> is no longer with the party or in camp (the list was out of date)." and the list redraws without them, keeping your other ticks. |

The 1.1.1 steps not yet done (docs/TEST_CARD_1.1.1.md steps 2-7: swap, trim, wake-up notice, dead member in the
long-rest window, profile switch, Halsin) still apply to 1.1.2.

The 1500 ms wait before the redraw (the game marks someone downed only half a second after it happens,
`__AAA_FirstGoal.txt` L1187-1203) cannot be checked offline: step 3 checks it.

## Console helpers
In the Script Extender console press Enter, type `server` and press Enter (the prompt reads `S >>`), then paste one
line at a time. Copy only the line that starts with `Osi.` (a pasted label such as "Kill:" is a Lua error: that
happened on 2026-11-01). Replace the ID with one from the list.

Kill:

Osi.Die("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")

Bring back:

Osi.Resurrect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")

Down (worked in game 2026-10-31: the log shows Gale downed and Party Picker refusing to move him):

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
