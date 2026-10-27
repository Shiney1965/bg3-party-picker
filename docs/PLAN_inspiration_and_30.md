# Plan: Inspiration limit option, and party limit above 16 (rev 2)

Request (the author, 2026-10-24): "Can you make a plan to add to our mod an option to increase the inspiration
limit and an option for more than 16 companions? Party picker has 30." (He means Configurable Party Limit,
Nexus 11172, which allows 1 to 30.) "I don't know the max possible in the Base Game but there are several
'add to the party' mods available including my own add Raphael mod. So the total number possible with mods
could exceed 16."

Status: **plan only**, nothing built. Rev 2 takes in an adversarial review (verdict on rev 1: "revise
before coding"). Decisions for the author are marked **DECIDE**, each with a recommendation.

**Decisions (the author, 2026-10-24):** party limit maximum **30**; Inspiration settings: **the slider plus the
"Match the party limit" checkbox**; lowering the limit: **never take points away**; release: **wait for
1.1.0** (1.0.1 is not uploaded; the first public release will be 1.1.0).

**Build order:** test build 1.0.3 = Part A + the step-0 probe command (`!pp_inspiration`) + Part C (1.0.2 was built but never installed); after the author's
in-game run of the probe, the Inspiration settings; then 1.1.0.

**Source rule (the author, 2026-10-24):** "Please don't use the configurable party limit code in our rewrite of our
own mod." Party Picker's code for both parts is written from primary sources only: the game's own data,
story scripts and text, and the Script Extender source and documentation. Other party mods are mentioned only
as mods that touch the same game values (compatibility), never as a model: no code, structure, names,
option labels or logic taken from them. Overlap that comes from the game itself (the one engine call that
sets the party limit, the one data field that holds the Inspiration maximum) is not copying. The diff review
compares the new code with Configurable Party Limit's scripts to confirm nothing was copied.

---

## Part A: party limit above 16

### Facts

- Party Picker today: MCM slider `max_party_size` 4–16 (`MCM_blueprint.json`); raft landing rows 5–16
  (`Server/Restrictions.lua`, `RAFT_MAX_INDEX = 16`); `Party.MaxSize()` has a lower clamp of 4 but no upper
  clamp; docs, comments and CLAUDE.md say "4 to 16" / "5–16".
- The limit is set with `Osi.SetMaxPartySizeOverride(n)` + `PROC_CheckPartyFull` (`Party.lua`), in Party
  Picker since its first build (2026-10-10; `docs/RESEARCH.md` §3). Nothing else in the code assumes 16.
- How many the base game can field at once, from the game's story tables (an upper bound read from tables,
  not a tested maximum):
  - 10 origin companions in `DB_Origins` (Shadowheart, Astarion, Gale, Lae'zel, Wyll, Karlach, Halsin,
    Minthara, Jaheira, Minsc);
  - hirelings: 12 characters, but only **three hire slots** (`Hirelings.txt` L100–120: dialog vars, Hired
    and InCamp flags 1–3);
  - the player character, one per player.
  So about **14 in single player** and about 17 with four players; companion mods (Alfira, Raphael Joins the
  Party, Mizora…) add to that.
- The party can be larger than the limit: the story adds members itself in some cases
  (`_GLO_Shared_PartyMembers.txt` L134–155, `PROC_CheckPartyFull`).
- Raft: a crew member without a landing row stays hidden and frozen (`Act1_UND_EbonLake.txt` L596–605);
  on the lake the raft has only four standing positions (L27–30).
- The tutorial saves and restores the party limit (`TUT_Start.txt` L176–181, L196–200; `TUT_Helm.txt`
  L1995–1999).
- Not known: how the game's party UI and everything else behave above 16. Only an in-game test settles it.

### Change

1. `PP.MAX_PARTY_SIZE = 30` in `Common.lua`; slider max 30; `Party.MaxSize()` clamps to it.
2. Raft rows: extend to the larger of `PP.MAX_PARTY_SIZE` and the current party count when the rows are
   added, so a party above the limit still lands. Rows cycle through each dock's four positions as now.
