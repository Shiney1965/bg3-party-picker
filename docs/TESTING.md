# Testing

## Outside the game (done)

`python3 tests/run_tests.py` (needs `pip install lupa`):
- compiles every Lua file under Lua 5.4;
- runs the server logic against `tests/mock_game.lua`, a fake of the Osiris databases and story
  procedures as documented in `docs/RESEARCH.md`. The mock checks `TeleportTo`'s argument count,
  refuses two-argument `Remove` calls and avatar removals, and models the hireling camp counter.
  Since v0.1.6 it also models: the add rule needing a `DB_GLO_PartyMembers_DefaultFaction` row and
  marking hireling templates as hired; the three hireling factions; removal only when the game's
  own conditions hold; off stage → cannot move → travel block; and a table's column count.

The 114 checks cover:
- roster building and summon filtering;
- a companion the host is controlling;
- party changes from the MCM tab, including hirelings in camp;
- the limit check, the host-only check and the combat block;
- the long-rest hold, trim and restore;
- a recruit joining between trim and restore (kept);
- a hand-picked party replacing a pending trim;
- restore when everyone is already back;
- "keep everyone this time", including that it does not lose an earlier trim;
- an error inside a request handler still reaching the client;
- a dead party member never being sent to camp; dismissed avatars locked;
- restore when the limit was lowered, and when night mode ends after the rest;
- the one-time bypass expiring;
- adding raft landing spots on level start and again just before landing;
- Withers, summons (including one only its entity component reveals) and followers: never listed,
  never counted, never moved by Apply;
- camp followers and camp pets in `DB_PartOfTheTeam` not listed; a companion from another mod
  listed once seen in the party, and still listed from camp (the record is saved), also when they
  joined and left with the tab closed; a companion with the game's dismissal mark listed; summons
  never remembered; `!pp_forget`;
- `!pp_roster` printing the version, each character's story tables and faction, and `?` for a
  failed lookup;
- an off-stage hireling: listed but locked, never recruited; if already in the party, the refusal
  to send her to camp says why and is logged; requests and results name who moved;
- a hireling the game does not remove: reported, hireling camp flag and counter left alone; the
  same report for a companion from another mod that the story does not mark;
- a restore after a rest while a trimmed member is off stage;
- the settings switches.

A mock is not the game. These tests catch Lua mistakes and logic errors. They cannot show that the
story procedures behave as documented in the current patch. The client UI is not covered.

## In the game

**2026-10-11, v0.1.1 (SHA-256 `3187775e...28ef`), MCM 1.40.1:** Alan reported "The mod seems to
work perfectly". v0.1.0 had first shown an MCM "Dependency issue detected" warning (it required MCM
1.41); fixed in v0.1.1. Which of the steps below were exercised is not yet recorded, so none is
marked passed individually.
**Withdrawn the same day** (Alan): "The mod does not yet work perfectly -- that was premature".
Treat no step as confirmed by this report.

**2026-10-11, v0.1.1, second report:** "it includes Withers in the party roster, which is incorrect"
and "summonses are listed there". Fixed in v0.1.2: Withers is excluded by his story id, and summons
and followers are excluded by any of IsSummon / IsPartyFollower, DB_PlayerSummons /
DB_PartyFollowers, or the entity's IsSummon / PartyFollower component. `!pp_roster` now also prints
each excluded character and the reason. The test for v0.1.2: open the Party tab with a summon out
(for example a familiar) and check that neither it nor Withers is listed.

**2026-10-11, version not stated (v0.1.2 was the pak under test):** Alan: "On loading the game it
didn't crasah but I got a message "Error . Server shutting down."" Cause not yet known; the Script
Extender log for that session has not been seen. A desk check of the server's load-time code found
every Osiris listener's name and argument count matching the story copies cited in
`docs/RESEARCH.md` (`GLO_Camp.txt`, `Act1_UND_EbonLake.txt`).

**2026-10-11, follow-up with logs** (`Extender Runtime 2026-10-11 16-27-24.log`,
`Extender Runtime 2026-10-11 16-46-43.log`, `Osiris Runtime 2026-10-11 16-29-44.log`, plus a
screenshot). Alan: "The save game loaded even after the server shutdown error. The Party Picker
error continued -- it listed summonses and other non-party camp followers, such as Volo,
Oathbreaker Knight and Elminster. This seems to include camp followers not currently in camp."
- **Server shutting down (16-27-24 log).** Both Party Picker scripts loaded
  (`[PartyPicker] server loaded.`, `[PartyPicker] client loaded (Party tab added to MCM).`). The
  session was then unloaded straight after `Attempted to send extender message to a host that does
  not understand extender protocol!`. The line before it was another mod's
  (`[RandomizedDisguiseSelf][Server][V2Randomizer] Re-broadcast 0 active rolls (client request)`).
  Party Picker sends nothing over the network while loading. It only replies to the Party tab and
  sends notices around a long-rest hold or restore, so it is not the likely sender. The log does not name the
  sender. That session never reached `party size limit set to`.
