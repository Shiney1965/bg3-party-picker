# Changelog — Party Picker

Party Picker's development history. **v1.0.1 is the first public release.** Everything below it was a test build that was never published; the list is here so the first public release carries an honest record of how it got here.

Dates are the day each build was completed.

---

## v1.0.1 — 2026-10-22 — first public release

**Added: the House of Hope's Debtor's Attire for the whole party.** The game has four sets of the disguise Hope hands out and gives them to the first four party members, so members five and up got none. Party Picker now gives a set to every other party member inside the House when Hope hands them out, and puts it on. The extra sets are the game's own outfit: the game switches the wearer to it, and destroys it when the alarm is raised, exactly as it does its own four. New setting on the Settings tab, **Debtor's Attire for the whole party (House of Hope)**, on by default.

## v1.0.0 — 2026-10-15 — not released

The tested v0.1.6 build, renumbered for release. Only the version number changed; the code is the same. Superseded by v1.0.1 before upload.

## v0.1.6 — 2026-10-12 — the tested build (its code is in v1.0.0 and v1.0.1)

Tested in game on 2026-10-13 to 2026-10-15: joining and dismissing companions and hirelings from the Party tab, a party of more than four, the long-rest hold with a party of ten (six waited in camp and all six rejoined after waking), and the Grymforge raft crossing with a party of seven.

**Fixed: a hireling could be recruited but not sent back.** She was off stage (not present in the world at that moment, which another mod had done). The game blocks travel for a party member in that state, and Party Picker then refused to move her without saying why. Now:

- An off-stage character is listed but greyed out, "not available: off stage", and cannot be recruited.
- A refusal stays on the Party tab until you press Refresh or reopen the page, and is written to the log as `request refused: ...`.
- An accepted request is logged as `request: join [...]; send to camp [...]`, and the result names who moved: `Party updated. Joined: X. Sent to camp: Y.`

**Fixed:** a hireling the game did not actually remove is no longer marked as in camp.

**Changed:** after a long rest, a member who is still off stage is left in camp and the Restore button stays, instead of the record of who waited being dropped.

**Added to `!pp_roster`:** the marks the game uses to stop someone moving (`offstage`, `cantmove`, `cantact`, `travelblock`), the hireling state flags, and `IsOnStage=0`.

## v0.1.5 — 2026-10-12 — not released

A hireling character nobody has hired is no longer listed. (The game gives every hireling the companion marks before anyone hires them.)

## v0.1.4 — 2026-10-11 — not released

**Only real party members are listed:** player characters, companions the game marks as companions, hired hirelings, and anyone Party Picker has seen join your party (which covers companions added by other mods). Camp followers and camp pets (Volo, Elminster, the Oathbreaker Knight, Scratch, Tara and others) are no longer listed. `!pp_forget Name` added.

## v0.1.3 — 2026-10-11 — not released

Diagnostics: the version is printed at load, and `!pp_roster` shows for every character the story tables they are in and their faction.

## v0.1.2 — 2026-10-11 — not released

Withers, summons and followers are never listed.

## v0.1.1 — 2026-10-11 — not released

Requires Mod Configuration Menu 1.38 rather than 1.41, which had raised a "Dependency issue detected" warning on MCM 1.40.1.

## v0.1.0 — 2026-10-10 — not released

First build: the Party tab in MCM, the party-size slider (4 to 16), the long-rest hold with the pick-four window and the restore after waking, and the extra Grymforge raft landing spots.
