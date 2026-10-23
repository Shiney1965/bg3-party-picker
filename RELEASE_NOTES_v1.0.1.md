Party Picker v1.0.1 — first public release.

**Choose who is in your party from a menu.** Open the Party tab in Mod Configuration Menu, tick the companions and hirelings you want with you, and press **Apply**. The party limit goes from 4 to 16.

**The places where the game only handles four:**

- **Long rest.** The camp has four beds. With a larger party, End the Day is held and a small window asks which four stay with you tonight; the others wait in camp and rejoin a few seconds after you wake. Nobody is sent away to make room for them.
- **The Grymforge raft (Act 1 Underdark).** The raft has four landing spots per dock, so members five and up were left on board. Party Picker adds landing spots so the whole party arrives.
- **The House of Hope (Act 3).** The game has four sets of the Debtor's Attire disguise. When Hope hands them out, Party Picker gives a set to every other party member inside the House and puts it on.

**No game files replaced, no executable patched.** Party Picker uses the game's own recruit and dismiss procedures, the ones the companions' dialogue and the dismiss button use.

**Tested in game:** joining and dismissing companions and hirelings from the Party tab, a party of more than four, a long rest with ten in the party (six waited in camp, all six rejoined on waking), and the raft crossing with seven. **Not yet tested:** the House of Hope hand-out (new in 1.0.1; covered by the automated tests only), multiplayer, saving between the pick-four window and the rest, and the raft's lake stop. Reports welcome.

**Requires** BG3 Script Extender (v29+) and Mod Configuration Menu (Nexus 9162, v1.38+), loaded **above** Party Picker.

**Download:** `PartyPicker-1.0.1.zip` — `PartyPicker.pak` plus README / INSTALL (md, docx, pdf), CHANGELOG, LICENSE, third-party notices and a manifest.

| File | SHA256 |
|---|---|
| PartyPicker.pak (33,913 bytes) | `B3A9893CA4B66E140198879D2EBE1D7EEB444BE05E0E034D4FB72488148BFF60` |
| PartyPicker-1.0.1.zip (706,275 bytes) | `4167E1F793E13243F28689030FD02201EC24DE034006D69F19D17D7CE4565770` |

Version 1.0.1 is the tested v0.1.6 code plus the House of Hope hand-out. Source for this build is the `main` branch at this tag. See [dist_docs/CHANGELOG.md](dist_docs/CHANGELOG.md) for the history.
