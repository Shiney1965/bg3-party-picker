# Party Picker — development notes

For players: the user README is [README.md](../README.md) at the top of the repository, and the
install guide is [dist_docs/INSTALL.md](../dist_docs/INSTALL.md). This page is for building and
changing the mod. **Status: v1.0.0 built and tested in game (2026-10-15 to 2026-10-17), the tested v0.1.6 code renumbered; publishing to GitHub and Nexus in progress.**
Every in-game report is in [TESTING.md](TESTING.md); research and sources are in
[RESEARCH.md](RESEARCH.md); install and test steps are in [RUN_CARD.md](../RUN_CARD.md).

- **Party tab in Mod Configuration Menu (MCM).** Your party members are listed with a checkbox:
  player characters, origin companions, hirelings, and companions added by other mods. Tick who
  you want with you and press **Apply**. There are no hotbar spells and no talking to companions to
  invite or dismiss them.
- **Larger parties.** A slider sets the party limit from 4 to 16.
- **The two places the game handles only four:**
  - **Long rest.** The camp has four beds, and the game puts only four party members to bed. If
    your party is larger, End the Day is held and a window asks which four to keep tonight. The
    others wait in camp and rejoin when you wake up. Nobody is sent away to make room for them.
  - **The Grymforge raft (Underdark).** The raft already takes everyone aboard but has only four
    landing spots, so members five and up are left on board, hidden and unable to move. Party Picker adds landing
    spots so the whole party arrives. No choice is needed.

## Requirements

- BG3 Script Extender v29 or newer (developed against v32; tested in game on v33).
- Mod Configuration Menu 1.38 or newer (the first version with the table-style API calls this mod uses; developed against 1.41; tested in game on 1.40.1 and 1.41.0).

## How it works

Party Picker uses the same story procedures the game's own dialogue and dismiss button use, so the
game's bookkeeping stays correct:

| Task | Story procedure |
|---|---|
| Join | `PROC_GLO_PartyMembers_CheckAdd` (companions), `PROC_Hirelings_TakeFromCamp` (hirelings in camp), `PROC_Hirelings_AddToParty` (other hirelings) |
| Go to camp | `PROC_GLO_PartyMembers_Remove(member, your avatar, 1)`; hirelings also `PROC_Hirelings_SendToCamp` |
| Party limit | `SetMaxPartySizeOverride`, re-applied on each level load |

The two four-member situations are handled with Script Extender listeners and story databases.
No game file is replaced and the executable is not patched:

- **Long rest:** Party Picker adds a story reason to the camp's existing "not ready for night"
  check. This is the mechanism the game itself uses to block resting in some story moments.
- **Raft:** Party Picker adds rows 5–16 to the raft's landing-position table. They reuse the
  existing positions at each dock.

Details and sources are in [RESEARCH.md](RESEARCH.md).

## Layout

```
src/Mods/PartyPicker/
  meta.lsx                       mod info; depends on MCM
  MCM_blueprint.json             Settings tab
  ScriptExtender/Config.json
  ScriptExtender/Lua/
    BootstrapServer.lua          network handlers, console commands
    BootstrapClient.lua          MCM Party tab, picker window, !pp fallback
    Shared/Common.lua            channels, helpers
    Server/Party.lua             roster, apply changes
    Server/Restrictions.lua      long-rest hold/restore, raft landing spots
    Client/PartyTab.lua          the Party tab
    Client/PickFour.lua          the pick-four window
    Client/RosterList.lua        checkbox list used by both
tests/                           mock game + scenarios (python3 tests/run_tests.py)
docs/                            research notes and the in-game test plan
```

## Console commands (testing)

- **Server context:** `!pp_roster`, `!pp_set Shadowheart,Astarion,Gale`, `!pp_restore`, `!pp_size`,
  `!pp_forget Name`
- **Client context:** `!pp` opens the Party list without MCM.

## Building the .pak and the release

