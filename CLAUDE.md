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
  listed un-hired templates. **Not yet installed. An adversarial review was running when the cloud
  session handed over; re-run one before Alan installs.**

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

## Story sources
Third-party copy of Larian's story goals (Shared + SharedDev only; Act files missing):
https://github.com/Interzoneism/qdnd/tree/b4f963a57b3a0265beac871fbf23dbd09e13cf65/BG3_Data/Shared/Mods
Sparse clone: `git clone --depth 1 --filter=blob:none --sparse https://github.com/Interzoneism/qdnd.git`
then `git sparse-checkout set --no-cone '/BG3_Data/**/Story/RawFiles/Goals/*'`.
Script Extender API: https://github.com/Norbyte/bg3se/blob/main/Docs/API.md
