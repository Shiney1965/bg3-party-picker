<!-- Generated from dist_docs/README.md by tools/repo_readme.py. Edit that file, not this one. -->
# Party Picker

**Choose who is in your party from a menu. Open the Party tab in Mod Configuration Menu, tick the companions and hirelings you want with you, and press Apply. Raise the party limit to as many as 16. When the game can only handle four, at a long rest and on the Grymforge raft, Party Picker handles it for you: before a rest it asks which four to keep tonight and brings the others back when you wake, and on the raft it makes sure the whole party lands.**

Recruiting and dismissing companions normally means walking to each one and talking to them, one at a time. With a bigger party, the four-member parts of the game get in the way too: the camp has four beds, and the Underdark raft has four landing spots. Party Picker puts the whole roster on one screen and takes care of those two places.

**Why another party mod?** I wanted to swap companions in and out from one list, without hotbar spells, and to keep a large party through long rests and the raft crossing. **Your preferences may vary, so I am not saying this mod is better than others, only different.**

**No game files replaced, no executable patched.** Party Picker uses the game's own recruit and dismiss procedures, the same ones the companions' dialogue and the dismiss button use, so the game's bookkeeping stays correct. A single pak file is all that is needed.

```
  Open MCM, Party Picker, Party tab.
  Tick who you want with you (up to your limit).
  Press Apply.
  New members join and appear next to you; the others go to camp.
```

## Download

