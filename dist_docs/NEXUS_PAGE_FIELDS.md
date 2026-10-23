# Party Picker 1.0.1 — Nexus page fields

What to type into each field of the Nexus "add mod" form, matched to how the live MIR page
(<https://www.nexusmods.com/baldursgate3/mods/24831>, read 2026-10-17) fills them in. Not part of
the download.

## Mod details

| Field | Value |
|---|---|
| Mod name | `Party Picker (By SerpentineShel)` (MIR's page uses the same "(By SerpentineShel)" form) |
| Version | `1.0.1` |
| Category | Gameplay (MIR's category; there may be a better fit such as a party or companions category, your choice) |
| Brief overview ("About this mod") | see below |
| Description | paste `NexusMods_BBCode_v1.0.1.txt` |
| Tags | AI-Generated Content (as on MIR) |
| Adult content | No |

**Brief overview** (242 characters):

> Pick your party from a Mod Configuration Menu tab: tick who you want and press Apply. Raises the party limit to 16, asks which four to keep at a long rest and brings the rest back on waking, and lands your whole party from the Grymforge raft.

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
| File | `PartyPicker-1.0.1.zip` |
| File name shown | `Party Picker` |
| Version | `1.0.1` |
| Category | Main files |
| Description | Party Picker 1.0.1: PartyPicker.pak plus README and INSTALL (Markdown, Word, PDF), CHANGELOG, licences and a manifest. Requires Script Extender and Mod Configuration Menu (load MCM above Party Picker). |

## Changelog entry (version 1.0.1)

> First public release. Pick your party from a Mod Configuration Menu tab, party limit 4 to 16, a
> pick-four window before a long rest with everyone brought back on waking, landing spots for the
> whole party on the Grymforge raft, and the House of Hope's Debtor's Attire for every party member. Tested in game: joining and dismissing companions and hirelings,
> a long rest with ten in the party, and the raft crossing with seven. Multiplayer not yet tested.

## Before publishing

1. Replace the two `TODO` lines in the BBCode: screenshot links near the top, and the page
   permalink at the end (or delete that line).
2. Paste the BBCode so the `[size]` tags arrive as written: if the editor offers a BBCode or source
   view, use it. Headings are `[size=5]` (24px), body text `[size=4]` (18px), the title
   `[size=6]` (32px).
3. Preview: every section heading should be visibly larger than the text under it. Log lines such as
   **[PartyPicker] server loaded (v1.0.1)** are bold rather than `[code]`, because Nexus turns
   `[code]` into a separate block that would split the sentence.
