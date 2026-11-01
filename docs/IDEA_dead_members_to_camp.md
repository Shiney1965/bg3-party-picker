# Idea for a later release: send a dead party member to camp

Status: not built; parked by the author's decision, 2026-11-01: "I think that if the base game locks dead party
members in the party then we should keep that for not, and fork out an option for a later release to remove that
removal restriction and send them to camp instead." 1.1.3 keeps the lock and explains it on a click
(docs/PLAN_1.1.3_dead_member_notice.md).

## What the game does (verified in the story sources)
Paths: Shared = `RaphaelJoinsTheParty\_vanilla_story\Mods\Shared\Story\RawFiles\Goals\`, Gustav = `...\Mods\Gustav\Story\RawFiles\Goals\`.
- The game blocks dismissing the dead: a dead character goes into DB_CantTalk_IgnoreStatuses
  (Shared __AAA_FirstGoal.txt L2040-2045), then DB_CantTalk (L2068-2074); a party member in DB_CantTalk gets
  DB_BlockDismissable and PROC_SetBlockDismiss(_, 1) (Shared _GLO_Shared_PartyMembers.txt L241-249).
- The removal procedure itself has no dead check for companions: PROC_GLO_PartyMembers_Remove ->
  RemoveIfUserHasOtherCharacter -> DetachFromPartyGroup + PROC_GLO_PartyMembers_MakeNPC (L636-699; companion MakeNPC L1298-1321).
  It moves nobody, so the body would stay where it fell. For avatars there is an explicit "Dead avatar -> Instant
  dismissal" branch (L1345-1356) and a dead-avatar definition of QRY_GLO_AvatarCanBeDismissed (L1882-1900).
- Withers revives dead party members (Gustav GLO_Jergal.txt L537-539) and also dead companions who are on the team
  but not in the party: DB_Origins + DB_PartOfTheTeam + NOT DB_Players + DB_Dead (L578-599); hirelings likewise
  with DB_Hirelings_CampPos (L602-620). So a dead companion sent to camp could still be revived there.
- The game already sends dead companions to camp, through Withers (found by the 1.1.3 plan review, checked): for a
  dead party member who is not an avatar he sets a "can dismiss" flag (Gustav GLO_Jergal.txt L556-564); if the
  player picks it, "Dead Party management" teleports the body to its camper position (PROC_GLO_Jergal_Teleport,
  L1099-1137) and on the event "GLO_Jergal_CompanionDismissed" removes it: PROC_GLO_PartyMembers_Remove(_Origin, 1)
  for origins, PROC_Hirelings_SendToCampForStorage for hirelings (L1170-1185). A later option could follow the
  same steps from the Party tab, which answers most of question 1 below.
- Companion Permadeath (Necrotic Flame), which the author ran until 2026-11-01, takes a dead companion off the team
  altogether (docs/TESTING.md 2026-10-31); this idea is the softer version: off the party, still
  on the team.

## Not known yet (to settle before any code)
1. What the camp scripts (GLO_Camp.txt) do with a dead companion who is on the team and not in the party: whether
   they teleport the body to its camp spot, leave it, or skip it.
2. Whether any story rule assumes a dead companion is in the party (dialogue, quest, long-rest and resurrection
   flows; the "Dead_Character" tutorial rules seen in the Osiris log 2026-11-01 L7209312 onwards).
3. Whether MakeNPC on a dead character leaves its inventory reachable (story items, gear).
4. What happens to a dead hireling (PROC_Hirelings_SendToCamp sets only the in-camp flag, Hirelings.txt
   L670-675).
5. Multiplayer: a dead member controlled by another player.

## Shape if built
An MCM option, off by default ("Allow sending dead party members to camp"), so the game's rule stays the default.
With it on, a dead party member is unlocked on the tab, and Apply sends them through the same removal as anyone
else; with it off, 1.1.3's notice. Needs its own plan, plan review, diff review and an in-game test (a throwaway
save: kill a companion, send them to camp, check the body, then revive at Withers).
