# Test card: Party Picker 1.1.1 (TEST build)

What 1.1.1 changes: the fixes from the external review (docs/REVIEW_external_2026-10-31.md, plan
docs/PLAN_1.1.1_review_fixes.md). Pak size and SHA-256: RUN_CARD.md. Install only with the game closed, and check
the hash. Record what you see in docs/TESTING.md (your own words are quoted there).

Make a hard save before step 3.

| # | Do | Expect |
|---|---|---|
| 1 | Load a save. Open the Script Extender log. | `[PartyPicker] server loaded (v1.1.1). Console (server context): !pp_roster  !pp_set Name1,Name2  !pp_restore  !pp_size  !pp_forget Name  !pp_halsin` |
| 2 | Party tab: send one companion to camp and bring one back, as you normally would (in camp and out in the world). | Both work as in 1.1.0. If one is refused, the message names the reason and a story table in brackets, e.g. `(DB_CantMove)`. Please copy that message. |
| 3 | With 5 or more in the party, in camp: End the Day. In the window, keep four and press **Keep these 4**. | Both buttons grey out at once. The window then says the party was trimmed; press End the Day again; rest. |
| 4 | Wake up. | Everyone who waited in camp comes back, and **one** notice says who joined (not two). If a companion is busy in a morning camp conversation, they may stay in camp and the notice says so; press Restore on the Party tab afterwards. |
| 5 | (If it comes up) A long rest with a dead party member and 5 or more in the party. | The window counts the dead member towards the four: e.g. with you, two dead and two living companions it asks for 4 and **Keep these 4** can be pressed. |
| 6 | MCM profile switch, without closing the MCM window (steps below the table). | When you come back to the Party tab, its "Limit:" line already shows the other profile's number. |
| 7 | (Optional, an Act Two save with "Let Halsin join early" and a dead party member) Put Halsin's quest back on track. | Halsin goes to camp and the quest is put back on track; the dead member stays. |

## Step 6 in detail: switching MCM profiles
MCM keeps every mod's settings in a "profile"; the default one is called Default. Its profile page is the
**Profile management** entry in the left-hand menu of the MCM window (BG3-MCM, `UIProfileManager.lua`: a dropdown
of profiles, then "Create a new profile" with a name box and a **Create** button). Creating a profile also switches
to it at once (same file: `CreateProfile`, then `SetProfile`). MCM's own page warns "Profile changes require a reload
to take effect." - that is about mods in general; Party Picker reacts to the switch straight away.
1. Set up (once): in Profile management type a name, e.g. `PPTest`, and press **Create** (you are now on PPTest).
   Go to Party Picker > Settings and set Maximum party size to a number different from Default's and **not below
   your current party size** (a lower number is refused). Then in Profile management pick **Default** in the dropdown.
2. The test: go to Party Picker > Party and note "Limit: N". Without closing the MCM window, go to Profile management,
   pick **PPTest** in the dropdown, then go back to Party Picker > Party.
3. Expect: "Limit:" shows PPTest's number (in 1.1.0 it kept the old number until MCM was reopened). Switch back to
   Default the same way and the old number comes back. Leave Default selected when you are done.

## Console helpers for steps 5 and 7: dead and downed companions
Use a throwaway save. In the Script Extender console press Enter, type `server` and press Enter (the prompt reads
`S >>`), then paste one line at a time. Replace the ID with one from the list below.
- Kill (story function `Die`; the one-argument form killed an NPC in game in the Roah Moonglow test, 2026-08-30):
  Osi.Die("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")
- Bring back (story function `Resurrect`, used this way for companions in `_GLO_Shared_PartyMembers.txt` L1218):
  Osi.Resurrect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")
- Down (NOT yet tried in game: applies the game's `DOWNED` status, `Status_DOWNED.txt`):
  Osi.ApplyStatus("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "DOWNED", -1, 1)
- Get up again (the game's own two lines, `Act1_CHA_ShadowHeartRecruitment.txt` L462-463):
  Osi.RemoveStatusesWithType("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "DOWNED", "NULL_00000000-0000-0000-0000-000000000000")
  Osi.SetHitpoints("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", 1)
- Check: `_D(Osi.DB_Downed:Get(nil))` lists the downed (the game adds a row half a second after the status lands,
  `__AAA_FirstGoal.txt` L1187-1203); `Osi.IsDead("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604")` returns 1 for dead.

Companion IDs (from the game's story scripts): Shadowheart `S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679`;
Lae'zel `S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12`; Gale `S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604`;
Astarion `S_Player_Astarion_c7c13742-bacd-460a-8f65-f864fe41f255`; Wyll `S_Player_Wyll_c774d764-4a17-48dc-b470-32ace9ce447d`;
Karlach `S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c`; Jaheira `S_Player_Jaheira_91b6b200-7d00-4d62-8dc9-99e8339dfa1a`;
Minsc `S_Player_Minsc_0de603c5-42e2-4811-9dad-f652de080eba`; Halsin `S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323`;
Minthara `S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b`.

What Party Picker should show: a dead member is tagged "dead" and counts towards the four in the long-rest window
(step 5). A downed member is held by the game (`DB_Downed` puts them in `DB_CantMove`, `__AAA_FirstGoal.txt`
L2277-2283 and L2324-2330): on the Party tab they are tagged "can't leave now", and "Send everyone to camp" leaves them in the party.

The fast-travel/dismiss checks (plan Unit L) have no dedicated step (the author, 2026-10-31: "It would be too time
consuming to check this in game."). Step 2 is ordinary use; any refusal you see there is worth copying.
