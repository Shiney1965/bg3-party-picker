# Changelog — Party Picker

Party Picker's development history. **v1.1.0 was the first public release; v1.1.4 is the second.** The builds in between, and everything below v1.1.0, were test builds that were never published; the list is here so each release carries an honest record of how it got here.

Dates are the day each build was completed.

---

## v1.1.4 — 2026-11-01

Everything from the test builds v1.1.1 to v1.1.3 (none released), plus the fixes from a whole-mod review of v1.1.3. Several of these came from an outside review of v1.1.0 and from the author's own tests.

**The Party tab keeps itself up to date.** It redraws by itself when the game changes someone on it: a death, a revival, someone going down or getting up, a fight ending, recruiting or dismissing in the game's own conversations, and switching the character you control; also when a change finishes, when the MCM window opens and when you switch MCM profile. Nothing runs between those events. Ticks you have not applied yet are kept through these redraws (Refresh and opening the Party page start from the party as it is). Tested in game (with v1.1.2): the list followed a death and a revival with MCM open.

**Dead and held party members stay ticked.** A dead party member, or one the game is holding right now (downed, in a conversation, in combat with **No party changes in combat** on), stays ticked; clicking their box says why instead of unticking them. The label reads "(dead)" (it read "(dead, dead)"), and "downed" also shows for the character you control.

**Camp companions the game is holding** (in a camp conversation, knocked out) can no longer be ticked; a click says why. Before, ticking one made the whole change fail.

**While your own character is dead, the party can't be changed.** Every change, including the long-rest trim and the restore, is refused with "Your character (<name>) is dead ..." until they are revived, and the Party tab says so. Before, the refusal named a story table. A downed character gets "your character is downed".

**The long rest.** The pick-four window counts dead party members, and anyone the game is holding, towards the four (with two dead it could not be confirmed before). Its two buttons work once per request. The record of who waited in camp is saved before anyone is sent there, and if it can't be saved nobody is sent. With **Bring everyone back after the rest** on, a party still waiting in camp is brought back when you load a save made after the rest. A restore that leaves someone out names who and why, in a message window when it happens on waking. With **Bring everyone back after the rest** off, the window now says to press Restore.

**Following the game's own rules.** Party Picker now checks the game's fast-travel restrictions for everyone it moves (companions coming from camp too), and the game's dismiss lock for those leaving: someone who can't move or can't talk right now, an area where companions can't be dismissed, arrest, camp night. A refusal names the person and the reason, with the game's table where there is one.

**Smaller fixes.** A profile switch redraws the tab and cancels a pending slider check; a list that still shows someone who has left gets a clear refusal; Restore says who could not come back; "Put Halsin's quest back on track" works with a dead party member; ticking **Let Halsin join early** in a game where it can't apply says so; changing **No party changes in combat** redraws the tab; the raft setting's description says that turning it off keeps spots already added.

**Not yet tested in game:** everything above except the redraw on a death and a revival. A downed party member being refused with the reason was seen in game with v1.1.2.

## v1.1.0 — 2026-10-31 — first public release

Everything in v1.0.1, plus the party, camp and Halsin changes from the test builds v1.0.2 to v1.0.9 (completed by 2026-10-28, none released). Some settings tried in those test builds were left out of this release.

**Party limit up to 30** (was 16). The raft gets landing spots for all of them. Parties above 16 have not been tested by the author.

**The limit is never below your party.** Setting Maximum party size below the number already in the party moves the slider back and a message window explains. A save whose party is larger than your setting keeps everyone; Party Picker says so once and leaves your setting as it is. Tested in game: loading a party of ten with the setting at 8 kept all ten, and the applied limit came down with the party as members went to camp.

**Ticking more than the limit** no longer greys out Apply: pressing it changes nothing and a message window says how many to untick.

**Send everyone to camp:** a Party tab button that asks once, then sends everyone who can go; your own character always stays. Tested in game with nine sent to camp. If your character is then alone, a message window explains that the game hides the party portraits for a party of one (that is the game, not the mod).

**Halsin is locked until the story lets him join.** In the base game Halsin can't be recruited in Act Two until Thaniel is saved. Earlier builds let you add him from camp before that, which stopped his quest at Last Light from starting. The Party tab now locks him until the game marks him recruitable, and does the same for Minthara and Minsc while the story keeps them from being recruited.

**New setting, Let Halsin join early** (off by default, Act Two only, before his quest at Last Light begins), with a Party tab button, **Put Halsin's quest back on track**, to press once your party has reached Last Light and before you talk to Art Cullagh. A message window reminds you when you first arrive there.

**New console command `!pp_halsin`** (`repair`, `haven`): reports on, or repairs, a Halsin who joined before the story allowed it. Tested in game with test build v1.0.8 (v1.0.9 moved that code behind the new button, unchanged in what it does): in a save where an earlier build had added Halsin early, `!pp_halsin repair` and a talk with him in camp sent him to Last Light, and Art Cullagh's scene with Halsin then started.

**The Party tab redraws by itself** when you change Maximum party size or Let Halsin join early; ticks you have not applied yet are kept.

**Not yet tested in game:** the Halsin lock in a game where he was never added early (and its release once Thaniel is saved), Let Halsin join early with its button, the slider moving back, the over-the-limit message window, the party-of-one message window, and parties above 16.

## v1.0.1 — 2026-10-22 — not released

**Added: the House of Hope's Debtor's Attire for the whole party.** The game has four sets of the disguise Hope hands out and gives them to the first four party members, so members five and up got none. Party Picker now gives a set to every other party member inside the House when Hope hands them out, and puts it on. The extra sets are the game's own outfit: the game switches the wearer to it, and destroys it when the alarm is raised, exactly as it does its own four. New setting on the Settings tab, **Debtor's Attire for the whole party (House of Hope)**, on by default. Tested in game with ten in the party: the game dressed four, Party Picker the other six.

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