- **16-46-43 log (the session that loaded):** `[PartyPicker] party size limit set to 14`, so step 1
  passed on that load. No `!pp_roster` output was in the log.
- **Roster still wrong:** the list shows camp followers (Volo, the Oathbreaker Knight, Elminster)
  and summons. The logs cannot show which pak was installed, because v0.1.2 and earlier did not
  print their version. If v0.1.2 was installed, its summon filter missed these summons. Camp
  followers were never filtered by any version. Which story table puts them in the list is
  unknown: `DB_PartOfTheTeam` is added by `PROC_ORI_SetupCamp` (`_GLO_Shared_Origins.txt`
  L1943–1950, Interzoneism/qdnd copy), but the Act scripts that bring Volo, Elminster and the
  Oathbreaker Knight to camp were not available to check.
- **v0.1.3** prints its version at load. `!pp_roster` now prints, for every character, the story
  tables they are in and their faction, so the next report shows where each wrong entry comes from.

**2026-10-11, `!pp_roster` output** (Alan: "same error in the mod here is the output from
pp_roster"). The output has no `Party Picker v0.1.3 roster:` line and no `[in: ...]` parts, so the
pak loaded was v0.1.2 or earlier, not v0.1.3. Listed: Lae'zel (ACTIVE avatar, locked), Alfira,
Astarion, Gale, Halsin, Karlach, Minthara, Raphael, Shadowheart, Wyll (all ACTIVE); in camp:
Bernard (twice), Elminster Aumar, Oathbreaker Knight, Scratch, Shovel, Tara, Tara the Tressym,
Volo. Withers: `not listed: Withers (in DB_PartOfTheTeam)`. `active 10, limit 14 (game reports 14)`.
That build builds the list from `DB_PartOfTheTeam`, `DB_Hirelings_Hired` and `DB_Players`, so every
camp entry came from the first two. Alan's requirement for the fix: list only "real party members --
that is Tavs/Durges and companions", "and hirelings of course and companions added by mods", using
a rule that works in every game, not just his. v0.1.4 does this (see README, "Who is listed").

**2026-10-11, v0.1.4 installed.** Downloaded from the repository's `main` branch into
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak`; Alan: "the hash is correct
so it seems to be installed" (SHA-256 `5B068FDF...63CF303B`, 27,419 bytes). In-game result not yet
reported.

**2026-10-12, hireling report.** Alan: "I ran party picker this morning and there is a bug with
recruiiting hirelings. One recruited I was unable to dismiss Brianna Brightsong." No log from that
session has been received yet, so the version that ran is not confirmed. Who Brianna Brightsong is
(vanilla hireling or a character from another mod) is not known. A web search found no
character of that name. Desk check: Party Picker sends a hireling to camp with the same two calls
as the game's own hireling dialogue (`PROC_GLO_PartyMembers_Remove(hireling, avatar, 0)` then
`PROC_Hirelings_SendToCamp`, SharedDev `Hirelings.txt` L1095–1096). The game's removal ends in
`PROC_GLO_PartyMembers_MakeNPC`, which only runs for a character in
`DB_GLO_PartyMembers_OriginalAlignment` and `DB_PartyMembers` (`_GLO_Shared_PartyMembers.txt`
L1297–1305), so a character without that row would stay in the party.

**2026-10-12, logs for that session read on Alan's PC** (`Extender Runtime 2026-10-12 13-54-03.log`,
2,294 lines, and `Osiris Runtime 2026-10-12 13-56-15.log`, 552,632 lines; both in
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs`). Story lines
below are from Alan's own extract of the game's story,
`C:\Claude Projects\BG3 Mods\RaphaelJoinsTheParty\_vanilla_story\Mods\` (H = `SharedDev\...\Hirelings.txt`,
PM = `Shared\...\_GLO_Shared_PartyMembers.txt`); its line numbers agree with the copy cited above.

Checked, not assumed:
- **Installed pak:** `PartyPicker.pak`, 27,419 bytes, SHA-256
  `5B068FDF1D269AE64D5835DCCA0AE314A0394DD0EEEA67BC6F19AD8A63CF303B` = v0.1.4. v0.1.5 is not installed.
- **Version that ran:** `[PartyPicker] client loaded (v0.1.4) (Party tab added to MCM). Client console: !pp`
  (line 1029) and `[PartyPicker] server loaded (v0.1.4). ...` (line 1602).
- **Every other `[PartyPicker]` line in that log:** `party size limit set to 14` (1897),
  `raft: added 36 landing positions` (1898), `Party updated: 1 joined, 0 sent to camp.` (2270, 2271),
  `Party updated: 0 joined, 1 sent to camp.` (2275, 2276). Each result is printed twice because the
  server prints it and the client prints the same notice. There is **no** `did not leave`, no
  `Party partly updated`, no `remove failed`, no `add failed` and no `!pp_roster` output.
- **Who joined:** the Bard hireling, `S_GLO_Hirelings_Bard_4d3c9cb3-ca34-46ba-9c81-44081270bfde`
  (another mod's line 2256: `AEE [Info] S_GLO_Hirelings_Bard_4d3c9cb3-... joined the party, providing spells`).
  Party Picker called `PROC_Hirelings_AddToParty` (H:453–458); the Osiris log shows its three steps at
  464001–464121 (`PROC_CheckPartyFull`, `PROC_Hirelings_AssignFaction`, `PROC_GLO_PartyMembers_CheckAdd`).
- **Who left:** the **Rogue** hireling, not the Bard. Line 2274:
  `AEE [Info] S_GLO_Hirelings_Rogue_e4818484-7ee4-466b-82b3-60bbd7b2ff8f left the party, removing spells`.
  Osiris log 477387: `PROC_GLO_PartyMembers_Remove( ...Rogue..., ...a9724ba4..., 0, 0 )`, then
  `PROC_GLO_PartyMembers_MakeNPC` (477498), `DB_Players( ...Rogue... ) [delete fact]` (477509),
  `PROC_Hirelings_SendToCamp` (478245–478258) and `DB_InCamp( ...Rogue... ) [add fact]` (490307).
  That removal worked.
- **No removal of the Bard was ever requested.** In the whole Osiris log there is no
  `PROC_GLO_PartyMembers_Remove`, `PROC_Hirelings_SendToCamp` or `PROC_Hirelings_Dismiss` call for
  the Bard, and no hireling dialogue with her. She is still in `DB_Players` at the last dump (477404)
  and the session ends with two saves. So the earlier guesses (the game's removal failing for want
  of an alignment row) are **not** what happened in this session: the story was never asked.
- **The Bard was already hired before Party Picker touched her.** Before the add, `DB_Hirelings_Hired`
  held the Rogue, the Bard and the Fighter (dump at 464061–464065), `DB_PartOfTheTeam` held all three
  (33856–33862), and `DB_GLO_PartyMembers_DefaultFaction` had rows for the Bard and the Fighter, both
  with faction `Hireling1_9459fd54-...` (464170–464171). Their current faction was
  `Hirelings_b7b47ac8-...` (464077, 464080), which the story's own comment describes: "Hired but not
  in current party hirelings are in Hirelings faction" (H:492). So v0.1.4 listed her because the
  story says she is hired, not because of the template marks v0.1.5 filters (H:280–285), and
  v0.1.5 would list her too.
- **Where the unexpected hirelings probably come from:** another mod in this load order, DaisyMorph,
  hires hireling characters as stand-ins. Its own lines, this session: `findPartyHireling catalog
  rank Maddala S_GLO_Hirelings_Rogue_e4818484-...` (1956), `Stored DummyUuid S_GLO_Hirelings_Rogue_...`
  (1988); and in 14 earlier sessions from 2026-09-22 to 2026-10-10: `Dismissing dummy hireling
  S_GLO_Hirelings_Fighter_d61d12ad-...`. No log line shows how the Bard was hired, so that part is
  an inference, not a finding.
- **Odd state seen:** the Bard had no in-camp flag (Party Picker took the `AddToParty` branch, not
  `TakeFromCamp`), and `Hirelings_InCamp_Count` was -1 before the Rogue was sent to camp (478266:
  `DB_GlobalCounter( "Hirelings_InCamp_Count", -1 ) [delete fact]`). Because the Bard had a stale
  `Hireling1` row and was given `Hireling2` (464118), the game's add rule ran twice for her
  (PM:501–528 runs once per `DB_GLO_PartyMembers_DefaultFaction` row; 464179 and 471812). Her
  final faction is `Hireling2` (476287). The game's own "take from camp" would do the same.

**Cause (found by the adversarial review, then checked line by line):** the Bard was off stage,
that is, not present in the world, when v0.1.4 recruited her.
- Off stage: `IsActive( S_GLO_Hirelings_Bard_..., 0 )` (Osiris log 471532), a distance of 998.149
  from the Rogue standing in the party (470511), and no on-stage call for her anywhere in the log (the Rogue gets
  `SetOnStage( ...Rogue..., 1 )` at 490164 when she reaches camp).
- The story records an off-stage object in `DB_OffStage` (`__AAA_FirstGoal.txt` L1282–1285) and
  treats it as unable to move (L2285–2291, L2325–2331: `DB_CantMove`). The companion add rule never
  puts anyone on stage (PM:501–528).
- A party member who cannot move gets the fast-travel block (`_Waypoints.txt` L188–194). It fired
  for her the moment she joined: 470532 `ApplyStatus( ...Bard..., "TRAVELBLOCK_CANTMOVE", -1.0, 1, ... )`,
  470533 `DB_FastTravelBlock_CantMove_StatusSet( ...Bard... ) [add fact]`. It is never removed in the
  log, and the game's own waypoint check still counts her as blocked later (492240–492261).
- Party Picker refuses to move anyone in that table (`Server/Party.lua`, `BLOCKING_DBS`, checked for
  everyone a request would send to camp). So every request that unticked the Bard was refused with
  "... cannot travel right now (DB_FastTravelBlock_CantMove_StatusSet)." before any story call, which
  is why the Osiris log shows none. v0.1.4 did not log refusals, and the Party tab redrew itself
  1.5 seconds after every reply, wiping the message and ticking her box again
  (`Client/PartyTab.lua`). A request that only unticked the Rogue passed, which matches the log.
- Inferred, not logged: that Alan unticked her. His clicks are not in any log.

Fixed in v0.1.6 (reproduced first in `tests/test_server.lua` 21 and 22, which failed on v0.1.5):
- A character who is off stage is listed but locked (`not available: off stage`) and is never
  recruited. "Off stage" means a row in `DB_OffStage` or the game's `IsOnStage` query answering 0.
  The Bard's own `DB_OffStage` row is not printed in that session's log; it is inferred from the
  rule that fired (above) and from `IsTagged( ...Bard..., PERMA_DEFEATED_OR_OFFSTAGE )` answering 1
  while `PERMA_DEFEATED` answered 0 (476304, 476335). Her v0.1.6 `!pp_roster` line will settle it
  (`offstage` and/or `IsOnStage=0`).
- After a long rest, a trimmed member who is still off stage is not added, the others are, and the
  trim record is kept so Restore can bring her back later (the camp hides benched companions at
  night, `GLO_Camp.txt` L1630–1649; test 23).
- Every refusal is written to the log (`request refused: ...`) and stays on the Party tab; the tab
  no longer redraws after a refused request. Accepted requests are logged with names
  (`request: join [...]; send to camp [...]`) and the result names who moved
  (`Party updated. Joined: X. Sent to camp: Y.`).
- A hireling the game did not remove no longer gets the in-camp flag and counter set
  (`PROC_Hirelings_SendToCamp`, H:670–675); failures of either call are logged.
- `!pp_roster` also shows `offstage`, `cantmove`, `cantact`, `travelblock`, `campflag`, `hiredflag`
  and `IsOnStage=0`.

Both the plan and the finished change were reviewed adversarially by a subagent. The first review
found the cause; the second found that the first version of the fix made the after-rest restore
forget an off-stage member (fixed, test 23) and that a message could reappear on the tab hours
later (the status line is now cleared when the Party Picker page is opened).

Not fixed by v0.1.6: the Bard already in the party in Alan's two saves from the end of that
session. She is off stage with the travel block, and v0.1.6 will still refuse to send her to camp
(now saying why), because how the game's camp walk (`PROC_DismissToCamp`,
`_GLO_Shared_Origins.txt` L460–507) treats an off-stage character has not been tested. The safe
route is a save from before that session. Untested alternative: hard save, then in the server
console put her on stage and untick her on the Party tab.

**2026-10-12, v0.1.6 installed** at Alan's request ("install 0.1.6 please"). Copied from the
repository's `PartyPicker.pak` (commit `eaf2072`) over v0.1.4 in
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak` with the game and the mod
manager closed; hash checked after the copy: 30,043 bytes, SHA-256
`8A73AF064D42378231D0F39C13FE08B672DDB713DF8B08DC14B3397D847B384D`. Party Picker is still in the
load order (`modsettings.lsx`).