3. Comments, MCM descriptions, docs and CLAUDE.md: "4 to 30" / "5–30". Above 16 is described as **not
   tested by the author**, not as a known problem.
4. Tests: raft checks expect 30 rows; rows go past 30 when the party is larger; the clamp; a party of 20
   joins under a limit of 30.

### In-game test

17 or more in the party (the author's main game: companions, up to three hirelings, mod companions): Apply, check
portraits and party panel, travel, a long rest (still four in bed). If a save allows: the raft, including
the lake stop (step 11b) with 17+ (about eight per standing spot at 30). One new-game start through the
tutorial at limit 30.

---

## Part B: Inspiration limit

### Facts (primary sources only)

- The game's Inspiration is the action resource `InspirationPoint`, UUID
  `a9c98304-08e7-44b5-aaf9-da2ef5a50672`, `MaxValue` 4, `PartyActionResource` true, `ReplenishType` Never
  (Shared.pak `Public/Shared/ActionResourceDefinitions/ActionResourceDefinitions.lsx`; no entry for it in
  SharedDev or GustavDev).
- **Inspiration above the limit becomes experience.** The game's own tutorial text (english.xml L31560,
  L32305): "your party can only store four at a time to spend - any additional Inspiration will be converted
  into Experience Points." So a higher limit means fewer experience awards, and that tutorial text will still
  say "four".
- Script Extender: `ActionResource` is an `Ext.StaticData` type (bg3se `LuaScripts/Tests/StaticDataTests.lua`
  L24) with a `double MaxValue` field (`GameDefinitions/GuidResources.h` L168–186); the same tests write a
  static-data field and read the new value back (L12–20). There is one resource bank for the process, used by
  both Lua states (`Lua/Libs/StaticData.inl` L164–167, L200). Each character also carries its own
  `ActionResourceEntry` with `Amount` and `MaxAmount` (`Components/ActionResources.h` L54–68).
- Osiris calls available (`story_header.div` L293–297): `PartyGetActionResourceValue`,
  `PartyIncreaseActionResourceValue`, `GiveInspirationPoints`.
- "The Lua state and all local variables are reset after each game reload" (API.md L598), while the
  resource bank is process-wide: a value Party Picker wrote stays in the bank after a reload.
- Configurable Party Limit also writes this value (compatibility only).
- Not known, so to be measured first (see the probe): whether characters' `MaxAmount` follows a new
  `MaxValue`, when; whether the game clamps or converts stored points on load or when the limit drops; whether
  remote clients in multiplayer need the value written separately.

### Step 0: probe (a console command, before any feature code)

`!pp_inspiration` (server): print the static `MaxValue`, the party's `PartyGetActionResourceValue`, and each
party member's InspirationPoint `Amount`/`MaxAmount`; `!pp_inspiration 8` writes `MaxValue` 8 and prints
the same again; `!pp_inspiration reset` writes 4. The author runs it once in game; the results decide steps 3–4
below. It ships only if useful as a diagnostic.

### Change

1. Settings (**DECIDE**; recommended): a slider **Inspiration limit** 4–30, default 4 (the game's own
   value), and a checkbox **Match the party limit**, off by default, which keeps it equal to the party-size
   limit. No mode that follows the current head-count: Party Picker's own long-rest trim sends everyone above
   four to camp every night, which would drop such a limit every night.
