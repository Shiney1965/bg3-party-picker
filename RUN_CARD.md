# Party Picker: test run card (v1.0.2, test build)

**v1.0.2 (2026-10-24): test build toward 1.1.0.** Party limit up to 30, and the Inspiration probe
command (plan `docs/PLAN_inspiration_and_30.md`, step 0). No Inspiration setting yet. Tests: 146
passed. Plan and code each reviewed adversarially; the code review's no-copying check against
Configurable Party Limit passed. **Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (37,207 bytes)
SHA256 `f4cf50d26a8301b1a4f9f2ffebb31a0c7e862c9624ac63dd286d955d63ed04eb`

**Test card for v1.0.2** (record results in docs/TESTING.md):
1. Log: `[PartyPicker] server loaded (v1.0.2).`
2. MCM, Party Picker, Settings: the Maximum party size slider goes up to 30.
3. If you can field 17 or more: set the limit to 17+, tick them, Apply; check the portraits, travel, a long
   rest (still four in bed).
4. Inspiration probe, in a save where the party has some Inspiration. SE console: type server, then
   !pp_inspiration (shows the limit, the party total, and each member's points). Then
   !pp_inspiration 8 (sets a test limit of 8 and shows the same again). If convenient, earn one
   Inspiration with the limit at 8 and run !pp_inspiration again. Then save, reload, and run
   !pp_inspiration once more (shows whether the test limit survives a reload). Finally
   !pp_inspiration reset (back to the game's 4). Send the log.

# v1.0.1 (kept for the record)


**v1.0.1 (2026-10-22): the House of Hope's Debtor's Attire for the whole party.** Alan: "Let's add the
fix to give the Debtor's attire then to the whole party." New `Server/HouseOfHope.lua`, one new MCM
setting (`hope_attire_everyone`), version 1.0.1. Tests: 136 passed. Plan and code each reviewed
adversarially (`docs/PLAN_hope_attire.md`). **Installed on Alan's PC 2026-10-22** (Alan: "install"; replaced 1.0.0 `89005f94…`, hash checked after the copy). **Tested in game 2026-10-23:** "the whole party got the debtors clothes" (log line 3355 names the six extra members; see docs/TESTING.md).

**Pak:** `PartyPicker.pak` (33,913 bytes)
SHA256 `b3a9893ca4b66e140198879d2ebe1d7eeb444be05e0e034d4fb72488148bff60`

**The test for v1.0.1** (docs/TESTING.md step 13): a save in Act 3 before Hope hands out the
Debtor's Attire in the House of Hope, with five or more in the party. After the conversation everyone
wears the attire, and the log has `House of Hope: giving the Debtor's Attire to N more party
member(s): <names>`. Then walk a member five or up past a debtor spirit: no crime reaction.
Also check the log line `[PartyPicker] server loaded (v1.0.1).`

## v1.0.0 (kept for the record)

**v1.0.0 is the release build (2026-10-15).** It is v0.1.6 with the version changed and nothing
else: unpacking both paks and comparing them shows only `PP.VERSION` in `Shared/Common.lua` and the
two `Version64` values in `meta.lsx` differ. v0.1.6 was installed on Alan's PC on 2026-10-12 and
tested in game 2026-10-13 to 2026-10-15, long rest and raft included (see docs/TESTING.md).
**v1.0.0 installed on Alan's PC 2026-10-16** (at his request; hash checked after the copy: `89005f94…b07a56e3c`). **Loaded in game 2026-10-17** (`Extender Runtime 2026-10-17 18-17-18.log`: `server loaded (v1.0.0)` at 1603, `client loaded (v1.0.0) (Party tab added to MCM)` at 1034, `party size limit set to 14` at 1879). The check was: the log line reads
`[PartyPicker] server loaded (v1.0.0).` and BG3 Mod Manager shows 1.0.0.

**Pak:** `PartyPicker.pak` (30,043 bytes)
SHA256 `89005f94feeab56fa4e79969bc2f258de1804a809b4359a587c82f4b07a56e3c`

**The tested v0.1.6 pak** (30,043 bytes) was SHA256
`8a73af064d42378231d0f39c13fe08b672ddb713df8b08dc14b3397d847b384d`.

**Built with:** `python3 tools/lspk.py create src PartyPicker.pak`, from the files as git stores
them (LF line endings). Rebuilding Scroll Repair's `src/` with the same tool gives a pak
byte-identical to the Divine-built `ScrollRepair.pak`, and rebuilding v0.1.5 this way on Alan's PC
gave the committed v0.1.5 pak byte for byte.

## What changed since v0.1.4 (the installed build)
- **The hireling who could be recruited but not sent back (2026-10-12).** She was off stage (not
  present in the world). The game blocked her travel as soon as she joined, and Party Picker then
  refused to move her; the reason flashed on the Party tab for a second and a half and was not in
  the log. Now:
  - an off-stage character is listed but locked ("not available: off stage") and cannot be recruited;
  - a refusal stays on the Party tab and is written to the log as `request refused: ...`;
  - an accepted request is logged as `request: join [...]; send to camp [...]`, and the result
    names who moved: `Party updated. Joined: X. Sent to camp: Y.`
- A hireling the game did not remove is no longer marked as "in camp".
- `!pp_roster` also shows `offstage`, `cantmove`, `cantact`, `travelblock`, `campflag`,
  `hiredflag` and `IsOnStage=0`.
- After a long rest, a member who is still off stage is left in camp and the Restore button stays,
  instead of the trim record being dropped.
- From v0.1.5: a hireling character nobody has hired is not listed.

**Not fixed:** the Bard hireling already in the party in Calliope's game (Honour Mode, Dark Urge
tiefling warlock, with Shadowheart; save folder `886719e0-5e70-1e04-ca24-c73bbab5a1e0__HonourMode`).
v0.1.6 will still refuse to send her to camp, and now says why. Honour Mode keeps one save, so
there is no earlier save to go back to. A copy of the save as it was on 2026-10-12 10:13 is in
`C:\Claude Projects\BG3 Mods\PartyPicker_SaveBackups\2026-10-12_Calliope_HonourMode\`.
Untested repair: in the server console, Osi.SetOnStage("4d3c9cb3-ca34-46ba-9c81-44081270bfde", 1)
and then untick her on the Party tab.

## Before you start
1. Make a **hard save** in a new slot, e.g. `BACKUP before Party Picker`.
2. Requirements:
   - BG3 Script Extender, with the console on (`"CreateConsole": true`).
   - **Mod Configuration Menu** 1.38 or newer, installed and active. Party Picker lists it as a dependency.
3. Quit the game.

## Install
4. Put `PartyPicker.pak` in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\`.
5. In BG3 Mod Manager: refresh, activate **Party Picker** with **Mod Configuration Menu** above it,
   then export/save the order.
6. Launch and load the backup.

## Quick checks
7. Open the newest Script Extender log,
   `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs\Extender Runtime *.log`
   (the folder name really is misspelled). Look for:
   - `[PartyPicker] server loaded (v1.0.0).`
   - `[PartyPicker] client loaded (v1.0.0) (Party tab added to MCM).`
   - `[PartyPicker] party size limit set to 6` (or your own limit)
8. Open the SE console, type `server`, then `!pp_roster`. The first line must read
   `Party Picker v1.0.0 roster:`. If it does not, the old pak is still loaded. Your companions
   should be listed, your character marked `locked(player character)`. Each line ends with
   `[in: ...; faction: ...; id: ...]`. **Send me the whole output.**
9. Open MCM. Party Picker should have a **Settings** tab and a **Party** tab.

## The test for the 2026-10-12 report
10. In Calliope's game (the only save has the Bard already in the party): run `!pp_roster`. The
    Bard's line should contain `offstage` or `IsOnStage=0` (or both), and `travelblock`. On the
    Party tab she should be ticked and tagged "off stage". The Fighter hireling is in the same
    story tables and not in the party: if she is off stage too, her box should be greyed out with
    "not available: off stage"; whether she is was not in the log, so note what her line shows.
11. Untick the Rogue hireling, press Apply. The tab should say
    `Party updated. Sent to camp: <her name>.` and the log should have a
    `request: join []; send to camp [<her name>]` line.
12. Tick her again, Apply. `Party updated. Joined: <her name>.`
13. The refusal, in Calliope's game: untick the Bard, Apply. Expected: nothing changes, and the tab keeps showing
    `<her name> cannot travel right now (DB_FastTravelBlock_CantMove_StatusSet): they are off stage ...`
    until you press Refresh. The same text is in the log after `request refused:`.

## The other tests that matter
Follow `docs/TESTING.md`, steps 3–12. Most important:
- **Step 3:** tick 6, Apply, and check that 6 portraits appear.
- **Step 7:** with 6 in the party, End the Day. The rest should **not** start; the picker window
  should open.
- **Steps 8–9:** pick four, rest, wake. The other two rejoin.

## If something goes wrong
- Do not save over your backup. Reload it.
- Send me every `[PartyPicker]` line from the log and say which step failed.
- To remove the mod: deactivate it in BG3MM, then delete the pak. It adds no items or spells, only
  its own settings and two saved variables.
