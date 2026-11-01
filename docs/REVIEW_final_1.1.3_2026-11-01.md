# Whole-mod final review of Party Picker 1.1.3 (2026-11-01)

The author, 2026-11-01: "Then after the build is complete please conduct a whole-mod fresh review, as discussed
earlier for each new release."

## Method
- Baseline: `main` at 78e3f84 (1.1.3 TEST build, pak 63,790 bytes, SHA-256 708cec61...). Offline tests at the
  baseline: 308 server + 83 client checks pass.
- Skill `bg3-mod-final-review`. The mod has 3,039 lines of Lua, so three adversarial reviewers ran in parallel on all
  the code (not a diff), each with part of the checklist: (A) lenses 1 + 5, every delay is a window and failure
  handling; (B) lenses 2 + 6, every kind of character through every path and UI truth; (C) lenses 3 + 4 + 7, the
  game's own contracts, callbacks and events, docs against code. They had the code, the story scripts, the repo
  notes and the earlier reviews, not an opinion of the code.
- Every finding below was then traced by this session in the code and, for game behaviour, in the story files.
  Verdicts: **Confirmed**, **Narrower** (confirmed in a smaller case, named), **Partly**, **Not a defect**, **Wrong**.
- No game test was run for this review. All three reviewers: SHIP WITH NOTES, no blocker.

## Summary

| # | Finding | From | Verdict | Likely in play | Recommendation |
|---|---|---|---|---|---|
| 1 | Your own character dead: every party change is refused, the long-rest trim included, with a story-table message | B | Confirmed | Low-medium | Fix now (message; decide the rule) |
| 2 | Restore warnings reach only the status line, which opening the tab clears | A | Confirmed | Medium (a failed morning restore) | Fix now |
| 3 | Camp members the game holds (in a conversation, knocked out) are offered on the tab; ticking one refuses the whole Apply | B | Confirmed | Low-medium | Fix now |
| 4 | Nights the story starts itself (Act One celebration and others) skip the long-rest picker | C | Confirmed (story) | High with 5+ in Act One | Document now (verified limitation) |
| 5 | Release docs still describe 1.1.0 (about ten places) | B, C | Confirmed | Certain | Fix in the release docs |
| 6 | "Block party changes in combat" does not redraw the tab | C | Confirmed | Low | Fix now (one line) |
| 7 | Timed 1.5 s redraws still run beside the outcome redraw and drop unapplied ticks | B | Narrower | Low | Fix now (small) |
| 8 | A failed write of the trim record is silent and the trim goes ahead | A | Confirmed | Very low | Fix now (small) |
| 9 | A trimmed record is not resumed after loading a save | A | Confirmed in code; game case unknown | Unknown | Fix now (small) |
| 10 | "Keep everyone this time" pressed twice: the first timer ends the second early | A, C | Confirmed | Very low | Fix (small) |
| 11 | The long-rest window ignores a failed roster read | A | Confirmed | Very low | Fix (small) |
| 12 | The long-rest window says the others "rejoin when you wake up" also with auto-restore off | C | Confirmed | Low | Fix (text) |
| 13 | Party changes made with the game paused may finish only when the game resumes | A, B | Unverified (needs a game test) | Unknown | Test first |
| 14 | "Put Halsin's quest back on track" offered while Halsin is held | B | Confirmed | Low | Optional |
| 15 | Party-tab buttons stay pressable while their request runs | B | Confirmed, harmless | Low | Optional |
| 16 | Multiplayer: every player's character is labelled "(you)" | B | Confirmed | Multiplayer only | Optional |
| 17 | Multiplayer: reserved player slots not counted in the limit override | B | Partly (story cited; effect untested) | Multiplayer only | Leave, note |
| 18 | Multiplayer: a non-host pressing End the Day gets no word | A | Confirmed | Multiplayer only | Optional |
| 19 | The long-rest window is never redrawn by game events | B | Confirmed | Low | Leave (server re-checks) |
| 20 | Held state ("in a conversation") can go stale; a dropped untick is not explained | B | Confirmed, partly by design | Low | Leave (text says press Refresh) |
| 21 | The trim record can name the wrong people | A | Narrower | Very low | Leave |
| 22 | Halsin repair can stop half-way | A | Narrower | Very low | Leave |
| 23 | Minthara's and Minsc's recruit gate fails open on a failed read | A | Narrower | Very low | Leave |
| 24 | House of Hope attire handed out once, 1 s after the flag | A | Confirmed | Very low | Leave |
| 25 | A hireling taken from camp lowers the camp count even when the join fails | C | Narrower | Very low | Leave |
| 26 | The picker opens even when the story also blocks the rest | C | Confirmed | Very low | Leave |
| 27 | `!pp_set` with no names sends everyone movable to camp; it does not clear a waiting trim record | B, C | Confirmed (console only) | Very low | Optional |
| 28 | No guidance on removing the mod | A | Confirmed (docs) | Low | Add to the release docs |
| 29 | docs/REPORT_external_review_status_1.1.3.md listed DB_InBlockedWaypointZone as read | B, C | Confirmed | - | Fixed in this commit |

