# Party Picker — notes for Claude sessions

Read this first, then README.md, RUN_CARD.md, docs/RESEARCH.md and docs/TESTING.md. They hold the
design, the source for every game procedure used, and every in-game report so far (quoted exactly).
Last updated 2026-10-12 by the cloud session https://claude.ai/code/session_01Mtwddt4A8ek5TsMuTXAzd5.

## What this is
Baldur's Gate 3 mod (Script Extender Lua + Mod Configuration Menu). Party tab in MCM lists party
members with checkboxes; Apply changes the party; raises the party limit (slider 4–16); holds End the
Day above four and asks which four to keep; adds Ebonlake raft landing spots 5–16.

## Working rules (from the user, Alan)
- Work on the `main` branch of Shiney1965/bg3-party-picker only. Commit and push each change.
- Bump the version for each new pak: `PP.VERSION` in `src/Mods/PartyPicker/ScriptExtender/Lua/Shared/Common.lua`
  AND `Version64` (two places) in `src/Mods/PartyPicker/meta.lsx`.
  Version64 = major<<55 | minor<<47 | revision<<31 | build — compute it with python, never by hand.
- Build: `pip install lz4 lupa`, then `python3 tests/run_tests.py` (must pass), then
  `python3 tools/lspk.py create src PartyPicker.pak`. Put size and SHA-256 in RUN_CARD.md.
- After any change that took more than ~5 minutes, run an adversarial review by a subagent before moving on.
- Record every in-game report in docs/TESTING.md with Alan's exact words in quotes. Never mark a test
  step passed unless he confirms it. Do not guess; cite story-file lines for any game behaviour.
- Never put model names in commits or files.

## Where things are on Alan's PC
- Mods folder: `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak`
- Script Extender logs (folder name really is misspelled):
  `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs\Extender Runtime *.log`
- Party Picker log lines start with `[PartyPicker]`. From v0.1.3 the load line shows the version,
  e.g. `[PartyPicker] server loaded (v0.1.5)`.
- Install from GitHub (public repo), then verify the hash against RUN_CARD.md:
  `Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Shiney1965/bg3-party-picker/main/PartyPicker.pak" -OutFile <Mods>\PartyPicker.pak`
- Alan runs many other mods (see the log header), including AlfiraJoinsTheDurgesParty and Raphael
  Joins the Party (companions added by mods), MCM 1.41, Script Extender v32. A separate ClothMorph
  project has its own install steps; keep the two installs apart when testing.

## Version history and state (2026-10-12)
- v0.1.1: worked except Withers and summons listed. v0.1.2: excluded Withers, summons, followers.
- v0.1.3: diagnostics — version in log; `!pp_roster` prints `[in: <story tables>; faction; id]`.
- v0.1.4: list only party members. Installed and hash-verified by Alan 2026-10-12
  (SHA-256 5B068FDF…63CF303B). Rule: player characters; companions marked by the story
  (DB_OriginNPCAlignment / DB_GLO_PartyMembers_OriginalAlignment / DB_GLO_PartyMembers_DefaultFaction);
  hirelings (DB_Hirelings_Hired); anyone seen joining the party (saved mod variable "Seen").
- v0.1.5 (committed 24595c1, pak SHA-256 6bf969c9…cb28a9098, 27,867 bytes): hirelings listed only
  once hired at Withers (or while in the party). Reason: Hirelings.txt L280–285 gives every hireling
  template the companion marks with faction Hirelings_b7b47ac8-… before anyone hires them, so v0.1.4
  listed un-hired templates. **Not installed. Do not give it to Alan yet** — the adversarial review
  (below) found it does not fix his save and its premise is probably wrong.

## Open issues
1. **Brianna Brightsong (2026-10-12):** listed under v0.1.4 though never created at Withers; Alan
   recruited her with the Party tab and then could not dismiss her. Which version ran is not confirmed.
   Need the newest Extender Runtime log (look for `server loaded (v0.1.4)` and `did not leave` /
   `Party partly updated`) and `!pp_roster` output. Suspicion only: Party Picker's add went through
   PROC_GLO_PartyMembers_CheckAdd, whose hireling AddHook (Hirelings.txt ~L503–513) marks a raw
   template as hired without Withers creating her, and the dismiss path may not handle that. Check
   whether, with v0.1.5, such a template (now in DB_Hirelings_Hired) would be listed again, and find
   the safest way to remove her from the save (reloading an earlier save is the safe fallback).
2. "Error . Server shutting down." on load (2026-10-11): logs point to another mod's network message,
   not Party Picker; not reproduced since.
3. Not yet tested in game: long-rest hold (TESTING.md step 7, highest risk), restore after rest,
   raft, multiplayer.

## Adversarial review of v0.1.5 (2026-10-12) — findings to act on
(H = SharedDev Hirelings.txt, PM = Shared _GLO_Shared_PartyMembers.txt, P = Server/Party.lua)
1. High, confirmed: v0.1.5 still lists Brianna. v0.1.4's add went through CheckAdd → Add → AddHook,
   which puts any hireling template into DB_Hirelings_Hired and sets Hireling_State_Hired (H:502-513);
   v0.1.5 lets DB_Hirelings_Hired through. Test 20 covers a state the story cannot produce.
2. High, by story logic: "never created at Withers" is probably false. In the unmodded story an un-hired
   template cannot be in DB_PartOfTheTeam / DB_Hirelings_Hired / DB_Players, and plain CheckAdd needs
   a DB_GLO_PartyMembers_DefaultFaction row (PM:512). So she was most likely already hired (or another
   mod/debug tool put her there). Settle it with her `!pp_roster` line and the log.
3. Medium, guesses: dismiss fails if MakeNPC does not run — it needs DB_GLO_PartyMembers_OriginalAlignment
   and DB_PartyMembers (PM:1298-1307). A Withers dismiss deletes her OriginalAlignment row (H:639) and only
   a fresh hire re-adds it (H:746), so a hireling back in the party by another route cannot be removed;
   Remove then only detaches her (PM:692) and P reports "did not leave". Also: P's sendToCamp discards
   the pcall results for hirelings (no log on failure) — fix that. Also check she was not locked
   (controlled character).
4. If a stricter "hired at Withers" test is still wanted: DB_Hirelings_Hired_Rehire is set after a real
   Withers hire (H:290-316) and never removed; the Hireling_State_Hired flag and Hirelings_Hired_Count do
   not work (H:512, H:673, H:105). Caveat: debug hire path (H:868-877) does not set it.
5. Safest removal in Alan's save (hard save first): talk to Brianna and choose dismiss (game's
   PROC_Hirelings_Dismiss, H:888-896), or Withers' dismiss menu with her in the active party (H:1016).
   Console fallback `Osi.PROC_Hirelings_Dismiss("<uuid>")` (server) may leave Hirelings_Hired_Count one
   too low (H:626, H:1273-1276).
Test gaps: mock CheckAdd ignores the DefaultFaction requirement and AddHook; mock Remove ignores
MakeNPC's requirements; mock Get ignores arity.

## Story sources
Third-party copy of Larian's story goals (Shared + SharedDev only; Act files missing):
https://github.com/Interzoneism/qdnd/tree/b4f963a57b3a0265beac871fbf23dbd09e13cf65/BG3_Data/Shared/Mods
Sparse clone: `git clone --depth 1 --filter=blob:none --sparse https://github.com/Interzoneism/qdnd.git`
then `git sparse-checkout set --no-cone '/BG3_Data/**/Story/RawFiles/Goals/*'`.
Script Extender API: https://github.com/Norbyte/bg3se/blob/main/Docs/API.md
