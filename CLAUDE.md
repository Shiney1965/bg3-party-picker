# Party Picker — notes for Claude sessions

Read this first, then docs/DEVELOPMENT.md (the developer notes; README.md is now the user README,
generated from dist_docs/README.md by tools/make_docs.ps1), RUN_CARD.md, docs/RESEARCH.md and docs/TESTING.md. They hold the
design, the source for every game procedure used, and every in-game report so far (quoted exactly).
Last updated 2026-10-31 (1.1.0 release build) by a session on the author's PC; first written 2026-10-12, continuing the cloud session
https://claude.ai/code/session_01Mtwddt4A8ek5TsMuTXAzd5.

## What this is
Baldur's Gate 3 mod (Script Extender Lua + Mod Configuration Menu). Party tab in MCM lists party
members with checkboxes; Apply changes the party; raises the party limit (slider 4–30); holds End the
Day above four and asks which four to keep; adds Ebonlake raft landing spots 5–30; House of Hope attire for
everyone; Halsin locked until the story allows (optional early join in Act Two).

## Working rules (from the user, the author)
- Work on the `main` branch of Shiney1965/bg3-party-picker only. Commit and push each change.
- Bump the version for each new pak: `PP.VERSION` in `src/Mods/PartyPicker/ScriptExtender/Lua/Shared/Common.lua`
  AND `Version64` (two places) in `src/Mods/PartyPicker/meta.lsx`.
  Version64 = major<<55 | minor<<47 | revision<<31 | build — compute it with python, never by hand.
- Build: `pip install lz4 lupa`, then `python3 tests/run_tests.py` (must pass), then
  `python3 tools/lspk.py create src PartyPicker.pak`. Put size and SHA-256 in RUN_CARD.md.
  On the author's PC `python` is not on PATH: use
  `%LOCALAPPDATA%\Programs\Python\Python313\python.exe`.
  On Windows the checkout has CRLF line endings (git autocrlf), which changes the pak's bytes.
  Build from an LF export so the hash matches a build anywhere else: stage the changes, then
  `git -c core.autocrlf=false checkout-index -a -f --prefix=<empty scratch folder>/` and run
  lspk.py on that folder's `src`. Checked 2026-10-12: v0.1.5 rebuilt this way is byte-identical
  to the committed pak.
- After any change that took more than ~5 minutes, run an adversarial review by a subagent before moving on.
- Record every in-game report in docs/TESTING.md with the author's exact words in quotes. Never mark a test
  step passed unless the author confirms it. Do not guess; cite story-file lines for any game behaviour.
- Never put model names in commits or files.

## Where things are on the author's PC
- Mods folder: `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Mods\PartyPicker.pak`
- Script Extender logs (folder name really is misspelled):
  `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs\Extender Runtime *.log`
- Party Picker log lines start with `[PartyPicker]`. From v0.1.3 the load line shows the version,
  e.g. `[PartyPicker] server loaded (v0.1.5)`.
- Install from GitHub (public repo), then verify the hash against RUN_CARD.md:
  `Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Shiney1965/bg3-party-picker/main/PartyPicker.pak" -OutFile <Mods>\PartyPicker.pak`
- The author runs many other mods (see the log header), including AlfiraJoinsTheDurgesParty and Raphael
  Joins the Party (companions added by mods), MCM 1.41, Script Extender v32. A separate ClothMorph
  project has its own install steps; keep the two installs apart when testing.
