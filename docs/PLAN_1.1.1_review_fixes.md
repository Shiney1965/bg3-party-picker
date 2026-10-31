# Plan: 1.1.1 - fixes from the external review (2026-10-31)

The author, 2026-10-31: "yes, plan 1.1.1 now". Source of the points: docs/REVIEW_external_2026-10-31.md (the
evaluation of each point against the 1.1.0 code and the game's story scripts). Base: `main` at e63e96b (1.1.0).
The Inspiration work on `inspiration-feature` is not part of this release; main is merged into that branch after
1.1.1 ships.

Rules that apply: no copying other mods' code; no real name or model names in files or commits; LF export for the
pak; PP.VERSION + both meta.lsx Version64 values; adversarial review of this plan and of the diff; tests pass;
install only on the author's word with the game closed; in-game reports go verbatim into docs/TESTING.md; no
unverified limitations in the release docs.

## Scope

| Unit | Review point | Change | Size |
|---|---|---|---|
| A | 7 | Long-rest picker counts dead party members as already chosen | small, client |
| B | 8 | Party.Apply ignores a wanted member it already keeps (dead, other locked) | small, server |
| C | 1 | The trim marks its record before anyone is sent to camp | small, server |
| D | 2 | No second request from the picker while a trim runs | small, client + server |
| E | 11 | Party.Apply delivers `done` exactly once, outside the guarded step | small, server |
| F | 4 | Restore names who could not come back instead of "Everyone is already back." | small, server |
| G | 5 | Auto-restore retries after a completed request that left someone out; one loop at a time | small, server |
| H | 6 | A profile switch cancels a waiting slider check | one line, server |
| I | 9 | The Party tab redraws on a profile switch | one line, client |
| J | remark | The Party tab redraws when the outcome of a change arrives | small, client |
| K | 10 | The raft setting's description says what turning it off does | text only |
| L | 3 | The game's own fast-travel restrictions for everyone moved, plus its dismiss lock for leavers | medium, server; no in-game gate (the author's decision) |

Not in 1.1.1 (reasons in the evaluation): retaining skipped members in the restore record (point 4's suggested
fix: a companion who left for good would keep the record and the raised limit forever); failing closed when a
blocking-table read fails (a read can only fail if a table is missing from the compiled story, and then every party
change would stop); removing the MCM fallbacks (MCM is a declared dependency; the fallbacks are harmless and match
the blueprint); changes to "Let Halsin join early" (a design choice).

## Units

### A. Picker count (Client/PickFour.lua L57-89)
Now: `available` counts only living members (L71-75), so with dead party members `need` is too low; locked members,
dead included, stay ticked (RosterList.lua L47-49, L55) and the server keeps them (Party.lua L633).
Change:
- `mandatory` = entries `locked and active` (dead included) - the existing `lockedCount`.
- `optional` = entries `not locked and not dead` (in the party or in camp, as now).
- `need = math.min(size, mandatory + optional)`; when `mandatory > size` the existing "cannot be trimmed" text and
  the disabled button stay.
- Preselection is unchanged (it already starts from the locked count, L58-68).
Results: you + 2 dead + 2 alive -> asks for 4, preselects one living companion; you + 3 dead + 1 alive -> asks
for 4, nothing to tick, confirm enabled (the living companion goes to camp, the four kept are those the server keeps
anyway). The window's button reads "Keep these 4" in both.

### B. Already-kept members in Party.Apply (Server/Party.lua L636-652)
Now: a wanted dead party member is refused ("<name> is dead.") although the first loop already keeps him (L633,
L643-644). HalsinRepair.TabReset sends every active member (HalsinRepair.lua L309-312), so one dead member stops
"Put Halsin's quest back on track".
Change: first branch in the wanted loop: `if e and keep[u] then -- already kept (locked or, in addOnly, in the party)`
do nothing. Everything else unchanged, so a dead camp member asked for by name is still refused and a dead camp
member in a restore is still skipped. HalsinRepair is left as it is (it then works with dead members).
Side effect (intended): `!pp_set` naming a dead party member no longer refuses; the body simply stays.

### C. Trim record before the trim (Server/Party.lua L683-690; BootstrapServer.lua L77-89; Restrictions.lua L96-106)
Now: `trimmed = true` is written in `done`, 0.85 s game time after members were sent to camp; a save in between
loads with an unmarked record.
Change:
- `Party.Apply` takes `opts.beforeChange(toAdd, toRemove)`, called once, synchronously, after every check has passed
  and immediately before the first `sendToCamp` (inside the same Lua call, so no save can fall between it and the
  first removal). An error in it is caught and logged; it does not stop the change.
