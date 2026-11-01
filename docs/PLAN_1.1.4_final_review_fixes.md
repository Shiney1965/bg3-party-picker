# Plan: Party Picker 1.1.4 - the fixes recommended by the 1.1.3 final review

The author, 2026-11-01: "Fix all the recommended ones in 1.1.4, Also the player character death should block party
picker and the player should receive a message if they attempt to change the party makeup before the PC is revived.
That would mimic normal game behavior I think (please check). However, for a later build let's create a toggle that
would allow the player to override this block and change the party composition even without the PC being alive."

Findings: docs/REVIEW_final_1.1.3_2026-11-01.md (numbers below are its numbers). Code fixes here: 1, 2, 3, 6, 7, 8,
9, 10, 11, 12; 13 is a test-card step; 4, 5 and 28 go into the release docs (a separate step after this build).

## "Mimic normal game behaviour" - what the game's scripts say (checked 2026-11-01)
- Settled: every dead character is put in DB_CantMove (DB_Dead -> DB_CantMove_IgnoreDialog, __AAA_FirstGoal.txt
  L2236-2242, -> DB_CantMove), and a party member in DB_CantMove gets TRAVELBLOCK_CANTMOVE and
  DB_FastTravelBlock_CantMove_StatusSet (_Waypoints.txt L187-194). Party Picker's own rule is "the game's fast-travel
  restrictions"; blocking while your character is dead is consistent with it.
- Not settled: the game's own recruit and dismiss conversations have no check on the player's character being alive
  in the scripts read (_GLO_Shared_Origins.txt has no DB_Dead/IsDead; the dismiss lock is about the companion being
  dismissed, _GLO_Shared_PartyMembers.txt L232-395). Whether the travel status alone stops fast travel is engine-side.
  So "the base game blocks this" is not confirmed; the block is the author's choice, and the override toggle (below)
  is the way back.

## Units

### A. Your own character dead (finding 1)
- Server: `Party.HostDeadText()` - the host's avatar (`Party.HostAvatar()`) is dead (Osi.IsDead == 1): returns
  "Your character (<Name>) is dead. Party Picker can't change the party until they are revived (a scroll, a spell, or
  Withers once he is at your camp)." else nil.
- Server Apply: checks it first, before the avatar's BlockedReason, and refuses with that text (so the message names
  death, not a story table). Covers the Party tab, the long-rest "Keep these N", Restore, the automatic restore,
  Halsin's repair and !pp_set (all go through Apply). "Keep everyone this time" does not go through Apply (it only
  lets the rest go ahead) and stays possible.
- rosterReply sends `hostDead = text`.
- Party tab: shows the text under the limit line; pressing Apply, Send everyone to camp (the Yes button), Restore or
  the Halsin button with `hostDead` set shows it in the message window and the status line and sends nothing.
- Long-rest window: shows the text; "Keep these N" disabled; "Keep everyone this time" stays.
- Automatic restore: an attempt refused for this reason stops retrying and sends one warning (B makes it visible);
  the record stays, so Restore or the next wake-up brings them back once the character is revived.
- Not in 1.1.4: the override toggle (the author: "for a later build"), recorded in docs/IDEA_dead_pc_override.md.

### B. Restore warnings reach the player (finding 2)
`Restrictions.Notice(text, "warning")` also broadcasts `PP.Net.Message` (the message window, host only), as
LimitGuard does. Info notices stay status-line only.

### C. Camp members the game holds (finding 3)
- rosterReply computes `joinBlocked` for camp members (not active, not locked) with `Party.JoinBlockedReason(e.id,
  checkCombat)` - the same check Apply makes.
- Party tab (RosterList): such a member's box is fixed unticked, grey text, tag "can't join now"; a click keeps it
  unticked and shows "<Name> <reason>, so they can't join the party right now. Press Refresh once that has changed."
  (the story table in brackets left out, as HeldText).
- Long-rest window: such members are drawn locked (reason in the label) and not counted as optional.
- Restore (addOnly) is unchanged: the server already makes them wait.

### D. The combat setting redraws the tab (finding 6)
`block_in_combat` joins `tabSettings` in BootstrapClient.lua.

### E. Redraws keep the ticks not yet applied (finding 7)
- `PartyTab.Redraw()`: an immediate redraw that keeps unapplied ticks (the snapshot SettingChanged takes, without its
  500 ms wait). `SettingChanged` = the wait + Redraw.
- When Apply (or Yes on Send everyone to camp, Restore, the Halsin button) is accepted, the tab remembers the ticks
  sent (`slot.sentTicks`, the set of uuids ticked at the press). The next snapshot compares with that set instead of
  the party as drawn, so only ticks changed after the press are kept, and a change the game did not complete shows
  as it really is. The set is cleared when the next roster reply is drawn.
- Every `Ext.Timer.WaitForRealtime(1500, PartyTab.Refresh)` and every `PartyTab.Refresh()` after a confirmation,
  Cancel or refusal becomes `PartyTab.Redraw` (the timer passes its handle; Redraw ignores arguments). The Refresh
  button and opening our page (Activated) still start fresh, as now.