## The findings

### 1. Your own character dead blocks every change - Confirmed
`Party.HostAvatar` returns the host's own avatar while it is in DB_Players, dead or not (Server/Party.lua L250-260),
and Apply checks it first: `Party.BlockedReason(avatar, ...)` -> "Party changes are blocked: your character cannot
travel right now (DB_FastTravelBlock_CantMove_StatusSet)." (L764-765). The story makes every dead character unable
to move: `DB_Dead` -> `DB_CantMove_IgnoreDialog` (__AAA_FirstGoal.txt L2236-2242) -> `DB_CantMove`, and for party
members the travel block (_Waypoints.txt L187-211). So with your character dead and the companions alive, the tab,
"Keep these 4" in the long-rest window, Restore and the automatic restore are all refused, and the message names a
story table. Not known: whether the game itself lets you dismiss companions in that state (its dismiss is a
conversation with the companion, not with your character). The mock does not derive DB_CantMove from death, so no
test sees it. Fix: at least say "your character is dead: revive them first"; the author decides whether a dead host
character should block at all (the check exists so that changes are not made while your own character cannot move).

### 2. Restore warnings are lost - Confirmed
The give-up and "Nobody else could come back: ..." messages go out as a Notice (Server/Restrictions.lua L184-197).
A Notice reaches the client's status line and the long-rest window only if that window is open (BootstrapClient.lua
L57-65; Client/PickFour.lua L175-180). In the morning the window is closed, and opening the Party page clears the
status line (PartyTab.Activated). The nothing-to-do path also clears the record (Restrictions.lua L139-140). So a
player who wakes up with four never sees why. This leaves the external review's points 4 and 5 short of their aim:
the text is right but does not reach the player. Fix: send warning notices to the message window too
(PP.Net.Message, as LimitGuard does).

### 3. Camp members the game holds are offered - Confirmed
`stuck` is computed only for party members (BootstrapServer.lua L17). For a camp member, Apply's join check
(`JOIN_DBS`: DB_CantMove, DB_IsArrested, Party.lua L572-575) refuses the whole request (L778-781). DB_CantMove holds
anyone in a conversation, knocked out, petrified and so on (__AAA_FirstGoal.txt "CantMove", ~L2228-2345). So a camp
companion in a camp conversation can be ticked, and Apply then refuses everything. The long-rest window counts them
as optional. Fix: send a join reason for camp members; draw them like held party members (box fixed, a click says
why) and leave them out of the picker's optional count. This is the UI half of the external review's point 3.

### 4. Story-started nights skip the picker - Confirmed in the story
Party Picker holds the rest through the ready check (Restrictions.lua L244-258: a row in
DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason, read by QRY_Camp_AllPlayersReadyForNightMode, GLO_Camp.txt
L623). `PROC_Camp_ForceEndTheDay` skips it - the script says "No Ready Checks" (GLO_Camp.txt L790-812) - and is
called by Act1_CAMP_GoblinHuntCelebration.txt L209, Act1_GOB_Orpheus_Protection.txt L726, Act2b_CAMP.txt L140,
GLO_CampNights.txt L3060 and L3067. So on those nights there is no picker. What then happens to members five and up
is not known (not tested). Fix: a known-limitation line in the README and Nexus page naming these nights as "nights
the story starts itself", without saying what goes wrong; qualify "before a rest it asks".