**[Releases](https://github.com/Shiney1965/bg3-party-picker/releases)**: `PartyPicker-<version>.zip` holds `PartyPicker.pak`, this README and the install guide (Markdown, Word and PDF), the changelog, the licence, the third-party notices and a manifest of SHA-256 hashes. Install steps: [INSTALL.md](dist_docs/INSTALL.md). Version history: [CHANGELOG.md](dist_docs/CHANGELOG.md).

## ➤ How to use — please read this

**PARTY PICKER REQUIRES MOD CONFIGURATION MENU (MCM). THE PARTY LIST AND EVERY SETTING ARE IN MCM. LOAD MCM ABOVE PARTY PICKER.**

Once installed (see [INSTALL.md](dist_docs/INSTALL.md)):

- **Set your party limit first.** Open MCM (the **INSERT** key, or from the ESC menu), find **Party Picker**, and on the **Settings** tab set **Maximum party size** (4 to 16, default 6). It counts your own character.
- **Pick your party on the Party tab.** Everyone you have recruited is listed with a checkbox. Tick who you want with you, untick who should go to camp, and press **Apply**. The line under the buttons says what happened, for example `Party updated. Joined: Karlach. Sent to camp: Gale.`
- **Greyed-out names are locked, and the reason is shown next to them.** Your own character, the companion you are currently controlling, dead party members, and in multiplayer every character another player controls cannot be sent to camp. A character who is off stage (not present in the world at the moment) cannot be recruited.
- **Long rest with more than four:** press End the Day as usual. Party Picker holds the rest and opens a small window: tick the four who stay with you tonight (your own character is always one of them) and press **Keep these 4**, then press End the Day again. The others wait in camp and rejoin a few seconds after you wake up. Or press **Keep everyone this time**, then End the Day again within two minutes: the game then rests as it does without the mod and puts only four to bed.
- **The Grymforge raft:** nothing to do. Board with your whole party; everyone lands.

## Features

- **One list for your whole roster.** Player characters, origin companions, hirelings, and companions added by other mods. Withers, summons, familiars, followers and camp followers (Volo, Elminster, Scratch, Tara and the like) are never listed.
- **Join and dismiss in one step.** Apply makes every change at once. New members are brought next to your character (switchable).
- **Larger parties.** The limit goes from 4 to 16 and is re-applied each time a save loads.
- **Long rests with a large party.** The camp has four beds and the game only puts four party members to bed. Party Picker asks which four to keep tonight; the others wait in camp and rejoin when you wake, as far as the limit allows. **Nobody is ever sent away to make room for them.** The record of who waited is saved with the game, so a save and load in between should not lose it (not yet tested in game).
- **The Grymforge raft (Ebonlake, Act 1 Underdark).** The raft takes everyone aboard but has only four landing spots per dock, so members five and up would be left on board, hidden and unable to move. Party Picker adds landing spots so the whole party arrives.
- **Every refusal says why.** A change that cannot be made (combat, someone who cannot travel right now, an off-stage character) is refused as a whole, the reason stays on the Party tab, and it is written to the Script Extender log.
- **Safe in combat.** By default no party changes are made while your character, or anyone joining or leaving, is in combat.

## Requirements

- Baldur's Gate 3, current Steam release (tested October 2026).
- **BG3 Script Extender**, version 29 or later. Required: Party Picker is entirely Script Extender Lua. Tested with Script Extender v33.
- **Mod Configuration Menu (BG3MCM)**, NexusMods mod 9162, version 1.38 or later. **Required**, and listed as a dependency in Party Picker's metadata. Tested with v1.41.0. Load it **above** Party Picker.
- A mod manager (BG3 Mod Manager recommended). Party Picker must be **active in your load order**.
- **Windows only** (Script Extender is Windows-only). MCM's window is driven with **mouse and keyboard**.

## The settings

All on the **Settings** tab of Party Picker's MCM page. Every change applies straight away.

### Party size

| Setting | Default | What it does |
|---|---|---|
| Maximum party size | 6 | How many characters can be in the active party, including your own (4 to 16). Applied when you load a save and whenever you change it. |
| Bring new members to you | On | A companion who joins from camp is moved next to your character. Off: they stay where they are until you fetch them or travel. |
| No party changes in combat | On | Refuse to change the party while your character, or anyone joining or leaving, is in combat. |

### Where the game needs four

| Setting | Default | What it does |
|---|---|---|
| Ask before a long rest | On | If your party is larger than four, End the Day is held and you are asked which four to keep tonight. The others wait in camp. |
| Bring everyone back after the rest | On | When you wake up, the members who waited in camp rejoin, as far as the party limit allows. Nobody is sent away to make room. Off: press **Restore** on the Party tab when you want them back. |
| Let the whole party ride the Grymforge raft | On | Adds landing spots so members five and up arrive with everyone else. |

## The Party tab

- **The list.** Everyone you have recruited, with a checkbox. The counter shows `Selected N of <limit>`. Characters who cannot be moved are greyed out with the reason.
- **Apply** carries out every change on the list at once. If a check fails first (combat, someone who cannot travel right now, an off-stage character), nothing is changed and the reason is shown. If the game itself refuses one step, the line reads `Party partly updated. ...` and names who did not move. Apply is greyed out while more people are ticked than the limit allows.
- **Refresh** reads the party again. The tab also refreshes itself each time you open Party Picker's MCM page.
- **Restore** appears only when some of your party are still waiting in camp after a long rest. It brings them back, as far as the limit allows, without sending anyone away.

## How it works (brief technical overview)

Party Picker calls the same story procedures the game's own dialogue and dismiss button call:

| Task | What Party Picker calls |
|---|---|
| Join | `PROC_GLO_PartyMembers_CheckAdd` (companions), `PROC_Hirelings_TakeFromCamp` (hirelings in camp), `PROC_Hirelings_AddToParty` (other hirelings) |
| Go to camp | `PROC_GLO_PartyMembers_Remove`; for hirelings also `PROC_Hirelings_SendToCamp` |
| Party limit | `SetMaxPartySizeOverride`, re-applied on each level load |

The two four-member situations are handled with Script Extender listeners and the game's own story tables:

- **Long rest:** Party Picker adds a story reason to the camp's existing "not ready for night" check. That is the mechanism the game itself uses to block resting at certain story moments. When the hold fires, the pick-four window opens. After `LongRestFinished`, the members who waited rejoin through the same join procedure, in add-only mode.
- **Raft:** Party Picker adds rows 5 to 16 to the raft's landing-position table for each dock. They reuse that dock's existing four positions.

What Party Picker keeps in your save: the record of who waited in camp during a rest, the record of who it has seen join your party (so that companions added by other mods stay listed), and the extra raft landing rows (used only when more than four ride the raft). Nothing else.

## Compatibility

**Compatible:** companion mods and hireling mods that recruit through the game's normal party procedures, appearance mods, and mods that change what is in camp.

**Do not combine with another party-limit mod** (Party Limit Begone and similar). Both set the party limit, and whichever applies it last wins. Pick one.

**Caveats:**

- **Mods that change the long rest or the camp beds** have not been tested with Party Picker's rest hold. If a rest misbehaves, turn **Ask before a long rest** off, trim your party to four on the Party tab before resting, and tick everyone again afterwards.
- **Some mods take a hireling off stage for their own use** (for example as a stand-in character). Party Picker then shows that hireling greyed out as "not available: off stage" instead of recruiting them.
- **Multiplayer:** only the host can change the party; other players see the Party tab read-only, and characters controlled by other players are never moved. Every player needs the same versions of Party Picker, Script Extender and MCM. Note that the game itself dismisses a companion when a player joins. **Not yet tested in a live multiplayer session; reports welcome.**

## Known limitations

- **Dialogue still seats the speaker plus three.** That is the game's cutscene system and is not changed.
- **Quest items carried by members five and up are sometimes not registered by the game**, according to Party Limit Begone's notes. Party Picker does not address that. Keep quest items on your first four.
- **On the raft's lake stop**, members five and up share the four standing spots on the raft. Not yet tested in game; if someone is left behind on the lake, reload or travel to them.
- **Someone already in your party who is off stage cannot be sent to camp** by Party Picker. The Party tab says so.
- **A companion the story is keeping in camp for a scene can still be ticked**, because the game's join procedure does not repeat the checks its recruitment dialogues make. Leave companions in camp during their own story moments.
- **A companion added by another mod that the game does not mark as a companion** is not listed until they have joined your party once the normal way. After that, Party Picker remembers them.
- **Turning the raft setting off does not remove landing spots already added.** They are only used when more than four people ride the raft.
- **After a rest you may see** `request refused: A party change is already in progress.` **in the log.** Party Picker listens for two end-of-rest signals; the second restore attempt is turned away while the first one runs. It is harmless.

## FAQ

**Can I install it in a game already in progress?** Yes. Your recruited companions are listed straight away.

**Does it work in Honour Mode?** Party Picker does not check the game mode. Honour Mode keeps a single save, so back up your save folder before trying any new mod there.

**Where are the hotbar spells?** There are none. Everything is on the Party tab.

**Why is a hireling greyed out with "off stage"?** They are not present in the world at the moment, so the game cannot bring them to you. This is usually another mod's doing. Party Picker does not move off-stage characters.

**Someone who is not a party member is listed. How do I remove them?** Run `!pp_roster` in the server console; it shows why each character is or is not listed. If their line shows `seen`, `!pp_forget Name` removes them from the "seen in your party" record. Someone the game itself marks as a companion stays listed.

**I turned off "Bring everyone back after the rest". How do I get them back?** Press **Restore** on the Party tab, or tick them and press Apply.

## Console reference

Script Extender console. Type `server` first for the server commands.

| Command | Context | What it does |
|---|---|---|
| `!pp_roster` | server | Lists everyone Party Picker considers, whether each is in the party or in camp, why anyone is locked, and why anyone is not listed. Ends with the active count and the limit. |
| `!pp_set Name1,Name2,...` | server | Sets the party to these characters, by name as `!pp_roster` spells them. Locked characters (you, the character you control, other players' characters) are always kept. |
| `!pp_restore` | server | Brings back the members who waited in camp during a rest (same as the Restore button). |
| `!pp_size` | server | Re-applies the party limit from MCM. |
| `!pp_forget Name` | server | Removes a character from the "seen in your party" record. |
| `!pp` | client | Opens the Party list in its own window, without MCM. Type `client` first if you switched to `server`. |

Every request from the Party tab is written to the Script Extender log as `request: join [...]; send to camp [...]`, or `request refused: ...` with the reason.

## Credits

- **Author:** Serpentine (NexusMods: SerpentineShel)
- **BG3 Script Extender:** Norbyte. Party Picker is built entirely on it.
- **Mod Configuration Menu:** AtilioA and contributors. The Party tab and every setting live in it.
- **Larian Studios**, for the party and camp scripts Party Picker works through.
- Thanks to the BG3 modding community for the public research on the game's story scripts, and to the authors of the party-size mods that mapped the four-member limits first.

## AI use disclosure

Party Picker was developed with substantial assistance from an AI coding assistant (Claude, by Anthropic) for code, research and documentation. It contains **no AI-generated art, images, audio, or other media**, only code and text. All design decisions, testing and the final release were done by the author.

## Source code

Party Picker is open source. Full source (Script Extender Lua, the MCM blueprint, the pak builder, tests and research notes) is in this repository. Building and changing the mod: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## License

MIT. The full text ships with the download as [LICENSE](LICENSE). Party Picker bundles no third-party files; see [LICENSE-THIRD-PARTY.md](dist_docs/LICENSE-THIRD-PARTY.md).

## Reporting issues

Comment on the Nexus page or open an issue on GitHub, with your BG3, Script Extender and MCM versions, every `[PartyPicker]` line from the Script Extender log (`%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\Scripe Extender Logs\`, the folder name really is misspelled), and the output of `!pp_roster`.