- DaisyMorph (another of the author's mods) hires hireling characters by script as stand-ins ("dummy
  hirelings") and parks them. They are in `DB_Hirelings_Hired` without a visit to Withers.
- Osiris logging is on: `Osiris Runtime *.log` in the same folder records every story call of a
  session (tens of MB to several GB; filter it, never read it whole). It settled the 2026-10-12
  report when the Extender log could not.
- The game's own story source, extracted from the author's install (use it for line numbers):
  `C:\Claude Projects\BG3 Mods\RaphaelJoinsTheParty\_vanilla_story\Mods\Shared\Story\RawFiles\Goals\`
  and `...\Mods\SharedDev\Story\RawFiles\Goals\` (`Hirelings.txt`).

## Version history and state (2026-10-12)
- v0.1.1: worked except Withers and summons listed. v0.1.2: excluded Withers, summons, followers.
- v0.1.3: diagnostics — version in log; `!pp_roster` prints `[in: <story tables>; faction; id]`.
- v0.1.4: list only party members. Installed and hash-verified by the author 2026-10-12
  (SHA-256 5B068FDF…63CF303B). Rule: player characters; companions marked by the story
  (DB_OriginNPCAlignment / DB_GLO_PartyMembers_OriginalAlignment / DB_GLO_PartyMembers_DefaultFaction);
  hirelings (DB_Hirelings_Hired); anyone seen joining the party (saved mod variable "Seen").
- v0.1.5 (committed 24595c1, pak SHA-256 6bf969c9…cb28a9098, 27,867 bytes): hirelings listed only
  once hired at Withers (or while in the party). Reason: Hirelings.txt L280–285 gives every hireling
  template the companion marks with faction Hirelings_b7b47ac8-… before anyone hires them, so v0.1.4
  listed un-hired templates. Never installed; superseded by v0.1.6. Its premise was wrong for
  the author's case: the log shows the Bard was in DB_Hirelings_Hired before Party Picker touched her.
  The filter itself is kept (it only hides a hireling character that is in DB_PartOfTheTeam but
  neither hired nor in the party).
- v0.1.6 (2026-10-12): fixes the Brianna Brightsong report. Size and SHA-256 are in RUN_CARD.md.
  **Installed on the author's PC 2026-10-12 at the author's request (hash checked). Tested in game; long rest and raft confirmed by the author 2026-10-15 ("ready to ship"). Released as **v1.0.0** (2026-10-15, the author's request): the v0.1.6 code with only the version changed (PP.VERSION and both Version64); pak SHA-256 in RUN_CARD.md. Docs in `dist_docs/`, bundle built by `tools/make_docs.ps1` + `tools/assemble_bundle.ps1` into `release/` (git-ignored).**
- v1.0.1 to v1.0.7 (2026-10-22 to 10-27): test builds toward 1.1.0 (plan `docs/PLAN_inspiration_and_30.md`):
  House of Hope attire for everyone, party limit up to 30, Send everyone to camp, the limit guard and message
  windows, the Inspiration limit settings, and the Inspiration point controls. The author's in-game results
  are in docs/TESTING.md; each build's size, SHA-256 and test card are in RUN_CARD.md (latest at the top).
  1.1.0 waits for the author's tests; then update `dist_docs/` and release. Tests: `tests/run_tests.py` runs
  `test_server.lua` and (since 1.0.7) `test_client.lua`, each in its own Lua state.
- v1.0.8 (2026-10-27): Halsin (and Minthara/Minsc while the story blocks them) locked until recruitable;
  `!pp_halsin [repair|haven]` repairs a save where an earlier build added Halsin early. Plan
  `docs/PLAN_halsin_recruit_gate.md`; test card in RUN_CARD.md.
- v1.0.9 (2026-10-28): MCM "Let Halsin join early" (Act Two only, before his quest reaches Last Light) and a
  Party tab button "Put Halsin's quest back on track" (sends him to camp, then the !pp_halsin repair). Plan
  `docs/PLAN_halsin_early_option.md` ("As built"); test card in RUN_CARD.md.
- v1.1.0 (2026-10-31): the release build. The author: "let's fork the idea of adding inspiration control to the
  Party Picker, and create a version to ship with no Inspiration control." All Inspiration features removed
  (plan `docs/PLAN_ship_without_inspiration.md`); they are kept on branch `inspiration-feature` (= 1.0.9).
  Everything else is 1.0.9. Run log of the release: `docs/GOAL_LOG_1.1.0.md`. GitHub release `v1.1.0` posted
  2026-10-31 (tag at 00314ba, asset `PartyPicker-1.1.0.zip` sha256 91dff50a…4b0d3a57); name scan of the repo,
  its history, the zip (docx/pdf metadata included) and the extracted pak was clean. Nexus page still to do.
- 2026-10-27: the GitHub repository was deleted and recreated at the author's request, starting from the
  1.0.7 files as a single commit; the earlier history was not carried over (commit IDs named above refer
  to it).

## The 2026-10-12 report: cause (full evidence in docs/TESTING.md)
- v0.1.4 ran. The Bard hireling (`4d3c9cb3`) joined; later the Rogue hireling was sent to camp.
  No story call ever tried to remove the Bard.
- The Bard was hired already (DB_Hirelings_Hired, DB_PartOfTheTeam) but **off stage**. The add rule
  never puts anyone on stage, so she joined as an absent party member; the story then gave her the
  fast-travel block (`_Waypoints.txt` L188–194: DB_Players AND DB_CantMove), and Party.lua's own
  BLOCKING_DBS check refused every request that would send her to camp. Refusals were not logged,
  and PartyTab.lua redrew 1.5 s after every reply, wiping the message.
- v0.1.6: off-stage characters are locked, refusals are logged and stay on the tab, requests and
  results name who moved, `PROC_Hirelings_SendToCamp` only runs if the game really removed the
  hireling, `!pp_roster` shows offstage/cantmove/cantact/travelblock/campflag/hiredflag.

## Open issues
1. **RESOLVED 2026-10-13:** the author unticked the Bard in Calliope's game and she was sent to camp
   ("she was removed from the party"; logs confirm Remove, MakeNPC, SendToCamp, CharacterLeftParty).
   The 2026-10-12 report is closed. Left to watch: whether DaisyMorph puts her off stage on a later
   load, as it does with the Rogue. History of this issue follows.
   **Update 2026-10-13 evening:** the author loaded Calliope's game on v0.1.6 and ran `!pp_roster`. The
   off-stage lock is confirmed in game on the Rogue (Maddala Deadeye) and Fighter (Varanna
   Sunblossom): `offstage`, `cantmove`, `cantact`, `IsOnStage=0`. The Bard (Brinna Brightsong) came
   back on stage during that load and lost the travel block, and has `origalign`, so unticking her
   should now work; the author has not tried it yet. DaisyMorph dismisses its stand-in hireling at every
   load (forced Remove, then off stage): that is where off-stage hired hirelings come from, and it
   did this to the Rogue Party Picker had sent to camp. What follows is the state before that.
   **Calliope's game still has the Bard in the party, off stage.** It is an Honour Mode run
   (leader Calliope, Dark Urge tiefling warlock, with Shadowheart), so there is one save and no
   earlier one to go back to: `...\Savegames\Story\886719e0-5e70-1e04-ca24-c73bbab5a1e0__HonourMode`.
   A copy from 2026-10-12 10:13 is in
   `C:\Claude Projects\BG3 Mods\PartyPicker_SaveBackups\2026-10-12_Calliope_HonourMode\`.
   v0.1.6 refuses to send her to camp (and says why). Untested repair: server console
   `Osi.SetOnStage("4d3c9cb3-ca34-46ba-9c81-44081270bfde", 1)`, then untick her. The author's other games
   are identified by the leader name at the start of the save folder (Lae'zel-…, Shadowheart-…,
   Astarion-…); the leader of an Honour Mode folder is `LeaderName` in the save's `meta.lsf`. Not known: what `PROC_DismissToCamp` (`_GLO_Shared_Origins.txt` L460–507, a
   walk to camp) does with an off-stage character, so no code removes one. Also not known: whether
   she has `DB_GLO_PartyMembers_OriginalAlignment` (`origalign` in `!pp_roster`), which the removal
   needs (PM:1305).
2. "Error . Server shutting down." on load (2026-10-11): logs point to another mod's network message,
   not Party Picker; not reproduced since.
3. Confirmed in game 2026-10-15: long-rest hold, restore after rest, raft. Still untested: multiplayer,
   saving between trim and rest (step 10), the raft's lake encounter (step 11b).
4. Not done, by choice: a "hired at Withers only" filter. Hirelings hired by another mod's script
   are listed like any other. If the author wants them hidden: DB_Hirelings_Hired_Rehire is set after a
   real Withers hire (H:290–316) and never removed, but whether DaisyMorph's hires set it is not
   known.
5. Not done: telling apart two listed characters with the same name (not seen in game).
   **Decided by the author 2026-10-13:** off-stage characters stay listed but locked ("option 1, leave
   as is is best"). Do not add code that puts a character on stage, and do not hide them.
6. A companion from another mod with no `DB_GLO_PartyMembers_OriginalAlignment` row cannot be sent
   to camp by the game's removal (PM:1305); Party Picker reports "did not leave" (test 22). Whether
   any real mod companion lacks the row is not known (Alfira has a DefaultFaction row in the author's
   log, so she has been through that procedure).
7. `Osi.IsOnStage` as a second off-stage signal: confirmed working in game 2026-10-13
   (`IsOnStage=0` printed for two off-stage hirelings, no `IsOnStage?`).

## Raft test helper (2026-10-14)
A separate testing-only mod, not part of this repository: `C:\Claude Projects\BG3 Mods\PartyPicker_RaftTest\`
(pak `PartyPickerRaftTest.pak` v0.2.0, installed on the author's PC, must be activated in BG3MM).
Server console `!raft_dock` sends the party to the dock where the raft is (the story's own
`PROC_TeleportPartiesTo`, as in the game's debug shortcut, Act1_UND_EbonLake.txt L184–193);
`!raft_fix` releases anyone the raft left hidden and frozen. Reviewed adversarially; its README
has the pass/fail criterion. Note from that review: Restrictions.lua's header says members 5+
"are never teleported"; more exactly, boarding hides and freezes the whole crew (L490–497) and
landing only releases those with a position row (L589–609). Correct that comment in the next build.

## Adversarial review of v0.1.5 (2026-10-12): how each finding ended
(H = SharedDev Hirelings.txt, PM = Shared _GLO_Shared_PartyMembers.txt, P = Server/Party.lua)
1. "v0.1.5 still lists Brianna": true, but not through v0.1.4's own add. She was in
   DB_Hirelings_Hired before Party Picker touched her (Osiris log 464061–464065).
2. "Never created at Withers is probably false": the story had her as hired. The likely source is
   DaisyMorph's scripted hires, so the author may well never have hired her himself. Inference only.
3. "Dismiss fails because MakeNPC does not run": not what happened. No removal reached the story;
   Party Picker refused first (see the cause above). The discarded pcall results in sendToCamp are
   fixed, and SendToCamp no longer runs for a hireling the game left in the party. Whether she
   was the character the author was controlling is not in the logs; the travel block alone explains the
   refusal.
4. Stricter filter: see open issue 4.
5. Removing her from the save: see open issue 1. Talking to her is not possible while she is off
   stage.
Test gaps: closed in tests/mock_game.lua (add needs a DefaultFaction row and runs the hireling
hook; the three hireling factions; removal only under the game's conditions; off stage → cannot
move → travel block; column count checked on `:Get`). Still not modelled: the party-full flag is
recomputed inside the mock's CheckAdd (the game only reads it), DetachFromPartyGroup, items.

## Story sources
Third-party copy of Larian's story goals (Shared + SharedDev only; Act files missing):
https://github.com/Interzoneism/qdnd/tree/b4f963a57b3a0265beac871fbf23dbd09e13cf65/BG3_Data/Shared/Mods
Sparse clone: `git clone --depth 1 --filter=blob:none --sparse https://github.com/Interzoneism/qdnd.git`
then `git sparse-checkout set --no-cone '/BG3_Data/**/Story/RawFiles/Goals/*'`.
Script Extender API: https://github.com/Norbyte/bg3se/blob/main/Docs/API.md
