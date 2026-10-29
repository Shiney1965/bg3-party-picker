# Plan: an option to let Halsin join early, and a quest reset at Last Light (Party Picker 1.0.9)

## As built (supersedes the automatic reset below)

After the plan review (2026-10-28, PROCEED WITH CHANGES: the DB_HAV_AnyPartyMemberInHaven fact fires in bursts
while the party LEAVES Last Light, `Osiris Runtime 2026-10-29 00-29-24.log` L679175-679279; a send-to-camp while
the party is in camp adds no DB_InCamp row; the long-rest trim would silently drop him; an Act 1 join gets his camp
dialog while in the party) the author chose (AskUserQuestion, 2026-10-28):
- "Let Halsin join early": **Act 2 only** (SCL_Main_A, state Waiting/InAct2/AtCamp, Art asleep, not GoToLake).
- The reset: "Halsin should be reset with a specific command in MCM and automatically sent to camp if he is
  already part of the party when reset". So **no automatic reset**: a Party tab button "Put Halsin's quest back on
  track" (MCM, Party Picker, Party tab), shown only for an early-joined Halsin whose quest has not reached Last
  Light, enabled once `HAV_PartyProgress_EnteredHaven` is set, with a confirm step ("Make a hard save first"). It
  sends him to camp with Party.Apply if he is in the party, then runs the console repair's steps (shared code:
  `repairRefusal` + `doRepair` in Server/HalsinRepair.lua), logs a report before and after, and shows the outcome
  in a message window.
- A one-time message window on the FlagSet of `HAV_PartyProgress_EnteredHaven` if Halsin joined early.
- Any reset (button or console) records mod variable `Halsin = { reset = true }`; from then on the setting no
  longer unlocks him (he joins once the story sets the recruitable flag). A failed flag read stays locked.
- Applies to any early-joined Halsin (also one added by builds before 1.0.8), since the player presses the button.
Not taken: the "early" record, the DB_HAV_AnyPartyMemberInHaven / DB_InCamp listeners, the long-rest handling (no
automatic reset, so the trim never resets him).

## Original plan (as reviewed)

Requested by the author 2026-10-28, after `!pp_halsin repair` fixed the Lae'zel game (docs/TESTING.md): "We should
have as default that Halsin is not recruitable until after the Thaniel quest ends successfully, just like the base
game. But can we add an option to override that block (As with the prior build) and then have an MCM setting reset
Halsin like we just did when you enter the Last Light Inn so that the player can then send Halsin back to camp and
then trigger the quest as normal."

Story files: the author's extract, `C:\Claude Projects\BG3 Mods\RaphaelJoinsTheParty\_vanilla_story\Mods\GustavDev\
Story\RawFiles\Goals\` unless noted (Shared = `...\Mods\Shared\...`).

## What exists (1.0.8)

- `Server/Party.lua` `notRecruitableYet` (L341-352): a non-active Halsin is locked while
  `GLO_LiftingTheCurse_State_HalsinRecruitable` is not 1; non-active Minthara/Minsc are locked while in
  `DB_GLO_PartyMembers_BlockRecruitmentDialog`. Default stays exactly this.
- `Server/HalsinRepair.lua` `Repair()` (L135-175): refuses unless level SCL_Main_A, in the team, not busy, not in
  DB_Players, alive, not knocked out / defeated, Art asleep, not GoToLake, state Waiting/InAct2/AtCamp, flag set.
  Then (Waiting only) progresses to InAct2 and reads it back, sets dialog CAMP_Halsin2 + SetHasDialog, deletes
  DB_OnlyOnce("RecruitedFirstTime_Halsin"), clears the flag. Confirmed in game 2026-10-28: the camp conversation then
  offered "go ahead to Last Light", he went (state HalsinAtHaven), Art brought him in.
- Why the repair needs him out of the party first: sending him to camp runs `PROC_GLO_PartyMembers_MakeNPCHook`,
  which puts his in-party dialog back (`Osiris Runtime 2026-10-29 00-29-24.log` L658522-658555,
  `DB_Dialogs(Halsin, Halsin_InParty_...)` add). A repair done while he is in the party would be overwritten.

## Design decisions (defaults chosen; the author can change them)

1. The override is for **Halsin only**. Minthara and Minsc stay locked by the story's
   BlockRecruitmentDialog rows (not part of the request).
2. The automatic reset runs only for a Halsin that **this Party Picker added early with the override** (a saved
   record). A Halsin recruited early by another mod, or by Party Picker before 1.0.9, is not touched automatically;
   `!pp_halsin repair` stays for those.
3. Once reset, Halsin stays **locked even with the override ticked**, until the story makes him recruitable
   (Thaniel saved). Otherwise re-adding him would undo the reset.
4. The reset setting defaults to **on**; the override defaults to **off**.

## New MCM settings (new section "Story companions", tab Settings)

- `halsin_early`, checkbox, default false. Name: "Let Halsin join before the story allows it". Description (draft):
  "In the base game Halsin cannot join you in Act Two until Thaniel is saved, and the Party tab follows that. Tick
  this to let the Party tab add him earlier. WARNING: taking him along early stops the start of his Act Two quest
  (he never goes ahead to Last Light, so Art Cullagh's scene leaves him out) unless 'Put Halsin's quest back on track
  at Last Light' is ticked."
- `halsin_reset_at_last_light`, checkbox, default true. Name: "Put Halsin's quest back on track at Last Light".
  Description (draft): "Only for a Halsin the Party Tab added early. Once the party has reached Last Light, the next
  time Halsin is in camp his quest is put back where the story expects it (as the console command !pp_halsin repair
  does). Then talk to him in camp and let him go ahead to Last Light. After that he can't join the party until
  Thaniel is saved, as in the base game. If he is in the party when you reach Last Light, a message tells you to send
  him to camp."

## Saved record (mod variable "Halsin", server-only, saved with the game; registered in Shared/Common.lua like
"Pending" and "Seen")

