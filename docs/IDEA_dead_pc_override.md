# Idea for a later build: let the player change the party while their own character is dead

Status: not built. The author, 2026-11-01: "the player character death should block party picker and the player
should receive a message if they attempt to change the party makeup before the PC is revived. ... However, for a
later build let's create a toggle that would allow the player to override this block and change the party
composition even without the PC being alive." 1.1.4 builds the block and the message
(docs/PLAN_1.1.4_final_review_fixes.md, unit A).

## What is known (from the game's story scripts, checked 2026-11-01)
- A dead character is put in DB_CantMove (__AAA_FirstGoal.txt L2236-2242), so a dead party member, the player's own
  character included, gets the fast-travel block TRAVELBLOCK_CANTMOVE (_Waypoints.txt L187-194). Party Picker checks
  the host's own character with Party.BlockedReason before any change; that is why 1.1.3 refused every change with a
  story-table message, and 1.1.4 names death instead.
- The game's own recruit and dismiss conversations have no check on the player's character being alive in the
  scripts read (_GLO_Shared_Origins.txt; the dismiss lock in _GLO_Shared_PartyMembers.txt L232-395 is about the
  companion). Whether the base game lets you recruit or dismiss in camp while your own character is dead is not
  confirmed either way.
- Party.Apply recruits and dismisses "by" the host's avatar (Party.HostAvatar, the speaker the game's dialogs use).

## Shape if built
- An MCM checkbox, off by default: "Allow party changes while your character is dead".
- With it on, Apply skips unit A's death check for the host's own character (only that one check; every other
  restriction stays, including the dead companions' own lock).
- Open questions to settle first: which character to recruit/dismiss "by" when the avatar is dead (another living
  avatar of the host, or the controlled character); whether PROC_GLO_PartyMembers_Remove/CheckAdd behave with a dead
  dismisser; the long-rest trim with a dead avatar (the camp puts the dead to bed?). Needs a plan, reviews and a game
  test (throwaway save: kill your own character, change the party, revive, rest).
