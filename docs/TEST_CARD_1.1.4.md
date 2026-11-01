# Test card: Party Picker 1.1.4 (TEST build)

What 1.1.4 changes (docs/PLAN_1.1.4_final_review_fixes.md, from docs/REVIEW_final_1.1.3_2026-11-01.md): with your
own character dead, Party Picker refuses every party change and says so (the author's decision, 2026-11-01); a camp
companion the game is holding can't be ticked and says why; restore warnings come in a message window; the tab
keeps your unapplied ticks through its own redraws; a waiting long-rest party is brought back after loading a save;
smaller fixes in the long-rest window. Everything else is 1.1.3 (docs/TEST_CARD_1.1.3.md still applies). Pak size
and SHA-256: RUN_CARD.md. Install only with the game closed, and check the hash. Record what you see in
docs/TESTING.md (your own words are quoted there).

Use a throwaway save. Console lines are under "Console helpers" below.

| # | Do | Expect |
|---|---|---|
| 1 | Load a save. Open the Script Extender log. | `[PartyPicker] server loaded (v1.1.4). ...` and `[PartyPicker] client loaded (v1.1.4) ...` |
| 2 | MCM > Party Picker > Party open. Kill your own character (console "Kill your character"). | Within about 2 seconds the tab shows "Your character (<name>) is dead. Party Picker can't change the party until they are revived ...". |
| 3 | Untick a companion and press Apply (also try "Send everyone to camp" > Yes). Other players in multiplayer do not see the line. | Nothing changes; a message window and the status line give the same text (no story-table name). |
| 4 | Bring your character back (console "Bring your character back", or a scroll/spell). | Within about 2 seconds the line goes; Apply works again. |
| 5 | (If it comes up) A long rest with 5 or more while your character is dead. | The "keep four" window shows the same line; "Keep these 4" is refused with it; "Keep everyone this time" still works. If members were already waiting in camp, one message says they wait until your character is revived, and they come back by themselves once revived. |
| 6 | In camp, start a conversation with a camp companion (not in the party), then open the Party tab without ending it. | That companion shows "(in camp, can't join now)", unticked, grey; a click keeps it unticked and says "<Name> can't move right now ..., so they can't join the party right now. Press Refresh once that has changed." |
| 7 | Tick a camp companion, press Apply, and tick another one straight away (within a second). | After the redraw, the second tick is still there; the first change shows as it really is. Same with "Send everyone to camp" > Cancel: your ticks stay. After "Send everyone to camp" > Yes, those sent to camp show unticked. |
| 8 | In a fight with the Party tab open: switch Settings > "No party changes in combat" off. | Within about a second the "can't leave now (is in combat)" tags go. |
| 9 | (If it comes up) A morning when someone can't come back (dead in camp, or held). | A message window names who could not come back and why (in 1.1.3 it was only in the status line). |
| 10 | (If it comes up) Save the morning after a long rest while members still wait in camp (the Restore button shows), then load that save. | About 2 seconds after loading they come back by themselves (with "Bring the party back after the rest" on). The log shows `server loaded (v1.1.4)` once for that load. A save made after "Keep these 4" but before the second End the Day keeps them in camp when loaded (you rest as usual). A save made with 1.1.3 or earlier while members waited does not bring them back on load: press Restore (or they come back after the next rest). |
| 11 | With "Bring the party back after the rest" off, a long rest with 5 or more. | The window says the others wait "until you press Restore on the Party tab after the rest." |
| 12 | (Review finding 13, a question for the game) Open MCM from the pause menu (Esc), change the party there, and watch before closing the menu. | Note whether the change finishes while the game is paused or only after you return to it. |

## Console helpers
In the Script Extender console press Enter, type `server` and press Enter (the prompt reads `S >>`), then paste one
line at a time. Copy only the line that starts with `_D(` or `Osi.`.

Your character's id (copy what it prints, with the quotes, into the next lines):

_D(Osi.GetHostCharacter())

Kill your character (replace ID with that id):

Osi.Die("ID")

Bring your character back:

Osi.Resurrect("ID")