### F. A failed write of the trim record stops the trim (finding 8)
- `setPending` returns true/false; `MarkTrimming` raises when the write fails or does not read back as trimmed.
- Party.Apply: when `opts.beforeChange` raises, refuse ("Party Picker could not save its record of who to bring back
  in the morning, so nobody was sent to camp.") instead of logging and going on. It runs before `busy` is set, so a
  refusal leaves nothing half done.
- Shared/Common.lua: a failed RegisterModVariable logs one line.

### G. A trimmed record resumes after a load (finding 9)
`Restrictions.ResumeAfterLoad()`, called from the LevelGameplayStarted listener: with a trimmed record and no camp
night (DB_Camp_NightMode(1) absent), start the automatic restore (it respects auto_restore and a running change).

### H. "Keep everyone this time" twice (finding 10)
A counter per reason: a 120 s expiry clears the bypass only if no newer press came since.

### I. The long-rest window and a failed roster read (finding 11)
With `reply.error`: show "Could not read the party: <error>", no list, "Keep these N" not drawn; "Keep everyone
this time" stays.

### J. The long-rest window's text with auto-restore off (finding 12)
With `auto_restore` off (PP.Setting on the client): "The others wait in camp; press Restore on the Party tab to bring
them back when you wake up." instead of "rejoin when you wake up".

### K. Version 1.1.4
PP.VERSION "1.1.4"; meta.lsx L35 and L38 Version64 computed with python; L15 untouched.

## Tests (each must fail on 1.1.3 at 9238991)
Server: A - Apply refused with the death text when the host avatar is dead (and the mock must derive the refusal
from death, not from a hand-set table), rosterReply hostDead, an automatic restore refused for death stops and warns
once; B - a warning notice also sends Message; C - joinBlocked for a camp member in DB_CantMove; F - Apply refuses
when the hook fails, nothing moves; G - ResumeAfterLoad starts the restore with a trimmed record, not at camp night,
not without a record; H - a second press survives the first timer.
Client: A - the tab line, Apply sends nothing and shows the window, the picker's Keep these N disabled; C - the camp
member fixed unticked with the reason, the picker leaves them out of the optional count; D - block_in_combat
redraws; E - a tick made after an accepted Apply survives the timed redraw, a failed join is not shown ticked, Cancel
keeps ticks; I - error reply; J - auto_restore off text.

## Test card (docs/TEST_CARD_1.1.4.md)
Your character dead (console Kill on your avatar): the tab line, Apply's message, the long-rest window; a camp
companion in a conversation; turning the combat setting off mid-fight; finding 13 (changes made with the game
paused from the pause menu: does the change finish before you resume?).

## Steps
Plan review (adversarial subagent) -> code -> tests, run against 1.1.3 -> diff review (adversarial subagent) ->
version bump -> pak from an LF export -> RUN_CARD + test card -> commit + push. Then the release docs (4, 5, 28).
Not installed, not released (those wait for the author).

## Plan review (adversarial subagent, 2026-11-01): APPROVE WITH CHANGES, no blocker
Taken (these override the units above):
1. A: a host can own several avatars (QRY_GLO_AvatarCanBeDismissed, _GLO_Shared_PartyMembers.txt L1866-1880). The
   block applies only when NONE of the host's avatars in DB_Players is alive; HostAvatar prefers a living one. A
   non-host's dead avatar does not block (they are locked and kept; the host's avatar recruits and dismisses).
2. A: the automatic restore checks `Party.HostDeadText()` itself before each attempt (no matching on message text):
   one warning, no retries; it starts again when a host avatar is resurrected.
3. A: the check sits in Apply next to the host's own BlockedReason, after the nothing-to-do return, so a restore with
   nothing left to do still clears its record. The Halsin repair with Halsin in camp does not go through Apply
   (HalsinRepair.lua TabReset) and is not blocked. The client does not block on its own (its `hostDead` can be ~2 s
   stale): the server refuses, and its reply carries `hostDead = true` so the tab shows the refusal in the message
   window. The tab line stays as information. A downed host avatar gets "your character is downed" instead of the
   story table.
4. C: dead camp members are excluded (`not e.dead`: they are disabled as before, and every dead character is in
   DB_CantMove); a fixed-UNticked variant of the click (Checked = false, ticked false); the pick-four window locks its
   copies, so they are not counted as optional.
5. G: only on the first LevelGameplayStarted of a Lua session (a load), not on every level change; that run gives up
   quietly (status line, no message window).
6. Tests: the mock derives DB_Dead -> DB_CantMove (and the travel block) from death; the auto-restore test asserts no
   retries; H fires a single timer; F makes the write fail; G is driven through the LevelGameplayStarted listener;
   E with a held roster reply drawn before the outcome.