Release documents: edit `dist_docs/*.md` and `dist_docs/NexusMods_BBCode.txt`, then run
`powershell -File tools/make_docs.ps1` (Word, PDF, Nexus preview, and the repository README) and
`powershell -File tools/assemble_bundle.ps1 [-Force]` (the bundle and zip in `release/`).

The pak:

```
pip install lz4
python3 tools/lspk.py create src PartyPicker.pak
python3 tools/lspk.py list PartyPicker.pak      # inspect
```

`tools/lspk.py` writes LSPK version 18, the format LSLib's Divine writes for BG3 (layout taken
from LSLib's `PackageFormat.cs` and `PackageWriter.cs`). It was checked by rebuilding Scroll
Repair's `src/`: the result is byte-identical to the Divine-built `ScrollRepair.pak`. Divine or
BG3 Modder's Multitool can still be used instead. See [RUN_CARD.md](../RUN_CARD.md) to install and test.

## Known limits and how the roster is built

The user-facing list is in the README's "Known limitations". In-game results are in
[TESTING.md](TESTING.md); still untested: multiplayer, saving between the trim and the rest, and
the raft's lake stop.
- Multiplayer: only the host can change the party. Player characters and anyone another player
  controls are never moved.
- A companion the story is keeping in camp for a scene can still be ticked, because the add procedure does not repeat the
  checks the recruitment dialogues make. Whether that causes trouble is untested.
- On the raft's lake stop, members 5+ share the four standing spots on the raft. This is untested.
- Turning the raft setting off does not remove landing spots that were already added. They are
  only used when more than four people ride the raft.
- Who is listed. A character is listed when they are one of these:
  - a player character (`DB_Avatars`, or a dismissed one in `DB_DismissedAvatar`);
  - a companion the story marks as one: an NPC alignment (`DB_OriginNPCAlignment` or
    `DB_GLO_PartyMembers_OriginalAlignment`), which the game needs to dismiss a companion and which
    its camp script uses to tell companions from camp followers, or the record the game writes when
    a party member is dismissed (`DB_GLO_PartyMembers_DefaultFaction`);
  - a hireling the story has as hired (`DB_Hirelings_Hired`). Hireling characters carry the
    companion marks before anyone hires them (`Hirelings.txt` L280–285), so for them only hiring
    counts. A hireling hired by another mod's script counts too, because the story cannot tell the
    difference;
  - anyone Party Picker has seen join the active party. This covers companions added by other mods
    that the story does not mark, and it is saved with the game. `!pp_forget Name` removes someone
    from this record.

  A listed character who is off stage (not present in the world, `DB_OffStage`) is shown locked
  as "not available: off stage" and cannot be recruited: the game's add procedure would not bring
  them on stage, and the game blocks travel for a party member who cannot move
  (`_Waypoints.txt` L188–194). **Limit:** someone already in your party who is off stage (for
  example recruited with v0.1.4) cannot be sent to camp by Party Picker. The Party tab says so.
  Reload a save from before they joined, if there is one (Honour Mode keeps a single save).

  Withers, summons and followers are never listed. Camp followers and camp pets (Volo, Elminster,
  the Oathbreaker Knight, Scratch, Tara and others) are left out because they fit none of the above.
  **Limit:** a companion added by another mod that the story does not mark, who is in camp and has
  not joined your party since Party Picker was installed, is not listed until they join once the
  normal way. `!pp_roster` shows why each
  character is or is not listed, and the marks the game uses to stop someone moving (`offstage`,
  `cantmove`, `cantact`, `travelblock`).
- Every request from the Party tab is written to the Script Extender log: `request: join [...];
  send to camp [...]` when accepted, `request refused: ...` with the reason when not.
- Dialogue still seats the speaker plus three. That is not changed.
- Quest items carried by member 5+ are sometimes not registered, per Party Limit Begone's notes.
  That is not addressed.

## History

Developed first inside `Shiney1965/BG3-Scroll-Repair` (branch `claude/bg3-party-expansion-mod-w8q7co`,
folder `PartyPicker/`) and moved here on 2026-10-11 with its full commit history (`git subtree split`).
From now on this repository is the home of Party Picker.

## Licence

MIT.