### 5. Release docs describe 1.1.0 - Confirmed
README.md, NexusMods_BBCode.txt and NexusMods_Description.md: dead and held members are now clickable with a reason,
"downed" and "can't leave now" tags undocumented; the tab now redraws on game events, joins and leaves, control
changes, opening MCM, profile switches and outcomes, not only two settings; Send everyone to camp keeps held members;
the long rest counts dead and held members; Restore names who could not come back; the refusal list is incomplete
(can't talk, dialogue-suppressed area, arrested, camp night); the Halsin no-effect line; the combat untick behaviour
(finding in the 1.1.3 diff review). Version strings say 1.1.0 (INSTALL, BBCode, NexusMods_Description,
NEXUS_PAGE_FIELDS, which also names a file that does not exist); RELEASE_NOTES says "first public release" and must
not list the 1.1.1-1.1.3 fixes as tested in game; CHANGELOG has no 1.1.1-1.1.3 entries; INSTALL says Apply greys out
when nobody is ticked, which cannot happen for the host; README says Party Picker tells you "once" about a large
party, which is once per load. Fix: in the release-docs update.

### 6. The combat setting does not redraw the tab - Confirmed
`tabSettings` lists only max_party_size and halsin_early (BootstrapClient.lua L22-25); the held state depends on
block_in_combat (BootstrapServer.lua L12-19). Fix: add it.

### 7. Timed redraws drop unapplied ticks - Narrower
`WaitForRealtime(1500, PartyTab.Refresh)` after an accepted change and plain `Refresh()` calls remain (Client/
PartyTab.lua: Apply, Send everyone to camp, Restore, Halsin), beside the outcome redraw. Refresh without kept ticks
redraws from the party: ticks made in those 1.5 s, or before pressing Cancel on a confirmation, are lost. Narrower
than "the R4 fix is incomplete": the outcome redraw exists; the timed one is an extra. Fix: route them through
`PartyTab.SettingChanged`, which keeps ticks.

### 8. A failed write of the trim record is silent - Confirmed
`setPending` swallows errors (Restrictions.lua L51-54); `MarkTrimming` cannot tell; Apply logs a failed hook and goes
on (Party.lua L784-787). A failed RegisterModVariable is silent too (Shared/Common.lua L58-78). Unlike the
story-table reads (remark R2 of the external review), refusing here stops only the trim. Fix: setPending returns
success, MarkTrimming raises on failure, Apply refuses when the hook fails.

### 9. A trimmed record is not resumed after a load - Confirmed in code
The automatic restore starts only on LongRestFinished and the end of camp night (Restrictions.lua L260-268); the
LevelGameplayStarted handler does not look at the record (BootstrapServer.lua L162-166). A save loaded after the
wake-up (or after the five tries gave up) has members waiting in camp and only the Restore button. Whether the game
autosaves at that moment is not known. Fix: on LevelGameplayStarted, with a trimmed record and no camp night, run the
automatic restore (it respects auto_restore).

### 10-12. Small ones in the long-rest flow - Confirmed
10: `BypassOnce` starts a 120 s real-time timer per press with no counter (Restrictions.lua L66-69). 11: PickFour
does not check `reply.error` (Client/PickFour.lua; the Party tab does, PartyTab.lua L34). 12: the window's "rejoin
when you wake up" also shows with auto_restore off, when they only get a reminder (Restrictions.lua L166-172).

### 13. Changes with the game paused - Unverified
Apply's steps use game-time timers (Party.lua, `Ext.Timer.WaitFor`). If MCM opened from the pause menu stops game
time, the sends to camp happen at once and the joins only on resuming. Not tested; the mock ignores delays. Test
first.

### 14-28. Optional or left
Each traced; see the table. 14: `cannotMoveReason` checks only locked members (HalsinRepair.lua L273-281); the
server refuses with a reason. 15: the server's busy check refuses a second press with a message. 16: RosterList
`label` tags every avatar "you". 17: `PROC_CheckPartyFull` counts DB_PlayerSlotReserved (_GLO_Shared_PartyMembers.txt
L126-137); effect untested. 19-20: the server re-checks every request; the held text says to press Refresh. 21:
only when someone is recruited by conversation while the picker is open. 22: each step is pcall'd and logged. 23:
only if the story table is missing. 24: a load within that second. 25: Hirelings.txt L448-451; the mod's checks make
a failed join rare. 26: both reasons fail together (GLO_Camp.txt L629-639). 27: console only.
28: removing the mod with more than four restores the four-bed problem; whether the raised limit survives in the
save is not known (Party.lua L306-308).

## General remarks
- The game's contracts: every procedure call and listener matches the story scripts and story_header.div (21
  listeners checked); the leave checks cover every cause of the game's dismiss lock except combat, which is the
  setting. The external review's fixes are complete as built, point 4 partial by design.
- The offline mock's blind spots, now named: both timer kinds in one queue with delays ignored; mod variables are
  live tables (a sub-field write "persists" in tests but not in the game); requests answered synchronously; death
  does not derive DB_CantMove; the game's own procedures do not raise CharacterJoinedParty/LeftParty; one listener
  per event. Findings 1, 9 and 13 hid behind these.

## Recommendation
Before the next release: 1 (at least the message), 2, 3, 6, 7, 8, 9, 10, 11, 12 in one fix build (1.1.4), through
plan -> plan review -> code -> diff review -> build, each test failing on 1.1.3; 4 and 5 and 28 in the release docs;
13 as a game test step. 14-16, 18, 27 optional; 17, 19-26 left, with the reasons above. The author decides.