Also taken: E uses the server's `busy` (rosterReply) and a request sequence: `sentTicks` is shown while the change
runs and cleared only by a reply requested after the press with `busy == false`; the Refresh calls that open a
confirmation become Redraw too. B: only the automatic restore's warnings open the message window (Apply's "partly
updated" results stay in the status line and the pick-four window, to avoid the same text twice). J: INTRO becomes a
function.

## As built (differences from the units above)
- A: the long-rest window shows the death line but leaves "Keep these N" enabled; the server refuses with the same
  text (its status line shows it). The Party tab's line is shown to the host only.
- I: after a failed roster read the window draws "Keep these 0" disabled rather than leaving it out.
- The test mock now derives DB_Dead -> DB_CantMove (and the travel block) from death (`M.setDead`, every existing
  `.dead =` in the server tests converted) and keeps every listener of an event, as the game does.

## Diff review (adversarial subagent, 2026-11-01): DO NOT SHIP (one blocker), fixed
1. (blocker) After "Send everyone to camp" > Yes the members sent to camp stayed ticked on every later redraw:
   `sent()` recorded only those who stay, and Redraw compared the ticks on screen against it. Fixed with two sets:
   `pressTicks` (ticked on screen at the press: the baseline for kept ticks) and `sentTicks` (what was sent: shown
   while the change runs). Test: 14E "after Send everyone to camp, they show unticked ... and stay unticked".
2. (should-fix) A save made between "Keep these 4" and the second End the Day would have been restored on load (and
   a revive in that gap did the same). The record gets `rested = true` at the wake-up triggers (LongRestFinished,
   the end of camp night); ResumeAfterLoad and the Resurrected restart require it. Test 37G.
3. (should-fix) `refusedForDeath` flagged any refusal while the PC is dead: now only when the message is the death
   text. Test 37A.
4. (should-fix) Other players saw "Your character (<host>) is dead": the line is host-only. Test 14A.
5. (minor) HostAvatar now prefers a living avatar over a dead controlled one. 6: a restore that brought people back
   but skipped someone is a warning with the message window. 7: plan text brought in line (above). 10: comments.
Left: 8 (with auto-restore off the waiting reminder can come again after a load; acceptable); 9's first-load wiring
cannot be driven twice in one Lua state, so the positive case calls ResumeAfterLoad directly and the test card checks
it in game. Tests: 324 server + 101 client; of the new checks 10 server and 12 client fail on 1.1.3.

## Re-review of the fixes (adversarial subagent, 2026-11-01): SHIP WITH NOTES, no blocker
Verified: the blocker is fixed for Apply, Send everyone to camp, Restore and Halsin, in both slots; the sets cannot
stick (Refresh, Activated and any later non-busy reply clear them); refusedForDeath's compare is stable; OnTrimmed
keeps `rested`; markRested cannot run between MarkTrimming and OnTrimmed (no changes at camp night). Taken:
1. (should-fix) A new night's hold (ask, with a record left trimmed from an earlier night) writes a new table
   without `rested`. Test "37G: a new night's hold: not rested yet".
2. (minor) The baseline for kept ticks is what the list was drawn from (`slot.baseline`: the ticks on screen at the
   press, then the sent ticks once a busy reply drew them, then the party), not the ticks at the press throughout:
   a redraw while "Send everyone to camp" ran made a member the game kept in the party show unticked. Test 14E "a
   change that left someone in the party shows them ticked again" (fails with the press-time baseline).
3. (minor) The automatic restore's death warning is host-only (`hostOnly` on the Notice; other clients skip it).
4. (minor) A record saved by 1.1.3 after the rest has no `rested` mark: it waits for the next wake-up or Restore
   (on the test card).
Tests: 325 server + 103 client.

## Release docs (findings 4, 5, 28) and their review (adversarial subagent, 2026-11-01): FIX FIRST, fixed
dist_docs updated for 1.1.4 (README, INSTALL, CHANGELOG, RELEASE_NOTES, NexusMods_BBCode, NEXUS_PAGE_FIELDS;
NexusMods_Description.md, the .docx/.pdf copies and the repository README regenerated by tools/make_docs.ps1).
Fixed after the review: (B1) "Before removing" said nothing in the save is used without the mod - the raft rows are
in the game's own raft table and stay in use; (B2) ticks are kept on the automatic redraws, not when opening the
page or pressing Refresh; (S1) the tested-in-game lines name the build (v1.1.0 and earlier; test build v1.1.2, the
downed case from the log); (S2) the restore's message window is on waking only (after a load: the status line);
(S3) resuming after a load needs "Bring everyone back after the rest" on and a save made after the rest; (M1)
refusals name the table only where there is one; (M2) "dead companion or hireling"; (M4) Restore first, then down to
four; (M5) only members in combat are held. M6 ("Tested with Script Extender v33") checked: the 2026-11-01 log says
"SE version 33". The old wording was searched for in every copy (md, txt, docx text) after regenerating: none left;
the docx and pdf files (metadata included) contain no occurrence of the author's name.
