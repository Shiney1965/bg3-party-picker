# Testing

## Outside the game (done)

`python3 tests/run_tests.py` (needs `pip install lupa`):
- compiles every Lua file under Lua 5.4;
- runs the server logic against `tests/mock_game.lua`, a fake of the Osiris databases and story
  procedures as documented in `docs/RESEARCH.md`. The mock checks `TeleportTo`'s argument count,
  refuses two-argument `Remove` calls and avatar removals, and models the hireling camp counter.

The 82 checks cover:
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