- The Apply handler passes, for `data.reason`, a `beforeChange` that calls a new `Restrictions.MarkTrimming(reason,
  toRemove)`: if a record exists and `#toRemove > 0`, set `trimmed = true` and save it.
- `OnTrimmed` stays (it marks the record if `beforeChange` did not, e.g. a record created meanwhile) and still sends
  the "Press End the Day again" notice.

### D. One request at a time from the picker (Client/PickFour.lua L101-121; BootstrapServer.lua L73-76)
- Client: the first click on either "Keep these N" or "Keep everyone this time" disables both buttons. A refused
  request (reply not accepted) enables them again.
- Server: the keep-all branch refuses while `Party.IsBusy()`: "A party change is already in progress." (same text
  as Party.Apply's refusal), and does not touch the record.

### E. `done` once (Server/Party.lua L692-744)
- A local `deliver(result)` with a `delivered` flag: the first call runs `pcall(done, result)` and logs an error
  from the callback ("party change callback failed: ..."); later calls do nothing.
- The guard's failure path and both normal outcomes call `deliver`; `busy = false` and `ApplyMaxSize` happen before
  delivery, as now.
- HalsinRepair's `ran` guard (L284-288) stays as a second line of defence; its comment is updated.

### F. Restore says who stayed behind (Server/Party.lua L626-668, L728-741; Restrictions.lua L111-125)
- In addOnly mode Party.Apply collects `skipped` = { name, why } for wanted members it does not add: dead ("dead"),
  locked camp members (their lock reason), not in the roster any more ("no longer with the party", name from
  Party.DisplayName of the stored uuid), over the limit ("no room: party limit N"). Off-stage members stay in
  `waiting`, as now.
- The result (and the nothing-to-do return) carries `skipped`; the messages add "Could not bring back: Name (why);
  ...". The nothing-to-do case with skipped members says "Nobody else could come back: ..." instead of "Everyone is
  already back."
- The record is cleared as now (ok result, or nothing to do). The player adds those members by hand on the Party tab
  once they can join.
- Party.Apply's third return value is unchanged; the skipped list is a fourth return value.

### G. Auto-restore retries on the outcome (Server/Restrictions.lua L127-155)
- A module counter `autoRun`; each `autoRestore()` call takes a new number and its attempts stop when a newer run
  has started (two triggers fire on waking: `LongRestFinished` and the end of camp night, L213-221).
- An attempt whose request is accepted but whose result is not ok, with the record still trimmed, schedules the next
  attempt (same `RESTORE_RETRY_MS`, same `RESTORE_TRIES` budget shared by refusals and failed outcomes).
- Notices: intermediate failures only go to the log; the player sees the outcome of the last attempt (success, or
  the warning with "Use Restore on the Party tab").

### H. Profile switch cancels the slider check (Server/LimitGuard.lua L30-45; BootstrapServer.lua L160-165)
- `LimitGuard.Cancel()` = `generation = generation + 1`; the `MCM_Profile_Activated` handler calls it first.

### I. Party tab follows a profile switch (BootstrapClient.lua L22-32)
- Subscribe to `MCM_Profile_Activated` on the client (MCM relays it to both contexts by default, BG3-MCM
  ModEventManager:Emit) and call `PartyTab.SettingChanged` (keeps the ticks not yet applied; it already waits 0.5 s
  and coalesces, which also absorbs MCM's two emits per switch).

### J. Redraw on the outcome (BootstrapClient.lua L34-39)
- The Notice handler also calls `PartyTab.Refresh()` (no-op when no tab is open). The 1.5 s timers stay as a
  fallback; a second redraw is harmless.

### K. Raft setting text (MCM_blueprint.json, extend_raft Description)
- Add: "Turning this off later stops adding landing spots; spots already added stay in this save." (Verified from
  the code: Restrictions.lua L162-163 only returns.) Same sentence in README/Nexus where the setting is described.

### L. The game's own restrictions (Server/Party.lua L538-562, L670-681)
The author, 2026-10-31: "On Point 3 I think we should fix this to match the game behavior without checks. It would
be too time consuming to check this in game. We should track the fast travel restrictions of the game." So Unit L
ships without an in-game gate, and the rule is the game's own.

The game's fast-travel restrictions (_Waypoints.txt "Updating the Waypoint Travel State", L185-332) are five
conditions, each turned into a TRAVELBLOCK_* status **only for members of DB_Players**:
| Status table Party Picker reads now | Source condition (any character) | _Waypoints.txt |
|---|---|---|
| DB_FastTravelBlock_CantMove_StatusSet | `DB_CantMove(char)` | L187-211 |
| DB_FastTravelBlock_Arrested_StatusSet | `DB_IsArrested(_, char)` | L213-237 |
| DB_FastTravelBlock_BlockedZone_StatusSet | `DB_InBlockedWaypointZone(char, _)` | L239-263 |
| DB_FastTravelBlock_CampNightMode_StatusSet | `DB_Camp_NightMode(1)` (global) | L265-289 |
| DB_FastTravelBlock_FugitiveInPrison_StatusSet | escaped-prisoner chain (DB_PlayerEscapedPrison, DB_PlayerPrison, DB_FugitiveArea, DB_InRegion) | L291-332 |
Using a waypoint also needs "not in combat" (L334-341); that stays the "Block party changes in combat" setting.
`DB_CantMove` covers an interactive conversation, knocked out, downed, petrified, banished, iron-flasked, off stage
and dead (__AAA_FirstGoal.txt "High Level Object States - CantMove", ~L2228-2345).

Change 1 - fast-travel restrictions for everyone moved (joiners from camp and leavers):
- Keep the five status tables (they are what the game shows for party members) and DB_InDangerZone (L541, from
  the game's dismiss lock), and add the source conditions so characters outside DB_Players are covered:
  `DB_CantMove(id)` (arity 1), `DB_IsArrested(nil, id)` (arity 2, character in column 2),
  `DB_InBlockedWaypointZone(id, nil)` (arity 2), `DB_Camp_NightMode(1)` (arity 1, read once per request). The
  fugitive chain stays status-only: it is keyed on players (DB_PlayerEscapedPrison's first column) and a camp
  companion is never an escaped prisoner.
- Reasons in the refusal text: "can't move right now (in a conversation, knocked out or similar)", "is under
  arrest", "is in an area you can't travel from", "camp night".

Change 2 - the game's dismiss lock for leavers (point 3's second half): the game locks dismissal for a party member
who can't talk or is in a dialog-suppression zone (`DB_BlockDismissable`, _GLO_Shared_PartyMembers.txt L232-395).
Members leaving are also blocked when in `DB_CantTalk_IgnoreCombat(id)` (arity 1: can't talk for any reason except
combat - conversations, statuses, the engine talk block, dead; __AAA_FirstGoal.txt L1658-~2000) or
`DB_PartyDialogSuppressed(id, nil)` (arity 2; GLO_PartyDialogSuppressionZones.txt L13-35). The IgnoreCombat table
is used, not `DB_CantTalk`, so the combat setting keeps deciding about combat.

Both changes:
- The host's own character keeps being checked as now (status tables, as a party member).
- In addOnly (restore), a blocked joiner goes to `waiting` instead of refusing the whole request (a morning camp
  scene can hold one companion in a conversation; the others still come back and Unit G retries).
- A read failure stays "not blocked" (see Not in 1.1.1).
- No in-game gate (the author's decision above); the offline tests cover each condition.

## Tests (tests/test_server.lua, tests/test_client.lua; runner tests/run_tests.py)
New scenarios, each failing on 1.1.0 and passing after:
- A: picker with you + 2 dead + 2 alive asks for 4 and enables confirm with one living preselected; you + 3 dead + 1
  alive enables confirm with nothing ticked.
- B: TabReset with Halsin in the party and one dead party member sends Halsin to camp; `!pp_set` with a dead party
  member accepted, body stays.
- C: after the picker's Apply is accepted and before timers run, the saved record has `trimmed = true`; a refused
  Apply leaves it false.
- D: keep-all while busy is refused and the record is untouched; client buttons disabled after the first click and
  enabled again on a refusal.
- E: a `done` that raises is called once; the log has the callback error.
- F: restore with one dead and one departed member names both; nothing-to-do with a skipped member does not say
  "Everyone is already back."
- G: accepted-but-failed restore retries; two triggers run one loop; only the last outcome is a Notice.
- H: slider move, then profile switch before the timer: no MCM.Set on the new profile.
- I/J: client redraws on MCM_Profile_Activated and on a Notice.
- L: a camp member in DB_CantMove, DB_IsArrested or DB_InBlockedWaypointZone is refused as a joiner; any change
  is refused during DB_Camp_NightMode(1); a party member in DB_CantTalk_IgnoreCombat or DB_PartyDialogSuppressed is
  refused as a leaver; with block_in_combat off, a member only in combat still moves; restore with one blocked
  joiner adds the others and reports the blocked one as waiting; an ordinary camp swap with none of these rows
  still works.
- All existing scenarios still pass (244 server, 25 client, blueprint 8 settings at e63e96b).

## Game test card (docs/TEST_CARD_1.1.1.md, written with the build)
1. Load line says v1.1.1.
2. Party tab: send a companion to camp and bring one back (ordinary use; play-as-usual, not a dedicated Unit L test).
3. Long rest with 5+: trim to four, End the Day, wake: everyone comes back (Units C, G).
4. Long rest with a dead party member and 5+: the picker asks for 4 and confirms (Unit A).
5. MCM profile switch with the Party tab open: the limit line follows (Unit I).
6. Optional (Act 2 save with Halsin early and a dead party member): the Halsin button works (Unit B).
Unit L has no dedicated game test (the author's decision).

## Docs and release
- PP.VERSION "1.1.1"; meta.lsx L35 and L38 Version64 = 36169536654802944 (1<<55 | 1<<47 | 1<<31); L15 (MCM) untouched.
- dist_docs: CHANGELOG (1.1.1 section), RELEASE_NOTES (1.1.1), README/INSTALL only where behaviour text changes
  (raft sentence; picker wording if any), Nexus BBCode/Description changelog; regenerate docx/pdf
  (tools/make_docs.ps1); RELEASE_NOTES_v1.1.1.md at the repo root.
- Only fixes that passed tests and the game test card are named in the release notes.
- Pak from an LF export; size and SHA-256 in RUN_CARD.md; bundle with tools/assemble_bundle.ps1; name scan
  (the author's real name, model names) over docs, pak and bundle before any publish.
- Install, GitHub release and Nexus upload each on the author's word.

## Plan review (adversarial subagent, 2026-10-31) - APPROVE WITH CHANGES, no blocker
The author accepted the recommendations ("other than my comment about Point 3 I accept your recommendations").
Changes taken into the plan (they override the unit text above where they differ):
1. **L, addOnly order.** In addOnly the joiner checks run inside the wanted loop, before `keep`/`count`, so a
   waiting joiner never takes a slot. `waiting` entries are `{ e, why }`; both waiting texts (the nothing-to-do refusal
   and the result line) use `why` instead of the fixed "off stage". Outside addOnly a blocked member still refuses the
   request.
2. **F, branch order.** Already kept -> off stage or blocked (waiting) -> dead -> locked (skipped, lock reason) ->
   not in the roster (skipped) -> over the limit (skipped "no room"; no `break`, so later members are still recorded).
   Off-stage members can never become "skipped" (that would clear the record at night).
3. **L, joiner zone check dropped.** `DB_InBlockedWaypointZone` rows are only written for DB_Players and are not
   cleared when someone leaves (_Waypoints.txt L41-61; triggers unregistered on leaving, _GLO_Shared_PartyMembers.txt
   L1599-1605), so for a camp companion the row can be stale. Joiners are checked for `DB_CantMove` and
   `DB_IsArrested` only; leavers keep the status-table check, and the host's own status check covers a blocked zone.
4. **G, notices.** Restore returns a `nothingToDo` flag and the skipped list; no comparison with the message text.
   A newer run only stops an older run from scheduling; a successful outcome is always noticed. The auto_restore-off
   notice is sent once per wake (same run counter). The final warning adds: "Choosing the party by hand on the Party
   tab ends the wait."
5. **A, stuck members.** The roster reply carries `stuck` (the server's leaver check: status tables, can't talk,
   dialog suppressed) for active unlocked members. The picker counts stuck members as mandatory and pre-ticks them
   first; "Send everyone to camp" keeps them as it keeps off-stage members. With nothing left to choose the picker
   says so ("Nobody else can be chosen tonight.").
6. **C, missing record.** If no record exists when the trim starts (e.g. a hand change on the Party tab cleared it
   while the picker was open), MarkTrimming creates `{ reason, party = active members before the change, trimmed =
   true }`, written as a whole table.
7. **L, diagnosable refusals.** Every refusal names the matched table, as now ("(DB_...)"), the can't-talk text
   mentions wild shape, and the status tables are checked first so party members' messages and the off-stage hint are
   unchanged.
8. **J, keep ticks.** The Notice handler calls `PartyTab.SettingChanged` (coalesced, keeps the ticks the player has
   not applied), not `PartyTab.Refresh`.
Minor items taken: declare the new tables' column counts in the mock; the client fake's Apply channel replies; tests
check for no "could not draw" log; CLAUDE.md version history and docs/RESEARCH.md list the new story tables;
inspiration-feature takes a version above 1.1.1 when merged (expect conflicts in PartyTab.lua, both bootstraps, the
blueprint). Not taken: a time-ordered timer queue (the G tests drive the triggers in a fixed order instead).

## Order of work
1. Adversarial review of this plan; fix blockers.
2. Units A-K (tests first for each), then L.
3. Adversarial review of the diff; fix blockers; tests.
4. Build 1.1.1 TEST pak, RUN_CARD, test card; the author installs/tests.
5. Docs, bundle, release - after the test card passes.
