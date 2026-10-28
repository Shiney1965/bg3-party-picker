# Plan: Halsin's recruit gate (fix) and the repair of a save where Party Picker added him early

Reported in game 2026-10-27 (docs/TESTING.md, last entry). Story files cited are the author's extract at
`C:\Claude Projects\BG3 Mods\RaphaelJoinsTheParty\_vanilla_story\Mods\GustavDev\Story\RawFiles\Goals\`.

## What happened

- The story puts Halsin in camp (DB_PartOfTheTeam, DB_InCamp) before he can be recruited: after the goblin camp
  (`GLO_Companion_Halsin.txt` L49-61, `PROC_ORI_SetupCamp(Halsin, 1)`) and again on reaching the Shadow-Cursed
  Lands (`Act2_GLO_LiftingTheCurse_SetUp.txt` L128-145, `PROC_ORI_Halsin_RestoreToSCLCamp`). He also has
  DB_OriginNPCAlignment from the INIT section (`GLO_Companion_Halsin.txt` L5), so Party Picker lists him.
- The game gates his recruitment by dialog only. The flag `GLO_LiftingTheCurse_State_HalsinRecruitable_2c8b6be0-...`
  is set when Thaniel is saved (`Act2_TWN_LiftingTheCurse_Finale.txt` L163, L181), by act-skip debug, or by the
  first `PROC_GLO_PartyMembers_AddHook` for Halsin (`GLO_Companion_Halsin.txt` L41-47, QRY_OnlyOnce
  "RecruitedFirstTime_Halsin").
- `PROC_GLO_PartyMembers_CheckAdd` (Party Picker's add path) checks only GEN_MaxPlayerCountReached
  (`_GLO_Shared_PartyMembers.txt` L478-482). On 2026-10-11 Party Picker added Halsin in Act 2 (SE log
  `Extender Runtime 2026-10-11 03-01-41.log` L2788-2801; Osiris `Osiris Runtime 2026-10-11 03-10-45.log`
  L443056-443059, the first RecruitedFirstTime_Halsin). His Lifting the Curse state machine
  (`Act2_GLO_LiftingTheCurse_SetUp.txt` L5-18: HalsinWaiting 0, HalsinInAct2 100, HalsinAtCamp 200,
  HalsinAtHaven 300 ... ThanielRestored 1100, HalsinAtEpilogue 1200) never moved on: no State change for him in
  any log since. Art Cullagh's dialog adds Halsin only in HalsinAtHaven (`Act2_HAV_LiftingTheCurse_CursedFist.txt`
  L241-250).

## Part 1: the fix (Party Picker 1.0.8)

In `Server/Party.lua` `Party.Roster()`: a Halsin entry (uuid 7628bc0e-52b8-42a7-856a-13a6fd413323) that is NOT
active is locked, reason "joins later in the story", when `GetFlag(HalsinRecruitable, NULL) ~= 1`. Locked
non-active entries are already refused by Apply (L598-601), skipped by addOnly restores (L591) and drawn
disabled on the tab. If the flag read fails (pcall), treat as not recruitable (lock) — fail safe, and log once.
Active Halsin is never locked by this (sending him to camp stays allowed).

Not changed: anyone else. Only Halsin uses such a gate (grep of the story for `Recruitable` and "before he is
recruitable" finds only Halsin). Open question for review: other companions the story parks in camp before
recruitment (Minthara, Jaheira, Minsc, Alfira-type mod companions)?

Tests (tests/test_server.lua): Halsin in camp without the flag -> locked, Apply refused with the reason, restore
skips him; with the flag -> joins; active Halsin without the flag -> not locked, can be sent to camp.

## Review 2026-10-27 (plan, adversarial subagent): proceed with changes, all taken

- B1: the Finale sets HalsinRecruitable only as a fallback (Halsin in neither camp nor party,
  `Act2_TWN_LiftingTheCurse_Finale.txt` L153-181). So `repair` also deletes DB_OnlyOnce("RecruitedFirstTime_Halsin"):
  his first real join then runs the game's first-recruit block again, which sets the flag.
- S1: not recruitable + knocked out = permanently defeated (Gustav `GLO_Journal.txt` L357-362). `repair` refuses
  while he is knocked out or defeated; until he rejoins after Thaniel, a knockout is permanent for him, as in the
  unmodded game.
- S2: CAMP_Halsin and CAMP_Halsin2 are one dialog (same id), so his normal Act 2 camp dialog already carries the
  TravelToHaven reaction; the entity event step is dropped. `repair` sets that dialog directly. PROC_State_Progress
  moves only to equal or higher priority (Shared `_Global_StateProgression.txt`); from HalsinWaiting the repair
  first moves him to HalsinInAct2 (its own effects, SetUp L141-150).
- S3: Art's dialog brings Halsin in as an extra speaker (CursedFist L241-250), not into the party.
- Q2: also lock any non-active companion with a DB_GLO_PartyMembers_BlockRecruitmentDialog row (Minthara, Minsc).
- Saves where an earlier Party Picker already added Halsin keep the flag, so the lock alone does not protect them;
  `!pp_halsin repair` restores the gate.

## Part 2: repairing the author's save (console command, Party Picker 1.0.8)

As built (Server/HalsinRepair.lua), superseding the steps below where they differ: `repair` needs level SCL_Main_A,
Halsin in the team, not in the party, alive, not knocked out, Art asleep, not heading to the lake, the recruitable
flag set, and state HalsinWaiting / HalsinInAct2 / HalsinAtCamp. It then (Waiting only) progresses to HalsinInAct2,
replaces his dialog with CAMP_Halsin2, deletes the first-recruit record and clears the flag. `haven` needs the
repair done and TravelToHaven unset.

`!pp_halsin` (server console) reports: in DB_Players / DB_InCamp / DB_PartOfTheTeam, every DB_State_Current row
for (Halsin, "SCL_LiftingTheCurse"), flags HalsinRecruitable, GLO_LiftingTheCurse_State_HalsinIsInAct2,
HAV_LiftingTheCurse_State_HalsinLiftingCurse, HAV_LiftingTheCurse_State_HalsinAtHaven,
HAV_LiftingTheCurse_State_HalsinGoToLake, SCL_AncientFist_State_HasWokenUpFist, DB_Dialogs rows for Halsin,
DB_OnlyOnce "RecruitedFirstTime_Halsin". Read only.

`!pp_halsin repair` does, only if: Halsin is not in DB_Players (the author sends him to camp with the Party tab
first; the command refuses otherwise), his current state is HalsinWaiting or HalsinInAct2, and Art is not awake:
1. `PROC_GlobalClearFlagAndCache(HalsinRecruitable)` — so the game's own gate (GLO_Companion_Halsin.txt L77-84,
   GLO_Journal.txt L360-390) and the Part 1 lock work again until Thaniel is saved (the Finale sets it again).
2. `SetEntityEvent(Halsin, "SCL_EntryPoint_Halsin_HalsinLeavesEntry")` — the game's own rule
   (`Act2_CAMP_LiftingTheCurse.txt` L44-53) puts him in camp with dialog CAMP_Halsin and state HalsinAtCamp.
3. The author talks to Halsin in camp; the real CAMP_Halsin conversation sets TravelToHaven, and the game's
   reaction (L56-63) sends him to Last Light (state HalsinAtHaven, HalsinLiftingCurse, dialog HAV_HalsinQuest).
   Then talking to Art brings Halsin in (CursedFist L241-250).
Fallback `!pp_halsin haven` (only in state HalsinAtCamp, if the camp conversation offers no way to send him):
`PROC_GlobalSetFlagAndCache(TravelToHaven)` + `PROC_GlobalFlagReactionAfterDialog(TravelToHaven)` — the same
reaction the dialog would trigger.
Before any of it: the author makes a hard save. (Superseded by the review: step 2 became "set CAMP_Halsin2
directly", and DB_OnlyOnce("RecruitedFirstTime_Halsin") IS cleared, B1 above. The diff review of 2026-10-27,
SHIP WITH CHANGES, added: refuse while a party change is running, read the state back after the move, a
hard-save line in the report and usage, and a logged failed flag read.)

Risks to check: SetEntityEvent semantics (does a story EntityEvent fire from SetEntityEvent? the story's own
debug uses it, `Act2_GLO_LiftingTheCurse_SetUp.txt` L61); PROC_State_Progress moving only upward; whether a
recruited Halsin's in-party dialog gets re-assigned over CAMP_Halsin by party-member resets; long-rest camp
placement while he is "at Haven"; the Party Picker "Seen" record (he stays listed, locked).