**2026-10-13, v0.1.6, first in-game report.** Alan: "The party picker seems to be working properly
now but I need to run the PP_roster." No step is marked passed on this alone. What the log of that
session shows (`Extender Runtime 2026-10-13 04-15-47.log`):
- `client loaded (v0.1.6)` (1030), `server loaded (v0.1.6)` (1602), `party size limit set to 14` (1903).
- Nine requests, all accepted and all carried out, each with the new named lines, for example
  `request: join []; send to camp [Wyll]` (2703) then `Party updated. Sent to camp: Wyll.` (2707),
  and `request: join [Karlach, Wyll]; send to camp []` (2715) then
  `Party updated. Joined: Karlach, Wyll.` (2732). Sent to camp in turn: Wyll, Karlach, Shadowheart,
  Wyll, Halsin, Karlach, Gale, Astarion.
- No `request refused`, no `did not leave`, no `did not join`, no `!pp_roster` output.
- Only origin companions were moved. No hireling appears in these lines, so the off-stage lock
  (the fix for the 2026-10-12 report) was not exercised in this session.

Still not known:
- Whether the Bard has the row a removal needs (`DB_GLO_PartyMembers_OriginalAlignment`, PM:1305).
  It is given to every hireling template (H:280–285) and deleted by a permanent dismissal (H:639);
  only a hire through Withers' own screen puts it back (H:740–747). `!pp_roster` shows it as
  `origalign` on her line.
