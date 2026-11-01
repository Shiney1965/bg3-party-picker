# Party Picker

**[github.com/Shiney1965/bg3-party-picker](https://github.com/Shiney1965/bg3-party-picker)**

**Why this Mod: To choose the number and identity of your party members without spells, dialogues or using hotbar space.**

Choose who is in your party from a menu. Open the Party tab in Mod Configuration Menu, tick the companions and hirelings you want with you, and press Apply. Raise the party limit to as many as 30. When the game can only handle four, at a long rest and on the Grymforge raft, Party Picker handles it for you: before a rest it asks which four to keep tonight and brings the others back when you wake, and on the raft it makes sure the whole party lands.

Recruiting and dismissing companions normally means walking to each one and talking to them, one at a time. With a bigger party, the four-member parts of the game get in the way too: the camp has four beds, and the Underdark raft has four landing spots. Party Picker puts the whole roster on one screen and takes care of those two places.

**Why another party mod?** I wanted to swap companions in and out from one list, without hotbar spells, and to keep a large party through long rests and the raft crossing. **Your preferences may vary, so I am not saying this mod is better than others, only different.**

**No game files replaced, no executable patched.** Party Picker uses the game's own recruit and dismiss procedures, the same ones the companions' dialogue and the dismiss button use, so the game's bookkeeping stays correct. A single pak file is all that is needed.

## How to use — please read

**PARTY PICKER REQUIRES MOD CONFIGURATION MENU (MCM). THE PARTY LIST AND EVERY SETTING ARE IN MCM. LOAD MCM ABOVE PARTY PICKER.**
- **Set your party limit first.** Open MCM (INSERT, or from the ESC menu), find Party Picker, and on the **Settings** tab set *Maximum party size* (4 to 30, default 6). It counts your own character. It can't be set below the number already in your party: send members to camp first.
- **Pick your party on the Party tab.** Everyone you have recruited is listed with a checkbox. Tick who you want with you, untick who should go to camp, and press **Apply**. The line under the buttons says what happened, for example *Party updated. Joined: Karlach. Sent to camp: Gale.*
- **Some names are locked, and the reason is shown next to them.** Your own character, the companion you are currently controlling, and in multiplayer every character another player controls cannot be sent to camp; a character who is off stage (not present in the world at the moment) cannot be recruited. Halsin is locked until the story lets him join (after Thaniel is saved, as in the game), and so are Minthara and Minsc while the story keeps them from being recruited.
- **Dead and held party members stay ticked.** A dead companion or hireling in the party, and one the game is holding right now (downed, in a conversation, or in combat with *No party changes in combat* on), cannot be sent to camp; their box stays ticked and greyed, and clicking it says why. A camp companion the game is holding (in a camp conversation, knocked out) cannot be ticked the same way.
- **While your own character is dead, the party can't be changed.** The Party tab says so, and any change you try is refused with that reason, until your character is revived.
- **Send everyone to camp:** one button on the Party tab. It asks once, then sends everyone who can go. Your own character always stays.
- **Long rest with more than four:** press End the Day as usual. Party Picker holds the rest and opens a small window: tick the four who stay with you tonight (your own character is always one of them) and press **Keep these 4**, then press End the Day again. Dead party members and anyone the game is holding stay, and count towards the four. The others wait in camp and rejoin a few seconds after you wake up (with *Bring everyone back after the rest* on, also when you load a save made after the rest while they still wait). Or press **Keep everyone this time**, then End the Day again within two minutes: the game then rests as it does without the mod and puts only four to bed.
- **The Grymforge raft:** nothing to do. Board with your whole party; everyone lands.
- **The House of Hope:** nothing to do. When Hope hands out the Debtor's Attire, everyone in the party gets a set.

## Features

- **One list for your whole roster** — player characters, origin companions, hirelings, and companions added by other mods. Withers, summons, familiars, followers and camp followers (Volo, Elminster, Scratch, Tara and the like) are never listed.
- **Join and dismiss in one step.** Apply makes every change at once. New members are brought next to your character (switchable).
- **Larger parties.** The limit goes from 4 to 30 and is re-applied each time a save loads. It is never set below the party you already have: a save whose party is larger than your setting keeps everyone, and Party Picker tells you when the save loads. Parties above 16 have not been tested by the author.
- **Send everyone to camp in one click.** The Party tab asks once, then sends everyone except your own character (and anyone else who can't be moved). Tick them again and press Apply to bring them back.
- **Halsin joins when the story says so.** As in the game, Halsin can't join in Act Two until Thaniel is saved; the Party tab locks him until then. An optional setting, *Let Halsin join early*, lifts that lock in Act Two, with a Party tab button that puts his quest back on track before Last Light (see below).
- **Long rests with a large party.** The camp has four beds and the game only puts four party members to bed. Party Picker asks which four to keep tonight; the others wait in camp and rejoin when you wake, as far as the limit allows. **Nobody is ever sent away to make room for them.** The record of who waited is saved with the game, so a save and load in between should not lose it (not yet tested in game).
- **The Grymforge raft (Ebonlake, Act 1 Underdark).** The raft takes everyone aboard but has only four landing spots per dock, so members five and up would be left on board, hidden and unable to move. Party Picker adds landing spots so the whole party arrives.
- **The House of Hope's Debtor's Attire (Act 3).** The game has only four sets of the disguise Hope hands out, so members five and up would get none. When Hope hands them out, Party Picker gives a set to every other party member inside the House and puts it on. The game treats the extra sets exactly like its own, including destroying them when the alarm is raised.
- **Every refusal says why.** A change that cannot be made is refused as a whole, the reason stays on the Party tab, and it is written to the Script Extender log. Party Picker follows the game's own rules for travel and dismissal: combat (with the setting on), someone who can't move or can't talk right now (a conversation, knocked out, downed, wild shape and the like), an area where companions can't be dismissed, arrest, camp night, an off-stage character, and your own character being dead or downed.
- **The Party tab keeps itself up to date** when the game changes someone on it (a death, a revival, someone going down or getting up, a fight ending, recruiting or dismissing in the game's own conversations, switching the character you control), when a change finishes and when you open the MCM window. Ticks you have not applied yet are kept on these redraws (Refresh and opening the Party page start from the party as it is).
- **Safe in combat.** By default no party changes are made while your character, or anyone joining or leaving, is in combat.

---

## Requirements

- Baldur's Gate 3, current Steam release (tested October 2026).
- **BG3 Script Extender** (version 29+). Required — Party Picker is entirely Script Extender Lua. Tested with v33.
- **[Mod Configuration Menu (BG3MCM)](https://www.nexusmods.com/baldursgate3/mods/9162)**, version 1.38 or later — **required**, and listed as a dependency in Party Picker's metadata. Tested with v1.41.0. Load it **above** Party Picker.
- A mod manager (BG3 Mod Manager recommended) — Party Picker must be **active in your load order**.
- **Windows only** (Script Extender is Windows-only). MCM's window is driven with **mouse and keyboard**.

## Install / uninstall

- Drop **PartyPicker.pak** into **%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods**, activate it in BG3MM, put **Mod Configuration Menu above Party Picker**, save the load order, launch.
- **Verify:** the Script Extender log shows **[PartyPicker] server loaded (v1.1.4)** and, once a save is loaded, **[PartyPicker] party size limit set to 6** (or your own limit); type **server** then **!pp_roster** in the console and the first line reads **Party Picker v1.1.4 roster:**.
- **Mid-playthrough install is fine.** Your recruited companions are listed straight away.
- **Uninstall:** cut your party back to four on the Party tab and save first (what happens to a larger party once Party Picker is gone has not been tested), then deactivate and delete the pak. **If Halsin joined early**, keep Party Picker until you have pressed *Put Halsin's quest back on track* at Last Light: without the mod that button is gone, and his quest won't start by itself. Party Picker adds no spells or statuses; the only items it adds are the extra Debtor's Attire sets in the House of Hope.
- **Honour Mode keeps a single save.** Back up the save folder before trying any new mod there.

Full instructions, a settings reference and a console reference are in the README and INSTALL files in the download (Markdown, Word and PDF).

---

## Configuration — the Settings and Party tabs

- **Settings, Party size** — *Maximum party size* (4–30, default 6; never below the party you have); *Bring new members to you* (on: a companion who joins from camp is moved next to your character); *No party changes in combat* (on).
- **Settings, Where the game needs four** — *Ask before a long rest* (on); *Bring everyone back after the rest* (on, also when you load a save made after the rest while they still wait; on waking a message window names anyone who can't come back; off: press Restore when you want them back); *Let the whole party ride the Grymforge raft* (on); *Debtor's Attire for the whole party (House of Hope)* (on).
- **Settings, Story companions** — *Let Halsin join early* (off). Ticked, Halsin can join in Act Two before Thaniel is saved, but only before his quest at Last Light begins. **Once he has joined early, his quest at Last Light won't start by itself, even after you send him back to camp:** once your party has reached Last Light, and **before you talk to Art Cullagh**, press *Put Halsin's quest back on track* on the Party tab (a message window reminds you when you first arrive). It sends him to camp and resets his quest; then talk to him in camp and let him go ahead. After that he can't join again until Thaniel is saved. Ticked in a game where it can't apply, a message and a line on the Party tab say so; the setting stays ticked for your other saves.
- **Party** — the roster with checkboxes and a *Selected N of limit* counter; **Apply** (all changes at once; if a check fails first, nothing changes and the reason is shown), **Refresh**, **Send everyone to camp** (asks once first; the dead, anyone off stage and anyone the game is holding stay), **Restore**, which appears only while some of your party are still waiting in camp after a rest (it names anyone who could not come back), and **Put Halsin's quest back on track**, which appears only for a Halsin who joined early. Ticking more than the limit and pressing Apply changes nothing and a message window says how many to untick.

Every change applies straight away. Settings are kept **per MCM profile**, outside your save.

---

## Compatibility

**Compatible:** companion mods and hireling mods that recruit through the game's normal party procedures, appearance mods, and mods that change what is in camp.

**NOT compatible — do not run these alongside Party Picker:**
- **Party Limit Begone** and any other mod that sets the party limit. Both set the same limit, and whichever applies it last wins. Pick one. If Configurable Party Limit is active, Party Picker writes a warning to the Script Extender log when a save loads.
- Other Party Limit Mods: Could lead to odd results; use at your own risk.

**Caveats:**
- **Mods that change the long rest or the camp beds** have not been tested with Party Picker's rest hold. If a rest misbehaves, turn *Ask before a long rest* off, trim your party to four before resting, and tick everyone again afterwards.
- **Some mods take a hireling off stage for their own use** (for example as a stand-in character). Party Picker then shows that hireling greyed out as "not available: off stage" instead of recruiting them.
- **Multiplayer:** only the host can change the party; other players see the Party tab read-only, and characters controlled by other players are never moved. Every player needs the same versions of Party Picker, Script Extender and MCM. Note that the game itself dismisses a companion when a player joins. **Not yet tested in a live multiplayer session; reports welcome.**

---

## Known limitations

- **Nights the story starts itself skip the long-rest window.** Some story scenes send the party to bed through the game's "force end the day", which skips the ready check Party Picker uses to hold the rest (for example the Act One celebration after the goblin hunt, and some other story nights; Larian's own camp script notes that this path has no ready check). On those nights Party Picker cannot ask which four to keep. What happens then to members five and up has not been tested.
- **In a fight, party members in combat stay ticked** (with *No party changes in combat* on): the game holds them while they fight. An untick you make during the fight is not kept, and one made just before it can be dropped at the next redraw; untick again once the fight is over.
- **Dialogue still seats the speaker plus three.** That is the game's cutscene system and is not changed.
- **Debtor's Attire: only for those in the party at the moment Hope hands it out.** A member who joins the party later, or who is outside the House of Hope at that moment, gets none. The game itself hands its four sets to the first four party members wherever they are; Party Picker does not move those sets to someone else.
- **On the raft's lake stop**, members five and up share the four standing spots on the raft. Not yet tested in game; if someone is left behind on the lake, reload or travel to them.
- **Someone already in your party who is off stage cannot be sent to camp** by Party Picker. The Party tab says so.
- **A companion the story is keeping in camp for a scene can still be ticked** if the game does not mark them as unable to move (those it does mark show "can't join now"), because the game's join procedure does not repeat the checks its recruitment dialogues make. Leave companions in camp during their own story moments.
- **A companion added by another mod that the game does not mark as a companion** is not listed until they have joined your party once the normal way. After that, Party Picker remembers them.
- **After a rest you may see *request refused: A party change is already in progress.* in the log.** Party Picker listens for two end-of-rest signals; the second restore attempt is turned away while the first one runs. It is harmless.

---

## Console commands

Script Extender console, type **server** first: **!pp_roster** (everyone, in party or in camp, why anyone is locked or not listed) **!pp_set Name1,Name2** (set the party to these; locked characters are kept) **!pp_restore** (bring back who waited in camp during a rest) **!pp_size** (re-apply the limit) **!pp_forget Name** (drop someone from the "seen in your party" record) **!pp_halsin** (Halsin's quest state; **repair** and **haven** fix a Halsin who joined too early). In the client context (type **client**), **!pp** opens the Party list in its own window, without MCM. Full table in the README.

---

## Credits

- **Author:** Serpentine (NexusMods: SerpentineShel)
- **BG3 Script Extender:** Norbyte — Party Picker is built entirely on it
- **Mod Configuration Menu:** AtilioA and contributors — the Party tab and every setting live in it
- **Larian Studios** — for the party and camp scripts Party Picker works through
- Thanks to the BG3 modding community for the public research on the game's story scripts, and to the authors of the party-size mods that mapped the four-member limits first

## AI use disclosure

Party Picker was developed with substantial assistance from an AI coding assistant (Claude, by Anthropic) for code, research and documentation. It contains **no AI-generated art, images, audio, or other media** — only code and text. All design decisions, testing and the final release were done by the author.

## Source code

Party Picker is open source. Full source (Script Extender Lua, the MCM blueprint, the pak builder, tests and research notes) is on GitHub:
[github.com/Shiney1965/bg3-party-picker](https://github.com/Shiney1965/bg3-party-picker)

## License

MIT — the full text ships with the download as *LICENSE*. Party Picker bundles no third-party files; see LICENSE-THIRD-PARTY.md in the download. Reuse the code freely in your own mods; just keep the copyright notice with it.

## Reporting issues

Comment on this page or open an issue on GitHub, with your BG3, Script Extender and MCM versions, every line starting **[PartyPicker]** from the Script Extender log, and the output of **!pp_roster**.
