# Party Picker: test run card (v0.1.6)

**v0.1.6 is installed on Alan's PC** (2026-10-12, hash checked after the copy; steps 4–5 below are
done). Not yet tested in game. It replaces v0.1.4; v0.1.5 was never installed.

**Pak:** `PartyPicker.pak` (30,043 bytes)
SHA256 `8a73af064d42378231d0f39c13fe08b672ddb713df8b08dc14b3397d847b384d`

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
   - `[PartyPicker] server loaded (v0.1.6).`
   - `[PartyPicker] client loaded (v0.1.6) (Party tab added to MCM).`
   - `[PartyPicker] party size limit set to 6` (or your own limit)
8. Open the SE console, type `server`, then `!pp_roster`. The first line must read
   `Party Picker v0.1.6 roster:`. If it does not, the old pak is still loaded. Your companions
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
