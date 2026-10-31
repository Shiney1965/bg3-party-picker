# External review of 1.1.0 (received 2026-10-31) - evaluation

The author, 2026-10-31: "A mod picker did a "review" of the mod and found the following issues .. I don't know how
the review was conducted so do not assume that these are real issues. ... But please evaluate each one carefully".

Method: each point was traced in the published 1.1.0 source (`main` at 934de1a, the code in PartyPicker.pak 1.1.0)
and, where it makes claims about the game, in the game's own story scripts (the author's extract,
`RaphaelJoinsTheParty\_vanilla_story\Mods\Shared\Story\RawFiles\Goals\`) and the BG3-MCM source on GitHub
(AtilioA/BG3-MCM, main, read 2026-10-31). No game test was run for this evaluation. Every line number the review
cites matches the 1.1.0 source exactly, so it was made from the code, not from play; none of these points has been
reported in game.

Verdict scale: **Confirmed** = the code does what the point says. **Narrower** = confirmed, but only in a smaller
case than stated. **Partly** = part of it is right. **Not a defect** = an accurate description of a choice.

## Summary

| # | Point | Verdict | How likely in play |
|---|---|---|---|
| 1 | Interrupted trim loses the restore record | Confirmed, narrower | Low: a save in the 0.85 s the trim takes |
| 2 | "Keep everyone" during a trim erases the record | Confirmed | Low: second button within about 1 s |
| 3 | Missing game checks (can't move / dialog suppression) | Confirmed as a gap; harm not shown | Medium: needs game tests |
| 4 | Restore forgets members it skipped | Partly | Low |
| 5 | Auto-restore stops retrying after an accepted request | Confirmed, partly covered | Low |
| 6 | Slider timer writes into a newly selected profile | Confirmed | Very low |
| 7 | Dead members make the long-rest picker unconfirmable | Confirmed | **Medium: the most likely to hit players** |
| 8 | A dead member blocks "Put Halsin's quest back on track" | Confirmed | Low-medium |
| 9 | Profile switch leaves an open Party tab stale | Confirmed | Low |
| 10 | Turning raft expansion off leaves the rows | Confirmed | Very low |
| 11 | Completion callback can run twice | Confirmed, latent | None today |

None of them crashes the game or changes a save in a way the player cannot undo by hand (sending a companion back
with the Party tab).

## The numbered points

### 1. Interrupted trims lose the restore record - Confirmed, narrower
- The picker's choice runs `Party.Apply` with `reason = "rest"`. It sends members to camp at once (Party.lua L689),
  then waits 250 ms + 600 ms of game time (L18-19, L705-708) before calling `done`, and only then does
  `Restrictions.OnTrimmed` set `trimmed = true` (Restrictions.lua L96-102). Until then the saved record says
  `trimmed = false`.
- The mod's Lua restarts on every save load (the author's Script Extender logs show "server loaded" two or three times
  in one game session, e.g. Extender Runtime 2026-10-30 19-34-51.log), so only the saved record survives a load.
- A save made in that 0.85 s therefore loads with members in camp and `trimmed = false`: no automatic restore
  (Restrictions.lua L129), no Restore button (PartyTab.lua L181), and `PartyFloor` ignores the record (Party.lua L293).
  `!pp_restore` would still bring them back (Restore does not check `trimmed`, L111-116).
- Fix (small): mark the record trimmed as soon as `Party.Apply` accepts, in the same Lua call (nothing can save in
  between). The review's "persist the operation and reconcile during recovery" is more than this needs.

### 2. "Keep everyone this time" during a trim - Confirmed
- Both picker buttons stay clickable after "Keep these four" (PickFour.lua L101-121). The server's keep-all branch
  does not check `Party.IsBusy()` (BootstrapServer.lua L73-75), and `BypassOnce` deletes a record that is not yet
  trimmed (Restrictions.lua L67-70). When the trim then finishes, `OnTrimmed` finds no record (L97-98).
- The reverse order (keep-all first, then "Keep these four" before the reply redraws the window) does the same.
- Result as in 1: four in the party, the rest in camp, nothing to restore them. Needs two clicks within about a second.
- Fix (small): disable both buttons on the first click; refuse keep-all while a party change is running.

### 3. Party changes skip some of the game's own checks - Confirmed as a gap; harm not shown
What the game does (verified in the story scripts):
- `DB_CantMove` holds anyone in an interactive conversation, knocked out, downed, petrified, banished, iron-flasked,
  off stage or dead (__AAA_FirstGoal.txt, "High Level Object States - CantMove", about L2228-2345).
- The fast-travel block that Party Picker reads, `DB_FastTravelBlock_CantMove_StatusSet`, is only set for active
  party members (`DB_Players(_Player) AND DB_CantMove(_Player)`, _Waypoints.txt L187-210). So for a companion in
  camp, Party Picker's check (Party.lua L540-562) never sees "in a conversation", "knocked out" and the rest. Dead and
  off-stage camp members are already refused by other checks (Party.lua L406, L422-423, L638).
- For dismissal, the game keeps its own list, `DB_BlockDismissable` (_GLO_Shared_PartyMembers.txt L232-395): can't
  talk, danger zone, dialog-suppression zone (`DB_PartyDialogSuppressed`, L261-269), blocked zone, engine move block,
  defeated, engine talk block, in combat, arrested, fugitive in prison. It turns it into the UI's dismiss lock
  (`SetBlockDismiss`, L397-401). `PROC_GLO_PartyMembers_Remove` itself checks none of these (L631-645).
- Party Picker checks danger zone, blocked zone, the can't-move status, arrested, fugitive, and combat (when the
  setting is on). It does **not** check dialog-suppression zone, can't talk, defeated, or the engine talk block.

What is not known: whether moving someone in those states actually breaks a scene. The game's dismiss is a
conversation, so some of its locks may exist only because the conversation can't run. That needs game tests.

Fix (medium, needs testing): refuse recruiting a camp member in `DB_CantMove`; refuse sending to camp anyone in
`DB_PartyDialogSuppressed`, `DB_CantTalk`, `DB_Defeated` or `DB_Is_EngineBlock_Talk`. Using `DB_BlockDismissable`
whole would be simpler but it includes combat, which would override the "Block party changes in combat" setting.
Test that ordinary daytime camp changes are not blocked.

### 4. Restore forgets members it skipped - Partly
- Confirmed: in add-only mode, a member who is dead, locked (e.g. "not recruitable yet"), no longer in the roster, or
  over the limit is skipped without a word (Party.lua L636-652). If someone else came back the record is deleted
  (Restrictions.lua L117); if nobody could, the reply is "Everyone is already back." (L120-122) although someone is
  still missing.
- Already handled: members who are off stage (the usual case at night) are kept as waiting and reported (Party.lua
  L626-630, L649-650, L728-729).
- Not right: "retain unresolved members until their membership is verified". A companion who left the team for good
  would keep the record forever, and the record raises the party limit (`PartyFloor`, Party.lua L290-297).
- Fix (small): name who could not come back, and why, instead of "Everyone is already back."; keep the record only
  for reasons that pass (locked for now, dead).

### 5. Automatic restore stops retrying - Confirmed, partly covered
- The retry loop stops as soon as a request is accepted (Restrictions.lua L143-146). If the change then reports
  "did not join", the record stays and the player sees a warning and the Restore button, but no retry is scheduled.
- Partly covered: two events start their own attempts (`LongRestFinished` and the end of camp night, L213-221), so
  a later one often tries again.
- Fix (small): retry from the completion callback while tries remain.

### 6. Slider timer and a profile switch - Confirmed, very unlikely
- The slider check runs 1.5 s after the last move (LimitGuard.lua L41-45) and reads and writes whatever profile is
  active then (L47, L66). If the profile changes in that 1.5 s and the new profile's limit is below the party, the
  new profile gets the party count written into it - which the profile path itself deliberately never does
  (LimitGuard.lua L80-96).
- Fix (one line): bump the generation counter when a profile is activated.

### 7. Dead members and the long-rest picker - Confirmed (the most likely to matter)
- Dead party members are locked (Party.lua L412-414), stay ticked (RosterList.lua L47-49, L55) and are kept by the
  server (Party.lua L633). But the number the picker asks for leaves them out (`available`, PickFour.lua L71-75).
- Party of five, you + 2 dead + 2 alive: the picker asks for 3 ("Keep these 3"). The four beds allow you, both bodies
  and one companion, but the only choice it accepts sends both living companions to camp.
- Party of five, you + 3 dead + 1 alive: it asks for 2 while 4 are locked, so it can never be confirmed; only "Keep
  everyone this time" works.
- Fix (small): count the locked party members, dead included, as already chosen when working out the number.

### 8. A dead member blocks Halsin's repair - Confirmed
- With Halsin in the party, the button sends every other party member, dead ones included, as the party to keep
  (HalsinRepair.lua L309-312). `Party.Apply` refuses a dead member in that list before noticing he is kept anyway
  (Party.lua L638-644), so the button fails: "Halsin could not be sent to camp: <name> is dead."
- Fix (small): send only the unlocked members (locked ones are kept anyway), or let Apply skip members it already keeps.

### 9. Profile switch leaves an open Party tab stale - Confirmed
- MCM's `SetProfile` emits `MCM_Profile_Activated` (MCMServer.lua, SetProfile), and `ModEventManager:Emit` relays it
  to the other context by default. It does not emit `MCM_Setting_Saved` for each setting. The client only listens for
  `MCM_Setting_Saved` (BootstrapClient.lua L22-32).
- An open tab (MCM or the `!pp` window) keeps the old limit and Halsin lock until Refresh, and its own over-limit
  check (PartyTab.lua L77-81) can refuse a choice the new profile allows. The server side is right
  (BootstrapServer.lua L160-165).
- Aside: MCM emits the profile event twice per switch (MCMServer.lua SetProfile, two Emit calls), so the server
  handler runs twice; harmless.
- Fix (small): on the client, treat `MCM_Profile_Activated` like a setting change (`PartyTab.SettingChanged`).

### 10. Raft rows stay after turning the setting off - Confirmed, very small
- Rows added to `DB_UND_EbonLake_Raft_Locations_PlayerPositions` stay in the story database and the save; turning
  the setting off only stops adding more (Restrictions.lua L162-163). They reuse the dock's own spots 1-4 and are only
  read for party members five and up. The setting's description does not say this.
- Fix: either remove our rows when it is turned off, or say in the description that turning it off does not remove
  spots already added. Do not call them harmless in the docs without a test.

### 11. Completion callback can run twice - Confirmed, latent
- `done` runs inside the guard (Party.lua L693-702, L738-741); if it raised, the guard would call it again with a
  failure. Every current callback wraps its own calls, so none can raise today, and the Halsin repair already guards
  against a second call (HalsinRepair.lua L284-288).
- Fix (small): call `done` once, outside the guarded step.

## The general remarks
- **No central owner for loading and teardown** - Partly. Confirmed that the Lua restarts on each load, so timers,
  `busy` and the keep-all flag are dropped and only the saved records survive. Point 1 is the one concrete failure
  found from that. "Other transition failures remain untested" is a fair statement, not a finding.
- **Failed safety queries count as "not blocked"; failed saves are ignored** - Confirmed as described.
  `Party.BlockedReason` treats a failed read as not blocked (Party.lua L553-559) and record writes ignore errors
  (Restrictions.lua L51-54). Halsin's flag read already fails closed on purpose (Party.lua L349-355). Making
  `BlockedReason` refuse (with a log line) when a read fails is reasonable; the tables are declared by the game's own
  scripts, so a read failing would itself be unusual.
- **Required MCM treated as optional; defaults duplicated** - Not a defect. MCM is a declared dependency (meta.lsx);
  the fallbacks only matter if it is missing. All seven fallback defaults in the Lua match the blueprint (checked
  2026-10-31: max_party_size 6, teleport_joiners, block_in_combat, prompt_long_rest, auto_restore, extend_raft on;
  halsin_early off). The duplication is a drift risk only.
- **UI refresh by elapsed time** - Confirmed. The tab redraws 1.5 s real time after an accepted request (PartyTab.lua
  L89-91); the change itself finishes after 0.85 s game time, and the outcome notice updates the status line but does
  not redraw the list (BootstrapClient.lua L34-39). Fix: redraw when the outcome notice arrives.
- **Early Halsin recruitment creates a repair obligation** - Not a defect; a design choice (the author's). It is off by
  default, Act Two only, and the repair checks its preconditions and reads back the state change (HalsinRepair.lua
  L167-196). The flag clear is not read back.

## Recommendation
A 1.1.1 fix release for points 7 and 8 (most likely to hit players), 1 and 2 (cheap, close the lost-record cases),
9, 11, the message part of 4, 5, 6, the refresh-on-notice remark, and the raft description (10). Point 3 needs its own
game tests before it ships. Per the standing rule: plan, adversarial plan review, code, adversarial diff review,
tests, build.

## The review as received
<details><summary>Text pasted by the author</summary>

1. P1 — Interrupted trims lose restoration state. Companions are removed before the saved snapshot is marked
   `trimmed`. A save/reset in that interval leaves a reduced party that automatic restoration and the Restore button
   do not recognize. Persist the operation before mutation and reconcile it during recovery. [Party.lua (line 689)]
2. P1 — "Keep everyone" can erase an ongoing trim's snapshot. The button remains usable while trimming. Its server
   handler bypasses the busy check and deletes the still-unmarked snapshot; the trim then finishes without a
   restoration record. Reject conflicting actions while an operation is running. [BootstrapServer.lua (line 73)]
3. P1 — Party changes bypass native safety contracts. The preflight omits two protections:
   * Inactive camp companions can have `DB_CantMove` without the player-only fast-travel status the mod checks,
     allowing recruitment during dialogue or incapacitation.
   * Dismissal omits `DB_PartyDialogSuppressed`, then calls forced removal, whose native procedure does not enforce
     that restriction.
   Native scripts confirm both gaps. The exact scene damage requires scenario-specific gameplay testing.
   [Party.lua (line 540)]
4. P2 — Restore forgets companions it skipped. Locked, unavailable, missing, or excess members can be skipped while
   the operation reports success or no work needed. Restore then deletes the whole snapshot, sometimes claiming
   "Everyone is already back." Retain unresolved members until their actual membership is verified.
   [Restrictions.lua (line 116)]
5. P2 — Automatic restoration stops retrying before completion. An accepted request ends the retry loop even when
   its later callback reports failure. Retry according to the completed result and remaining members.
   [Restrictions.lua (line 140)]
6. P2 — A stale slider timer overwrites a newly selected MCM profile. Changing the slider and switching profiles
   within 1.5 seconds lets the old callback read and modify the new profile. Profile activation must invalidate
   pending slider work or preserve its originating profile identity. [LimitGuard.lua (line 44)
7. P2 — Dead members can make the rest picker impossible to confirm. Dead active members remain checked and locked,
   but are excluded when calculating the required selection count. The picker can demand three selections while four
   are mandatory. [PickFour.lua (line 71)]
8. P2 — Another dead companion unnecessarily blocks Halsin's repair. The repair submits every other active UUID,
   including locked dead members. `Party.Apply` rejects those explicit dead selections even though they would remain
   untouched. [HalsinRepair.lua (line 309)
9. P3 — Profile changes leave an existing Party view stale. The client listens for individual setting saves but not
   profile activation. An existing view, particularly the standalone window, retains its old limit and Halsin locks
   until refreshed or reopened. It can locally reject selections permitted by the new profile.
   [BootstrapClient.lua (line 26)
10. P3 — Disabling raft expansion leaves it installed. Previously inserted landing rows remain in the story database
    and save. Disabling should remove owned additions, or the setting must explicitly describe its prospective-only
    behavior. [Restrictions.lua (line 162)
11. P3 — Completion callbacks can execute twice. If `done` throws, the enclosing guard catches that exception and
    calls `done` again with failure. Halsin's repair already compensates for this. Callback delivery should be
    protected separately and occur once. [Party.lua (line 693)

* Loading and teardown have no central owner. Gameplay callbacks, pending requests, and floating windows lack
  coordinated suspension, invalidation, and recovery. The interrupted-trim defect demonstrates one consequence; other
  transition failures remain untested.
* Required failures are often silently converted into ordinary state. Failed safety queries become "not blocked";
  failed persistence writes can be ignored. Unknown state should prevent dependent mutations and produce useful
  diagnostics.
* Required MCM is treated as optional. Availability guards and silent fallback defaults conflict with our guidance
  and conceal configuration problems. Defaults are also duplicated between Lua and the blueprint.
* UI refresh depends on elapsed time instead of operation completion. The fixed refresh delay can show stale
  membership. Completion should drive refresh.
* Early Halsin recruitment deliberately creates a quest-repair obligation. Substantially increases maintenance risk.
  The repair needs verified postconditions and focused quest-flow coverage.

</details>
