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

**2026-10-11, v0.1.1 (SHA-256 `3187775e...28ef`), MCM 1.40.1:** the author reported "The mod seems to
work perfectly". v0.1.0 had first shown an MCM "Dependency issue detected" warning (it required MCM
1.41); fixed in v0.1.1. Which of the steps below were exercised is not yet recorded, so none is
marked passed individually.
**Withdrawn the same day** (the author): "The mod does not yet work perfectly -- that was premature".
Treat no step as confirmed by this report.

**2026-10-11, v0.1.1, second report:** "it includes Withers in the party roster, which is incorrect"
and "summonses are listed there". Fixed in v0.1.2: Withers is excluded by his story id, and summons
and followers are excluded by any of IsSummon / IsPartyFollower, DB_PlayerSummons /
DB_PartyFollowers, or the entity's IsSummon / PartyFollower component. `!pp_roster` now also prints
each excluded character and the reason. The test for v0.1.2: open the Party tab with a summon out
(for example a familiar) and check that neither it nor Withers is listed.

**2026-10-11, version not stated (v0.1.2 was the pak under test):** the author: "On loading the game it
didn't crasah but I got a message "Error . Server shutting down."" Cause not yet known; the Script
Extender log for that session has not been seen. A desk check of the server's load-time code found
every Osiris listener's name and argument count matching the story copies cited in
`docs/RESEARCH.md` (`GLO_Camp.txt`, `Act1_UND_EbonLake.txt`).

**2026-10-11, follow-up with logs** (`Extender Runtime 2026-10-11 16-27-24.log`,
`Extender Runtime 2026-10-11 16-46-43.log`, `Osiris Runtime 2026-10-11 16-29-44.log`, plus a
screenshot). The author: "The save game loaded even after the server shutdown error. The Party Picker
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

**2026-10-11, `!pp_roster` output** (the author: "same error in the mod here is the output from
pp_roster"). The output has no `Party Picker v0.1.3 roster:` line and no `[in: ...]` parts, so the
pak loaded was v0.1.2 or earlier, not v0.1.3. Listed: Lae'zel (ACTIVE avatar, locked), Alfira,
Astarion, Gale, Halsin, Karlach, Minthara, Raphael, Shadowheart, Wyll (all ACTIVE); in camp:
Bernard (twice), Elminster Aumar, Oathbreaker Knight, Scratch, Shovel, Tara, Tara the Tressym,
Volo. Withers: `not listed: Withers (in DB_PartOfTheTeam)`. `active 10, limit 14 (game reports 14)`.
That build builds the list from `DB_PartOfTheTeam`, `DB_Hirelings_Hired` and `DB_Players`, so every
camp entry came from the first two. The author's requirement for the fix: list only "real party members --
that is Tavs/Durges and companions", "and hirelings of course and companions added by mods", using
a rule that works in every game, not just his. v0.1.4 does this (see docs/DEVELOPMENT.md, "Who is listed").

**2026-10-11, v0.1.4 installed.** Downloaded from the repository's `main` branch into
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak`; the author: "the hash is correct
so it seems to be installed" (SHA-256 `5B068FDF...63CF303B`, 27,419 bytes). In-game result not yet
reported.

**2026-10-12, hireling report.** the author: "I ran party picker this morning and there is a bug with
recruiiting hirelings. One recruited I was unable to dismiss Brianna Brightsong." No log from that
session has been received yet, so the version that ran is not confirmed. Who Brianna Brightsong is
(vanilla hireling or a character from another mod) is not known. A web search found no
character of that name. Desk check: Party Picker sends a hireling to camp with the same two calls
as the game's own hireling dialogue (`PROC_GLO_PartyMembers_Remove(hireling, avatar, 0)` then
`PROC_Hirelings_SendToCamp`, SharedDev `Hirelings.txt` L1095–1096). The game's removal ends in
`PROC_GLO_PartyMembers_MakeNPC`, which only runs for a character in
`DB_GLO_PartyMembers_OriginalAlignment` and `DB_PartyMembers` (`_GLO_Shared_PartyMembers.txt`
L1297–1305), so a character without that row would stay in the party.

**2026-10-12, logs for that session read on the author's PC** (`Extender Runtime 2026-10-12 13-54-03.log`,
2,294 lines, and `Osiris Runtime 2026-10-12 13-56-15.log`, 552,632 lines; both in
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs`). Story lines
below are from the author's own extract of the game's story,
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
- Inferred, not logged: that the author unticked her. His clicks are not in any log.

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

