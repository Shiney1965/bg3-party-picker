# Party Picker 1.1.3: how far each point of the external review is fixed

**TL/DR.** All eleven numbered points of the external review of 1.1.0 (received 2026-10-31) are addressed in the
code of 1.1.3: ten are fixed as the evaluation recommended, and one (point 4) on purpose only in part. Of the five
general remarks, one is fixed (refresh on completion, now driven by the game's own events), one was partly true and
needs no change, and three were left as they are, for the reasons given below. Every fix is covered by offline
tests (308 server + 83 client checks pass). **None of the fixes is confirmed in the game yet**: the in-game steps
for them are on `docs/TEST_CARD_1.1.1.md` steps 2-7, and 1.1.3 is not installed.

Sources: the review and its point-by-point evaluation, `docs/REVIEW_external_2026-10-31.md`; the fixes,
`docs/PLAN_1.1.1_review_fixes.md` (units A-L, with its plan review and diff review); later changes,
`docs/PLAN_1.1.2_live_roster.md` and `docs/PLAN_1.1.3_dead_member_notice.md`; in-game reports, `docs/TESTING.md`.
Line numbers below are from the 1.1.3 source as committed with this report.

How to read the status column: **Fixed** = the code now does what the evaluation said it should, with tests that
fail on 1.1.0. **Partly fixed** = only the part the evaluation found right was changed. **Not changed** = left as is,
with the reason. "In game" says what the author has seen so far.

## Summary

| # | Review point (its own title, shortened) | Evaluation verdict | 1.1.3 status | Fixed in | In game |
|---|---|---|---|---|---|
| 1 | Interrupted trims lose the restore record | Confirmed, narrower | Fixed | 1.1.1 unit C | not yet tested |
| 2 | "Keep everyone" erases an ongoing trim's record | Confirmed | Fixed | 1.1.1 unit D | not yet tested |
| 3 | Party changes bypass the game's own checks | Confirmed as a gap | Fixed for the gaps found, without a dedicated game test (the author's decision) | 1.1.1 unit L; 1.1.3 units G, H | partly seen (below) |
| 4 | Restore forgets members it skipped | Partly | Partly fixed (by design) | 1.1.1 unit F | not yet tested |
| 5 | Auto-restore stops retrying | Confirmed, partly covered | Fixed | 1.1.1 unit G | not yet tested |
| 6 | Slider timer writes into a newly selected profile | Confirmed, very unlikely | Fixed | 1.1.1 unit H | not yet tested |
| 7 | Dead members make the long-rest picker unconfirmable | Confirmed (most likely to hit players) | Fixed | 1.1.1 unit A; 1.1.3 unit B | not yet tested |
| 8 | A dead member blocks Halsin's repair | Confirmed | Fixed | 1.1.1 unit B | not yet tested |
| 9 | A profile switch leaves the Party tab stale | Confirmed | Fixed | 1.1.1 unit I | not yet tested |
| 10 | Turning raft expansion off leaves the rows | Confirmed, very small | Fixed by stating it (the description) | 1.1.1 unit K | n/a (text) |
| 11 | The completion callback can run twice | Confirmed, latent | Fixed | 1.1.1 unit E | n/a (latent) |
| R1 | No central owner for loading and teardown | Partly | No further change; its one concrete failure is point 1 | 1.1.1 unit C | - |
| R2 | Failed safety queries count as "not blocked"; failed saves ignored | Confirmed as described | Not changed (reason below) | - | - |
| R3 | Required MCM treated as optional; defaults duplicated | Not a defect | Not changed | - | - |
| R4 | UI refresh by elapsed time | Confirmed | Fixed, and extended | 1.1.1 unit J; 1.1.2; 1.1.3 unit F | seen working (below) |
| R5 | Early Halsin recruitment creates a repair obligation | Not a defect (a design choice) | Not changed; 1.1.3 adds a warning | 1.1.3 unit I | seen (the warning is new) |

## The numbered points

