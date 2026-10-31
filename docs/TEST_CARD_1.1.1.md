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
| 6 | MCM: switch to another MCM profile with a different Maximum party size, with the Party tab open. | The tab's "Limit:" line changes by itself within a second. |
| 7 | (Optional, an Act Two save with "Let Halsin join early" and a dead party member) Put Halsin's quest back on track. | Halsin goes to camp and the quest is put back on track; the dead member stays. |

The fast-travel/dismiss checks (plan Unit L) have no dedicated step (the author, 2026-10-31: "It would be too time
consuming to check this in game."). Step 2 is ordinary use; any refusal you see there is worth copying.