Not fixed by v0.1.6: the Bard already in the party in the author's two saves from the end of that
session. She is off stage with the travel block, and v0.1.6 will still refuse to send her to camp
(now saying why), because how the game's camp walk (`PROC_DismissToCamp`,
`_GLO_Shared_Origins.txt` L460–507) treats an off-stage character has not been tested. Untested repair: in the server console put her on stage, then untick her on the Party tab.

**Correction, 2026-10-13:** "use a save from before that session", which this file and the run
card said until today, is not possible. That game is an Honour Mode run with a single save
(`...\Savegames\Story\886719e0-5e70-1e04-ca24-c73bbab5a1e0__HonourMode\HonourMode.lsv`, last written
2026-10-12 10:13:05). Its metadata, read with Divine: leader `Calliope`; `SaveInfo.json` lists a
level 2 Dark Urge Asmodeus tiefling Hexblade warlock, Shadowheart, and `Hireling_Bard` (level 1
Bard). The first two stand in the camp region at about (-650, 0, -190); the Bard's position is
(278.75, 1.41, 223.25), far from them, which fits her being absent. A copy of the save folder as
it was then is in `C:\Claude Projects\BG3 Mods\PartyPicker_SaveBackups\2026-10-12_Calliope_HonourMode\`
(outside this repository).

**2026-10-12, v0.1.6 installed** at the author's request ("install 0.1.6 please"). Copied from the
repository's `PartyPicker.pak` (commit `eaf2072`) over v0.1.4 in
`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak` with the game and the mod
manager closed; hash checked after the copy: 30,043 bytes, SHA-256
`8A73AF064D42378231D0F39C13FE08B672DDB713DF8B08DC14B3397D847B384D`. Party Picker is still in the
load order (`modsettings.lsx`).

**2026-10-13, v0.1.6, first in-game report.** the author: "The party picker seems to be working properly
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

**2026-10-13 (evening), v0.1.6, Calliope's game.** the author: "I went to the Tiefling save and ran the
pp_roster". (He also pointed out, correctly: "But there is only one save for that character because
its honor mode", "so I could not go to an older save".) From
`Extender Runtime 2026-10-14 01-43-11.log` and `Osiris Runtime 2026-10-14 01-45-39.log`:
- `Party Picker v0.1.6 roster:` (1912), then, shortened here to the parts that matter:
  - `Calliope  ACTIVE avatar locked(player character)`
  - `Brinna Brightsong  ACTIVE hireling  [in: seen,team,hired,players,aligned,origalign,partymembers,incamp,hiretemplate,hiredflag; faction: Hireling2_...]`
  - `Maddala Deadeye  camp  hireling locked(not available: off stage (not present in the world)) [in: seen,team,hired,aligned,origalign,dismissed,offstage,cantmove,cantact,hiretemplate,campflag,IsOnStage=0; faction: Hirelings_...]`
  - `Shadowheart  ACTIVE`
  - `Varanna Sunblossom  camp  hireling locked(not available: off stage (not present in the world)) [in: team,hired,aligned,origalign,dismissed,offstage,cantmove,cantact,hiretemplate,hiredflag,IsOnStage=0; faction: Hirelings_...]`
  - `active 3, limit 14 (game reports 14)`
- **Confirmed in game:** the off-stage lock works, by both signals (`offstage` and `IsOnStage=0`;
  `Osi.IsOnStage` is callable from Script Extender, no `IsOnStage?`). The names are now known:
  Bard = Brinna Brightsong, Rogue = Maddala Deadeye, Fighter = Varanna Sunblossom.
- **The Bard is on stage again and no longer blocked.** During this load:
  `event WentOnStage(4d3c9cb3-..., 1)` (Osiris 65939), `DB_OffStage( 4d3c9cb3-... ) [delete fact]`
  (65942), `DB_CantMove( 4d3c9cb3-... ) [delete fact]` (65948), `RemoveStatus( ..., "TRAVELBLOCK_CANTMOVE", ... )`
  (65951), `DB_FastTravelBlock_CantMove_StatusSet( 4d3c9cb3-... ) [delete fact]` (65952). A fact can
  only be deleted if it was there, so this settles what was inferred on 2026-10-12: she did have
  the `DB_OffStage` row and the travel block. The log does not show what put her on stage (an
  engine event with no story call before it). She has `origalign` and `partymembers`, the two
  things the game's removal needs (PM:1305–1307), so unticking her should now work. Not yet tried.
- **Where off-stage hirelings come from: confirmed for the Rogue.** At load DaisyMorph wrote
  `Leftover DummyUuid S_GLO_Hirelings_Rogue_e4818484-... (keeping DummyUuid for reuse)` (1843),
  `Dismissing dummy hireling ...` (1845), `Dismissed dummy hireling e4818484-...` (1846). In the
  Osiris log: `PROC_GLO_PartyMembers_Remove( (CHARACTER)e4818484-..., (CHARACTER)NULL_..., 1 )`
  (52065), `DB_InCamp( ...Rogue... ) [delete fact]` (57118), `event WentOnStage(e4818484-..., 0)`
  (59335), `DB_OffStage( e4818484-... ) [add fact]` (59338), `DB_CantMove( e4818484-... ) [add fact]`
  (59344). So the hireling Party Picker sent to camp on 2026-10-12 was taken out of camp and put
  off stage by DaisyMorph, which treats her as its stand-in. That is DaisyMorph's doing, not Party
  Picker's; Party Picker now shows her as not available instead of recruiting her.

**2026-10-13 (evening), v0.1.6, the original report resolved in Calliope's game.** the author: "I
unticked Brianna and pressed apply and she was removed from the party". The same session's logs:
- `[PartyPicker] request: join []; send to camp [Brinna Brightsong]` (Extender log 1938),
  `AEE [Info] S_GLO_Hirelings_Bard_4d3c9cb3-... left the party, removing spells` (1939),
  `[PartyPicker] Party updated. Sent to camp: Brinna Brightsong.` (1940, 1941).
- Osiris log: `PROC_GLO_PartyMembers_Remove( ...Bard..., ...a9724ba4..., 0, 0 )` (897319),
  `PROC_GLO_PartyMembers_MakeNPC` (897417), `DB_Players( ...Bard... ) [delete fact]` (897428),
  `PROC_DismissToCamp` (897749), then `PROC_Hirelings_SendToCamp` (rule at 898156: hired flag
  cleared, in-camp flag set, `Hirelings_InCamp_Count` 0 → 1 at 898177–898178), and
  `event CharacterLeftParty(S_GLO_Hirelings_Bard_...)` (898528).
- This confirms, for a hireling: step 4 of the table below (untick, Apply, sent to camp) and the
  "send to camp" half of step 5, on v0.1.6. Not confirmed by this: that she is standing in camp
  with her normal talk options, and bringing a hireling back from camp.

**2026-10-13 (evening), same session.** the author, about the other two hirelings on the Party tab: "The
other ones say hireling unavailable off stage". That is the intended display for Maddala Deadeye
and Varanna Sunblossom, whose roster lines above carry `offstage` and `IsOnStage=0`. Whether the author
wants them to be recruitable was put to him the same day. His decision: "option 1, leave as is is
best". Off-stage characters stay listed, greyed out, with the reason; Party Picker does not bring
anyone on stage.

**2026-10-13 (evening), same session, from the log only (the author did not report this step).** After
being sent to camp, the Bard was ticked again: `[PartyPicker] request: join [Brinna Brightsong];
send to camp []` (Extender log 1942), then `[PartyPicker] Party updated. Joined: Brinna Brightsong.`
(1951, 1952). So bringing a hireling back from camp was accepted and verified by the mod's own
check. Not marked as passed: the author has not said what he saw.

**2026-10-13 (evening), v0.1.6.** the author: "Party picker seems to be working fine. Once I try a long
rest with a large party we will know if tis ready to ship.  I don't know if we can test the
grymforge boat but I will try to find a convenient save for that." So the long rest with more than
four (steps 7–10) is the test he will run before release; the raft (step 11) depends on finding a
save. Save folders whose names put them near the raft, from his Savegames folder (old saves, made
before many of the current mods, so they may not load cleanly): `Hellie-41612522216__Ebonlake Grotto - 44h 11m`,
`Electra-40281240519__Decrepit Village - 17h 25mGD`, `Electra-2911245914__Decrepit Sanctuary - 16h 06m`,
`Electra-56171242647__Grymforge - 37h 30mevilbefgrym`.

Still not known:
- (Answered 2026-10-13: the Bard has `origalign`, and "Brianna Brightsong" is this Bard, shown by
  the game as Brinna Brightsong.)
- Whether two listed characters can show the same name (another mod transformed the Rogue in that
  session). Not seen; the named result line would show it.

**2026-10-15, v0.1.6: long rest and raft.** the author: "The mod works fine with the boat and long rest!
So it's ready to ship." The logs of those sessions:
- **Long rest** (`Extender Runtime 2026-10-15 12-18-20.log`): `party size limit set to 14` (1904),
  `long rest held: party is larger than four` (2230), `request: join []; send to camp [Gale, Halsin,
  Karlach, Minthara, Raphael, Wyll]` (2231), `Party updated. Sent to camp: Gale, Halsin, Karlach,
  Minthara, Raphael, Wyll.` (2238), `Party trimmed to four for the night. Press End the Day again.`
  (2239), then after waking `request: join [Gale, Halsin, Karlach, Minthara, Raphael, Wyll]; send to
  camp []` (2331), `request refused: A party change is already in progress.` (2332, a second restore
  trigger while the first was running; harmless), `Party updated. Joined: Gale, Halsin, Karlach,
  Minthara, Raphael, Wyll.` (2381). Each message appears twice because the server and the client
  both log it.
- **Raft** (`Extender Runtime 2026-10-15 17-11-02.log`): `raft: added 36 landing positions` (3561);
  the raft test helper: `party of 7; landing spots at that dock: 16` (3690). `!raft_fix` was not
  used in that log.
- Steps 7, 8, 9 and 11 below are confirmed by the author's report. Not confirmed: step 10 (save between
  trim and rest), step 11b (the lake encounter; not stated), step 12 (multiplayer).
- Released as v0.1.6 (the same pak, unchanged). Release documents: `dist_docs\`.

**2026-10-15, release renumbered to v1.0.0.** the author: "Please change the version to 1.0.0 and redo the
pak and documentation". The v1.0.0 pak was rebuilt from the v0.1.6 source with only `PP.VERSION`
and the two `Version64` values changed; unpacking both paks and diffing them shows those three lines
and nothing else. Tests: 114 passed. Installed on the author's PC 2026-10-16 (the author: "please load the mod"; hash checked). Not yet loaded in game: the check is
`[PartyPicker] server loaded (v1.0.0).` in the log and 1.0.0 in BG3 Mod Manager.

**2026-10-17, v1.0.0 loaded in game.** the author: "You can check the SE log for the last game to see if
the PartyPicker loaded with the right version". `Extender Runtime 2026-10-17 18-17-18.log`:
`[PartyPicker] client loaded (v1.0.0) (Party tab added to MCM). Client console: !pp` (1034),
`[PartyPicker] server loaded (v1.0.0). ...` (1603, again at 2515 after a second load),
`[PartyPicker] party size limit set to 14` (1879, 3556). No error lines mention Party Picker.
Confirms the 1.0.0 pak loads, adds the MCM tab and applies the limit. The author, the same day: "Redux shows the correct version" (BG3 Mod Manager Redux lists Party
Picker as 1.0.0). The 1.0.0 install check is complete.

**2026-10-23, v1.0.1, House of Hope.** the author: "I think it worked -- the whole party got the debtors
clothes." `Extender Runtime 2026-10-23 02-55-09.log`: `server loaded (v1.0.1)` (1380, 2193), then
`House of Hope: giving the Debtor's Attire to 6 more party member(s): Alfira, Astarion, Halsin, Karlach,
Mizora, Wyll` (3355). The party was ten: the game's own four sets went to Shadowheart, Lae'zel,
Minthara and Gale (equip events for them just before, 3343-3354). No `did not arrive`, `could not give`,
`could not put` or `failed` line in that log. Step 13 confirmed for the hand-out; not reported: walking a
member five or up past a debtor spirit (the disguise status check).

**2026-10-25, v1.0.3, Inspiration probe, first step.** the author: "here is the result of the inspiration test..."
(console output pasted): `!pp_inspiration` printed `limit in the game's definition = 4`,
`party total (PartyGetActionResourceValue) = 3`, and for each of the ten party members (Lae'zel, Alfira,
Astarion, Gale, Halsin, Karlach, Minthara, Raphael, Shadowheart, Wyll) `personal nil; component: no
InspirationPoint entry`. So the static definition is readable, the party total is 3, and no character
carries an InspirationPoint entry of its own: the game keeps Inspiration for the party, not per character,
and a per-character fix is not needed. Second step, the author: "I set pp_inspiration 8 ...": `Inspiration limit set to 8 (test)`, then `limit in the game's definition = 8`, party total still 3,
members unchanged: writing the limit works and changes no points. Still to run: earning Inspiration past four,
save/reload, reset. Also reported the same day: lowering the party-size slider below the current party
"nothing happens"; the author wants it blocked (plan Part D).

