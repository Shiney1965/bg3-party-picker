# Plan: Inspiration limit option, and party limit above 16 (rev 2)

Request (Alan, 2026-10-24): "Can you make a plan to add to our mod an option to increase the inspiration
limit and an option for more than 16 companions? Party picker has 30." (He means Configurable Party Limit,
Nexus 11172, which allows 1 to 30.) "I don't know the max possible in the Base Game but there are several
'add to the party' mods available including my own add Raphael mod. So the total number possible with mods
could exceed 16."

Status: **plan only**, nothing built. Rev 2 takes in an adversarial review (verdict on rev 1: "revise
before coding"). Decisions for Alan are marked **DECIDE**, each with a recommendation.

**Source rule (Alan, 2026-10-24):** "Please don't use the configurable party limit code in our rewrite of our
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

17 or more in the party (Alan's main game: companions, up to three hirelings, mod companions): Apply, check
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
the same again; `!pp_inspiration reset` writes 4. Alan runs it once in game; the results decide steps 3–4
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
5. Compatibility, detected at runtime and logged (a pak scan cannot see Lua writers):
   `Ext.StaticData.GetSources("ActionResource")` (API.md L1842) for a mod that redefines InspirationPoint;
   `Ext.Mod.IsModLoaded("16b5fbb6-72fe-4a08-814a-87a9fc0b14bc")` for Configurable Party Limit (its meta.lsx
   UUID), which sets both values. Docs keep Alan's wording: other party mods, use at your own risk.
6. **Warning in the MCM panel** (Alan, 2026-10-24: "Please put a warning in the Experience Point slider panel
   that raising the limit will block experience point awards for experience points above 4"). Exact text:
   - Slider **Inspiration limit**, description: "How many Inspiration points the party can hold. The game's
     own limit is 4. WARNING: the game turns Inspiration you earn beyond the limit into experience points. Set
     above 4, the extra points are kept as Inspiration instead, so you get fewer experience points from
     background goals and other Inspiration awards. Experience from combat and quests is not affected."
   - Checkbox **Match the party limit**, description: "Keep the Inspiration limit equal to the party-size
     limit. WARNING: this raises the Inspiration limit above 4, with the same loss of experience points
     described under Inspiration limit."
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

## Release (**DECIDE**; recommended)

Upload **1.0.1 now** (built and tested in game). Ship these two features later as **1.1.0**: Part B depends
on an in-game probe that has not been run. Process as usual: this plan reviewed (done; rev 2), code, diff
review including the no-copying check, build from an LF export, install on Alan's say-so, in-game tests,
docs and bundle.
