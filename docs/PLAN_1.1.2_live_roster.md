# Plan: Party Picker 1.1.2 - the Party tab follows deaths, revivals and downed members

The author, 2026-10-31: "When a party member dies they are not automatically removed from the list.  You have to
hit refresh.  If possible when a party member dies the list should automatically reset to exclude that member."
Then: "Is that feasible without adding constant checks to the game", and after the log check (docs/TESTING.md,
Companion Permadeath): "yes, go ahead with 1.1.2".

## What is wrong now (verified in code)
The tab fetches the roster only when it is drawn (`PartyTab.Attach`), when our MCM page is activated
(`MCM_Mod_Tab_Activated` -> `PartyTab.Activated`), on a setting or profile change, on a Notice, and on Refresh
(Client/PartyTab.lua, BootstrapClient.lua). No listener follows a death, a revival or a member going down. In the
author's game this left Wyll on the tab after Companion Permadeath had removed him, and ticking him gave "request
refused: Unknown character c774d764-4a17-48dc-b470-32ace9ce447d." (SE log 2026-11-01 02-54-16).

## Constraint
No polling, no Tick handler, no timer that runs while nothing happens (the author's question above). Everything
below runs only when the game raises a one-off event or the player opens MCM.

## Units

### A. Server: watch the game's own events (new Server/RosterWatch.lua, required by BootstrapServer.lua)
- Osiris events (story_header.div): `Died((CHARACTER))` L312, `Resurrected((CHARACTER))` L313,
  `DownedChanged((CHARACTER), (INTEGER))` L391. Listeners: `Ext.Osiris.RegisterListener("Died", 1, "after", fn)`,
  `("Resurrected", 1, "after", fn)`, `("DownedChanged", 2, "after", fn)`, each wrapped in pcall.
- Who counts: the bare uuid is in `listed` (the uuids of the last roster sent to a client, set in `rosterReply`
  through `RosterWatch.Listed(entries)`), or the character is in `DB_Players` or `DB_PartOfTheTeam` (one `Get` each).
  `listed` is needed because an "after" listener runs after the story's rules for the same event: by then
  Companion Permadeath (ZZZ_Permadeath.txt L60-67) has already taken the character out of DB_Players and the team
  (Osiris log 2026-11-01 02-56-44 L1179085 onwards). Anyone else (enemies, NPCs) costs one table lookup and two
  `Get` calls, and nothing is sent.
- Coalescing: a sequence counter; each counted event bumps it and starts `Ext.Timer.WaitForRealtime(1500, ...)`;
  only the timer whose number is still current sends `PP.Net.RosterChanged:Broadcast({})`. 1500 ms because the
  story marks a member downed only after its own 500 ms check (`__AAA_FirstGoal.txt` L1187-1203, realtime timer
  `GLO_Downed_VerifyStillDowned`), and the travel block follows from that row (`_Waypoints.txt` L185-332): the
  redraw must come after both. A combat with several deaths sends one message.
- Realtime, not game time, so a paused game still redraws. A save loaded inside the 1.5 s drops the timer with the
  Lua state (nothing to clean up; nothing is saved).

### B. Shared: one more channel
- `PP.Net.RosterChanged = Ext.Net.CreateChannel(ModuleUUID, "RosterChanged")` in Shared/Common.lua (server ->
  clients, no data). Created in both contexts like the others.

### C. Client: redraw on the message
- `PP.Net.RosterChanged:SetHandler(function() pcall(PartyTab.SettingChanged) end)` in BootstrapClient.lua.
  `SettingChanged` already coalesces (500 ms), keeps ticks not yet applied, does nothing when no tab was drawn
  (`PartyTab.Refresh` returns when `#roots == 0`), and does not clear the status line.
- Locked members (the dead in the party) ignore kept ticks already (Client/RosterList.lua L47-50), and a dead camp
  member is drawn unticked (L56): no change needed there.
- Every client redraws its own (read-only in multiplayer for non-hosts) tab; a roster request is the same one
  Refresh makes.

### D. Client: refresh when the MCM window opens
- Subscribe to `Ext.ModEvents.BG3MCM["MCM_Window_Opened"]` (BG3-MCM EventChannels.lua L63-65; emitted by the client
  in IMGUIAPI.lua L167-169 when the window is shown) -> `pcall(PartyTab.SettingChanged)`. Covers anything that
  changed while the window was closed, whatever the cause (story recruitments, other mods). Not `Activated`: that
  clears the status line and the kept ticks.

### E. Server: a clearer refusal for someone no longer listed
- Party.lua Apply (non-addOnly branch, `not e`): `refuse(Party.DisplayName(u) .. " is no longer with the party or
  in camp. Press Refresh.")` instead of `"Unknown character " .. u .. "."`. `DisplayName` falls back to the id when
  the name cannot be read (Party.lua L262-276). The addOnly branch already says "no longer with the party".

### F. Version 1.1.2
- `PP.VERSION = "1.1.2"` (Shared/Common.lua); meta.lsx L35 and L38 Version64 = 36169538802286592
  (1<<55 | 1<<47 | 2<<31); L15 (MCM dependency) untouched.

## Tests (offline, tests/run_tests.py) - each must fail on 1.1.1 (90685f0)
Server (tests/test_server.lua, new section):
1. A listed party member dies (`Died` after): after the timers, exactly one `RosterChanged` broadcast.
2. The same member already removed from DB_Players and the team before the listener runs (Companion Permadeath):
   still one broadcast (listed).
3. Two members die in the same combat: one broadcast.
4. An enemy (not listed, in no party table) dies: no broadcast.
5. `Resurrected` and `DownedChanged(_, 1)` / `(_, 0)` for a listed member: one broadcast each.
6. `!pp_set`/Apply with a uuid no longer in the roster: the refusal names the character and says Press Refresh.
Client (tests/test_client.lua, new section):
7. A `RosterChanged` message with the tab drawn: one more roster request and a redraw; ticks not yet applied are
   kept.
8. `MCM_Window_Opened`: one more roster request; status line kept.
9. `RosterChanged` before any tab was drawn: no request, no error.
Mock: `RosterChanged` needs no new mock code (channels and listeners are generic); test 2 deletes the rows before
firing the listener.

## Not in scope
- Listing companions the game (or Companion Permadeath) has taken out of the team: they are no longer companions.
- `CharacterJoinedParty` / `CharacterLeftParty`: D covers the window being reopened; can be added if seen stale.

## Steps
Plan review (adversarial subagent) -> code -> tests, run against 1.1.1 too -> diff review (adversarial subagent)
-> version bump -> pak from an LF export -> RUN_CARD + docs/TEST_CARD_1.1.2.md -> commit + push. Not installed,
not released (those wait for the author).