2. Server `Server/Inspiration.lua`: the game default is **4, taken from the game's definition**, not read
   back from the bank (after a reload the bank still holds Party Picker's own value). Write the chosen value on
   `StatsLoaded` and `SessionLoaded` (before saved values are loaded, so stored points above four are not
   clamped on load) and again on `LevelGameplayStarted` and on setting changes.
3. **Never take points away** (recommended; nothing in Party Picker removes points). Lowering the limit
   only limits future gains; what the game itself does with stored points above a lower limit is measured in
   the probe and written into the docs. If the probe shows characters' `MaxAmount` does not follow, add the
   smallest fix the probe points to, after a further review.
4. Client: in single player the host's client shares the server's bank, so nothing to do. For multiplayer,
   a non-host client writes the value the server sends it (net message on `SessionLoaded` and on change).
   Multiplayer stays **untested** in the docs unless someone tests it.
5. Compatibility, detected at runtime and logged (a pak scan cannot see Lua writers; 1.0.5 implements the
   Configurable Party Limit check; the GetSources check is deferred):
   `Ext.StaticData.GetSources("ActionResource")` (API.md L1842) for a mod that redefines InspirationPoint;
   `Ext.Mod.IsModLoaded("16b5fbb6-72fe-4a08-814a-87a9fc0b14bc")` for Configurable Party Limit (its meta.lsx
   UUID), which sets both values. Docs keep the author's wording: other party mods, use at your own risk.
6. **Warning in the MCM panel** (the author, 2026-10-24: "Please put a warning in the Experience Point slider panel
   that raising the limit will block experience point awards for experience points above 4"). Exact text:
   - Slider **Inspiration limit**, description: "How many Inspiration points the party can hold. The game's
     own limit is 4. WARNING: the game turns Inspiration you earn beyond the limit into experience points. Set
     above 4, the extra points are kept as Inspiration instead, so you get fewer experience points from
     background goals and other Inspiration awards. Experience from combat and quests is not affected."
   - Checkbox **Match the party limit**, description (as built in 1.0.5, clarified from the first draft):
     "Keep the Inspiration limit equal to the Maximum party size (your setting, not the number currently in
     the party), instead of the Inspiration limit slider. WARNING: this raises the Inspiration limit above 4,
     with the same loss of experience points described under Inspiration limit."
   - The slider's description also ends: "The limit never goes below the Inspiration your party already
     holds." (code review 2026-10-26: the limit is floored at the party's current points, so the game has no
     reason to take any away.)
   - The README and Nexus description carry the same warning, and note that the in-game tutorial still says
     four. The probe and the in-game test confirm the conversion threshold really moves with the limit
     before release (the game text describes it only for its own limit of four); if it does not, the warning
     is reworded to what the test shows.
7. Uninstall: the write is in memory only (nothing new goes into the save); after removing the mod the game's
   four returns at the next start. What happens to stored points above four is to be seen in game and written
   into the uninstall notes.
8. Tests: the written value per setting; the default is 4 after a simulated Lua reset with the bank still
   holding 8; the long-rest trim does not change the limit; no call removes points; a non-host client applies
   the server's value and the host's client does not; warnings for the two compatibility cases.

### In-game test

After the probe: "Match the party limit" with 8 in the party; earn Inspiration past four (background
goals); the counter shows more than four and points can be spent; save, reload, travel to another region,
check again; set the limit back to four and note what happens to the extra points.

---

## Part C: "Send everyone to camp" button

The author, 2026-10-24: "Yes 1.1.0 should also get a one-click 'send everyone to camp' button."

