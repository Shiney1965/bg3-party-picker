# Plan: ship 1.1.0 without the Inspiration features

The author, 2026-10-31: "I think for now let's fork the idea of adding inspiration control to the Party Picker,
and create a version to ship with no Inspiration control." Scope chosen by the author: drop all of it (the limit
slider, "Match the party limit", the - / + point controls and both console commands).

Why: in the author's games the game's own counter and the d20 roll screen never showed the points the party held
(docs/TESTING.md, 2026-10-28 to 2026-10-31). Even the game's own `GiveInspirationPoints` landed on one character
(Raphael, from Raphael Joins the Party) and nowhere else. The cause is not settled and may be another mod;
the feature waits until it is.

## Kept
All the Inspiration work stays on branch `inspiration-feature` (pushed 2026-10-31, = main at 667c4b8, v1.0.9).
`docs/PLAN_inspiration_and_30.md` stays in docs as the record; its Part D (the party limit never below the party)
and Part E (message window) ship, as before.

## Removed from main (code)
1. `Server/Inspiration.lua`: deleted from the pak (the file goes; a deletion in git, done by `git rm`).
2. `BootstrapServer.lua`: the `Ext.Require` of it; `inspiration` in `rosterReply`; the `InspirationPoints`
   request handler; the SessionLoading / SessionLoaded / UserConnected subscriptions (they only call
   Inspiration); `Inspiration.Apply` / `SyncSlider` in LevelGameplayStarted, MCM_Setting_Saved and
   MCM_Profile_Activated (the party-limit calls in those stay); the `pp_inspiration` and
   `pp_inspiration_points` console commands; both names in the "server loaded" line.
3. `Server/LimitGuard.lua`: the two `Inspiration.*` calls after `MCM.Set` and its Require (L20).
   Kept (review 2026-10-31, should-fix 1): the Configurable Party Limit warning that ran from
   Inspiration.WarnOtherMods on SessionLoaded, now about the party limit only, in LimitGuard.
4. `Shared/Common.lua`: `PP.INSPIRATION_UUID`; the `Inspiration` and `InspirationPoints` channels.
5. `BootstrapClient.lua`: the three `inspiration_*` entries in `tabSettings`; the `PP.Net.Inspiration` handler.
6. `Client/PartyTab.lua`: the Inspiration block in `render`; the comment on `SettingChanged` (no longer about
   Inspiration buttons).
7. `MCM_blueprint.json`: the whole `inspiration` section (three settings).
8. Version 1.1.0: `PP.VERSION = "1.1.0"`, both Version64 values in meta.lsx (L35, L38; L15 is a dependency).

Nothing else changes: the party limit (4-30), the long-rest hold, the raft, the House of Hope attire, the Halsin
lock / early option / repair all stay as in 1.0.9.

## Save and uninstall safety
- Party Picker kept no Inspiration state in saves: no mod variable, no story DB. The limit was a runtime change
  to static data (`Ext.StaticData`), which is not saved. With 1.1.0 the definition keeps the game's own 4.
- A save made with 1.0.5-1.0.9 and points above 4: the game may cut them to 4 on load. Only the author ran those
  test builds (never released). Accepted.
- MCM deletes the three old values from settings.json on first load (BG3-MCM 1.41
  Shared/Helpers/Preprocessing/LoadedSettingsRepair.lua L105-122, RemoveDeprecatedKeys, with the log line
  "Removing deprecated setting: ..."; profiles too, ProfileManager.lua L109). Harmless; the RUN_CARD says so.
- Points the 1.0.6-1.0.9 test builds changed with PartyIncreaseActionResourceValue are in the author's own test
  saves and stay there; 1.1.0 cannot undo them. Only the author's saves are affected.
- Mixed versions in multiplayer: each player has their own pak; 1.0.9 was never released, so moot.

## Tests
- `tests/test_server.lua`: remove sections 25, 28, 29, 30 (Inspiration only). Keep section 27 (Part D). Add one
  guard section: no SessionLoading / UserConnected subscriber, no pp_inspiration* commands, no Inspiration
  channels or PP.INSPIRATION_UUID, no `inspiration` in the roster reply, `#M.pointChanges == 0` and MaxValue
  still 4.0 after a level start, every remaining setting saved and a profile event, no Ext.StaticData.Get call,
  no MCM read of an `inspiration_*` id, the load line as INSTALL.md shows it, and the party-limit-only warning.
- `tests/run_tests.py`: parse MCM_blueprint.json and check its setting ids are exactly the eight kept ones.
- `tests/mock_game.lua`: keep the static-data entry and the raising point functions as a guard.
- `tests/test_client.lua`: the redraw tests use `inspiration_*` settings as triggers; switch them to
  `max_party_size` / `halsin_early`; remove `reply.inspiration` and the "-"/"+" and "Inspiration: 2 of 4"
  checks; add a check that no "-"/"+" button or "Inspiration" text appears.

## Docs
- RUN_CARD.md: a 1.1.0 card (load line shows 1.1.0; MCM has no Inspiration section; party limit, Halsin and
  attire as before; the game's Inspiration counter behaves as without the mod).
- CLAUDE.md: history line. TESTING.md: the decision. dist_docs (README, CHANGELOG, release notes, BBCode) are
  updated in the release-docs step after the in-game check, and must not mention Inspiration.

## Plan review (2026-10-31)
Subagent verdict: proceed after should-fixes 1-5, no blockers. All five are taken in above.

## Order
Plan review -> code -> tests pass -> diff review -> LF-export build -> RUN_CARD -> commit + push -> install only
on the author's word, game closed, hash checked.
