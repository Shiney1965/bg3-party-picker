Party Picker v{{VERSION}}.

**What's new since v1.1.0** (details in [dist_docs/CHANGELOG.md](dist_docs/CHANGELOG.md)):

- **The Party tab keeps itself up to date** when the game changes someone on it: a death, a revival, someone going down or getting up, a fight ending, recruiting or dismissing in the game's own conversations, switching the character you control. Ticks you have not applied yet are kept.
- **Dead and held party members stay ticked**, and a click on their box says why. Camp companions the game is holding can't be ticked.
- **While your own character is dead, the party can't be changed**, and the tab says so.
- **Long rests:** the dead and held count towards the four; the record of who waited is saved before anyone moves; with **Bring everyone back after the rest** on, a party still waiting in camp comes back when you load a save made after the rest; a restore that leaves someone out says who.
- **The game's own travel and dismissal rules** are checked for everyone Party Picker moves.
- Smaller fixes: profile switches, the combat setting, Halsin's early-join setting, Restore messages.

**Tested in game** (with v1.1.0 and the test builds before it): joining and dismissing companions and hirelings, a long rest with ten, the raft with seven, the House of Hope with ten, Send everyone to camp with nine. With test build v1.1.2: the Party tab redrawing by itself on a death and a revival, and (from the log) a request to send a downed member to camp refused with the reason. Nothing has been tested with v1.1.4 itself yet. **Not yet tested:** the other changes in this release, multiplayer, the raft's lake stop, parties above 16. Reports welcome.

**Known limitation found in this release's review:** nights the story starts itself (for example the Act One celebration after the goblin hunt) skip the long-rest window; see the README.

**Requires** BG3 Script Extender (v29+) and Mod Configuration Menu (Nexus 9162, v1.38+), loaded **above** Party Picker.

**Download:** `PartyPicker-{{VERSION}}.zip` — `PartyPicker.pak` plus README / INSTALL (md, docx, pdf), CHANGELOG, LICENSE, third-party notices and a manifest.

| File | SHA256 |
|---|---|
| PartyPicker.pak ({{PAK_BYTES}} bytes) | `{{PAK_SHA}}` |
| PartyPicker-{{VERSION}}.zip ({{ZIP_BYTES}} bytes) | `{{ZIP_SHA}}` |

Source for this build is the `main` branch at this tag. See [dist_docs/CHANGELOG.md](dist_docs/CHANGELOG.md) for the history.
