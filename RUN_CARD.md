# Party Picker: test run card (v1.0.9, test build)

**v1.0.9 (2026-10-28): "Let Halsin join early" and "Put Halsin's quest back on track"** (asked for by the author
2026-10-28; plan docs/PLAN_halsin_early_option.md, "As built"). Default unchanged from 1.0.8: Halsin is locked
until Thaniel is saved.
1. MCM Settings, new section **Story companions**, checkbox **Let Halsin join early** (off by default). Ticked,
   the Party tab lets him join in Act Two only, before his quest at Last Light begins (Art Cullagh asleep).
2. Party tab, new section (only for a Halsin who joined early and whose quest hasn't reached Last Light): button
   **Put Halsin's quest back on track**, available once the party has reached Last Light. It asks once ("Make a
   hard save first"), sends Halsin to camp if he is in the party, then does what `!pp_halsin repair` does. Then
   talk to him in camp and let him go ahead to Last Light. After that he stays locked until Thaniel is saved,
   even with the checkbox ticked.
3. The first time the party reaches Last Light with an early-joined Halsin, a message window says what to do.
Tests: 292 server + 25 client checks pass. Plan reviewed (proceed with changes; the author then chose Act Two only
and a button instead of an automatic reset) and code reviewed (ship with changes; all changes made). The pak
contains no occurrence of the author's name. **Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (62,451 bytes)
SHA256 `87e30b987425b09a1e074ac5e382dd4d5e499900f5df61830036bd11d99e0459`

**Test card for v1.0.9** (record results in docs/TESTING.md). Your Lae'zel game is already repaired, so the full
path needs a save in Act Two before Last Light with Halsin in camp (not yet recruited). Make a hard save first.
1. Log: `[PartyPicker] server loaded (v1.0.9).`
2. Checkbox off: Halsin locked on the Party tab ("not recruitable yet ...").
3. Tick **Let Halsin join early**: the Party tab unlocks him; tick him, Apply. He joins.
4. Party tab: the Halsin section shows; the button is greyed: "Available once your party has reached Last Light."
5. Walk into Last Light: a message window tells you to press the button before talking to Art Cullagh.
6. Press **Put Halsin's quest back on track**, then **Yes**. He goes to camp; a message window says his quest is
   back on track. `!pp_halsin`: recruitable no, dialog CAMP_Halsin2.
7. In camp, talk to Halsin; let him go ahead to Last Light. Then talk to Art Cullagh: Halsin joins the scene.
In your current Lae'zel game only steps 1-2 apply (and the checkbox should NOT unlock him: his quest is under way).

# v1.0.8 (kept for the record)
**v1.0.8 (2026-10-27): Halsin's recruit gate and a repair for the author's save** (docs/TESTING.md, last
entry; plan docs/PLAN_halsin_recruit_gate.md). On 2026-10-11 an early Party Picker added Halsin from camp in
Act 2, before the story made him recruitable, so his Lifting the Curse steps never ran (no stay at Art
Cullagh's bedside). 1.0.8:
1. The Party tab locks Halsin, while he is not in the party, until the game marks him recruitable ("not
   recruitable yet: they join later in the story"). Minthara and Minsc are locked the same way while the story
   blocks their recruitment (DB_GLO_PartyMembers_BlockRecruitmentDialog).
2. Server console `!pp_halsin` reports his state; `!pp_halsin repair` puts him back where the story expects him
   (camp, his Act 2 camp dialog, not recruitable); `!pp_halsin haven` is the fallback that sends him to Last
   Light if the camp conversation does not.
Tests: 260 server + 17 client checks pass. Plan and code each reviewed adversarially (plan: proceed with
changes; code: ship with changes; all changes made). The pak contains no occurrence of the author's name.
**Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (57,650 bytes)
SHA256 `4e5a8637b80c561a1dafffede19c279832b505576add372d0346e942aed6e224`

**Test card for v1.0.8** (record results in docs/TESTING.md). Make a hard save first, and do steps 3-7 before
any long rest.
1. Log: `[PartyPicker] server loaded (v1.0.8).`
2. Server console `!pp_halsin`: lines starting `!pp_halsin:` with his state, flags and dialog. Send them over.
3. Party tab: untick Halsin, Apply. He goes to camp.
4. Server console `!pp_halsin repair`: `done. Talk to Halsin in camp ...`. The Party tab now shows Halsin locked.
5. In camp, talk to Halsin and let him go ahead to Last Light. If no such option: `!pp_halsin haven`.
6. `!pp_halsin`: state `SCL_LiftingTheCurse_State_HalsinAtHaven`.
7. At Last Light, Halsin is by Art Cullagh; talk to Art: Halsin joins the conversation.
Until Halsin rejoins after Thaniel, a knockout is permanent for him (as in the unmodded game).

# v1.0.7 (kept for the record)
**v1.0.7 (2026-10-27): fixes from the author's 1.0.6 test the same day** (docs/TESTING.md, 2026-10-27).
1. Ticking **Show Inspiration point controls** now redraws the Party tab by itself (and so do the Inspiration
   limit, Match the party limit and Maximum party size). Ticks not yet applied are kept. The checkbox
   description also says to press Refresh if the buttons do not appear.
2. **Match the party limit** now moves the Inspiration limit slider to the party limit and holds it there:
   dragging it moves it back half a second after the drag stops. (MCM cannot grey out a slider; its settings
   file only has VisibleIf, which hides it.) Unticking leaves the slider at the party limit; the description
   says to move it back to 4 for the game's own limit.
3. **- / + reporting:** in 1.0.6 every press said "The game kept N (asked for N+1)" and the count lagged one
   press behind, though the change worked (the log showed 3 -> 9). The game applies the change a moment
   later; 1.0.7 checks it half a second later, says "Inspiration set to N.", and redraws after that. A message
   window appears only if the game really keeps another number.
Tests: 229 server + 17 client checks pass (the client tests are new). Code reviewed adversarially (verdict
SHIP WITH NOTES; the fixes it asked for are in). The pak contains no occurrence of the author's name.
**Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (51,731 bytes)
SHA256 `0c90435fe38c3045f46e2fa1d9a25e6537e411d1963654272d5601209f1b0c72`

**Test card for v1.0.7** (record results in docs/TESTING.md). Make a hard save first.
1. Log: `[PartyPicker] server loaded (v1.0.7).`
2. Open MCM on the Party tab, then Settings. Tick **Show Inspiration point controls**, go back to the Party
   tab: "Inspiration: P of L" with - and + is there without pressing Refresh. Untick it: they go away.
3. Before step 2, tick or untick someone on the Party tab without pressing Apply: after the redraw the ticks
   are as you left them.
4. Tick **Match the party limit**: the Inspiration limit slider jumps to your Maximum party size. Drag the
   slider: it goes back to the party limit after you let go. Change the Maximum party size: the Inspiration
   slider follows.
5. Untick Match: the slider stays at the party limit and you can move it again.
6. Press + a few times: the status line says "Inspiration set to N." each time (no "The game kept"), and the
   count on the tab, after about a second, shows the new number. Log: `Inspiration points X -> N asked
   (Party tab)` then `Inspiration points now N`.
7. Still open from the 1.0.6 card: steps 5-9 (spend one, save/reload with 8, slider back to 4 while holding 8,
   the console, earning past 4).

# v1.0.6 (kept for the record)
**v1.0.6 (2026-10-27): change the party's Inspiration points on request** (plan Part F), on top of 1.0.5 (the
Inspiration limit settings; 1.0.5 was never installed). The author: "Yes good idea to add that to the party
picker mod as an added feature, to allow the user to change the number of existing inspiration points, up or
down." MCM, Settings, Inspiration: new checkbox **Show Inspiration point controls** (default off). With it on,
the Party tab has "Inspiration: P of L" with - and + buttons, and `!pp_inspiration_points [n]` sets a number.
Raising is capped at the Inspiration limit setting; lowering goes down to 0. While a save loads, the limit is
held at 30 so nothing is capped; the level start sets the real value. Tests: 215 passed. Plan and code each
reviewed adversarially (fixes applied); no-copying check passed; the pak contains no occurrence of the
author's name. **Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (49,362 bytes)
SHA256 `d98efd49e1ac04bf0351785100a98b615f7efc7536abb18bd19501840341aa42`

**Test card for v1.0.6** (record results in docs/TESTING.md). Make a hard save first.
1. Log: `[PartyPicker] server loaded (v1.0.6).` and, after loading a save, `Inspiration limit set to 4`.
2. MCM, Settings, Inspiration: the slider, Match the party limit, and Show Inspiration point controls, each
   with its description.
3. Set the Inspiration limit to 8 and tick Show Inspiration point controls. Party tab: "Inspiration: P of 8"
   with - and +.
4. **The key test:** press + until 8. Each press: the status line says "Inspiration is now N"; check the
   on-screen Inspiration counter and that no experience award appears. At 8, + is greyed out. If the game ever
   keeps a different number, the status line says "The game kept ...": note it.
5. Spend one Inspiration (reroll a failed check): the total drops by one (Refresh the tab to see it).
6. With 8 points, save, quit to the desktop, start the game, load: `!pp_inspiration_points` shows 8.
7. Set the slider back to 4 while holding 8: the log says the limit is kept at 8; the tab says the points are
   above your setting. Press - down to 4; + stays greyed out at 4.
8. Console (server): `!pp_inspiration_points 6` with the limit 8 sets 6; `!pp_inspiration_points 9` is
   refused. Untick Show Inspiration point controls: the buttons disappear and the console refuses to set.
9. Earning Inspiration the normal way (a background goal) with 5-7 points: it should be added, not turned
   into experience.

# v1.0.5 (kept for the record)


**v1.0.5 (2026-10-26): the Inspiration settings** (plan Part B), on top of 1.0.4. The author: "Please complete the
MCM for the inspiration settings and I will test it thoroughly in the next game." MCM, Settings, new section
Inspiration: slider **Inspiration limit** 4-30 (default 4) and checkbox **Match the party limit** (default off),
both with the experience-point warning. Party Picker never adds or removes Inspiration points; the limit is
never set below the points the party holds. Tests: 192 passed. Code reviewed adversarially (fixes applied);
no-copying check against Configurable Party Limit clean. **Not installed yet; not tested in game.**

**Pak:** `PartyPicker.pak` (46,421 bytes)
SHA256 `a90c6ddda33b572e85b7cf3ca53873dc3ddd9c4e216504037b8f27cbb178b491`

**Test card for v1.0.5** (record results in docs/TESTING.md). Make a hard save first.
1. Log: `[PartyPicker] server loaded (v1.0.5).` and, after loading a save, `Inspiration limit set to 4`.
2. MCM, Party Picker, Settings: an Inspiration section with the slider and the checkbox, each with the
   WARNING text.
3. Set Inspiration limit to 8. Log: `Inspiration limit set to 8`. SE console (server): `!pp_inspiration` shows
   the limit 8 and the party's points.
4. **The key test:** earn Inspiration until the party has more than 4 (background goals). `!pp_inspiration`:
   the party total goes above 4. Note whether the on-screen Inspiration counter shows more than 4, and whether
   an experience award appears instead (it should not, until the party has 8).
5. Spend one Inspiration (reroll a failed check): the total drops by one.
6. Save, quit to the main menu or the desktop, load the save: `!pp_inspiration` shows the same points (above 4).
7. Tick Match the party limit: the Inspiration limit follows your Maximum party size; send members to camp: it
   does not change.
8. With more than 4 points, set the slider back to 4: the log says `Inspiration limit kept at N: the party
   holds N points`; no points are lost. Spend down to 4 and set 4 again: `Inspiration limit set to 4`.

# v1.0.4 (kept for the record)


**v1.0.4 (2026-10-25): test build toward 1.1.0.** Everything in 1.0.3 (limit up to 30, the Inspiration probe,
Send everyone to camp) plus: the party limit is never below the party (plan Part D), a message window when
more are ticked than the limit (Part E), and a message after Send everyone to camp leaves you alone (the
game hides the portraits for a party of one). Tests: 177 passed. Plan and code reviewed adversarially; the
code review's blocker (re-applying the limit on each added member stopped the next joiner) is fixed and its
test fails without the fix. No-copying checks clean. **Installed on the author's PC 2026-10-25** (the author: "game is closed please install the new pak"; replaced 1.0.3 `469b6da7…`, hash checked after the copy). **Not yet tested in game.**

**Pak:** `PartyPicker.pak` (43,863 bytes)
SHA256 `082e7232418c3b9240e186d9770cdf2c374278014e50f1bbb02ee6898a2f1729`

**Test card for v1.0.4** (record results in docs/TESTING.md):
1. Log: `[PartyPicker] server loaded (v1.0.4).`
2. Limit below the party: with, say, 6 in the party, drag the slider to 4 and let go. After a moment the
   slider returns to 6 and a message window explains. Send two to camp, set 4: accepted.
3. Load a save whose party is bigger than your setting: one message ("This game's party has N members...
   your setting stays S"); the setting is not changed; the Party tab says "Limit: N (your setting S, raised
   to fit the party)".
4. Over the limit: tick more than the limit and press Apply: a message window, nothing changes.
5. Swap two out and two in while the setting is below the party: both join.
6. Send everyone to camp: after it is done, a message window says your character is still with you.
7. Inspiration probe, if not finished: !pp_inspiration 8, earn past 4, save/reload, reset (see the 1.0.3
   card below).

# v1.0.3 (kept for the record)


**v1.0.3 (2026-10-24): test build toward 1.1.0.** Party limit up to 30, the Inspiration probe command
(plan `docs/PLAN_inspiration_and_30.md`, step 0), and the **Send everyone to camp** button (Part C). No
Inspiration setting yet. 1.0.2 was built but never installed. Tests: 154 passed. Plan and each code
change reviewed adversarially; both no-copying checks against Configurable Party Limit passed.
**Installed on the author's PC 2026-10-25** (the author: "please install the new pak the game is off"; replaced 1.0.1 `b3a9893c…`, hash checked after the copy). **Not yet tested in game.**

**Pak:** `PartyPicker.pak` (38,104 bytes)
SHA256 `469b6da73ceee7a8052dafe71eccaa0757f7c504e052c4ba3f2e2a7cf4047af4`

**Test card for v1.0.3** (record results in docs/TESTING.md):
1. Log: `[PartyPicker] server loaded (v1.0.3).`
2. MCM, Party Picker, Settings: the Maximum party size slider goes up to 30.
3. If you can field 17 or more: set the limit to 17+, tick them, Apply; check the portraits, travel, a long
   rest (still four in bed).
4. Party tab: press Send everyone to camp. It asks "Send N party members to camp?"; press Yes. Everyone
   except your own character goes to camp. Tick them again and Apply to bring them back. Also try it in
   combat: it should be refused with the reason.
5. Inspiration probe, in a save where the party has some Inspiration. SE console: type server, then
   !pp_inspiration (shows the limit, the party total, and each member's points). Then
   !pp_inspiration 8 (sets a test limit of 8 and shows the same again). If convenient, earn one
   Inspiration with the limit at 8 and run !pp_inspiration again. Then save, reload, and run
   !pp_inspiration once more (shows whether the test limit survives a reload). Finally
   !pp_inspiration reset (back to the game's 4). Send the log.

# v1.0.1 (kept for the record)


**v1.0.1 (2026-10-22): the House of Hope's Debtor's Attire for the whole party.** the author: "Let's add the
fix to give the Debtor's attire then to the whole party." New `Server/HouseOfHope.lua`, one new MCM
setting (`hope_attire_everyone`), version 1.0.1. Tests: 136 passed. Plan and code each reviewed
adversarially (`docs/PLAN_hope_attire.md`). **Installed on the author's PC 2026-10-22** (the author: "install"; replaced 1.0.0 `89005f94…`, hash checked after the copy). **Tested in game 2026-10-23:** "the whole party got the debtors clothes" (log line 3355 names the six extra members; see docs/TESTING.md).

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
two `Version64` values in `meta.lsx` differ. v0.1.6 was installed on the author's PC on 2026-10-12 and
tested in game 2026-10-13 to 2026-10-15, long rest and raft included (see docs/TESTING.md).
**v1.0.0 installed on the author's PC 2026-10-16** (at the author's request; hash checked after the copy: `89005f94…b07a56e3c`). **Loaded in game 2026-10-17** (`Extender Runtime 2026-10-17 18-17-18.log`: `server loaded (v1.0.0)` at 1603, `client loaded (v1.0.0) (Party tab added to MCM)` at 1034, `party size limit set to 14` at 1879). The check was: the log line reads
`[PartyPicker] server loaded (v1.0.0).` and BG3 Mod Manager shows 1.0.0.

**Pak:** `PartyPicker.pak` (30,043 bytes)
SHA256 `89005f94feeab56fa4e79969bc2f258de1804a809b4359a587c82f4b07a56e3c`

**The tested v0.1.6 pak** (30,043 bytes) was SHA256
`8a73af064d42378231d0f39c13fe08b672ddb713df8b08dc14b3397d847b384d`.

**Built with:** `python3 tools/lspk.py create src PartyPicker.pak`, from the files as git stores
them (LF line endings). Rebuilding Scroll Repair's `src/` with the same tool gives a pak
byte-identical to the Divine-built `ScrollRepair.pak`, and rebuilding v0.1.5 this way on the author's PC
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
