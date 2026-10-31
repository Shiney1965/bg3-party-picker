Party Picker v{{VERSION}} — first public release.

**Choose who is in your party from a menu.** Open the Party tab in Mod Configuration Menu, tick the companions and hirelings you want with you, and press **Apply**. The party limit goes from 4 to as many as 30, and is never set below the party you already have. **Send everyone to camp** is one button.

**The places where the game only handles four:**

- **Long rest.** The camp has four beds. With a larger party, End the Day is held and a small window asks which four stay with you tonight; the others wait in camp and rejoin a few seconds after you wake. Nobody is sent away to make room for them.
- **The Grymforge raft (Act 1 Underdark).** The raft has four landing spots per dock, so members five and up were left on board. Party Picker adds landing spots so the whole party arrives.
- **The House of Hope (Act 3).** The game has four sets of the Debtor's Attire disguise. When Hope hands them out, Party Picker gives a set to every other party member inside the House and puts it on.

**Halsin joins when the story says so.** As in the game, the Party tab keeps Halsin locked in Act Two until Thaniel is saved. The optional setting **Let Halsin join early** lifts that in Act Two, with a Party tab button that puts his quest back on track at Last Light.

**No game files replaced, no executable patched.** Party Picker uses the game's own recruit and dismiss procedures, the ones the companions' dialogue and the dismiss button use.

**Tested in game:** joining and dismissing companions and hirelings from the Party tab, a party of more than four, a long rest with ten in the party (six waited in camp, all six rejoined on waking), the raft crossing with seven, the House of Hope hand-out with ten (six extra sets), Send everyone to camp with nine, a save with a party larger than the setting, and the Halsin repair from the console (in test build 1.0.8; 1.0.9 moved that code behind the new button). **Not yet tested:** multiplayer, saving between the pick-four window and the rest, the raft's lake stop, parties above 16, the Halsin lock in a game where he was never added early, Let Halsin join early with its button, the party-limit slider moving back when set below the party, and the message windows (over the limit, party of one). Reports welcome.

**Requires** BG3 Script Extender (v29+) and Mod Configuration Menu (Nexus 9162, v1.38+), loaded **above** Party Picker.

**Download:** `PartyPicker-{{VERSION}}.zip` — `PartyPicker.pak` plus README / INSTALL (md, docx, pdf), CHANGELOG, LICENSE, third-party notices and a manifest.

| File | SHA256 |
|---|---|
| PartyPicker.pak ({{PAK_BYTES}} bytes) | `{{PAK_SHA}}` |
| PartyPicker-{{VERSION}}.zip ({{ZIP_BYTES}} bytes) | `{{ZIP_SHA}}` |

Source for this build is the `main` branch at this tag. See [dist_docs/CHANGELOG.md](dist_docs/CHANGELOG.md) for the history.
