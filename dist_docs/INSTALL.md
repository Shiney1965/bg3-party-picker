# Install — Party Picker

Party Picker installs like a normal `.pak` mod, with one requirement: **Mod Configuration Menu (MCM) must be installed and must load above Party Picker.** The Party list and every setting are in MCM. The whole process takes a couple of minutes.

## Prerequisites

1. **Baldur's Gate 3**, current Steam release (tested October 2026).
2. **BG3 Script Extender (BG3SE)** installed and working (version 29 or later). If you don't have it, get it from <https://github.com/Norbyte/bg3se>. When BG3 launches with Script Extender active, you'll see its console window if the console is switched on.
3. **Mod Configuration Menu (BG3MCM)**, NexusMods mod **9162**, version 1.38 or later. **Required.** Party Picker lists it as a dependency. Tested with MCM v1.41.0.
4. **BG3 Mod Manager (BG3MM)**, strongly recommended. Party Picker must be in your *active* load order, and a mod manager makes that one click.
5. **Windows.** Script Extender is Windows-only, so Party Picker is too.

Party Picker is safe to add to a playthrough already in progress. Your recruited companions are listed straight away.

**Honour Mode keeps a single save.** Back up the save folder before trying any new mod there.

## Install

1. **Download and unzip** `PartyPicker-1.0.0.zip`. Inside you'll find `PartyPicker.pak` plus these documents.

2. **Copy the `.pak` into your BG3 Mods folder.** Open File Explorer, paste this into the address bar, and press Enter:
   ```
   %LocalAppData%\Larian Studios\Baldur's Gate 3\Mods
   ```
   Copy `PartyPicker.pak` into that folder.

3. **Activate it in your load order.** Open BG3 Mod Manager and refresh its mod list (`F5` or the refresh button). "Party Picker" appears in the **Inactive** pane. Drag it into the **Active** list.

4. **Put Mod Configuration Menu above Party Picker.** Party Picker adds its Party tab to MCM while it starts, so MCM has to be loaded first. A minimal correct order looks like:
   ```
   Mod Configuration Menu
   ...(anything else)...
   Party Picker
   ```
   Click **Save Load Order to File**, then launch the game from BG3MM.

5. **Load any save, or start a new game.**

**Playing multiplayer?** Every player installs the same Party Picker, Script Extender and MCM versions, with MCM above Party Picker. The game compares mod lists when a player joins, and it cannot download a Nexus mod for you. Only the host can change the party. Multiplayer has not been tested yet.

## Verify it loaded

**1. The Script Extender log or console.** Party Picker prints two lines at startup:

```
[PartyPicker] client loaded (v1.0.0) (Party tab added to MCM). Client console: !pp
[PartyPicker] server loaded (v1.0.0). Console (server context): !pp_roster  !pp_set Name1,Name2  !pp_restore  !pp_size  !pp_forget Name
```

and, once the save has loaded:

```
[PartyPicker] party size limit set to 6
```

(or your own limit). The log is in `%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs\` (the folder name really is misspelled); open the newest `Extender Runtime *.log`.

**2. `!pp_roster`.** In the Script Extender console type `server` and press Enter, then `!pp_roster`. The first line reads `Party Picker v1.0.0 roster:`. Your companions are listed, your own character marked `locked(player character)`, and the last line shows the active count and the limit.

**3. The MCM page.** Press **INSERT** (or open MCM from the ESC menu) and find **Party Picker**. You should see two tabs: **Settings** and **Party**.

## Using it

- **Set your limit** on the Settings tab: **Maximum party size**, 4 to 16, default 6, counting your own character.
- **Pick your party** on the Party tab: tick who you want with you, untick who should go to camp, press **Apply**. The line under the buttons says what happened.
- **Before a long rest with more than four**, press End the Day as usual. A small window asks which four stay with you tonight (your own character is always one of them). Tick four, press **Keep these 4**, then press End the Day again. The others rejoin a few seconds after you wake up.
- **On the Grymforge raft**, board with everyone. They all land.

## Troubleshooting

### No [PartyPicker] lines in the log

- The pak isn't in `%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods`, or Party Picker isn't in the **active** load order. Refresh BG3MM and check both.

### BG3MM or the game reports a missing dependency

- Mod Configuration Menu is not installed or not active. Install it and put it **above** Party Picker.

### MCM opens but has no Party Picker page, or no Party tab

- Check the load order: MCM must be above Party Picker. If the log has `could not add the MCM Party tab: ...`, report that line. In the meantime, the client console command `!pp` opens the Party list in its own window.

### Apply does nothing

- Read the line under the buttons; it says why. Common reasons: someone joining or leaving is in combat (wait until combat ends, or switch off **No party changes in combat**); `cannot travel right now (...)`, meaning someone is in a danger zone, arrested, or the camp is in night mode (wait and try again); or a character is off stage. The same message is in the log after `request refused:`.
- If **Apply** is greyed out, more people are ticked than the limit allows, or nobody is ticked.

### A hireling is greyed out with "not available: off stage"

- They are not present in the world at the moment, so they cannot be brought to you. This is usually another mod's doing. Party Picker does not put characters back on stage.

### The long rest started without asking

- Check that **Ask before a long rest** is on and that more than four are in the party. If a mod that changes the camp or the rest is installed, it may run the rest its own way. Fallback: trim your party to four on the Party tab before resting and tick everyone again afterwards.

### After a rest, some of the party did not come back

- Press **Restore** on the Party tab (it appears while anyone is still waiting), or run `!pp_restore` in the server console. If the party is already at the limit, raise the limit first: Restore never sends anyone away to make room.

### The version BG3MM shows doesn't match the log

- Go by the log; it is printed by the code that is actually running. Refresh BG3MM and re-export the load order.

### Do not run Party Picker alongside another party-limit mod

- Party Limit Begone and similar mods set the same party limit; whichever applies it last wins. Pick one.

## Uninstalling

1. **Before removing it, cut your party back to four** on the Party tab and save. What happens to a party larger than four once Party Picker is gone has not been tested.
2. Deactivate **Party Picker** in BG3 Mod Manager and save the load order.
3. Delete `PartyPicker.pak` from your BG3 Mods folder.

Party Picker adds no items, spells or statuses. What stays in your save is its own small records (who waited in camp during a rest, and who it has seen join your party) and the extra raft landing rows, which the game only uses when more than four people ride the raft.

Your settings are kept in MCM's profile folder in case you reinstall:

```
%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\BG3MCM\Profiles\<profile>\PartyPicker\settings.json
```

Delete that folder too if you want a clean slate.
