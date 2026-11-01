# Party Picker 1.1.4 — Nexus page fields

What to type into each field of the Nexus "add mod" form, matched to how the live MIR page
(<https://www.nexusmods.com/baldursgate3/mods/24831>, read 2026-10-17) fills them in. Not part of
the download.

## Mod details

| Field | Value |
|---|---|
| Mod name | `Party Picker (By SerpentineShel)` (MIR's page uses the same "(By SerpentineShel)" form) |
| Version | `1.1.4` |
| Category | Gameplay (MIR's category; there may be a better fit such as a party or companions category, your choice) |
| Brief overview ("About this mod") | see below |
| Description | paste `NexusMods_BBCode.txt` |
| Tags | AI-Generated Content (as on MIR) |
| Adult content | No |

**Brief overview** (242 characters):

> Pick your party from a Mod Configuration Menu tab: tick who you want and press Apply. Raises the party limit to 30, asks which four to keep at a long rest and brings the rest back on waking, and lands your whole party from the Grymforge raft.

## Requirements tab

| Requirement | Link | Note |
|---|---|---|
| Mod Configuration Menu | <https://www.nexusmods.com/baldursgate3/mods/9162> | v1.38 or later; load above Party Picker |
| BG3 Script Extender | <https://github.com/Norbyte/bg3se> | off-site requirement, v29 or later |

## Permissions

MIR's page asks people to get permission before modifying its files. Party Picker's description
says the code is MIT-licensed and free to reuse with the copyright notice, which matches the
`LICENSE` file in the download. **Pick permissions that agree with the MIT licence**, for example:
modification allowed, asset use allowed with credit, upload to other sites with credit. If you would
rather keep MIR's stricter settings, change the License section of the BBCode instead so the two do
not contradict each other.

## Files tab

| Field | Value |
|---|---|
| File | `PartyPicker-1.1.4.zip` |
| File name shown | `Party Picker` |
| Version | `1.1.4` |
| Category | Main files |
| Description | Party Picker 1.1.4: PartyPicker.pak plus README and INSTALL (Markdown, Word, PDF), CHANGELOG, licences and a manifest. Requires Script Extender and Mod Configuration Menu (load MCM above Party Picker). |

## Changelog entry (version 1.1.4)

> Fixes from an outside review and a whole-mod review, and from the author's own tests. The Party
> tab now keeps itself up to date when the game changes someone on it (deaths, revivals, downed,
> the end of a fight, recruiting and dismissing in conversation, switching character); dead and
> held party members stay ticked and a click says why; camp companions the game is holding can't
> be ticked; while your own character is dead the party can't be changed (it says so); the
> long-rest window counts the dead and held towards the four; a restore that leaves someone out
> says who (in a message window on waking); a party waiting in camp after a rest is brought back after
> loading a save made after the rest (with "Bring everyone back after the rest" on); Party Picker
> follows more of the game's own travel and dismissal rules. Tested in game with test build 1.1.2:
> the Party tab redrawing by itself on a death and a revival, and (from the log) a request to send
> a downed member to camp refused with the reason. The other fixes are not yet tested in game.
> Multiplayer not yet tested.

## Before publishing

1. The page exists (mod 26092): this is an update. Upload the zip as a new main file, add the changelog
   entry above, and replace the description with `NexusMods_BBCode.txt`.
2. Paste the BBCode so the `[size]` tags arrive as written: if the editor offers a BBCode or source
   view, use it. Headings are `[size=5]` (24px), body text `[size=4]` (18px), the title
   `[size=6]` (32px).
3. Preview: every section heading should be visibly larger than the text under it. Log lines such as
   **[PartyPicker] server loaded (v1.1.4)** are bold rather than `[code]`, because Nexus turns
   `[code]` into a separate block that would split the sentence.