**2026-10-25, v1.0.3, Send everyone to camp.** the author: "When I send the whole party to camp then in camp the
party panel disappears. It doesn't show even the primary player character -- in this case Laezel -- which I
believe should always be in the party panel.  Is this a bug?" `Extender Runtime 2026-10-25 20-42-03.log`:
`request: join []; send to camp [Alfira, Astarion, Gale, Halsin, Karlach, Minthara, Raphael, Shadowheart,
Wyll]` (1794) and `Party updated. Sent to camp: ...` the same nine (1804): Lae'zel was kept. The Osiris log
(`Osiris Runtime 2026-10-25 20-44-16.log`) has no DB_Players delete or party-leave event for her. **Not a
Party Picker bug: the game hides the portraits for a party of one.** Game.pak
`Mods/MainUI/GUI/Pages/PlayerPortraits.xaml` L194-207, comment "Check if we can hide player portraits": hidden
when "There's only one player", "it only has one assigned character" and "it has no companion nor follower"
(nor unlinked follower). The panel returns when someone joins (Astarion, Gale and Halsin rejoined at 1806-1825).
The button itself worked: step 4 of the 1.0.3 card confirmed for sending to camp.

**2026-10-26, v1.0.4.** the author: "Party picker is working fine. Please complete the MCM for the inspiration settings
and I will test it thoroughly in the next game." `Extender Runtime 2026-10-26 03-15-22.log`: `server loaded
(v1.0.4)` (1391); `party size limit set to 10` (1669); the load check, `This game's party has 10 members, more
than your Maximum party size (8). Party Picker uses 10 in this game; your setting stays 8.` (1741); sending
Wyll, then Shadowheart to camp lowered the applied limit with the party, 10 -> 9 -> 8 (3148-3160); Send
everyone to camp (seven at 3162-3173) and seven rejoining (3176-3219). Seen in the log: card steps 1, 3 and 6
(the message windows themselves are not in the log). Steps 2, 4 and 5 are not in this log, so not marked.

**2026-10-27, v1.0.6 (installed that day, hash checked).** The author, three reports from the same session:
"When you turn on the inspiration point controls the plus/minus does not appear automatically in the party
panel you have to press refresh. Ideally it should refresh automatically but if that is not possible then the
instructions should tell the user to refresh. Otherwise they may think its not working." Then: "When I check
match the party limit for inspiration the inspiration limit slider does not change -- it just stays where it
was. It should automatically move to match the party limit"; "The inspiration limit slider also allows you to
set it above the party limit even when match the party limit is toggled"; "the Inspiration limit slider should
be frozen at the party limit when match the party limit is chosen". `Extender Runtime 2026-10-27 18-13-49.log`:
`server loaded (v1.0.6)` (1391); `Inspiration limit set to 4` (1697); the slider moved 5 -> 8 (1778-1781);
five + presses, logged `Inspiration points 3 -> 3 (asked 4; Party tab)` ... `7 -> 7 (asked 8; Party tab)`
(1784-1788), then `Inspiration limit set to 9` and `8 -> 8 (asked 9; Party tab)` (1789-1790). Each press
started from one more than the last, so **the + button worked** (3 -> 9); the line read the points back
before the game had applied the change. Found from the log, not reported: in 1.0.6 that early read also put
"The game kept N Inspiration (asked for N+1)" on the status line after every press, and the tab redrew
before the change landed, so its count lagged one press behind. All four fixed in 1.0.7.

**2026-10-27, v1.0.7, Act 2 (Lae'zel game).** The author: "There may be a bug in the way the game counts excess
party members as being present for quest purposes.  In Act 2, Halsin was with the party when they met Jaheira,
but the dialogue with Halsin after assumed he was not present during the meeting. Also, when the player
character (in this instance Laezel) spoke to Art Cullagh and heard him speaking and thinking of Thaniel, and
then spoke to Halsin, Halsin seemed unaware that Thaniel was mentioned, and although Halsin referred to
Thaniel, the player character did not mention the connection to Cullagh.  To my recollection, once Halsin
learns of Cullagh speaking of Thaniel, he stays with Cullagh until Cullagh wakes up.  But in this instance
nothing triggered with Halsin." Then: "I caused Halsin to speak directly to Cullaugh, and that did not trigger
his Thaniel quest either although he asked about the name". **Cause: a Party Picker bug, not party size.**
Party members past four are counted: in `Osiris Runtime 2026-10-28 00-51-02.log` the Art Cullagh dialog
(`HAV_CursedFist`, started by Lae'zel at 1565763) walks all eight `DB_Players`, Halsin included (1566962 ff.).
But Halsin joins Art only in his quest state `SCL_LiftingTheCurse_State_HalsinAtHaven`
(`Act2_HAV_LiftingTheCurse_CursedFist.txt` L241-250, which also sets `HalsinAvailableForFist`), reached from
camp (`Act2_CAMP_LiftingTheCurse.txt` L44-60). The game keeps him out of the party until Thaniel is saved
(`GLO_LiftingTheCurse_State_HalsinRecruitable`, set in `Act2_TWN_LiftingTheCurse_Finale.txt` L163/L181;
bg3.wiki: he "can be recruited in Act Two after the party progress in the quest to lift the Shadow Curse to a
certain point"). On 2026-10-11, in Act 2, Party Picker added him from camp: `Extender Runtime 2026-10-11
03-01-41.log` 2788-2801 (`... Halsin ... joined the party`, `[PartyPicker] Party updated: 1 joined`) and
`Osiris Runtime 2026-10-11 03-10-45.log` 443056-443059 (first `RecruitedFirstTime_Halsin`). That first add ran
`GLO_Companion_Halsin.txt` L41-47 (recruitable flag set, normal companion), so his quest states never ran: no
`SCL_LiftingTheCurse_State_Halsin*` change in any log since. Only the journal entry fired
(`QuestUpdate(Halsin, "SCL_LiftingTheCurse", "ArtMentionsThaniel")`, 1661403). Party Picker lists him because
the story puts him in `DB_PartOfTheTeam` and `DB_OriginNPCAlignment` (`GLO_Companion_Halsin.txt` L5) before he
is recruitable; `PROC_GLO_PartyMembers_CheckAdd` checks only the player-count flag (`_GLO_Shared_PartyMembers.txt`
L478-482). 1.0.7 still allows it. The Jaheira meeting is probably the same cause (not checked in the logs).

**2026-10-28, v1.0.8 (installed that day, game closed, hash 4E5A8637 checked), same Lae'zel game.** The author ran
`!pp_halsin` with Halsin still in the party and pasted the output:
"[PartyPicker] !pp_halsin: state: SCL_LiftingTheCurse_State_HalsinInAct2 /
in party yes; in camp no; team yes; dead no; knocked out no; perma-defeated no /
flags: recruitable yes; inAct2 yes; travelToHaven no; liftingCurse no; atHaven no; availableForFist no; goToLake no; artAwake no /
dialog: Halsin_InParty_890c2586-6b71-ca01-5bd6-19d533181c71 /
first-recruit record (DB_OnlyOnce RecruitedFirstTime_Halsin): yes / level: SCL_Main_A"
(lines joined with " / "). Confirms the cause above: his quest state stopped at HalsinInAct2 (never AtCamp or
AtHaven), the recruitable flag and first-recruit record came from Party Picker's early add, and Art is still
asleep. The repair applies (InAct2 is an allowed state); the only check it would refuse today is "in party".
Next: send him to camp with the Party tab, hard save, `!pp_halsin repair`.

The author then sent him to camp and ran `!pp_halsin repair`; output:
"[PartyPicker] !pp_halsin: done. Talk to Halsin in camp and let him go ahead to Last Light. If that conversation
has no such option, run !pp_halsin haven. ... / state: SCL_LiftingTheCurse_State_HalsinInAct2 /
in party no; in camp yes; team yes; dead no; knocked out no; perma-defeated no /
flags: recruitable no; inAct2 yes; travelToHaven no; liftingCurse no; atHaven no; availableForFist no; goToLake no; artAwake no /
dialog: CAMP_Halsin2_c0ab0f6f-3ffc-d06d-0d6d-d1aaef70dfe4 /
first-recruit record (DB_OnlyOnce RecruitedFirstTime_Halsin): no / level: SCL_Main_A".
The repair did all three things it is meant to (flag cleared, first-recruit record deleted, camp dialog set).
State stays HalsinInAct2, as designed: the TravelToHaven reaction (`Act2_CAMP_LiftingTheCurse.txt` L56-63) moves
him straight to HalsinAtHaven, and PROC_State_Progress allows that upward move. Not yet confirmed: that the camp
conversation offers the Last Light option (fallback `!pp_halsin haven`), and that Art then brings Halsin in.

Then the author: "I went back to camp and Halsin is not there" (a second `!pp_halsin` still showed "in camp yes",
on stage not in question: no SetOnStage 0 for him in the session). `Osiris Runtime 2026-10-29 00-29-24.log`: the
send-to-camp walk (658080 ff.) ended with `DB_InCamp` (662695) and a teleport to
`S_Spawnpoint_Halsin_Fallback_SCLMain_A` (663295-663307); at the camp change to "HAVEN" he was teleported to
`S_Spawnpoint_Halsin_Fallback_Haven_A` (1231519, `PROC_CampSwap_UpdateAnubisCampPos`, 1232669). Those are his
alternate camp spots, used when Halsin and Minthara are both in the team (`Act2_CAMP_HalsinMintharaCFM.txt`
L5-12, L25-82), not his usual corner. So he is in camp, at the other spot. Not a Party Picker or repair fault.
The author: "I found him", then: "OK I spoke to him and he went to the Last Light Inn. So the repair seems to have
worked fine". **Confirmed in game: `!pp_halsin repair` plus the camp conversation sent Halsin to Last Light**
(the TravelToHaven option appeared; `!pp_halsin haven` was not needed). Then the author: "Art brought Halsin in
and the Thaniel quest started". **The 2026-10-27 Halsin / Art Cullagh report is closed: cause confirmed, save
repaired in game.** Still untested in game: the 1.0.8 lock itself (Halsin locked on the Party tab before he is
recruitable, in a game where Party Picker never added him) and its unlock after Thaniel is saved.
`!pp_halsin` afterwards (the author pasted it): "state: SCL_LiftingTheCurse_State_HalsinAtHaven / in party no; in camp
no; team yes; dead no; knocked out no; perma-defeated no / flags: recruitable no; inAct2 yes; travelToHaven yes;
liftingCurse yes; atHaven yes; availableForFist yes; goToLake no; artAwake no / dialog:
HAV_HalsinQuest_Halsin_2b827a2e-2358-d97a-a59a-e52b8be10a46 / first-recruit record ...: no / level: SCL_Main_A".
Matches the game's own path: L56-63 (AtHaven, LiftingCurse, HAV_HalsinQuest dialog) and CursedFist L241-250
(AvailableForFist).

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
| 11 | Act 1 Underdark: Ebonlake raft with 6 in party, to Grymforge and back | All 6 arrive at each dock, visible and able to move. Without Party Picker, boarding hides, protects and freezes every crew member (`Act1_UND_EbonLake.txt` L490–497) and landing only releases those with a position row (L589–609), so members 5+ would stay hidden and frozen. Helper to get there: `C:\Claude Projects\BG3 Mods\PartyPicker_RaftTest\` (`!raft_dock`, `!raft_fix`) | Raft landing spots 5–16. Log: `raft: added … landing positions` (at a level load or just before landing) |
| 11b | Same, through the lake encounter (Duergar raft) | All 6 stay on the raft and continue | **Risk:** on the lake, members 5+ share the four on-raft spots; if the game pushes someone off the raft they may be left behind |
| 13 | Act 3 House of Hope with 5+ in the party: talk to Hope until she hands out the Debtor's Attire | Everyone in the party wears it after the conversation. Log: `House of Hope: giving the Debtor's Attire to N more party member(s): <names>`. Server console for a member 5+: `_D(Osi.HasAppliedStatus("<their uuid>", "LOW_HOH_DEBTOR"))` prints 1; walking past a debtor spirit with them starts no crime reaction | v1.0.1 hand-out (`Server/HouseOfHope.lua`); that a copy gives the same disguise status as the game's own set |
| 12 | Multiplayer (host + 1) | Other player's tab is read-only; their characters stay locked | Peer id → user id conversion |