### 1. Interrupted trims lose the restore record - Fixed (1.1.1 unit C)
The long-rest trim now writes its record, marked trimmed, before anyone is sent to camp, in the same Lua call, so no
save can fall in between: `Party.Apply` calls `opts.beforeChange` just before the first member moves
(Server/Party.lua, Apply), and the request handler uses it to call `Restrictions.MarkTrimming`
(BootstrapServer.lua L102-103; Server/Restrictions.lua L102-108). A save made during the 0.85 s of the trim now
loads with a record the automatic restore and the Restore button recognise. In game: not yet tested.

### 2. "Keep everyone this time" during a trim - Fixed (1.1.1 unit D)
Both buttons of the long-rest window are disabled on the first click until the server answers, and a refusal enables
them again (Client/PickFour.lua, `setBusy`); the server refuses "Keep everyone" while a party change is running
(BootstrapServer.lua L92, `Party.IsBusy()`). In game: not yet tested (TEST_CARD_1.1.1 step 3: "Both buttons grey out
at once").

### 3. Party changes bypass the game's own checks - Fixed for the gaps found (1.1.1 unit L; 1.1.3 units G, H)
- 1.1.1: the game's fast-travel restrictions now apply to everyone Party Picker moves, joiners from camp included:
  besides the five TRAVELBLOCK status tables (which the game keeps only for party members), their source conditions
  are read - `DB_CantMove`, `DB_IsArrested`, `DB_InBlockedWaypointZone`, and the camp night `DB_Camp_NightMode`
  (Server/Party.lua `JOIN_DBS` L572-575, the night check in Apply). Members leaving are also blocked by the game's own
  dismiss lock causes the review named: `DB_CantTalk_IgnoreCombat` (can't talk for any reason except combat) and
  `DB_PartyDialogSuppressed` (`LEAVE_DBS` L579-582). Combat stays under the "Block party changes in combat" setting.
  Refusals name the reason and the story table, e.g. "(DB_CantMove)".
- 1.1.3: on the Party tab a party member the game holds right now (downed, in a conversation, in combat with that
  setting on) can no longer be unticked; a click says why (Client/RosterList.lua `HeldText`). "downed" shows even for
  the character you control.
- Not done: a dedicated in-game test of each condition. The author, 2026-10-31: "It would be too time consuming to
  check this in game. We should track the fast travel restrictions of the game." The review's own caveat ("The exact
  scene damage requires scenario-specific gameplay testing") still applies: whether moving someone in each of those
  states would have broken a scene was never shown; Party Picker now simply follows the game's rules.
- In game so far: a downed party member was refused with the reason and the table ("request refused: Gale cannot
  travel right now (DB_FastTravelBlock_CantMove_StatusSet)", Extender Runtime 2026-11-01 17-58-39.log), and the author
  saw the box could still be unticked - which 1.1.3 changes.

### 4. Restore forgets members it skipped - Partly fixed, by design (1.1.1 unit F)
- Fixed: a restore now names who could not come back and why ("Could not bring back: Name (why)"), and when nobody
  could come back it says "Nobody else could come back: ..." instead of "Everyone is already back." (Server/Party.lua
  Apply, the `skipped` list and `Party.SkippedText`). Off-stage members still wait and are retried.
- Not done, on purpose: keeping skipped members in the record "until their membership is verified". The evaluation
  found that a companion who left for good would then keep the record, and the raised party limit that comes with
  it, forever. In game: not yet tested.

### 5. Auto-restore stops retrying - Fixed (1.1.1 unit G)
The retry loop now decides on the outcome of each attempt, not on its acceptance: an attempt that completes but leaves
someone out tries again, up to five times (Server/Restrictions.lua `RESTORE_TRIES` L36, `attempt` L161-192), and only
one loop runs at a time. In game: not yet tested.

### 6. Slider timer and a profile switch - Fixed (1.1.1 unit H)
A profile switch bumps the slider check's generation counter, so a check that was waiting is dropped before it can
read or write the new profile (Server/LimitGuard.lua L30-45, L82). In game: not yet tested (very unlikely to arise).

### 7. Dead members and the long-rest picker - Fixed (1.1.1 unit A; 1.1.3 unit B)
The picker counts every party member it must keep (players' characters, the dead, the held) towards the four, so
with you, two dead and two living companions it asks for 4 and can be confirmed (Client/PickFour.lua L72-91). 1.1.3:
clicking a dead member there keeps the tick and its status line says why. In game: not yet tested
(TEST_CARD_1.1.1 step 5).

### 8. A dead member blocks Halsin's repair - Fixed (1.1.1 unit B)
`Party.Apply` no longer refuses a wanted member it keeps anyway (dead or otherwise locked): it checks "already kept"
first (Server/Party.lua Apply, "Already kept (locked, or in the party for addOnly): nothing to check"). So "Put
Halsin's quest back on track" works with a dead member in the party. In game: not yet tested (TEST_CARD_1.1.1 step 7,
optional).

### 9. A profile switch leaves the Party tab stale - Fixed (1.1.1 unit I)
The client redraws the Party tab on MCM's `MCM_Profile_Activated` (BootstrapClient.lua, keeping ticks not yet
applied). In game: not yet tested (TEST_CARD_1.1.1 step 6).

### 10. Raft rows after turning the setting off - Fixed by stating it (1.1.1 unit K)
The evaluation offered two fixes: remove the rows, or say so. The setting's description now says: "Turning this off
later stops adding landing spots; spots already added stay in this save." (MCM_blueprint.json, extend_raft.) The rows
are not removed: they reuse the dock's own spots and are only read for members five and up, and removing story rows
untested was judged riskier than leaving them.

### 11. The completion callback can run twice - Fixed (1.1.1 unit E)
`done` is now delivered once, outside the guarded step, behind a `delivered` flag (Server/Party.lua L798-801). It was
latent: no current callback could raise.

## The general remarks

- **R1. No central owner for loading and teardown** - the evaluation found it partly right: the Lua restarts on each
  load and only saved records survive, and point 1 was the one concrete failure from that; it is fixed. No wider
  rework was made: "other transition failures remain untested" is a fair statement, not a finding.
- **R2. Failed safety queries count as "not blocked"; failed saves are ignored** - not changed. A read of one of the
  game's own story tables can only fail if the table is missing from the compiled story, and then failing closed
  would stop every party change for every player. Halsin's recruitable flag already fails closed on purpose
  (Server/Party.lua `notRecruitableReason`).
- **R3. MCM treated as optional; defaults duplicated** - not changed. MCM is a declared dependency (meta.lsx); the
  fallback defaults only matter if MCM is missing, and all of them match the blueprint (checked 2026-10-31).
- **R4. UI refresh by elapsed time** - fixed, and extended beyond what the review asked:
  - 1.1.1 unit J: the Party tab redraws when the outcome notice of a change arrives.
  - 1.1.2: it also redraws on the game's own events for anyone on it - Died, Resurrected, DownedChanged, LeftCombat -
    one message per burst, nothing running between events; and when the MCM window opens; and after a refused change.
  - 1.1.3: also on CharacterJoinedParty and CharacterLeftParty (recruiting and dismissing in the game's own
    conversations), GainedControl and MoveCapabilityChanged.
  - In game (1.1.2, 2026-11-01): "I confirmed even with MCM open the list updates automatically when the character
    dies" and "and the same when he is resurrected". The 1.1.3 additions came from the author's own tests that day
    (dismissing and recruiting by conversation did not redraw); not yet tested in 1.1.3.
- **R5. Early Halsin recruitment** - not changed: it is the author's design choice, off by default, Act Two only, and
  the repair checks its preconditions. 1.1.3 adds a warning, from the author's own test (not the review): ticking
  "Let Halsin join early" in a game where it cannot apply (his quest at Last Light under way, or outside Act Two) says
  so on the Party tab and in a message; the tick stays, as MCM settings belong to the profile, not to one save.

## What is still open
- The in-game test cards: `docs/TEST_CARD_1.1.1.md` steps 2-7 (points 1, 2, 5, 7, 8, 9), then
  `docs/TEST_CARD_1.1.2.md` and `docs/TEST_CARD_1.1.3.md`.
- A whole-mod final review of 1.1.3 before release (requested by the author 2026-11-01).
- Release documents (dist_docs) for the next public version.
