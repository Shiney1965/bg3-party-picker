# Plan: Debtor's Attire for the whole party (House of Hope)

Request (Alan, 2026-10-22): "Let's add the fix to give the Debtor's attire then to the whole party."

## What the game does (GustavDev `Act3b_LOW_HouseOfHope2.txt`, Alan's own extract)

- L70: `DB_GlobalFlagReactionAfterDialog(LOW_HouseOfHope_Event_HopeGrantsDisguise_bb82e10f-…, LOW_HouseOfHope_HopeSpirit01_32a22a1a-…)`:
  when Hope's dialog that sets the flag ends, the story calls `PROC_GlobalFlagReactionAfterDialog(flag)`.
- L74–77: `DB_LOW_HouseOfHope_DebtorClothes(1..4, S_LOW_HouseOfHope_DebtorClothes01..04)`: four pre-placed items.
  L79 counter starts at 1.
- L973–990: for each `DB_Players` member, while `NOT DB_LOW_HouseOfHope_AlarmIsReady(1)`, take item number
  `counter`, `ToInventory(item, player, 1, 0, 1)`, `Equip(player, item, 0, 0, 0)`, counter + 1. Rows stop at 4,
  so party members five and up get nothing.
- L81–82: `DB_LOW_HouseOfHope_DebtorTemplates` = `UNI_Camp_Refugee_EternalDebtors_30c5721d-…`,
  `ARM_Vanity_Prison_EternalDebtors_6f7d15a8-…`.
- L992–999: `TemplateEquipped(template, player)` for a debtor template, alarm not ready →
  `PROC_SetArmourSet(player, Vanity)` + poof effect. So equipping any item of a debtor template triggers the
  game's own presentation; Party Picker does not need to set the armour set itself.
- L1024–1034 `PROC_LOW_HouseOfHope_SetAlarm`: every `DB_Players` member wearing a debtor-template item in
  `VanityBody` has it destroyed. L1036–1045: equipping one after the alarm destroys it. Cleanup is by template,
  so copies Party Picker creates are destroyed exactly like the originals.
- L2840–2849: `GetItemByTemplateInInventory(template, player, item)` → `Equip` (wear the clothes back). Works
  for copies too.
- Nothing else in the game's story references these items or templates (searched all of Alan's extract).

PixellBytes' Adjustable Party Limit fixes the same thing (`ZZZ_ConfigurablePartyLimit_v3_Tweaks&Fixes.txt`
L48–125): after Hope's dialog it gives `ARM_Vanity_Prison_EternalDebtors` with `TemplateAddTo(…, member, 1, 0)`
to every party member without one and equips it on `TemplateAddedTo`.

## Change (Server/Restrictions.lua, plus one MCM setting)

1. Listener: `Ext.Osiris.RegisterListener("PROC_GlobalFlagReactionAfterDialog", 1, "after", fn(flag))`; act only
   when `flag` is the HopeGrantsDisguise flag (compare the bare UUID `bb82e10f-9c0f-5c16-9f1d-e482d9074ca8`,
   since SE may pass the flag with or without its name prefix).
2. Setting `hope_attire_everyone` (checkbox, default on) in the "Where the game needs four" section. Off: do nothing.
3. After a short delay (`Ext.Timer.WaitFor(1000)`, so the game's own four hand-outs and equips have run), and
   only if `DB_LOW_HouseOfHope_AlarmIsReady(1)` is absent:
   - template to copy = `Osi.GetTemplate(item)` of `DB_LOW_HouseOfHope_DebtorClothes` row 1 (the one the game
     really hands out), falling back to `ARM_Vanity_Prison_EternalDebtors_6f7d15a8-9bcb-45de-94c5-8c77424aaf42`;
   - for each `DB_Players` member (all party members) who holds no item of either debtor template
     (`Osi.GetItemByTemplateInInventory` for each template in `DB_LOW_HouseOfHope_DebtorTemplates`):
     `Osi.TemplateAddTo(template, member, 1, 0)`, then (next timer tick) find the new item with
     `GetItemByTemplateInInventory(template, member)` and `Osi.Equip(member, item, 0, 0, 0)`, the same call the
     game uses at L990.
   - log `House of Hope: gave the Debtor's Attire to N more party member(s): names`; log and skip anyone the
     calls fail for (every call in pcall).
4. Nothing on uninstall: the items are ordinary items the game already knows how to destroy.

## Not handled (documented)

- A member who joins the party after Hope hands out the attire gets none (same as the game for anyone not in the
  party at that moment). Possible later: give it on join while the flag is set, the alarm is not ready and the
  joiner is in the House of Hope — needs a reliable "in the House of Hope" test, not attempted now.
- Multiplayer: `DB_Players` covers every player's characters, so the same code covers them; untested.

## Tests (tests/mock_game.lua + tests/test_server.lua)

Mock: `DB_LOW_HouseOfHope_DebtorClothes`, `DB_LOW_HouseOfHope_DebtorTemplates`, `DB_LOW_HouseOfHope_AlarmIsReady`,
`GetTemplate`, `TemplateAddTo`, `GetItemByTemplateInInventory`, `Equip`. Cases: six in the party, four already
given → two new items, each equipped; alarm ready → nothing; setting off → nothing; another flag → nothing;
everyone already has one → nothing and no log of a hand-out; template lookup fails → fallback template.

## Version, docs, test in game

- New pak, so a new version: **1.0.1** (1.0.0 was never published; Alan may prefer to publish as 1.0.1 or 1.1.0).
- Docs: the House of Hope limitation becomes a feature line and a setting row; CHANGELOG entry; TESTING.md step.
- In-game test (Alan): a save before Hope's first conversation in the House of Hope with 5+ in the party. Expected:
  everyone wears the Debtor's Attire after the conversation, and the log line above lists members 5+.