- Whether "Brianna Brightsong" is this Bard. Alan's notes give the Bard hireling the id `4d3c9cb3`;
  the name was not checked against the game files in this session.
- Whether two listed characters can show the same name (another mod transformed the Rogue in that
  session). Not seen; the named result line would show it.

Make a hard save first. All `[PartyPicker]` lines go to the Script Extender log
(`Extender Runtime *.log`).

| # | Step | Expect | Confirms |
|---|---|---|---|
| 1 | Load a save with 4+ recruited companions | Log: `party size limit set to 6`; MCM has a **Party** tab | `SetMaxPartySizeOverride` on `LevelGameplayStarted`; MCM tab |
| 2 | Server console `!pp_roster` | Everyone recruited, summons absent, your character locked | Roster DBs |
| 3 | Party tab: tick 6, Apply | The new members appear next to you; portraits show 6 | `PROC_GLO_PartyMembers_CheckAdd` above 4; 6-argument `TeleportTo` |
| 4 | Untick one, Apply | They go to camp and are there when you visit | `PROC_GLO_PartyMembers_Remove(…, 1)` |
| 5 | Hireling in camp: tick, Apply; then untick, Apply | Joins; then back in camp; talking to them in camp shows the normal options | Hireling procedures and flags |
| 6 | Switch to controlling a companion, open the Party tab | That companion is shown locked | Host-character handling |
| 7 | With 6 in party, End the Day | Rest does not start; the picker opens | **Highest risk:** the QRY `before` listener plus `PROC_Camp_TryEnterNightModeFailed`. If the rest starts anyway, the user-query listener did not fire as the SE source suggests |
| 8 | Pick 4, Keep, then End the Day again | Normal rest, four in beds | |
| 9 | Wake up | The other 2 rejoin a few seconds later (after the camp returns to day) | `LongRestFinished` / end of night mode + add-only restore |
| 10 | Trim to four, save before pressing End the Day, reload, rest, wake | Restore still happens | Mod variable persistence |
| 11 | Act 1 Underdark: Ebonlake raft with 6 in party, to Grymforge and back | All 6 arrive at each dock | Raft landing spots 5–16. Log: `raft: added … landing positions` (at a level load or just before landing) |
| 11b | Same, through the lake encounter (Duergar raft) | All 6 stay on the raft and continue | **Risk:** on the lake, members 5+ share the four on-raft spots; if the game pushes someone off the raft they may be left behind |
| 12 | Multiplayer (host + 1) | Other player's tab is read-only; their characters stay locked | Peer id → user id conversion |

If step 7 fails, there is a fallback. Turn off "Ask before a long rest", trim with the Party tab
before resting, and tick everyone again afterwards.
