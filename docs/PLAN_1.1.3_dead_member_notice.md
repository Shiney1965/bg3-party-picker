# Plan: Party Picker 1.1.3 - a dead party member says why it cannot be unticked

The author, 2026-11-01 (docs/TESTING.md): "After Gale dies as a party member the party picker displays him as
(dead, dead).  But then he cannot be unclicked to remove him from the party." After the log check and the options:
"I think that if the base game locks dead party members in the party then we should keep that for not, and fork
out an option for a later release to remove that removal restriction and send them to camp instead. The current
build for release should have warning message when you click on a dead party member that dead party members
cannot be removed from the party."

## What is there now (verified in code)
- Server/Party.lua L412-414: a party member who is dead is `locked` with `lockReason = "dead"`. Apply keeps every
  locked party member (L694) and refuses a dead one by name (L725-726). This stays as it is: the game blocks
  dismissing the dead (dead -> DB_CantTalk_IgnoreStatuses, __AAA_FirstGoal.txt L2040-2045 -> DB_CantTalk L2068-2074
  -> DB_BlockDismissable, _GLO_Shared_PartyMembers.txt L241-249).
- Client/RosterList.lua L17 adds the tag "dead" and L23 adds the lock reason, also "dead": "(dead, dead)".
- RosterList.lua L62: `cb.Disabled = true` for locked or dead entries. A disabled IMGUI checkbox reports no click:
  bg3se `Checkbox::StyledRender` calls OnChange only when `ImGui::Checkbox` returns true (IMGUI.cpp L1435-1441,
  bg3se main aa1d509), and a disabled item never does. So the click does nothing and says nothing.

## Units