- Party tab: a **Send everyone to camp** button next to Refresh. It asks first ("Send N party members to
  camp?" with **Yes, send them to camp** / **Cancel**), then sends the same request as Apply with nobody else
  ticked. The server already keeps the locked members (you, the character you control, other players'
  characters, the dead) and makes every check Apply makes (combat, travel blocks), so nothing new runs on the
  server. Disabled when nobody can be moved, and for non-host players.
- Our own design (the idea of such a button is common; nothing taken from another mod's code).
- Test (server): an empty selection sends every unlocked member to camp and never the player character.
- In game: press it with several companions, confirm, check they are in camp; press it in combat and see
  the refusal.

## Part D: never a limit below the current party

The author, 2026-10-25: "When you change the limit to a number below the current party size, nothing happens. I
think it should prompt the user to reduce the number of people in the party. ... if you attempt to set the
limit below the current party number the mod should block that action and set it to the current party
number, and tell the user to reduce the party to be equal or less than the preferred limit."

### Facts

- Today `Party.ApplyMaxSize()` applies the slider value as it is, even below the number already in the party
  (`Party.lua` L281-292). Nobody is removed, but the game then treats the party as over its limit
  (`PROC_CheckPartyFull` sets the party-full flag). Known game rule that reacts to a full party: a multiplayer
  join force-dismisses a companion (`docs/RESEARCH.md`, `ForceDismissCompanion`). No other bug is known; the
  block is a safety rule.
- MCM: `MCM_Setting_Saved` fires on every slider drag step, not on release; `MCM.Set` returns false without
  raising when it fails; settings are per MCM profile, shared by all saves (memory note
  bg3-se-modding-hard-won-api-facts).

### Change (rev 2, after review: verdict "revise before coding", 1 blocker, 7 should-fix)

1. **Effective limit** = max(setting, the party), where "the party" is Party Picker's own count
   (`Party.ActiveCount()`, summons and followers excluded) or, while a long-rest trim is pending, the size of
   the party before the trim (so lowering the setting at night never strands the members waiting in camp).
   It is what the game gets (`SetMaxPartySizeOverride`), what Apply and Restore check against, and what the
   Party tab shows: "Limit: N (your setting S, raised to fit the party)" when it is above the setting.
2. **You move the slider below the party** (the author's case): the effective limit applies at once; 1.5 s after
   the last change (real time, so a paused game does not delay it; a generation counter so a drag is not
   fought) Party Picker writes the setting back to the party count with `MCM.Set` (MCM 1.41 source: returns
   true/false, persists, moves the open slider, emits no MCM_Setting_Saved by default so no loop; only `true`
   counts as success) and shows the message window: "The party limit can't be lower than the number in your
   party (N). It has been set to N. To lower it, send members to camp on the Party tab first, then lower the
   limit." If MCM.Set fails, the effective limit still holds and the message says the setting could not be
   changed.
3. **A save loads with a bigger party than the setting** (the setting is shared by all saves, so it is **not**
   written back): 3 s after the level loads, recount; if the party is bigger, show once per load: "This game's
   party has N members, more than your Maximum party size (S). Party Picker uses N in this game; your setting
   stays S." Same check after an MCM profile switch (`MCM_Profile_Activated`).
4. The story can add members itself: the existing `DB_Players` listener re-applies the effective limit
   silently (the "limit set to N" log line only when the value changes).
5. **Message window**: Party Picker's own window (`Client/MessageWindow.lua`), separate from the pick-four
   window, on its own net channel; shown only on the host. Shared with Part E.
6. MCM slider description adds: "It can't be set below the number already in your party."
7. Facts corrected: count = limit already sets the game's party-full flag (`_GLO_Shared_PartyMembers.txt`
   L127-141, `>=`), so Part D is a usability and safety rule, not a fix for the multiplayer force-dismiss
   (L229-233), which also happens at the limit.
8. Tests: mock `MCM.Set` with the 4-30 validator; captured MCM event subscribers; slider below the party
   applies the party count and writes back after the delay; several quick changes act once; a refused Set; the
   trim with a lowered setting; a load with a bigger party (message, no write-back); a profile switch; host
   only.

### In-game test

Party of 6, drag the slider to 4: the slider returns to 6 and the message appears. Send two to camp, set 4:
accepted. Load a save with a bigger party than the setting: the message appears once and the setting is
unchanged. With MCM opened from the pause menu; during a long-rest night; after a profile switch.

## Part E: message when more are ticked than the limit allows

The author, 2026-10-25: "When rebuilding a party from below the party limit, if I attempt to add members above the
party number limit then the apply button does nothing. That is working as intended but we should add a popup
message to the player that they cannot add more party members than the limit set by the mod."

- Today the Party tab greys out Apply when more are ticked than the limit (`Client/PartyTab.lua`, `onChange`:
  `n > limit`), so the click does nothing and nothing says why.
- Change: Apply stays clickable when too many are ticked (still disabled for non-host players and when nobody
  is ticked). Clicking it then opens Party Picker's message window: "You have ticked N, but the party limit is
  L. Untick N-L, or raise the Maximum party size in Settings." Nothing is sent to the server. The counter line
  reads "Selected N of L (over the limit)". The server's own refusal of an over-limit request stays as a
  second safeguard.
- One shared message window module (`Client/MessageWindow.lua`, an IMGUI window with the text and OK), used by
  Part D and Part E.
- In game: tick more than the limit, press Apply: the window appears and the party is unchanged.

## Part F: change the party's Inspiration points (on request)

The author, 2026-10-27: "Yes good idea to add that to the party picker mod as an added feature, to allow the
user to change the number of existing inspiration points, up or down." (Following a console line suggested
for testing.)

### Facts

- Osiris (`story_header.div` L293-294): `PartyIncreaseActionResourceValue(player, name, delta)` (call, REAL
  delta) and `PartyGetActionResourceValue(player, name)` (query). The game keeps Inspiration for the party
  (probe 2026-10-25), so one value. `GiveInspirationPoints` (L297) is the game's award path, which converts
  the excess to experience at the limit; not used here (the author asked to set a number, not to award).
- Not known: whether PartyIncreaseActionResourceValue clamps at the limit or converts the excess. Avoided
  by never asking for more than the limit.

### Change

1. Server `Inspiration.SetPoints(n)`: n rounded, 0 <= n <= the current limit (the InspirationPoint
   MaxValue); delta = n - current, applied with `PartyIncreaseActionResourceValue(host, "InspirationPoint",
   delta)`; reads the total back and reports it. Above the limit: refused with "The Inspiration limit is L;
   raise it in Settings first."; nothing changed. Host only (the existing host check on requests).
2. The decision "Party Picker never adds or removes Inspiration points" becomes: **never on its own**; this
   control is the one place it changes them, and only when the player asks.
3. Party tab: a line "Inspiration: P of L" with **-** and **+** buttons (one point each; disabled at 0 and
   at the limit, and for non-host players); the roster reply carries P and L. The result shows on the
   status line.
4. Console (server): `!pp_inspiration_points <n>` sets n; without a number it shows P and L.
5. Tests: set up and down; refused above the limit and below 0; only this path changes points (the mock
   records every point change; other paths must record none); non-host refused.

### Rev 2 (plan review: "revise before coding", 1 blocker)

- **Steps, not targets, from the tab** (blocker: the tab is not live, so "set 3" could remove points the
  game awarded since it was drawn). Buttons send +1 / -1; the server counts from a fresh
  `PartyGetActionResourceValue`. Only the console sends a number. Buttons disabled while a request runs; the
  tab refreshes after every reply.
- + is capped at `Inspiration.ChosenLimit()` (the setting), not the floored MaxValue; lowering is always
  allowed down to 0. After every change `Inspiration.Apply` runs again, so the limit follows the points down.
  When the points are above the setting, the tab says so.
- Read back the total at once and again a moment later; if the game kept a different number, say "The game
  kept P (asked for n)" and log it; never retry. Values are REAL (floats) in Osiris: round with
  floor(v + 0.5); console input must be a whole number (`math.tointeger`). Refused while a save is loading
  (no host character or no definition).
- Load path: while a save loads (Osiris not available), the limit is not lowered below the value the bank
  already holds; tested in game: hold 8, setting 4, save, reload.
- The game itself never calls PartyIncreaseActionResourceValue (0 calls in the story extract); it awards
  only through GiveInspirationPoints (_Greevers_Little_Helpers.txt L3550-3554). What the engine does with a
  direct change above 4 is untested: the first in-game step is "limit 8, hold 4, press + once".
- **Behind an MCM checkbox "Show Inspiration point controls", off by default** (review recommendation; a
  direct edit some players consider a cheat; the author runs Honour Mode games). The console command shows
  the points at any time; changing them needs the checkbox too.
- Design from `story_header.div` and the Script Extender source only; no other mod's code.

### In-game test

Limit 8: press + until 8, then + is disabled; - down to 0; `!pp_inspiration_points 5`; save and reload,
still 5. With limit 4 and `!pp_inspiration_points 6`: refused with the message.

## Release (**DECIDE**; recommended)

Upload **1.0.1 now** (built and tested in game). Ship these two features later as **1.1.0**: Part B depends
on an in-game probe that has not been run. Process as usual: this plan reviewed (done; rev 2), code, diff
review including the no-copying check, build from an LF export, install on the author's say-so, in-game tests,
docs and bundle.