`{ early = true }` set by Party.Apply when it is about to add Halsin while his recruitable flag is not 1 (only
possible with the override). `{ reset = true }` set by any successful reset (automatic or console) and kept;
`early` is cleared by the reset. A failed add leaves `early = true` but harmless: every reset also requires the flag
to be set.

## Lock (Party.lua notRecruitableYet)

Halsin, not active, flag ~= 1 (or unreadable):
- record.reset → locked (NOT_YET), whatever the override says.
- else override ticked → not locked.
- else → locked (as 1.0.8).
Flag == 1 → never locked by this (unchanged).

## Automatic reset (HalsinRepair.AutoCheck(reason))

Runs the same steps as `Repair()` (refactored into a shared core so console and automatic paths cannot drift) when
ALL hold:
- `halsin_reset_at_last_light` is on, and record.early is true;
- the party has reached Last Light: global flag `HAV_PartyProgress_EnteredHaven_0afbb64d-f996-4e41-ab6b-a51d37c29fd3`
  is set. It is set once, by the first party member entering trigger `S_HAV_Haven_SUB` (`Act2_CAMP.txt` L90;
  Shared `_Greevers_Little_Helpers.txt` L3022-3036, SetFlag with NULL);
- every `Repair()` condition (level, team, not busy, not in DB_Players, alive, not KO, Art asleep, not GoToLake,
  allowed state, flag set);
- he is in `DB_InCamp` (so the send-to-camp walk and its MakeNPCHook have finished; in the 2026-10-29 log
  DB_InCamp is added at L662695, after the dialog reset at L658547).

When to check (each wrapped in pcall, quiet unless something happens):
- `DB_HAV_AnyPartyMemberInHaven(1)` insert, the story's "a party member is in Last Light" fact, added on each
  re-entry (`Act2_Subregions.txt` L85-94). Listener `Ext.Osiris.RegisterListener("DB_HAV_AnyPartyMemberInHaven", 1,
  "after", ...)`, the same form 1.0.8 uses for DB_Players (BootstrapServer.lua L139).
- `DB_InCamp` insert for Halsin (he arrives in camp after being sent there).
- `LevelGameplayStarted` (a save loaded after the conditions came true).
- MCM `MCM_Setting_Saved` for `halsin_reset_at_last_light`.
- Each check runs after a short delay (1 s) so the story's own same-frame rules finish first.

After a successful reset: record `{ reset = true }`, log, and a message window (PP.Net.Message): "Halsin's quest is
back on track. Talk to him in camp and let him go ahead to Last Light. (When Minthara is also in camp, Halsin
stands at another spot: Act2_CAMP_HalsinMintharaCFM.txt L5-12.) He can't join the party again until Thaniel is
saved."

Halsin in the party at Last Light: on the DB_HAV_AnyPartyMemberInHaven insert, if every condition except "not in
the party" (and "in camp") holds, a message window: "Halsin is still in your party. To start his quest at Last Light,
send him to camp on the Party tab; Party Picker then puts his quest back on track." At most once per insert (the
fact is only re-added after the whole party has left Last Light).

## Not changed

- `!pp_halsin`, `repair`, `haven`: same behaviour; `repair` now also writes record.reset.
- Minthara/Minsc locks, every other setting.

## Tests (tests/test_server.lua, new section 32)

- Default: Halsin locked without the flag (1.0.8 behaviour).
- Override on: not locked; Apply adds him; record.early written; the mock's AddHook sets the flag.
- Auto reset: with record.early, flag set, EnteredHaven set, in camp, state InAct2 → reset effects as Repair, record
  becomes reset, message broadcast. Each missing condition → nothing happens (setting off, no record, no EnteredHaven,
  in party, not in camp, busy, KO, Art awake, wrong state).
- In party at Last Light → message, no change.
- After reset: override on, flag clear → still locked; flag set later → unlocked.
- Console repair writes record.reset.

## Risks / open questions for review

- The camp conversation's "go ahead to Last Light" option may need conditions (e.g. EnteredHaven) that are not in
  the story files (dialogs are not extracted). Confirmed only for the author's game, which had been to Last Light.
- Is `DB_HAV_AnyPartyMemberInHaven` insert visible to an SE listener when the story adds it from a rule (it is a
  story DB, so it should be, like DB_Players)?
- What happens to an override-added Halsin across the Act 1 → Act 2 transition while in the party
  (`Act2_GLO_LiftingTheCurse_SetUp.txt` L130-148 teleports him to camp and SetupCamp on the first SCL load)? Same as
  every pre-1.0.8 build; not changed here, but the reset must cope with state HalsinWaiting (it does: Repair
  progresses Waiting → InAct2).
- The reset clears the flag while he is in camp; a knockout before Thaniel is then permanent (GLO_Journal.txt
  L357-362), as in the base game. He is locked out of the party, so this needs a fight in camp.