### A. Label: no repeated tag (Client/RosterList.lua `label`)
The lock reason is added only when it is not already one of the tags. Gale reads "Gale  (dead)". Every other label
is unchanged (no other lock reason equals a tag: "player character", "you are controlling them", "controlled by
another player", the off-stage text, the not-recruitable reasons, PickFour's "can't leave now: ...").

### B. A dead party member answers a click (Client/RosterList.lua `Draw`)
For an entry with `e.dead and e.active and e.locked` when the list is not read-only:
- the checkbox is NOT disabled, is drawn ticked, and keeps the greyed look with `cb:SetColor("Text", {0.5, 0.5,
  0.5, 1.0})` in a pcall (bg3se Lua binding `SetColor` = `StyledRenderable::SetStyleColor`, IMGUI.inl L24;
  Objects.h L184);
- its OnChange, when the box was unticked (`checked == false`), puts it back (`cb.Checked = true`; Checked is a
  plain field the renderer reads every frame, Objects.h L755, IMGUI.cpp L1437), leaves `ticked[e.uuid]` true, and
  calls `opts.onLocked(e, text)` if given, with
  text = "<Name> is dead. Dead party members cannot be removed from the party (the game does not allow it).
  Revive them first (a scroll, a spell or Withers at camp), then untick them."
  Withers revives dead party members: GLO_Jergal.txt L537-539 (and the 2026-11-01 console revive in TESTING.md).
- `opts.onChange` is not called for that click (nothing changed); Selected() still leaves locked members out, so
  Apply and the kept-ticks code (PartyTab.lua L291, which skips dead and locked) are unchanged.
Everything else stays disabled as now: other locked members, a dead camp member (not in the party: not asked for),
and every entry when the list is read-only (multiplayer non-host).

### C. Where the warning shows
- Party tab (Client/PartyTab.lua `render`): `onLocked = function(_, text) setStatus(text); MessageWindow.Show(text) end`
  - the small OK window already used for the over-limit warning (PartyTab.lua L78), plus the status line so it is
  still there after the window is closed. MessageWindow.Show does nothing for a non-host (MessageWindow.lua L28), and
  a non-host's list is read-only anyway.
- Pick-four window (Client/PickFour.lua): `onLocked = function(_, text) status.Label = text end` (its own status
  line, L114), not a second window over the picker. `status` is created after the list, so the callback reads it
  when clicked (it is an upvalue assigned before any click can happen).

### D. Fork for a later release: send a dead member to camp
Not built. Written up in docs/IDEA_dead_members_to_camp.md with what is already known (the game's block above;
Withers revives dead companions who are on the team but not in the party, GLO_Jergal.txt L578-599; the removal
procedure moves nobody, _GLO_Shared_PartyMembers.txt L636-699, so the body would stay where it fell) and what is not
(what camp scripts do with a dead body outside the party; any story rule that assumes dead companions are in the
party). CLAUDE.md "Open issues" points to it.

### E. Version 1.1.3
`PP.VERSION = "1.1.3"`; meta.lsx L35 and L38 Version64 = 36169540949770240 (1<<55 | 1<<47 | 3<<31, python); L15
(MCM dependency) untouched.

## Tests (tests/test_client.lua, new section 11) - each must fail on 1.1.2
1. Party tab, Gale dead in the party: the label is exactly "Gale  (dead)"; the box is ticked and not disabled.
2. Unticking it: the box is ticked again, the status line and a message window carry "Gale is dead. Dead party
   members cannot be removed from the party", no Apply request is sent, and the count line is unchanged.
3. Apply after that click sends no uuid for Gale (Selected leaves locked members out).
4. Read-only (IsHost false): the dead member's box stays disabled; no message window.
5. A dead camp member (dead, not active): still disabled, label "(dead)" once.
6. Pick-four window: unticking a dead party member re-ticks it and puts the text in the window's status line; the
   "Keep these N" count is unchanged.
7. Other locked members unchanged: "Tav  (you)" stays disabled; a "you are controlling them" member's label is the
   same as in 1.1.2.
Fake: checkboxes need `SetColor` (record it) and tests 4 need a way to make IsHost return false for one render.
Server tests: none change (no server code changes); the whole suite must still pass.

## Steps
Plan review (adversarial subagent) -> code -> tests, run against 1.1.2 too -> diff review (adversarial subagent) ->
version bump -> pak from an LF export -> RUN_CARD + docs/TEST_CARD_1.1.3.md -> commit + push. Not installed, not
released (those wait for the author).

## Plan review (adversarial subagent, 2026-11-01): APPROVE WITH CHANGES
Verified by the reviewer: the story and bg3se citations above; `SetColor("Text", {r,g,b,a})` is valid (GuiColor
`Text`, Enumerations/IMGUI.inl L361); no other lock reason equals a tag; nothing reads `cb.Disabled` on roster boxes;
multiplayer read-only stays disabled. Taken (these override the units above):
1. (blocker) "(the game does not allow it)" is not true: Withers flags a dead companion or hireling in the party as
   dismissable (GLO_Jergal.txt L556-564) and his "Dead Party management" teleports the body to its camp spot and
   removes it from the party (L1099-1185; checked). Text as built: "<Name> is dead. Dead party members cannot be
   removed from the party here. Revive them first (a scroll, a spell or Withers at camp), or ask Withers at camp to
   dismiss them." The idea note for the later release cites the same lines.
2. (blocker) PickFour's `status` is created after the list: forward-declared with `countText, confirm, status`.
3. (should-fix) The condition is `lockReason == "dead"`, so a dead player character (locked as "player character")
   stays disabled; test added ("Tav  (you, dead)"). "then untick them" dropped from the text.
4. (should-fix) `cb.Checked = true` in a pcall, and every click on the box is handled the same way (re-ticked),
   whatever `checked` says.
5. (should-fix) Tests set `Checked = false` before calling OnChange, as ImGui does; tests 3, 4, 5, 7 are labelled
   guards (they pass on 1.1.2 by design). Result: 9 of the new checks fail on 1.1.2.
6. (minor) Disabled boxes are not dimmed by bg3se (`PushItemFlag`, IMGUI.cpp L295), so the grey text is a new look
   rather than a kept one.

## Added 2026-11-01 (later the same day): the author's in-game reports on 1.1.2
Quoted in docs/TESTING.md (2026-11-01, second entry). Log facts (Osiris Runtime 2026-11-01 18-01-19.log, Extender
Runtime 2026-11-01 17-58-39.log):
- The author took control of Gale (GainedControl L9205973) and Gale went down while controlled (DownedChanged(_, 1)
  L9225646): the redraw locked him "you are controlling them", and a locked member shows no "can't leave now" tag
  (RosterList `label`, server `stuck` only for unlocked members, BootstrapServer.lua L17). Control then moved to
  Shadowheart (L9236137) and Lae'zel (L9312892): nothing redraws on a control change, so the stale lock stayed.
- On getting up the engine briefly blocks movement again: DownedChanged(_, 0) L9506482, MoveCapabilityChanged(_, 0)
  L9507659 -> DB_CantMove + TRAVELBLOCK_CANTMOVE again, MoveCapabilityChanged(_, 1) L9514334 frees him. A redraw
  1.5 s after getting up can land inside that window, and nothing redraws afterwards. (No timestamps in the Osiris
  log, so this is the likely cause, not proven.)
- A downed member's box can be unticked on the Party tab (stuck members are not locked there); Apply is then refused
  ("request refused: Gale cannot travel right now (DB_FastTravelBlock_CantMove_StatusSet)", twice in the Extender log)
  and the tick comes back. Every send-to-camp of a downed Gale in the logs was refused; Gale went to camp only with
  the game's own camp travel while up (TeleportedToCamp L9057126).
- Dismissing or recruiting through the game's own conversations does not redraw the tab: Lae'zel removed by the camp
  dialog (PROC_GLO_PartyMembers_Remove(Laezel, Shadowheart, 0, 0), CharacterLeftParty), recruited again
  (PROC_GLO_PartyMembers_CheckAdd, CharacterJoinedParty). 1.1.2 left these events out (its plan, "Not in scope").
- Confirmed working in game: death and resurrection redraw the tab with MCM open, and MCM reopened after a revive with
  the window closed shows him normally.

### F. Server: watch more of the game's own events (Server/RosterWatch.lua)
Same listener, same coalesced 1.5 s broadcast, same "counts" check: `CharacterJoinedParty((CHARACTER))` and
`CharacterLeftParty((CHARACTER))` (story_header.div L369-370), `GainedControl((CHARACTER))` (L380),
`MoveCapabilityChanged((CHARACTER), (INTEGER))` (L386). All one-off events: in the author's 2026-11-01 session
(1,048 MB Osiris log) MoveCapabilityChanged fired 180 times and GainedControl 11 times in all; the counts check makes
anyone not on the tab cost two table lookups. Party Picker's own Apply raises the join/leave events too: one more
redraw after the one the client already makes (ticks then match the party, so nothing is kept wrongly).

### G. Client: a held party member cannot be unticked (Client/RosterList.lua)
A party member the game holds right now (`e.active and e.stuck and not e.locked`: the server's
Party.LeaveBlockedReason, e.g. downed, in combat with the setting on, in a conversation) is treated like a dead
party member in unit B: box ticked and clickable, grey text, a click re-ticks it and calls `opts.onLocked` with
"<Name> can't leave the party right now: <reason>. Try again once they can." Its tag "can't leave now" stays. The
pick-four window already locks its stuck copies (PickFour.lua L57-66), unchanged.

### H. Downed shown even when locked
Server: each roster entry gets `downed = true` when the character has a DB_Downed row (the story's own table,
__AAA_FirstGoal.txt L1187-1203). Client label: tag "downed" for an active member with `e.downed`, so the character
you control shows "(downed, you are controlling them)".

### Tests added
Server: each new event redraws once for a listed member and not for an enemy; `downed` in the roster reply.
Client: a stuck member re-ticks on a click with the reason (status line + message window), Apply sends no uuid for
them; a locked member with `downed` shows the tag.

## Plan review of units F-H (adversarial subagent, 2026-11-01): APPROVE WITH CHANGES
Taken (these override F-H above):
1. (blocker) A held member is NOT locked and stays in Selected(): Apply keeps a wanted active member (Party.lua
   L731-732) and checks leaving only for toRemove (L768-774), so leaving them out would make every Apply refuse.
   Test: Apply sends the held member's uuid.
2. (blocker) A held box is always drawn ticked (`initial = true`, `ticked = true`), whatever the kept ticks say: an
   untick not yet applied is dropped once the member is held. Test added.
3. (should-fix) GainedControl and CharacterJoinedParty redraw for anyone (no counts check): control can move to a
   character not on the tab, and a first recruit may not be in the tables yet.
4. (should-fix) Held text follows the name like Apply's refusals: "<Name> <reason>, so they can't leave the party
   right now. Press Refresh once that has changed."; "is downed" when downed; the story table in brackets left out;
   Apply's off-stage suffix mirrored.
5. (should-fix) Some holds clear with no event (dialogue suppression, danger zone, several travel-block statuses):
   a click on a held (or dead) box also redraws through PartyTab.SettingChanged (ticks kept), and the text says to
   press Refresh.
6. (minor) "downed" only when not dead; the tag comes before the lock reason.
Verified by the reviewer: no redraw loop (roster replies only read); RosterChanged redraws only the Party tab, never
the pick-four window, so the long-rest flows are untouched; MoveCapabilityChanged(_, 1) clears the travel block in
the same rule pass (__AAA_FirstGoal.txt L1273-1275, _Waypoints.txt L196-202), so 1.5 s is enough; event counts in the
2026-11-01 log: MoveCapabilityChanged 180, GainedControl 12, CharacterJoinedParty 4, CharacterLeftParty 8.
From the first diff review (units A-E, SHIP WITH NOTES, no blocker), taken: the Withers wording ("Withers once he is
at your camp", as he joins the camp only after the player meets him), and checks that read-only and the pick-four
window open no message window. Tests now: 302 server + 79 client; of the new checks 6 server and 17 client fail on 1.1.2.

## Diff review of units F-H (adversarial subagent, 2026-11-01): SHIP WITH NOTES, no blocker
Verified by the reviewer: no path drops or sends a held member (Apply, Send everyone to camp, kept ticks, pick-four,
Restore); HeldText's pattern against every reason LeaveBlockedReason returns; no redraw loop (setting Checked from
code fires no OnChange); event signatures; read-only clients unchanged; line endings consistent per file; no new
ModVars. DB_Downed has one column: the Osiris log shows `DB_Downed( S_Player_Gale_... ) [add fact]` (2026-11-01).
Taken: (should-fix 1) in a fight with block_in_combat on, every party member is held, so the tab stays ticked and an
untick made during or just before the fight is not kept: on the test card (step 12) and for the release notes;
(minor 2) the pick-four label leaves out the story table name too. Left: a downed member who is not held (rare: being
downed sets the travel block the leave check reads); redraws on clients whose tab is closed (bounded, few events);
a steady burst of MoveCapabilityChanged only delays the redraw.

## Added 2026-11-01 (evening): unit I - "Let Halsin join early" says when it cannot apply
The author: "But it does allow you to click on recruit early even after the quest started without a warning. So
that is a little confusing. It should block the recruit early option once the questions starts.  Only the checkbox
for Halsin is blocked as it currently stands." MCM cannot disable a setting by game state: `VisibleIf` depends only on
other settings' values and "controls visibility only" (BG3-MCM wiki.md L287-314, Client/Helpers/VisibilityManager).
Asked, the author chose "Warn, keep the tick": MCM settings belong to the profile, not to one save, so unticking it
would also switch it off in earlier saves where it applies.
- Server/HalsinRepair.lua `EarlyIdleText()`: the setting is on, Halsin is on the team, not in the party and not
  recruitable by the story, and EarlyGate gives "his quest at Last Light is under way" or "Act Two only": a sentence
  saying the setting has no effect in this game and why, and that it stays ticked for other saves. Otherwise nil.
- BootstrapServer.lua rosterReply sends it as `halsinEarlyIdle`; Client/PartyTab.lua shows it under the limit line.
- BootstrapClient.lua: on MCM_Setting_Saved for halsin_early with value true, `PartyTab.HalsinEarlyTicked()` asks the
  server and shows the text in the message window (also when the tab was never drawn).
Tests: server (quest under way, setting off, outside Act Two, nothing while it applies); client section 13 (message
on ticking, the tab line, nothing on unticking, nothing when it applies).

## Diff review of unit I (adversarial subagent, 2026-11-01): SHIP WITH NOTES, no blocker
Verified by the reviewer: the author's case (Act Two, Halsin at Last Light, on the team, not in the party) gives the
text; silent when the setting is off, Halsin is in the party, recruitable, or in an early state; MCM sends `value` as
a boolean for a checkbox (MCMServer.lua SetSettingValue L73-90), a reset to default (false) shows nothing, a profile
switch shows no popup but the tab line updates; non-host and main menu safe. Taken: outside Act Two the text says
"has no effect here yet" without "other saves" (in Act One it applies later in the same save); after "Put Halsin's
quest back on track" it says the quest was put back on track (he is in camp, not at Last Light); nothing while Halsin
is dead; the Act Two reason is a named constant, not a text match. Tests added for the reset and dead cases (308
server + 83 client). Left: the tab line partly repeats Halsin's own lock reason (cosmetic).