If step 7 fails, there is a fallback. Turn off "Ask before a long rest", trim with the Party tab
before resting, and tick everyone again afterwards.

**2026-10-28, v1.0.8, Lae'zel game: no Inspiration reroll offered.** First the author: "Also, the Inspiration may
not be working properly. I just had a persuasion check with Talli that I used a cheat to lose. After losing the
check I did not get a chance to try again with an Inspiration point, although the Party Picker UI says I have 6
inspiration points. Can you check the log on that." (`Osiris Runtime 2026-10-28 00-51-02.log`: Talli's dialog
`HAV_HavenOutcasts_HarperQuartermaster`, instance 81426; SC_FAIL_CHECKS on the party, on Lae'zel at 6113349; roll
failed at 6144688, DialogRollResult 6144817; SC_FAIL_CHECKS removed from Lae'zel at 6713294.) Then, after a test
without Talli: "I ran the check in the Inspirations and failed an DC check. No Inspiration rolls were offered
although MCM said I had 6 inspirations available." Log analysis (subagent, 2026-10-28; `Osiris Runtime
2026-10-29 00-29-24.log`, `Extender Runtime 2026-10-29 00-27-03.log`): the fails were Karlach's, in the House of
Healing surgeon's dialogue (instance 81897), two failed ACTIVE rolls (result 0, IsActiveRoll 1, criticality NONE:
Osiris 7674270 / 7684173) and one pass between them (7676903). No forced-fail status this time: no SC_FAIL /
FAIL_CHECK anywhere; Karlach's statuses after the load were SOAP_WASH, S5E_RITUAL_SPELL_REMOVAL,
EVOLVED_CONTROLLED_CHANGED, TRAVELBLOCK_CANTMOVE, PASSIVE_PEACE_BREAKER, FLANKED, MAG_CQCASTER_SPELLDC_BONUS.
Party Picker 1.0.8 loaded (SE 2646, 3362), `Inspiration limit set to 6` (SE 3543), no Party Picker errors. The
logs cannot show why the dialogue offered no reroll. Leading suspect (inferred): points and limit above the
game's own 4. Also seen: another mod hooks every dialogue start (`PROC_DisablePassiveCheck_ISBF`, 7662300; it
checks LUCKY / TIDES_OF_CHAOS / *_INSPIRATION *_ON_ISBF statuses). Proposed A/B test: limit 4 with 3 points;
limit 6 with 3 points; limit 6 with 6 points; each on a fresh failed active check.
Test B (limit 6, points 3), 2026-10-29/30, v1.0.9. The author: "I set the number of IP to 3. I still did not get
the chance to reroll on a fail." Console: server `MaxValue` 6.0, client (host) `MaxValue` 6.0. So holding more
than 4 points is not the cause, and server and client agree on the limit. Next: test A (limit 4, points 3).
