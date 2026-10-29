-- Server-side scenarios for Party Picker against tests/mock_game.lua.
-- Run with: python3 tests/run_tests.py

local M = dofile(TEST_ROOT .. "/mock_game.lua")
M.LUA_ROOT = LUA_ROOT

-- Globals the mod expects from Script Extender.
Ext = M.Ext
Osi = M.Osi
ModuleUUID = "f8e3db24-5fe8-40e0-a2d5-eaaf1013aea9"
local settings = { max_party_size = 6 }
-- MCM.Set as BG3-MCM v1.41 behaves for a slider_int: false (no error) outside its range.
local mcmSets = {}
local mcmSetFails = false
MCM = {
    Get = function(id) return settings[id] end,
    Set = function(id, value, modUUID, shouldEmitEvent)
        mcmSets[#mcmSets + 1] = { id = id, value = value, emit = shouldEmitEvent }
        if mcmSetFails or math.type(value) ~= "integer" or value < 4 or value > 30 then return false end
        settings[id] = value
        return true
    end,
}

local passed, failed = 0, 0
local function check(cond, what)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. what) end
end

-- The party: Tav (avatar) + 6 companions + 1 hireling, 4 active + a summon.
local U = function(n) return string.format("00000000-0000-0000-0000-%012d", n) end
M.host = M.addChar("Tav", U(1))
local names = { "Shadowheart", "Astarion", "Gale", "Laezel", "Karlach", "Wyll" }
local c = {}
for i, n in ipairs(names) do c[n] = M.addChar(n, U(10 + i)) end
c.Hireling = M.addChar("Hireling", U(30))
local wolf = M.addChar("Wolf", U(40), { summon = true })
M.hostPeer = 65536 -- network peer id; Osiris user id is 65537

for _, ch in pairs(M.chars) do
    if not ch.summon then M.db("DB_PartOfTheTeam")(ch.id) end
end
M.db("DB_Avatars")(M.host.id)
M.db("DB_Hirelings_Hired")(c.Hireling.id)
-- Hirelings get the companion marks with the Hirelings faction (SharedDev Hirelings.txt L745-747).
local HIRELINGS = "Hirelings_b7b47ac8-8e29-4984-b8c5-f35b66d8265a"
M.db("DB_OriginNPCAlignment")(c.Hireling.id, HIRELINGS)
M.db("DB_GLO_PartyMembers_OriginalAlignment")(c.Hireling.id, HIRELINGS)
M.db("DB_Hirelings_HACK_Classes")("Recruit_Flag_H", c.Hireling.id, "Recruited_Flag_H")
-- Origins carry an NPC alignment (needed to dismiss them: _GLO_Shared_Origins.txt L439-450),
-- which the story copies to the table the dismissal procedure reads (L238-240).
for _, n in ipairs(names) do
    M.db("DB_OriginNPCAlignment")(c[n].id, "Origin_" .. n .. "_Alignment")
    M.db("DB_GLO_PartyMembers_OriginalAlignment")(c[n].id, "Origin_" .. n .. "_Alignment")
end
for _, ch in ipairs({ M.host, c.Shadowheart, c.Astarion, c.Gale, wolf }) do
    M.db("DB_Players")(ch.id)
    M.db("DB_PartyMembers")(ch.id)
end
for _, ch in ipairs({ c.Laezel, c.Karlach, c.Wyll, c.Hireling }) do M.db("DB_InCamp")(ch.id) end
-- Companions waiting in camp were dismissed, which leaves the row the add
-- rule needs (_GLO_Shared_PartyMembers.txt L512, L1313).
for _, ch in ipairs({ c.Laezel, c.Karlach, c.Wyll }) do
    M.db("DB_GLO_PartyMembers_DefaultFaction")(ch.id, "PlayerFaction")
end
Osi.PROC_Hirelings_SendToCamp(c.Hireling.id) -- the hireling was parked in camp by the game

-- A companion another mod looks after leaves the party that mod's own way.
local function leavesByOtherMod(ch)
    M.db("DB_Players"):Delete(ch.id)
    M.db("DB_InCamp")(ch.id)
end

-- Raft goal rows as in Act1_UND_EbonLake.txt: four positions per dock.
local RAFT = "DB_UND_EbonLake_Raft_Locations_PlayerPositions"
local docks = {
    cave = "UND_EbonLake_State_RaftAtCave_beb83efd-711a-4e20-8d87-470050aebee8",
    lake = "UND_EbonLake_State_RaftAtLake_8ff8fe26-4546-40e0-94a5-03dba9001650",
}
for i = 1, 4 do
    M.db(RAFT)(docks.cave, i, "S_UND_DarkLake_BoatPassengerPositionAtCave_906d8dc6-3824-4d37-a09a-40d49831ef74")
    M.db(RAFT)(docks.lake, i, "S_UND_DarkLake_PlayerPositionOnBoat_00" .. i .. "_" .. U(500 + i))
end

dofile(LUA_ROOT .. "/BootstrapServer.lua")
local Party = Ext.Require("Server/Party.lua")
local Restrictions = Ext.Require("Server/Restrictions.lua")

local function apply(data)
    local reply
    PP.Net.Apply:RequestToServer(data, function(r) reply = r end)
    M.runTimers()
    return reply
end

-- 1. Level start applies the limit and extends the raft.
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
check(M.maxOverride == 6, "limit applied on level start")
check(#M.db(RAFT):Get(docks.cave, nil, nil) == 30, "cave dock has 30 landing positions (PP.MAX_PARTY_SIZE)")
local lake9 = M.db(RAFT):Get(docks.lake, 9, nil)[1]
check(lake9 and lake9[3] == M.db(RAFT):Get(docks.lake, 1, nil)[1][3], "position 9 reuses position 1")
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
check(#M.db(RAFT).rows == 60, "second level start adds nothing")

-- 2. Roster: 8 characters, summon left out, avatar locked.
local roster = Party.Roster()
check(#roster == 8, "roster has 8 entries, got " .. #roster)
check(roster[1].name == "Tav" and roster[1].locked, "avatar first and locked")
local ids = {}
for _, e in ipairs(roster) do ids[e.name] = e.uuid; check(e.name ~= "Wolf", "summon excluded") end
check(Party.ActiveCount() == 4, "4 active (summon not counted)")

-- 3. Apply a party of six, including the hireling from camp.
local reply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Laezel, ids.Karlach, ids.Hireling } })
check(reply and reply.accepted, "apply accepted: " .. tostring(reply and reply.message))
check(M.activeNames() == "Astarion,Hireling,Karlach,Laezel,Shadowheart,Tav,Wolf",
    "six active after apply, got " .. M.activeNames())
check(#M.db("DB_InCamp"):Get(c.Gale.id) == 1, "Gale sent to camp")
check(M.counters.Hirelings_InCamp_Count == 0, "hireling taken from camp through the game's procedure")
check(#M.teleported > 0, "joiners brought to the player with a valid TeleportTo overload")

-- 4. Over the limit is refused and changes nothing.
reply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Laezel, ids.Karlach, ids.Hireling, ids.Gale } })
check(reply and not reply.accepted, "7 of 6 refused")

-- 5. Another player's peer is refused.
M.hostPeer = 131072
reply = apply({ uuids = {} })
check(reply and not reply.accepted and reply.message:find("host"), "non-host refused")
M.hostPeer = 65536

-- 6. Combat blocks changes.
c.Astarion.inCombat = true
reply = apply({ uuids = { ids.Shadowheart } })
check(reply and not reply.accepted and reply.message:find("combat"), "combat blocks")
c.Astarion.inCombat = false

-- 7. While the host controls a companion, that companion is locked and the
--    avatar is still the one recruiting.
M.controlled = c.Shadowheart
roster = Party.Roster()
for _, e in ipairs(roster) do
    if e.name == "Shadowheart" then check(e.locked, "controlled companion locked") end
end
check(Party.HostAvatar() == M.host.id, "host avatar found while controlling a companion")
M.controlled = nil

-- 8. Long rest: End the Day is held, picker asked, trim, then restore.
M.broadcasts = {}
M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
local reasons = M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows
check(#reasons == 1 and reasons[1][1] == "PartyPicker_PartyLargerThanFour", "rest held with our reason")
M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason"):Delete(nil) -- the story removes it
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
check(#M.broadcasts == 1 and M.broadcasts[1].channel == "PickFour" and M.broadcasts[1].data.reason == "rest",
    "picker requested for rest")
check(Restrictions.GetPending() and not Restrictions.GetPending().trimmed, "pending, not yet trimmed")

reply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Karlach, ids.Laezel }, reason = "rest" })
check(reply and not reply.accepted, "5 for a rest of four refused")
reply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Karlach }, reason = "rest" })
check(reply and reply.accepted, "trim to four accepted")
check(Party.ActiveCount() == 4, "four active for the rest, got " .. Party.ActiveCount())
check(Restrictions.GetPending().trimmed, "pending trimmed")
check(M.counters.Hirelings_InCamp_Count == 1, "hireling sent to camp through the game's procedure")

M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
check(#M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows == 0, "rest not held at four")

-- A recruit joins during the night; the restore must not send them away.
Osi.PROC_GLO_PartyMembers_CheckAdd(c.Wyll.id, M.host.id)
M.fire("LongRestFinished", 0, "after")
M.runTimers()
check(#M.db("DB_Players"):Get(c.Wyll.id) == 1, "night-time recruit kept by the restore")
check(Party.ActiveCount() == 6, "restore filled up to the limit, got " .. Party.ActiveCount())
check(Restrictions.GetPending() == nil, "pending cleared after restore")

-- 9. Trim, put everyone back by hand, rest: no stale record survives.
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Wyll }, reason = "rest" })
check(Restrictions.GetPending().trimmed, "trimmed again")
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Wyll, ids.Laezel, ids.Karlach } })
check(Restrictions.GetPending() == nil, "a hand-picked party clears the trim record")
M.fire("LongRestFinished", 0, "after")
M.runTimers()
check(Party.ActiveCount() == 6, "nothing changed by a later rest")

-- 10. Restore when everyone is already back clears the record.
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Wyll }, reason = "rest" })
Osi.PROC_GLO_PartyMembers_CheckAdd(c.Laezel.id, M.host.id)  -- the game itself brings them back
Osi.PROC_GLO_PartyMembers_CheckAdd(c.Karlach.id, M.host.id)
local ok, message = Restrictions.Restore()
check(ok and message:find("already back"), "restore with nothing to do succeeds")
check(Restrictions.GetPending() == nil, "and clears the record")

-- 11. "Keep everyone this time" skips exactly one hold and keeps an earlier trim.
reply = apply({ reason = "rest", keepAll = true })
check(reply and reply.accepted, "keep-all accepted")
M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
check(#M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows == 0, "bypass skips one hold")
M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
check(#M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows == 1, "next hold applies again")
M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason"):Delete(nil)

M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Wyll }, reason = "rest" })
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ reason = "rest", keepAll = true })
check(Restrictions.GetPending() and Restrictions.GetPending().trimmed, "keep-all does not lose an earlier trim")
Restrictions.Restore()
M.runTimers()
check(Party.ActiveCount() == 6, "earlier trim still restorable")

-- 12. A handler error still produces a reply.
local realRoster = Party.Roster
Party.Roster = function() error("boom") end
reply = apply({ uuids = { ids.Shadowheart } })
check(reply and reply.accepted == false and tostring(reply.message):find("boom"), "error reaches the client")
Party.Roster = realRoster

-- 13. Bypass expires if End the Day is not pressed soon after.
apply({ reason = "rest", keepAll = true })
M.runLongTimers()
M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
check(#M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows == 1, "bypass expired")
M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason"):Delete(nil)

-- 14. A dead party member is never sent to camp by an Apply.
c.Gale.dead = true
Osi.PROC_GLO_PartyMembers_Remove(c.Wyll.id, M.host.id, 1)
Osi.PROC_GLO_PartyMembers_CheckAdd(c.Gale.id, M.host.id)
reply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Laezel, ids.Karlach } })
check(#M.db("DB_Players"):Get(c.Gale.id) == 1, "dead member kept in the party")
c.Gale.dead = false

-- 15. Restore with the party already over a lowered limit: nothing to do.
settings.max_party_size = 4
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
local p = Restrictions.GetPending(); p.trimmed = true; Ext.Vars.GetModVariables(ModuleUUID).Pending = p
ok, message = Restrictions.Restore()
check(ok and Restrictions.GetPending() == nil, "restore over a lowered limit clears the record")
settings.max_party_size = 6

-- 16. Night ends after LongRestFinished: restore runs again without warnings.
M.broadcasts = {}
M.fire("DB_Camp_NightMode", 1, "afterDelete", 1)
M.runTimers()
check(#M.broadcasts == 0, "no restore notice without a pending trim")

-- 17. A dismissed avatar is listed but locked; raft rows added at disembark.
local other = M.addChar("OtherTav", U(2), { user = 131073 })
M.db("DB_PartOfTheTeam")(other.id)
M.db("DB_DismissedAvatar")(other.id)
local otherListed = false
for _, e in ipairs(Party.Roster()) do
    if e.name == "OtherTav" then otherListed = true; check(e.locked, "dismissed avatar locked") end
end
check(otherListed, "dismissed avatar listed")
local camp = "UND_EbonLake_State_RaftAtCamp_526b966d-e826-4290-8331-e4747c1df3a5"
for i = 1, 4 do M.db(RAFT)(camp, i, "S_UND_DarkLake_BoatPassengerPositionAtCamp_3478b34d-0e4f-4a4b-8f9f-b7d9361eec8b") end
M.fire("PROC_UND_EbonLake_DisembarkCrew", 1, "before", camp)
check(#M.db(RAFT):Get(camp, nil, nil) == 30, "late raft goal rows extended at disembark")
-- A party larger than the maximum (the story can add members itself) still gets a row each.
local extraRows = {}
for i = 1, 31 do local x = M.addChar("Extra" .. i, U(900 + i)); extraRows[i] = x; M.db("DB_Players")(x.id) end
Restrictions.ExtendRaft()
check(#M.db(RAFT):Get(camp, nil, nil) == #M.db("DB_Players").rows, "raft rows follow a party larger than 30: " .. #M.db(RAFT):Get(camp, nil, nil))
for _, x in ipairs(extraRows) do M.db("DB_Players"):Delete(x.id); M.chars[x.uuid] = nil end
-- The party-size setting is capped at the maximum.
settings.max_party_size = 99
check(Party.MaxSize() == 30, "party size capped at 30")
settings.max_party_size = 30
Party.ApplyMaxSize()
check(M.maxOverride == 30, "a limit of 30 reaches the game")
settings.max_party_size = 6
Party.ApplyMaxSize()

-- 18. Reported in game 2026-10-11: Withers and summons were listed.
local withers = M.addChar("Withers", "0133f2ad-e121-4590-b5f0-a79413919805")
M.db("DB_PartOfTheTeam")(withers.id)
M.db("DB_InCamp")(withers.id)
local familiar = M.addChar("Familiar", U(41), { entitySummon = true })   -- IsSummon query misses it
local cub = M.addChar("Cub", U(42), { follower = true })
local undead = M.addChar("Undead", U(43))
M.db("DB_PlayerSummons")(undead.id)
local before = Party.ActiveCount()
for _, ch in ipairs({ familiar, cub, undead }) do M.db("DB_Players")(ch.id) end
local names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = true end
check(not names.Withers, "Withers not listed")
check(not names.Familiar, "summon found only by its entity component not listed")
check(not names.Cub, "party follower not listed")
check(not names.Undead, "DB_PlayerSummons member not listed")
check(Party.ActiveCount() == before, "summons and followers not counted against the limit")
local excluded = {}
for _, x in ipairs(Party.Excluded()) do excluded[x.name] = x.why end
check(excluded.Withers == "Withers" and excluded.Familiar == "summon" and excluded.Cub == "follower",
    "!pp_roster explains each exclusion")
-- !pp_roster names the build and, per character, its story tables and faction.
c.Laezel.faction = "Origin_Laezel_Faction"
M.log = {}
M.console.pp_roster()
local out = table.concat(M.log, "\n")
check(out:find("Party Picker v" .. PP.VERSION, 1, true), "!pp_roster prints the version")
check(out:find("Lae'?zel[^\n]*%[in: [^;]*team[^\n]*faction: Origin_Laezel_Faction"), "!pp_roster prints tables and faction")
check(out:find("Withers[^\n]*not listed[^\n]*%[in: team,incamp;"), "!pp_roster prints tables for excluded characters")
check(out:find("Familiar[^\n]*not listed[^\n]*entity%.IsSummon"), "!pp_roster prints the entity summon signal")
-- A failing lookup is marked, not shown as absent.
local realGetFaction = Osi.GetFaction
Osi.GetFaction = function() error("no such query") end
check(select(2, Party.Sources(c.Laezel.id)) == "?", "failed faction lookup shown as ?")
Osi.GetFaction = realGetFaction
-- Applying a party must never touch them.
reply = apply({ uuids = { ids.Shadowheart, ids.Astarion } })
check(#M.db("DB_Players"):Get(familiar.id) == 1 and #M.db("DB_Players"):Get(cub.id) == 1
    and #M.db("DB_Players"):Get(undead.id) == 1, "summons and followers stay with the party on Apply")

-- 19. Reported in game 2026-10-11: camp followers and camp pets were listed.
--     They are in DB_PartOfTheTeam (and camp) but have no NPC alignment and
--     have never been in the party.
local volo = M.addChar("Volo", U(60))
local scratch = M.addChar("Scratch", U(61))
for _, ch in ipairs({ volo, scratch }) do
    M.db("DB_PartOfTheTeam")(ch.id); M.db("DB_InCamp")(ch.id)
end
-- A companion added by another mod: no NPC alignment, but in the party now.
local modded = M.addChar("Alfira", U(62))
M.db("DB_PartOfTheTeam")(modded.id)
M.db("DB_Players")(modded.id)
names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = true end
check(not names.Volo and not names.Scratch, "camp follower and camp pet not listed")
check(names.Alfira, "companion from another mod listed while in the party")
check(names.Laezel and names.Hireling, "origin and hireling still listed")
excluded = {}
for _, x in ipairs(Party.Excluded()) do excluded[x.name] = x.why end
check(excluded.Volo and excluded.Volo:find("camp only"), "!pp_roster explains the camp-only exclusion")
-- Once seen in the party, the mod companion stays listed from camp, also after a reload.
leavesByOtherMod(modded)
local saved = Ext.Vars.GetModVariables(ModuleUUID).Seen
check(type(saved) == "table" and saved[modded.uuid], "seen party members saved with the game")
names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = (e.inCamp and "camp" or "party") end
check(names.Alfira == "camp", "mod companion still listed from camp")
M.log = {}
M.console.pp_roster()
out = table.concat(M.log, "\n")
check(out:find("Alfira[^\n]*%[in: seen,team"), "!pp_roster shows the seen record")
check(out:find("Laezel[^\n]*aligned") or out:find("Lae'?zel[^\n]*aligned"), "!pp_roster shows the NPC alignment")
-- Summons and followers that sat in DB_Players were never remembered.
saved = Ext.Vars.GetModVariables(ModuleUUID).Seen
check(not (saved[wolf.uuid] or saved[familiar.uuid] or saved[cub.uuid] or saved[undead.uuid]),
    "summons and followers not remembered as party members")
-- A mod companion who joins and leaves without the tab being opened is
-- remembered by the DB_Players listener.
local raphael = M.addChar("Raphael", U(63))
M.db("DB_PartOfTheTeam")(raphael.id)
M.db("DB_Players")(raphael.id)
M.fire("DB_Players", 1, "after", raphael.id)
leavesByOtherMod(raphael)
-- A companion dismissed the normal way carries the dismissal mark, even if
-- never seen by this mod (_GLO_Shared_PartyMembers.txt L1313).
local minsc = M.addChar("Minsc", U(64))
M.db("DB_PartOfTheTeam")(minsc.id); M.db("DB_InCamp")(minsc.id)
M.db("DB_GLO_PartyMembers_DefaultFaction")(minsc.id, "PlayerFaction")
names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = true end
check(names.Raphael, "companion who joined and left while the tab was closed still listed")
check(names.Minsc, "companion dismissed the normal way listed")
check(not names.Volo, "camp follower still not listed")
-- !pp_forget removes someone from the remembered list.
M.log = {}
M.console.pp_forget(nil, "Raphael")
saved = Ext.Vars.GetModVariables(ModuleUUID).Seen
check(not saved[raphael.uuid] and table.concat(M.log):find("forgot 1"), "!pp_forget removes a remembered character")

-- 20. Reported in game 2026-10-12: a hireling never created at Withers was
--     listed. Hireling templates carry the companion marks with the Hirelings
--     faction before hiring (Hirelings.txt L280-285). Only hired ones are listed,
--     even if this mod saw them in the party before (v0.1.4 could recruit them).
local brianna = M.addChar("Brianna", U(70))
M.db("DB_Hirelings_HACK_Classes")("Recruit_Flag_X", brianna.id, "Recruited_Flag_X")
M.db("DB_OriginNPCAlignment")(brianna.id, HIRELINGS)
M.db("DB_GLO_PartyMembers_OriginalAlignment")(brianna.id, HIRELINGS)
M.db("DB_PartOfTheTeam")(brianna.id)
M.db("DB_InCamp")(brianna.id)
local seenNow = {}
for u, v in pairs(Ext.Vars.GetModVariables(ModuleUUID).Seen) do seenNow[u] = v end
seenNow[brianna.uuid] = true
Ext.Vars.GetModVariables(ModuleUUID).Seen = seenNow
names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = true end
check(not names.Brianna, "un-hired hireling template not listed, even if seen before")
check(names.Hireling, "hired hireling still listed")
excluded = {}
for _, x in ipairs(Party.Excluded()) do excluded[x.name] = x.why end
check(excluded.Brianna and excluded.Brianna:find("not hired"), "!pp_roster explains the un-hired hireling")
-- If such a character is in the party now, they stay listed so they can be sent away.
M.db("DB_Players")(brianna.id)
names = {}
for _, e in ipairs(Party.Roster()) do names[e.name] = true end
check(names.Brianna, "un-hired hireling in the party is listed so she can be sent away")
M.db("DB_Players"):Delete(brianna.id)
M.log = {}
M.console.pp_roster()
check(table.concat(M.log, "\n"):find("Brianna[^\n]*hiretemplate"), "!pp_roster tags hireling templates")

-- 21. Reported in game 2026-10-12 ("One recruited I was unable to dismiss
--     Brianna Brightsong"). The logs showed a hired hireling who was off
--     stage. v0.1.4 recruited her; the story then blocked her travel
--     (_Waypoints.txt L188-194) and the block check refused every request
--     that sent her to camp, without a log line. Off-stage characters are
--     now not offered, and refusals are logged and name the reason.
settings.max_party_size = 16
Party.ApplyMaxSize() -- as the settings listener does when the slider moves
local IN_CAMP ="Hireling_State_InCamp_e33aa0df-fcfc-4a30-8169-516d3956f02a"
local bard = M.addChar("Brinna", U(71))
M.db("DB_Hirelings_HACK_Classes")("Recruit_Flag_B", bard.id, "Recruited_Flag_B")
M.db("DB_OriginNPCAlignment")(bard.id, HIRELINGS)
M.db("DB_GLO_PartyMembers_OriginalAlignment")(bard.id, HIRELINGS)
M.db("DB_PartOfTheTeam")(bard.id)
M.db("DB_Hirelings_Hired")(bard.id)
M.db("DB_GLO_PartyMembers_DefaultFaction")(bard.id, "Hireling1_9459fd54-cdc5-458f-8aa0-fc6ea18c888f")
M.setOnStage(bard, false)
local function rosterEntry(name)
    for _, e in ipairs(Party.Roster()) do
        if e.name == name then return e end
    end
end
local function logText() return table.concat(M.log, "\n") end
local entry = rosterEntry("Brinna")
check(entry and entry.locked and tostring(entry.lockReason):find("off stage"),
    "off-stage hireling listed but locked, got " .. tostring(entry and entry.lockReason))
M.log = {}
M.console.pp_roster()
check(logText():find("Brinna[^\n]*offstage"), "!pp_roster shows the off-stage mark")
local without = Party.ActiveUuids()
local withBard = { bard.uuid }
for _, u in ipairs(without) do withBard[#withBard + 1] = u end
local activeBefore = M.activeNames()
M.log = {}
reply = apply({ uuids = withBard })
check(reply and not reply.accepted and tostring(reply.message):find("Brinna")
    and tostring(reply.message):find("off stage"),
    "recruiting an off-stage character is refused and says why: " .. tostring(reply and reply.message))
check(M.activeNames() == activeBefore, "and nothing changed")
check(logText():find("request refused[^\n]*Brinna"), "the refusal is written to the log")

-- As in the author's save: she is already in the party, off stage.
Osi.PROC_Hirelings_AddToParty(bard.id, M.host.id)
check(#M.db("DB_Players"):Get(bard.id) == 1
    and #M.db("DB_FastTravelBlock_CantMove_StatusSet"):Get(bard.id) == 1,
    "mock: an off-stage joiner gets the story's travel block")
M.log = {}
reply = apply({ uuids = without })
check(reply and not reply.accepted and tostring(reply.message):find("Brinna")
    and tostring(reply.message):find("off stage"),
    "sending an off-stage member to camp is refused and says why: " .. tostring(reply and reply.message))
check(logText():find("request refused[^\n]*Brinna"), "that refusal is in the log too")

-- Back on stage the block lifts and she can be sent to camp; the request
-- and the result name who moved.
M.setOnStage(bard, true)
M.log = {}
reply = apply({ uuids = without })
check(reply and reply.accepted, "on stage again: request accepted: " .. tostring(reply and reply.message))
check(#M.db("DB_Players"):Get(bard.id) == 0 and Osi.GetFlag(IN_CAMP, bard.id) == 1, "and she is sent to camp")
check(logText():find("request:[^\n]*send to camp[^\n]*Brinna"), "accepted request logged with names")
check(logText():find("Sent to camp: Brinna"), "result names who left")
M.log = {}
reply = apply({ uuids = withBard })
check(#M.db("DB_Players"):Get(bard.id) == 1 and logText():find("Joined: Brinna"), "result names who joined")

-- 22. A hireling the game does not remove (no original-alignment row,
--     _GLO_Shared_PartyMembers.txt L1305): reported, and her hireling camp
--     state (flag and counter, Hirelings.txt L670-675) is left alone.
M.db("DB_GLO_PartyMembers_OriginalAlignment"):Delete(bard.id, nil)
local campCount = M.counters.Hirelings_InCamp_Count
M.log = {}
apply({ uuids = without })
check(#M.db("DB_Players"):Get(bard.id) == 1, "mock: without the alignment row the game does not remove her")
check(logText():find("Brinna did not leave"), "reported as not having left")
check(M.counters.Hirelings_InCamp_Count == campCount and Osi.GetFlag(IN_CAMP, bard.id) == 0,
    "hireling camp state untouched when the game did not remove her")
M.db("DB_GLO_PartyMembers_OriginalAlignment")(bard.id, HIRELINGS)
apply({ uuids = without })
check(#M.db("DB_Players"):Get(bard.id) == 0, "with the row back she leaves")
-- The same for a companion from another mod that the story does not mark.
M.db("DB_Players")(modded.id)
M.db("DB_PartyMembers")(modded.id)
M.db("DB_InCamp"):Delete(modded.id)
M.log = {}
apply({ uuids = without })
check(logText():find("Alfira did not leave"), "unmarked mod companion the game does not remove is reported")
leavesByOtherMod(modded)
-- A character who was never on stage has no DB_OffStage row; the game's
-- IsOnStage query is the second signal.
local ghost = M.addChar("Ghost", U(72))
M.db("DB_PartOfTheTeam")(ghost.id)
M.db("DB_GLO_PartyMembers_DefaultFaction")(ghost.id, "PlayerFaction")
ghost.offStage = true
entry = rosterEntry("Ghost")
check(entry and entry.locked and tostring(entry.lockReason):find("off stage"),
    "never-on-stage character locked through IsOnStage")
M.db("DB_PartOfTheTeam"):Delete(ghost.id)
M.db("DB_GLO_PartyMembers_DefaultFaction"):Delete(ghost.id, nil)

-- 23. Restore after a rest while a trimmed member is off stage (the camp
--     hides benched companions at night, GLO_Camp.txt L1630-1649): the others
--     come back, the record is kept, and she follows once on stage again.
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Laezel } })
check(#M.db("DB_Players"):Get(c.Laezel.id) == 1, "Laezel in the party before the rest")
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ uuids = { ids.Shadowheart }, reason = "rest" })
check(#M.db("DB_Players"):Get(c.Astarion.id) == 0 and #M.db("DB_Players"):Get(c.Laezel.id) == 0
    and Restrictions.GetPending() and Restrictions.GetPending().trimmed, "two members trimmed for the rest")
M.setOnStage(c.Laezel, false)
M.log = {}
Restrictions.Restore(function(result) PP.Log(result.message) end)
M.runTimers()
check(#M.db("DB_Players"):Get(c.Astarion.id) == 1, "on-stage member restored")
check(#M.db("DB_Players"):Get(c.Laezel.id) == 0, "off-stage member not added")
check(Restrictions.GetPending() ~= nil, "trim record kept while someone is still off stage")
check(logText():find("Laezel[^\n]*off stage"), "and the result says who is waiting")
ok, message = Restrictions.Restore()
check(not ok and tostring(message):find("off stage") and Restrictions.GetPending() ~= nil,
    "only off-stage members left: not 'everyone is back', record kept: " .. tostring(message))
M.setOnStage(c.Laezel, true)
Restrictions.Restore()
M.runTimers()
check(#M.db("DB_Players"):Get(c.Laezel.id) == 1 and Restrictions.GetPending() == nil,
    "back on stage: restored, record cleared")
settings.max_party_size = 6
Party.ApplyMaxSize()

-- 23. Settings off: no hold, no raft change.
settings.prompt_long_rest = false
M.fire("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before")
check(#M.db("DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason").rows == 0, "setting off: no hold")
settings.extend_raft = false
check(Restrictions.ExtendRaft() == 0, "setting off: raft untouched")

-- 24. House of Hope: the Debtor's Attire for party members five and up
--     (GustavDev Act3b_LOW_HouseOfHope2.txt L70-82, L973-999, L1024-1046).
settings.prompt_long_rest = nil
local HouseOfHope = Ext.Require("Server/HouseOfHope.lua")
HouseOfHope.Register()
local GRANT = "LOW_HouseOfHope_Event_HopeGrantsDisguise_bb82e10f-9c0f-5c16-9f1d-e482d9074ca8"
local VANITY = "ARM_Vanity_Prison_EternalDebtors_6f7d15a8-9bcb-45de-94c5-8c77424aaf42"
local REFUGEE = "UNI_Camp_Refugee_EternalDebtors_30c5721d-bdc3-4150-8cd1-d99197eb4870"
local HOH_SUB = "S_LOW_HouseOfHope_SUB_49462249-7f39-4b91-af1d-ba121c711213"
M.db("DB_LOW_HouseOfHope_DebtorTemplates")(REFUGEE)
M.db("DB_LOW_HouseOfHope_DebtorTemplates")(VANITY)
M.db("DB_TriggerEvents_TriggerSet")("LOW_HouseOfHope", HOH_SUB)
M.db("DB_TriggerEvents_TriggerSet")("LOW_HouseOfHope", "S_LOW_HouseOfHope_Prison_SUB_829b3df1-01b1-4d31-b251-0495c7692bec")
-- Seven in the party: Tav, Shadowheart, Astarion, Gale, Laezel, Karlach, Wyll (the wolf is a summon).
settings.max_party_size = 8
Party.ApplyMaxSize()
M.runLongTimers() -- clear expiry timers left by earlier scenarios
-- Set the party directly: this scenario is about the hand-out, not recruiting.
for _, ch in ipairs({ c.Shadowheart, c.Astarion, c.Gale, c.Laezel, c.Karlach, c.Wyll }) do
    M.setOnStage(ch, true)
    M.db("DB_Players")(ch.id)
end
local party7 = { M.host, c.Shadowheart, c.Astarion, c.Gale, c.Laezel, c.Karlach, c.Wyll }
check(#party7 == 7 and #M.db("DB_Players"):Get(c.Wyll.id) == 1, "seven in the party for the House of Hope")
for _, ch in ipairs(party7) do M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. ch.uuid] = true end
M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. wolf.uuid] = true
-- The game hands out its four sets (to the first four DB_Players rows) and equips them.
local originals = {}
for i, ch in ipairs({ M.host, c.Shadowheart, c.Astarion, c.Gale }) do
    local item = M.addItem(VANITY, ch.id, string.format("S_LOW_HouseOfHope_DebtorClothes0%d_00000000-0000-0000-0000-%012d", i, 800 + i))
    originals[i] = item
    M.db("DB_LOW_HouseOfHope_DebtorClothes")(i, item.id)
    M.equipped[ch.uuid] = item.id
end
local function attireCount(ch)
    local n = 0
    for _, item in pairs(M.items) do
        if item.owner == ch.uuid and (PP.BareUuid(item.template) == PP.BareUuid(VANITY)) then n = n + 1 end
    end
    return n
end

-- Another flag: nothing.
M.log = {}
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", "SOME_OtherFlag_11111111-2222-3333-4444-555555555555")
M.runTimers()
check(#M.queuedItems == 0, "another flag: no hand-out")

-- Setting off: nothing.
settings.hope_attire_everyone = false
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 0, "setting off: no hand-out")
settings.hope_attire_everyone = nil

-- Alarm already raised: nothing.
M.db("DB_LOW_HouseOfHope_AlarmIsReady")(1)
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 0, "alarm raised: no hand-out")
M.db("DB_LOW_HouseOfHope_AlarmIsReady"):Delete(1)

-- Karlach is not in the House of Hope; Laezel is dead; one of the four originals is still landing
-- (its owner is set but she does not yet show it by template).
M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. c.Karlach.uuid] = nil
c.Laezel.dead = true
M.log = {}
originals[4].template = "STILL_LANDING" -- Gale's set: owner known, not yet findable by template
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", "bb82e10f-9c0f-5c16-9f1d-e482d9074ca8") -- bare flag form
M.runTimers()
originals[4].template = VANITY
check(#M.queuedItems == 1 and PP.BareUuid(M.queuedItems[1].owner) == c.Wyll.uuid,
    "copy only for the member in the House without one (not the four, the dead, the absent, the summon)")
check(logText():find("giving the Debtor's Attire to 1 more party member%(s%): Wyll"), "hand-out logged with names")
check(logText():find("no Debtor's Attire for Karlach %(not in the House of Hope%)"), "absent member logged")
check(not M.equipped[c.Wyll.uuid], "not equipped before the item arrives")
-- Fired again before the item arrives: no second copy.
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 1, "second firing while waiting: no extra copy")
M.deliverItems()
check(attireCount(c.Wyll) == 1 and M.equipped[c.Wyll.uuid] ~= nil
    and PP.BareUuid(Osi.GetTemplate(M.equipped[c.Wyll.uuid])) == PP.BareUuid(VANITY),
    "copy arrives and is worn")
-- Fired again afterwards: everyone served, no extra copies.
M.log = {}
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 0 and not logText():find("giving the Debtor"), "everyone served: nothing more")
c.Laezel.dead = nil

-- An item of another template arriving for a pending member is ignored; the alarm between the
-- add and the arrival means it is not worn; the timeout reports what never arrived.
M.db("DB_LOW_HouseOfHope_DebtorClothes"):Delete(nil, nil)
for _, it in ipairs(originals) do M.items[PP.BareUuid(it.id)] = nil end
for _, ch in ipairs(party7) do M.equipped[ch.uuid] = nil end
for u, item in pairs(M.items) do if PP.BareUuid(item.template) == PP.BareUuid(VANITY) then M.items[u] = nil end end
M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. c.Karlach.uuid] = true
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 7, "no originals handed out: all seven get a copy (fallback template)")
check(PP.BareUuid(M.queuedItems[1].template) == PP.BareUuid(VANITY), "fallback is the vanity template")
local other = M.addItem("OBJ_Something_99999999-9999-9999-9999-999999999999", M.host.id)
M.fire("TemplateAddedTo", 4, "after", other.template, other.id, M.host.id, "")
check(not M.equipped[M.host.uuid], "another template arriving is ignored")
M.db("DB_LOW_HouseOfHope_AlarmIsReady")(1)
local first = table.remove(M.queuedItems, 1)
local q1 = M.queuedItems
M.queuedItems = { first }
M.deliverItems()
check(not M.equipped[PP.BareUuid(first.owner)], "alarm raised before the copy arrived: not worn")
M.db("DB_LOW_HouseOfHope_AlarmIsReady"):Delete(1)
M.queuedItems = {}
M.log = {}
M.runLongTimers() -- the 10 s equip timeout
check(select(2, logText():gsub("did not arrive", "")) == 6, "timeout reports the six copies that never arrived")

-- The template the game really hands out is copied when it is a debtor template.
for u, item in pairs(M.items) do if PP.BareUuid(item.template) == PP.BareUuid(VANITY) then M.items[u] = nil end end
local refugeeSet = M.addItem(REFUGEE, M.host.id, "S_LOW_HouseOfHope_DebtorClothes01_00000000-0000-0000-0000-000000000801")
M.db("DB_LOW_HouseOfHope_DebtorClothes")(1, refugeeSet.id)
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 6 and PP.BareUuid(M.queuedItems[1].template) == PP.BareUuid(REFUGEE),
    "copies use the template of the set the game hands out (host already holds it)")
M.queuedItems = {}
M.runLongTimers()

-- A call that raises is logged and the others are still served.
for u, item in pairs(M.items) do M.items[u] = nil end
M.db("DB_LOW_HouseOfHope_DebtorClothes"):Delete(nil, nil)
local realAdd = Osi.TemplateAddTo
Osi.TemplateAddTo = function(template, ownerId, n, notify)
    if PP.BareUuid(ownerId) == c.Gale.uuid then error("boom") end
    return realAdd(template, ownerId, n, notify)
end
M.log = {}
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
Osi.TemplateAddTo = realAdd
check(#M.queuedItems == 6 and logText():find("could not give the Debtor's Attire to Gale"), "failure logged, others served")
M.queuedItems = {}
M.runLongTimers()

-- Two hand-outs overlap: the first one's timeout must not clear the second one's members.
for u in pairs(M.items) do M.items[u] = nil end
for _, ch in ipairs(party7) do M.equipped[ch.uuid] = nil; M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. ch.uuid] = nil end
M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. M.host.uuid] = true
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 1, "first hand-out: only Tav is in the House")
for _, ch in ipairs(party7) do M.inTrigger[PP.BareUuid(HOH_SUB) .. "|" .. ch.uuid] = true end
M.fire("PROC_GlobalFlagReactionAfterDialog", 1, "after", GRANT)
M.runTimers()
check(#M.queuedItems == 7, "second hand-out: the other six, Tav still waiting")
local firstTimeout = table.remove(M.longTimers, 1)
M.log = {}
firstTimeout()
check(select(2, logText():gsub("did not arrive", "")) == 1 and logText():find("for Tav did not arrive"),
    "first timeout reports only its own member")
M.deliverItems()
local worn = 0
for _, ch in ipairs(party7) do if ch ~= M.host and M.equipped[ch.uuid] then worn = worn + 1 end end
check(worn == 6, "the second hand-out's copies are still worn after the first timeout: " .. worn)
M.runLongTimers()
settings.max_party_size = 6

-- 26. "Send everyone to camp": the Party tab sends an Apply with nobody ticked. The server keeps
--     the locked members (here Tav, the player character) and sends everyone else to camp.
for _, ch in ipairs({ c.Shadowheart, c.Astarion, c.Gale }) do M.db("DB_Players")(ch.id) end
check(#M.db("DB_Players"):Get(c.Gale.id) == 1, "party has companions before sending everyone to camp")
M.log = {}
local campReply = apply({ uuids = {} })
check(campReply and campReply.accepted, "send everyone to camp accepted: " .. tostring(campReply and campReply.message))
-- The request names every unlocked party member and never the locked player character.
-- (Whether each removal then succeeds is the game's side; scenarios above cover it.)
local req = logText():match("request: join %[%]; send to camp %[([^%]]*)%]") or ""
check(req:find("Shadowheart") and req:find("Astarion") and req:find("Gale") and not req:find("Tav"),
    "everyone but the locked player character is sent to camp: " .. req)
check(#M.db("DB_Players"):Get(c.Shadowheart.id) == 0 and #M.db("DB_Players"):Get(M.host.id) == 1,
    "companions who can leave are in camp; the player character stays")

-- 26b. With the host controlling a companion, an off-stage member passed along (as the tab does) and
--      a pending long-rest record: the controlled companion and the off-stage member stay, the record
--      is cleared (the Apply handler clears it when the party changed).
for _, ch in ipairs({ c.Shadowheart, c.Astarion, c.Gale }) do M.db("DB_Players")(ch.id) end
M.db("DB_GLO_PartyMembers_DefaultFaction")(c.Shadowheart.id, "PlayerFaction")
M.controlled = c.Astarion
M.setOnStage(c.Gale, false)
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
check(Restrictions.GetPending() ~= nil, "a long-rest record is pending")
M.log = {}
local camp2 = apply({ uuids = { ids.Gale } })
local req2 = logText():match("request: join %[%]; send to camp %[([^%]]*)%]") or ""
check(camp2 and camp2.accepted and req2:find("Shadowheart") and not req2:find("Astarion") and not req2:find("Gale"),
    "controlled companion and off-stage member are not sent to camp: " .. req2)
check(#M.db("DB_Players"):Get(c.Astarion.id) == 1 and #M.db("DB_Players"):Get(c.Gale.id) == 1, "both still in the party")
check(Restrictions.GetPending() == nil, "the pending long-rest record is cleared")
M.controlled = nil
M.setOnStage(c.Gale, true)

-- 27. Party Part D: the limit is never below the party (plan docs/PLAN_inspiration_and_30.md).
-- Members added here get the rows the game's dismiss rule needs (_GLO_Shared_PartyMembers.txt L1297-1305).
for _, ch in ipairs({ c.Shadowheart, c.Astarion, c.Gale, c.Laezel, c.Karlach }) do
    M.db("DB_Players")(ch.id); M.db("DB_PartyMembers")(ch.id)
end
for _, row in ipairs(M.db("DB_Players").rows) do
    local ch = M.chars[PP.BareUuid(row[1])]
    if ch and not ch.summon and ch ~= M.host and ch ~= c.Shadowheart and ch ~= c.Astarion and ch ~= c.Gale
        and ch ~= c.Laezel and ch ~= c.Karlach then M.db("DB_Players"):Delete(row[1]) end
end
local partyNow = Party.ActiveCount()
check(partyNow == 6, "six in the party for the limit tests: " .. partyNow)
settings.max_party_size = 8
Party.ApplyMaxSize()
check(M.maxOverride == 8, "setting above the party: the setting applies")
-- The slider is dragged down through 7, 5 and 4 (MCM sends an event each step).
M.broadcasts, mcmSets, M.log = {}, {}, {}
for _, v in ipairs({ 7, 5, 4 }) do
    settings.max_party_size = v
    M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = v })
    check(M.maxOverride >= 6, "never below the party while dragging (" .. v .. "): " .. tostring(M.maxOverride))
end
M.runTimers()
check(#mcmSets == 1 and mcmSets[1].value == 6 and mcmSets[1].emit == nil, "written back once, to 6, without an event")
check(settings.max_party_size == 6 and M.maxOverride == 6, "setting and limit now 6")
local msgs = M.messages()
check(#msgs == 1 and msgs[1]:find("can't be lower than the number in your party %(6%)") and msgs[1]:find("It has been set to 6"),
    "one message explains: " .. tostring(msgs[1]))
-- A drag that ends at or above the party: nothing written, no message.
M.broadcasts, mcmSets = {}, {}
for _, v in ipairs({ 5, 7 }) do
    settings.max_party_size = v
    M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = v })
end
M.runTimers()
check(#mcmSets == 0 and #M.messages() == 0 and M.maxOverride == 7, "drag ending above the party: accepted as is")
-- MCM.Set refuses: the limit still holds and the message says so.
mcmSetFails = true
M.broadcasts, mcmSets = {}, {}
settings.max_party_size = 4
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = 4 })
M.runTimers()
check(M.maxOverride == 6 and M.messages()[1] and M.messages()[1]:find("could not change the setting"), "refused write-back: limit kept, message says so")
mcmSetFails = false
-- A save loads with a bigger party than the setting: no write-back, one message per party size/setting.
M.broadcasts, mcmSets = {}, {}
settings.max_party_size = 4
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(#mcmSets == 0 and settings.max_party_size == 4 and M.maxOverride == 6, "load: setting kept at 4, game gets 6")
check(#M.messages() == 1 and M.messages()[1]:find("This game's party has 6 members") and M.messages()[1]:find("your setting stays 4"),
    "load message: " .. tostring(M.messages()[1]))
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(#M.messages() == 1, "next level load: not repeated")
-- An MCM profile switch runs the same check.
M.broadcasts = {}
settings.max_party_size = 5
M.mcmEvent("MCM_Profile_Activated", {})
M.runTimers()
check(M.maxOverride == 6 and #M.messages() == 1 and M.messages()[1]:find("your setting stays 5"), "profile switch checked")
-- Apply and the Party tab use the effective limit: with the setting at 5 and six in the party, keeping
-- the six (or fewer) is accepted.
-- A swap of two for two while the setting (5) is below the party (6): both must join. (Review
-- 2026-10-25: re-applying the limit on each added row stopped the second joiner.)
M.db("DB_InCamp")(c.Wyll.id)
M.db("DB_GLO_PartyMembers_DefaultFaction")(c.Wyll.id, "PlayerFaction")
M.db("DB_InCamp")(c.Hireling.id)
M.log = {}
local swap = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Gale, ids.Wyll, ids.Hireling } })
check(swap and swap.accepted, "swap accepted: " .. tostring(swap and swap.message))
check(#M.db("DB_Players"):Get(c.Wyll.id) == 1 and #M.db("DB_Players"):Get(c.Hireling.id) == 1,
    "both joiners are in the party: " .. M.activeNames() .. " | " .. logText())
check(#M.db("DB_Players"):Get(c.Laezel.id) == 0 and #M.db("DB_Players"):Get(c.Karlach.id) == 0, "both leavers went to camp")
check(M.maxOverride == 6, "limit re-applied once after Apply: " .. tostring(M.maxOverride))
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Gale, ids.Laezel, ids.Karlach } })
local okApply = apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Gale, ids.Laezel } })
check(okApply and okApply.accepted, "reducing the party works while the setting is below it: " .. tostring(okApply and okApply.message))
-- A long-rest trim waiting to be restored counts: lowering the setting at night cannot strand the
-- members in camp.
settings.max_party_size = 6
Party.ApplyMaxSize()
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Gale, ids.Laezel, ids.Karlach } })
local before = Party.ActiveCount()
M.fire("PROC_Camp_TryEnterNightModeFailed", 2, "after", M.host.id, "PartyPicker_PartyLargerThanFour")
apply({ uuids = { ids.Shadowheart, ids.Astarion, ids.Gale }, reason = "rest" })
check(Restrictions.GetPending() and Restrictions.GetPending().trimmed and Party.ActiveCount() == 4,
    "trimmed to four for the night")
settings.max_party_size = 4
M.broadcasts, mcmSets = {}, {}
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = 4 })
M.runTimers()
check(Party.EffectiveMaxSize() == before and M.maxOverride == before,
    "at night the limit stays at the pre-trim party (" .. before .. "): " .. tostring(M.maxOverride))
check(mcmSets[1] and mcmSets[1].value == before, "the setting is written back to the pre-trim party size")
Restrictions.Restore()
M.runTimers()
check(Party.ActiveCount() == before and Restrictions.GetPending() == nil, "everyone restored after the night")
settings.max_party_size = 6
Party.ApplyMaxSize()
M.runTimers()

-- 25. The Inspiration probe, !pp_inspiration (docs/PLAN_inspiration_and_30.md, step 0).
local INSP = M.staticData["a9c98304-08e7-44b5-aaf9-da2ef5a50672"]
M.host.actionResources = { Resources = { ["a9c98304-08e7-44b5-aaf9-da2ef5a50672"] = { { Amount = 2.0, MaxAmount = 4.0 } } } }
M.log = {}
M.console["pp_inspiration"]("pp_inspiration")
check(logText():find("limit in the game's definition = 4 ") and logText():find("Tav%s+personal"), "probe shows the limit and each member")
check(logText():find("Tav[^\n]*Amount 2 / MaxAmount 4"), "probe reads the character's ActionResources entry")
M.log = {}
M.console["pp_inspiration"]("pp_inspiration", "3")
check(INSP.MaxValue == 4 and logText():find("usage"), "a limit below 4 is refused")
M.console["pp_inspiration"]("pp_inspiration", "8")
check(INSP.MaxValue == 8 and logText():find("Inspiration limit set to 8"), "probe sets a test limit")
M.log = {}
M.console["pp_inspiration"]("pp_inspiration", "99")
check(INSP.MaxValue == 8 and logText():find("usage"), "out-of-range value refused")
M.console["pp_inspiration"]("pp_inspiration", "reset")
check(INSP.MaxValue == 4, "reset applies the setting again (default 4)")
check(M.partyInspiration == 0, "the probe never changes points")

-- 28. The Inspiration settings (plan Part B). BootstrapServer was loaded at the start, so its
--     subscribers are in place; the bank value is the mock's static entry.
local IB = M.staticData["a9c98304-08e7-44b5-aaf9-da2ef5a50672"]
local function inspirationBroadcasts()
    local out = {}
    for _, b in ipairs(M.broadcasts) do if b.channel == "Inspiration" then out[#out + 1] = b.data.limit end end
    return out
end
-- The slider: 8.
M.broadcasts, M.log = {}, {}
settings.inspiration_limit = 8
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 8 })
check(IB.MaxValue == 8 and logText():find("Inspiration limit set to 8"), "slider 8 sets the limit to 8")
check(inspirationBroadcasts()[1] == 8, "non-host clients are told the limit")
-- While a save loads the limit is held wide open (30), so nothing the save holds is capped; the level
-- start then sets the real value from the points held.
IB.MaxValue = 4.0
M.events["SessionLoading"]()
check(IB.MaxValue == 30, "save starting to load: limit held open at 30")
M.events["SessionLoaded"]()
check(IB.MaxValue == 30, "save loaded: still open until the level starts")
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(IB.MaxValue == 8, "level start: the setting (8) applied")
-- A player who joins later is sent the limit.
M.broadcasts = {}
M.fire("UserConnected", 3, "after", 2, "Friend", "friend")
check(inspirationBroadcasts()[1] == 8, "a player who joins later is sent the limit")
IB.MaxValue = 4.0
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(IB.MaxValue == 8, "level loaded: limit applied")
-- Out of range is clamped to 4-30.
settings.inspiration_limit = 2
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 2 })
check(IB.MaxValue == 4, "below 4: the game's 4")
settings.inspiration_limit = 99
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 99 })
check(IB.MaxValue == 30, "above 30: 30")
-- Match the party limit: follows the Maximum party size setting, not the head count.
settings.inspiration_limit = 5
settings.inspiration_match_party = true
settings.max_party_size = 12
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_match_party", value = true })
check(IB.MaxValue == 12, "match the party limit: 12 with a party-size setting of 12")
local beforeTrim = IB.MaxValue
for _, ch in ipairs({ c.Gale, c.Karlach }) do M.db("DB_Players"):Delete(ch.id) end
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(IB.MaxValue == beforeTrim, "fewer people in the party: the Inspiration limit does not change")
settings.max_party_size = 9
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = 9 })
M.runTimers()
check(IB.MaxValue == 9, "party-size setting changed: the matched Inspiration limit follows")
settings.inspiration_match_party = false
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_match_party", value = false })
-- While matched, the slider was held at the party limit (9), so unticking leaves 9 until it is moved.
check(IB.MaxValue == 9 and settings.inspiration_limit == 9, "match off: the slider, left at the matched 9")
-- Never below the points the party holds: with 6 points, a limit of 4 stays at 6.
M.partyInspiration = 6
M.log = {}
settings.inspiration_limit = 4
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 4 })
check(IB.MaxValue == 6 and logText():find("kept at 6"), "limit kept at the 6 points the party holds")
M.partyInspiration = 0
-- The party-size guard's write-back (no MCM event) refreshes a matched Inspiration limit.
for _, ch in ipairs({ c.Gale, c.Karlach }) do M.db("DB_Players")(ch.id) end
settings.inspiration_match_party = true
settings.max_party_size = 4
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = 4 })
M.runTimers()
check(settings.max_party_size == Party.ActiveCount() and IB.MaxValue == Party.ActiveCount(),
    "after the write-back the matched Inspiration limit follows: " .. tostring(IB.MaxValue))
settings.inspiration_match_party = false
-- Back to the default, and points were never touched (the mock fails the test on any point change).
settings.inspiration_limit = 4
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 4 })
check(IB.MaxValue == 4 and M.partyInspiration == 0, "default 4 restored; points never changed")
settings.max_party_size = 6
Party.ApplyMaxSize()
M.runTimers()

-- 29. Changing the Inspiration points on request (plan Part F).
check(#M.pointChanges == 0, "no path so far changed any Inspiration points: " .. #M.pointChanges)
M.partyInspiration = 3.0
settings.inspiration_limit = 8
settings.inspiration_match_party = false
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 8 })
local Insp = Ext.Require("Server/Inspiration.lua")
-- Controls off (the default): refused, nothing changed.
local okC, msgC = Insp.ChangePoints({ step = 1 })
check(not okC and msgC:find("Show Inspiration point controls") and #M.pointChanges == 0, "controls off: refused")
settings.inspiration_point_controls = true
-- From here the game applies a change a moment later, as it does in game (2026-10-27).
M.delayPoints = true
-- The tab: a step from the points held now (stale tab safe).
M.log = {}
M.broadcasts = {}
local reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
check(reply.accepted and M.partyInspiration == 3 and reply.message:find("set to 4"), "+ from the tab: asked 4")
M.runTimers()
check(M.partyInspiration == 4 and logText():find("Inspiration points now 4") and not logText():find("The game kept")
    and #M.messages() == 0, "+ from the tab: 3 -> 4, confirmed half a second later, no false 'kept'")
M.partyInspiration = 6.0 -- the game awarded two meanwhile; the tab still shows 4
reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.runTimers()
check(M.partyInspiration == 7, "a step counts from the points held now (6 -> 7), not from the tab's 4")
reply = PP.Net.InspirationPoints.requestHandler({ step = -1 }, M.hostPeer)
M.runTimers()
check(M.partyInspiration == 6, "- : 7 -> 6")
-- Capped at the setting going up; down is always allowed.
M.partyInspiration = 8.0
reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
check(not reply.accepted and reply.message:find("limit is 8") and M.partyInspiration == 8, "+ at the limit refused")
settings.inspiration_limit = 4
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 4 })
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 8, "setting 4 while holding 8: limit kept at 8")
reply = PP.Net.InspirationPoints.requestHandler({ step = -1 }, M.hostPeer)
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 8, "the limit is not lowered before the change lands")
M.runTimers()
check(reply.accepted and M.partyInspiration == 7 and M.staticData[PP.INSPIRATION_UUID].MaxValue == 7,
    "- above the setting: 8 -> 7 and the limit follows the points down")
local r = nil
PP.Net.Roster:RequestToServer({}, function(x) r = x end)
check(r and r.inspiration and r.inspiration.controls and r.inspiration.points == 7 and r.inspiration.limit == 4,
    "roster reply carries points 7 and the setting's limit 4")
-- The console: a number; whole numbers only; never below 0.
M.log = {}
M.console["pp_inspiration_points"]("pp_inspiration_points", "2")
M.runTimers()
check(M.partyInspiration == 2 and logText():find("Inspiration points 7 %-> 2 asked")
    and logText():find("Inspiration points now 2"), "console sets 2")
for _, bad in ipairs({ "5.5", "abc" }) do
    M.console["pp_inspiration_points"]("pp_inspiration_points", bad)
    check(M.partyInspiration == 2, "console rejects " .. bad)
end
local okNeg = Insp.ChangePoints({ target = -1 })
check(not okNeg and M.partyInspiration == 2, "below 0 refused")
M.console["pp_inspiration_points"]("pp_inspiration_points", "6")
check(M.partyInspiration == 2, "console above the setting (4) refused")
-- Raising first makes room: bank 4, setting 8, points 4, the game caps at the bank's MaxValue.
settings.inspiration_limit = 8
M.partyInspiration = 4.0
M.staticData[PP.INSPIRATION_UUID].MaxValue = 4.0
M.capAtLimit = true
reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.runTimers()
check(reply.accepted and M.partyInspiration == 5, "the limit is raised before the increase, so the game keeps 5")
M.capAtLimit = false
-- The game keeps another number: said at once, and only once.
M.keepPoints = 5.0
M.log = {}
M.broadcasts = {}
reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.runTimers()
check(#M.messages() == 1 and M.messages()[1]:find("The game kept 5")
    and select(2, logText():gsub("The game kept", "")) == 1,
    "the game kept another number: one message window and one log line")
-- Two quick clicks: only the last is checked.
M.keepPoints = nil
M.partyInspiration = 5.0
M.broadcasts = {}
M.log = {}
PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.runTimers()
check(#M.messages() == 0 and select(2, logText():gsub("Inspiration points now", "")) == 1,
    "two quick clicks: one check, no false message")
-- A level loads before the check runs (its timer is lost): the next request counts from the points held.
M.partyInspiration = 3.0
PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.timers = {}
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
M.log = {}
PP.Net.InspirationPoints.requestHandler({ step = 1 }, M.hostPeer)
M.runTimers()
check(M.partyInspiration == 4 and logText():find("Inspiration points 3 %-> 4 asked"),
    "after a level load the pending change is forgotten: 3 -> 4")
M.keepPoints = nil
-- The definition cannot be read: refused, nothing changed.
local savedDef = M.staticData[PP.INSPIRATION_UUID]
M.staticData[PP.INSPIRATION_UUID] = nil
local before = #M.pointChanges
reply = PP.Net.InspirationPoints.requestHandler({ step = -1 }, M.hostPeer)
check(not reply.accepted and #M.pointChanges == before, "no definition: refused")
M.staticData[PP.INSPIRATION_UUID] = savedDef
-- Load: bank 8, setting 4, points 2 -> held open while loading, 4 at the level start.
settings.inspiration_limit = 4
M.partyInspiration = 2.0
M.staticData[PP.INSPIRATION_UUID].MaxValue = 8.0
M.events["SessionLoading"]()
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 30, "loading: held open")
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 4, "level start with 2 points and setting 4: limit 4")
-- Points cannot be read (no host): the limit is not lowered.
M.staticData[PP.INSPIRATION_UUID].MaxValue = 9.0
local savedHost = Osi.GetHostCharacter
Osi.GetHostCharacter = function() return nil end
Insp.Apply("setting")
Osi.GetHostCharacter = savedHost
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 9, "points unreadable: the limit is not lowered")
-- Non-host refused.
reply = PP.Net.InspirationPoints.requestHandler({ step = 1 }, 999999)
check(not reply.accepted and reply.message:find("Only the host"), "non-host refused")
local changesSoFar = #M.pointChanges
settings.inspiration_point_controls = false
M.fire("LevelGameplayStarted", 2, "after", "WLD_Main_A", 0)
M.runTimers()
check(#M.pointChanges == changesSoFar, "other paths still never change points")
settings.inspiration_limit = 4
M.partyInspiration = 0.0

-- 30. "Match the party limit" holds the Inspiration slider at the party limit (reported in game 2026-10-27:
-- the slider stayed where it was, and could be moved above the party limit).
M.runTimers()
local savedSize = settings.max_party_size
settings.max_party_size = 9
settings.inspiration_limit = 5
settings.inspiration_match_party = true
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_match_party", value = true })
check(settings.inspiration_limit == 9, "ticking Match moves the slider to the party limit")
check(mcmSets[#mcmSets].id == "inspiration_limit" and mcmSets[#mcmSets].emit == nil,
    "written without an MCM_Setting_Saved event (no loop)")
local setsBefore = #mcmSets
for _, v in ipairs({ 10, 12, 15 }) do
    settings.inspiration_limit = v
    M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = v })
end
check(settings.inspiration_limit == 15 and #mcmSets == setsBefore, "not moved back during the drag")
M.runTimers()
check(settings.inspiration_limit == 9 and #mcmSets == setsBefore + 1, "moved back once, after the drag")
settings.max_party_size = 12
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "max_party_size", value = 12 })
M.runTimers()
check(settings.inspiration_limit == 12, "the slider follows the party limit")
check(M.staticData[PP.INSPIRATION_UUID].MaxValue == 12, "and the limit in use is the party limit")
settings.inspiration_limit = 4
M.mcmEvent("MCM_Profile_Activated", {})
M.runTimers()
check(settings.inspiration_limit == 12, "a profile switch moves it too")
setsBefore = #mcmSets
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_match_party", value = true })
check(#mcmSets == setsBefore, "already in place: nothing written")
-- Unticked: the slider is the player's again.
settings.inspiration_match_party = false
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_match_party", value = false })
settings.inspiration_limit = 20
M.mcmEvent("MCM_Setting_Saved", { modUUID = ModuleUUID, settingId = "inspiration_limit", value = 20 })
M.runTimers()
check(settings.inspiration_limit == 20 and M.staticData[PP.INSPIRATION_UUID].MaxValue == 20,
    "unticked: the slider stays where it is put and sets the limit")
-- A refused write changes nothing and raises nothing.
settings.inspiration_match_party = true
mcmSetFails = true
local okSync, wrote = pcall(Insp.SyncSlider)
check(okSync and wrote == false and settings.inspiration_limit == 20, "refused write: reported false, no error")
mcmSetFails = false
settings.inspiration_match_party = false
settings.max_party_size = savedSize
settings.inspiration_limit = 4
M.runTimers()

-- 31. Halsin's recruit gate and !pp_halsin (reported in game 2026-10-27; docs/PLAN_halsin_recruit_gate.md).
-- The story keeps him in camp before he is recruitable; an earlier Party Picker added him from there.
local NULLU = "00000000-0000-0000-0000-000000000000"
local RECRUITABLE = "GLO_LiftingTheCurse_State_HalsinRecruitable_2c8b6be0-558d-485c-b4f2-93ec1926a2fa"
local function globalFlag(f) return M.flags[f .. "|" .. NULLU] == true end
local function setGlobal(f, on) M.flags[f .. "|" .. NULLU] = on or nil end
local halsin = M.addChar("S_GLO_Halsin", "7628bc0e-52b8-42a7-856a-13a6fd413323")
M.db("DB_PartOfTheTeam")(halsin.id)
M.db("DB_InCamp")(halsin.id)
M.db("DB_OriginNPCAlignment")(halsin.id, "GLO_Halsin_01ebccd1-8a58-4ca6-9726-c4bb484b85f2")
M.db("DB_GLO_PartyMembers_OriginalAlignment")(halsin.id, "GLO_Halsin_01ebccd1-8a58-4ca6-9726-c4bb484b85f2")
M.db("DB_GLO_PartyMembers_DefaultFaction")(halsin.id, "PlayerFaction")
local savedMax = settings.max_party_size
settings.max_party_size = 12
local function halsinEntry()
    for _, e in ipairs(Party.Roster()) do if e.uuid == halsin.uuid then return e end end
end
local function activeUuids()
    local out = {}
    for _, e in ipairs(Party.Roster()) do if e.active then out[#out + 1] = e.uuid end end
    return out
end
local e31 = halsinEntry()
check(e31 and e31.locked and e31.lockReason:find("not recruitable yet"), "Halsin in camp before he is recruitable: locked")
local wanted = activeUuids()
wanted[#wanted + 1] = halsin.uuid
local r31 = apply({ uuids = wanted })
check(r31 and not r31.accepted and r31.message:find("cannot join"), "Apply refuses him with the reason")
check(#M.db("DB_Players"):Get(halsin.id) == 0, "he stays in camp")
-- A Minthara-style block (DB_GLO_PartyMembers_BlockRecruitmentDialog) locks the same way.
M.db("DB_GLO_PartyMembers_BlockRecruitmentDialog")(c.Wyll.id)
local wyll31
for _, e in ipairs(Party.Roster()) do if e.uuid == c.Wyll.uuid then wyll31 = e end end
check(not wyll31.active and wyll31.locked and wyll31.lockReason:find("not recruitable yet"),
    "a companion the story blocks from recruitment is locked while in camp")
M.db("DB_GLO_PartyMembers_BlockRecruitmentDialog"):Delete(c.Wyll.id)
-- Recruitable: he can join, and once in the party he can be sent back.
-- A failed flag read locks him (and is logged once).
local realGetFlag = Osi.GetFlag
Osi.GetFlag = function(f, o)
    if f == RECRUITABLE then error("no such flag") end
    return realGetFlag(f, o)
end
M.log = {}
check(halsinEntry().locked and logText():find("could not read Halsin's recruitable flag"), "failed flag read: locked, logged")
Osi.GetFlag = realGetFlag
setGlobal(RECRUITABLE, true)
check(not halsinEntry().locked, "recruitable: not locked")
r31 = apply({ uuids = wanted })
check(r31 and r31.accepted and #M.db("DB_Players"):Get(halsin.id) == 1, "recruitable: he joins")
setGlobal(RECRUITABLE, false)
check(not halsinEntry().locked, "in the party: never locked by the gate")
local without = {}
for _, u in ipairs(activeUuids()) do if u ~= halsin.uuid then without[#without + 1] = u end end
r31 = apply({ uuids = without })
check(r31 and r31.accepted and #M.db("DB_Players"):Get(halsin.id) == 0, "he can be sent to camp")
M.db("DB_GLO_PartyMembers_DefaultFaction")(halsin.id, "PlayerFaction") -- as a dismissal leaves it (L1313)

-- !pp_halsin: the story procedures it calls, as far as the plan uses them.
local calls31 = {}
local H31 = halsin.id
local function st(n) return "SCL_LiftingTheCurse_State_" .. n end
Osi.PROC_State_Progress = function(ch, quest, s)
    calls31[#calls31 + 1] = "progress " .. s
    M.db("DB_State_Current"):Delete(ch, quest, nil)
    M.db("DB_State_Current")(ch, quest, s)
end
Osi.PROC_RemoveDialog = function(ch) calls31[#calls31 + 1] = "removedialog"; M.db("DB_Dialogs"):Delete(ch, nil) end
Osi.SetHasDialog = function() calls31[#calls31 + 1] = "hasdialog" end
Osi.PROC_GlobalClearFlagAndCache = function(f) calls31[#calls31 + 1] = "clear " .. f; setGlobal(f, false) end
Osi.PROC_GlobalSetFlagAndCache = function(f) calls31[#calls31 + 1] = "set " .. f; setGlobal(f, true) end
Osi.PROC_GlobalFlagReactionAfterDialog = function(f)
    calls31[#calls31 + 1] = "reaction " .. f
    Osi.PROC_State_Progress(H31, "SCL_LiftingTheCurse", st("HalsinAtHaven")) -- Act2_CAMP_LiftingTheCurse.txt L56-63
end
local function halsinConsole(arg)
    M.log = {}
    M.console["pp_halsin"]("pp_halsin", arg)
    return logText()
end
-- The author's save: recruited early (flag + first-recruit record set), state never moved on.
setGlobal(RECRUITABLE, true)
M.db("DB_OnlyOnce")("RecruitedFirstTime_Halsin")
M.db("DB_State_Current")(H31, "SCL_LiftingTheCurse", st("HalsinInAct2"))
M.db("DB_Dialogs")(H31, "Halsin_InParty_890c2586-6b71-ca01-5bd6-19d533181c71")
M.db("DB_Players")(H31) -- in the party, as in the author's game
local rep = halsinConsole()
check(rep:find("state: SCL_LiftingTheCurse_State_HalsinInAct2") and rep:find("in party yes")
    and rep:find("recruitable yes") and rep:find("Halsin_InParty"), "report shows state, party, flags and dialog")
check(#calls31 == 0, "the report changes nothing")
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("level SCL_Main_A"), "repair refused outside Act 2")
M.db("DB_CurrentLevel")("SCL_Main_A")
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("Send him to camp"), "repair refused while he is in the party")
M.db("DB_Players"):Delete(H31)
M.db("DB_KnockedOut")(H31)
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("knocked out") and globalFlag(RECRUITABLE), "repair refused while knocked out")
M.db("DB_KnockedOut"):Delete(H31)
halsin.dead = true
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("is dead"), "repair refused while dead")
halsin.dead = nil
setGlobal("SCL_AncientFist_State_HasWokenUpFist_45cddb53-edf5-4a9e-9943-898f55b29af3", true)
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("already awake"), "repair refused once Art is awake")
setGlobal("SCL_AncientFist_State_HasWokenUpFist_45cddb53-edf5-4a9e-9943-898f55b29af3", false)
check(#calls31 == 0, "refusals change nothing")
rep = halsinConsole("haven")
check(rep:find("repair first") and #calls31 == 0, "haven refused before repair")
rep = halsinConsole("repair")
check(rep:find("done%."), "repair runs")
check(not globalFlag(RECRUITABLE), "recruitable flag cleared")
check(#M.db("DB_OnlyOnce"):Get("RecruitedFirstTime_Halsin") == 0, "first-recruit record cleared")
local dlg = M.db("DB_Dialogs"):Get(H31, nil)
check(#dlg == 1 and dlg[1][2]:find("^CAMP_Halsin2_c0ab0f6f"), "his Act 2 camp dialog is set")
check(not table.concat(calls31, ","):find("progress"), "state already InAct2: not moved")
check(halsinEntry().locked, "after the repair the Party tab locks him again")
rep = halsinConsole("repair")
check(rep:find("not repaired") and rep:find("nothing to undo"), "a second repair is refused")
-- From HalsinWaiting the repair first moves him to HalsinInAct2.
calls31 = {}
setGlobal(RECRUITABLE, true)
M.db("DB_State_Current"):Delete(H31, "SCL_LiftingTheCurse", nil)
M.db("DB_State_Current")(H31, "SCL_LiftingTheCurse", st("HalsinWaiting"))
rep = halsinConsole("repair")
check(calls31[1] == "progress " .. st("HalsinInAct2") and rep:find("done%.") and not globalFlag(RECRUITABLE),
    "from HalsinWaiting: moved to HalsinInAct2 first, then repaired")
-- A state move the game ignores stops the repair before anything else changes.
local realProgress = Osi.PROC_State_Progress
Osi.PROC_State_Progress = function() calls31[#calls31 + 1] = "progress ignored" end
setGlobal(RECRUITABLE, true)
M.db("DB_State_Current"):Delete(H31, "SCL_LiftingTheCurse", nil)
M.db("DB_State_Current")(H31, "SCL_LiftingTheCurse", st("HalsinWaiting"))
calls31 = {}
rep = halsinConsole("repair")
check(rep:find("did not move his state") and #calls31 == 1 and globalFlag(RECRUITABLE), "ignored state move: stops, nothing else changed")
Osi.PROC_State_Progress = realProgress
halsinConsole("repair")
-- Fallback: the reaction the camp conversation would trigger.
calls31 = {}
rep = halsinConsole("haven")
check(rep:find("on his way") and calls31[1]:find("^set GLO_LiftingTheCurse_Event_TravelToHaven")
    and calls31[2]:find("^reaction GLO_LiftingTheCurse_Event_TravelToHaven"), "haven sets the flag and runs the reaction")
check(M.db("DB_State_Current"):Get(H31, "SCL_LiftingTheCurse", nil)[1][3] == st("HalsinAtHaven"), "he is now at Last Light")
calls31 = {}
rep = halsinConsole("haven")
check(rep:find("already been sent") and #calls31 == 0, "haven runs once")
rep = halsinConsole("nonsense")
check(rep:find("usage"), "unknown argument: usage")
-- Clean up: Halsin leaves the test world.
for _, db in ipairs({ "DB_PartOfTheTeam", "DB_InCamp", "DB_Players", "DB_PartyMembers" }) do M.db(db):Delete(H31) end
M.db("DB_GLO_PartyMembers_DefaultFaction"):Delete(H31, nil)
M.db("DB_CurrentLevel"):Delete("SCL_Main_A")
M.db("DB_State_Current"):Delete(H31, nil, nil)
M.db("DB_Dialogs"):Delete(H31, nil)
M.db("DB_OnlyOnce"):Delete("RecruitedFirstTime_Halsin")
setGlobal(RECRUITABLE, false)
setGlobal("GLO_LiftingTheCurse_Event_TravelToHaven_a946f0b8-badb-435d-915d-2e6a45845c7c", false)
Osi.PROC_State_Progress, Osi.PROC_RemoveDialog, Osi.SetHasDialog = nil, nil, nil
Osi.PROC_GlobalClearFlagAndCache, Osi.PROC_GlobalSetFlagAndCache, Osi.PROC_GlobalFlagReactionAfterDialog = nil, nil, nil
M.chars[halsin.uuid] = nil
settings.max_party_size = savedMax
M.runTimers()

-- 32. "Let Halsin join early" and the Party tab's "Put Halsin's quest back on track"
-- (asked for by the author 2026-10-28; docs/PLAN_halsin_early_option.md).
local ENTERED = "HAV_PartyProgress_EnteredHaven_0afbb64d-f996-4e41-ab6b-a51d37c29fd3"
local ARTAWAKE = "SCL_AncientFist_State_HasWokenUpFist_45cddb53-edf5-4a9e-9943-898f55b29af3"
halsin = M.addChar("S_GLO_Halsin", "7628bc0e-52b8-42a7-856a-13a6fd413323")
local H32 = halsin.id
M.db("DB_PartOfTheTeam")(H32)
M.db("DB_InCamp")(H32)
M.db("DB_OriginNPCAlignment")(H32, "GLO_Halsin_01ebccd1-8a58-4ca6-9726-c4bb484b85f2")
M.db("DB_GLO_PartyMembers_OriginalAlignment")(H32, "GLO_Halsin_01ebccd1-8a58-4ca6-9726-c4bb484b85f2")
M.db("DB_GLO_PartyMembers_DefaultFaction")(H32, "PlayerFaction")
M.db("DB_CurrentLevel")("SCL_Main_A")
M.db("DB_State_Current")(H32, "SCL_LiftingTheCurse", st("HalsinInAct2"))
M.db("DB_Dialogs")(H32, "CAMP_Halsin2_c0ab0f6f-3ffc-d06d-0d6d-d1aaef70dfe4")
settings.max_party_size = 12
Ext.Vars.GetModVariables(ModuleUUID).Halsin = nil
calls31 = {}
H31 = H32
Osi.PROC_State_Progress = function(ch, quest, s)
    calls31[#calls31 + 1] = "progress " .. s
    M.db("DB_State_Current"):Delete(ch, quest, nil)
    M.db("DB_State_Current")(ch, quest, s)
end
Osi.PROC_RemoveDialog = function(ch) calls31[#calls31 + 1] = "removedialog"; M.db("DB_Dialogs"):Delete(ch, nil) end
Osi.SetHasDialog = function() end
Osi.PROC_GlobalClearFlagAndCache = function(f) calls31[#calls31 + 1] = "clear " .. f; setGlobal(f, false) end
-- The game's first-recruit block, as GLO_Companion_Halsin.txt L41-47 (the mock's add does not run it).
local function firstRecruit()
    if #M.db("DB_OnlyOnce"):Get("RecruitedFirstTime_Halsin") == 0 then
        M.db("DB_OnlyOnce")("RecruitedFirstTime_Halsin")
        setGlobal(RECRUITABLE, true)
    end
end
local function roster32() return PP.Net.Roster.requestHandler({}, M.hostPeer) end
local function tabReset() return PP.Net.HalsinReset.requestHandler({}, M.hostPeer) end
local function withHalsin()
    local w = activeUuids()
    w[#w + 1] = halsin.uuid
    return w
end

-- Default: locked, as 1.0.8.
check(halsinEntry().locked and halsinEntry().lockReason == Party.NOT_YET, "default: Halsin locked until recruitable")
check(roster32().halsin == nil, "default: no Halsin section on the Party tab")
-- Reaching Last Light with no early join: no message.
M.broadcasts = {}
M.fire("FlagSet", 3, "after", ENTERED, "NULL_00000000-0000-0000-0000-000000000000", 0)
setGlobal(ENTERED, true)
M.runTimers()
check(#M.messages() == 0, "Last Light without an early join: no message")
setGlobal(ENTERED, false)
-- The setting unlocks him in Act 2 before his quest reaches Last Light.
settings.halsin_early = true
check(not halsinEntry().locked, "join early on: not locked in Act 2 (HalsinInAct2)")
-- ... but never on a failed flag read.
Osi.GetFlag = function(f, o)
    if f == RECRUITABLE then error("no such flag") end
    return realGetFlag(f, o)
end
check(halsinEntry().locked, "join early on, flag unreadable: still locked")
Osi.GetFlag = realGetFlag
-- ... nor outside Act 2, once Art is awake, or once his quest has reached Last Light.
M.db("DB_CurrentLevel"):Delete("SCL_Main_A")
check(halsinEntry().locked and halsinEntry().lockReason:find("Act Two only"), "join early: locked outside Act 2")
M.db("DB_CurrentLevel")("SCL_Main_A")
setGlobal(ARTAWAKE, true)
check(halsinEntry().locked and halsinEntry().lockReason:find("under way"), "join early: locked once Art is awake")
setGlobal(ARTAWAKE, false)
local GOTOLAKE = "HAV_LiftingTheCurse_State_HalsinGoToLake_bc4cd1f7-5e60-40e1-a583-aa886fe5b682"
setGlobal(GOTOLAKE, true)
check(halsinEntry().locked and halsinEntry().lockReason:find("under way"), "join early: locked once he heads to the lake")
setGlobal(GOTOLAKE, false)
M.db("DB_State_Current"):Delete(H32, "SCL_LiftingTheCurse", nil)
M.db("DB_State_Current")(H32, "SCL_LiftingTheCurse", st("HalsinAtHaven"))
check(halsinEntry().locked and halsinEntry().lockReason:find("under way"), "join early: locked once his quest is at Last Light")
M.db("DB_State_Current"):Delete(H32, "SCL_LiftingTheCurse", nil)
M.db("DB_State_Current")(H32, "SCL_LiftingTheCurse", st("HalsinInAct2"))
-- He joins.
local r32 = apply({ uuids = withHalsin() })
check(r32 and r32.accepted and #M.db("DB_Players"):Get(H32) == 1, "join early: he joins")
firstRecruit()
M.db("DB_Dialogs"):Delete(H32, nil)
M.db("DB_Dialogs")(H32, "Halsin_InParty_890c2586-6b71-ca01-5bd6-19d533181c71")
-- Before Last Light the tab shows the section, button disabled.
local info = roster32().halsin
check(info and info.inParty and info.why and info.why:find("reached Last Light"), "tab: section shown, waits for Last Light")
local before = #calls31
local rr = tabReset()
check(rr and not rr.accepted and rr.message:find("not reached Last Light") and #calls31 == before
    and #M.db("DB_Players"):Get(H32) == 1, "reset before Last Light: refused, nothing changed")
-- Reaching Last Light: the one-time notice.
M.broadcasts = {}
M.fire("FlagSet", 3, "after", ENTERED, "NULL_00000000-0000-0000-0000-000000000000", 0)
setGlobal(ENTERED, true)
M.runTimers()
local msgs = M.messages()
check(#msgs == 1 and msgs[1]:find("Put Halsin's quest back on track"), "reaching Last Light: a message says what to do")
M.broadcasts = {}
M.fire("FlagSet", 3, "after", "SOME_OtherFlag_11111111-1111-1111-1111-111111111111", "NULL_00000000-0000-0000-0000-000000000000", 0)
M.runTimers()
check(#M.messages() == 0, "another flag: no message")
info = roster32().halsin
check(info and info.why == nil, "tab: button enabled at Last Light")
-- While the host controls Halsin, the tab cannot send him to camp: disabled, with the reason.
M.controlled = halsin
info = roster32().halsin
check(info and info.why and info.why:find("Switch to another character"), "controlling Halsin: button disabled, reason given")
before = #calls31
rr = tabReset()
check(rr and not rr.accepted and rr.message:find("Switch to another character") and #calls31 == before
    and #M.db("DB_Players"):Get(H32) == 1, "controlling Halsin: reset refused, nothing changed")
M.controlled = nil
-- Only the host.
M.hostPeer = 131072
rr = tabReset()
check(rr and not rr.accepted and rr.message:find("host") and globalFlag(RECRUITABLE), "another player: refused")
M.hostPeer = 65536
-- The reset from the tab while he is in the party: sent to camp, then repaired.
M.broadcasts = {}
rr = tabReset()
check(rr and rr.accepted and rr.message:find("Sending Halsin to camp"), "reset: accepted, sending him to camp")
M.runTimers()
check(#M.db("DB_Players"):Get(H32) == 0, "reset: he left the party")
check(not globalFlag(RECRUITABLE) and #M.db("DB_OnlyOnce"):Get("RecruitedFirstTime_Halsin") == 0, "reset: flag and first-recruit record cleared")
local dlg32 = M.db("DB_Dialogs"):Get(H32, nil)
check(#dlg32 == 1 and dlg32[1][2]:find("^CAMP_Halsin2_c0ab0f6f"), "reset: camp dialog set")
msgs = M.messages()
check(#msgs == 1 and msgs[1]:find("back on track"), "reset: the outcome in a message window")
check(Ext.Vars.GetModVariables(ModuleUUID).Halsin.reset == true, "reset: recorded")
-- After the reset, join early no longer unlocks him; the section is gone.
check(halsinEntry().locked and halsinEntry().lockReason:find("under way"), "after the reset: locked even with join early on")
check(roster32().halsin == nil, "after the reset: no Halsin section")
rr = tabReset()
check(rr and not rr.accepted and rr.message:find("nothing to undo"), "a second reset is refused")
-- Thaniel saved: the story makes him recruitable and the lock goes.
setGlobal(RECRUITABLE, true)
check(not halsinEntry().locked, "recruitable after Thaniel: not locked")
-- The reset while he is already in camp runs at once (record cleared to test it from the start).
setGlobal(RECRUITABLE, false)
Ext.Vars.GetModVariables(ModuleUUID).Halsin = nil
r32 = apply({ uuids = withHalsin() })
firstRecruit()
r32 = apply({ uuids = (function()
    local w = {}
    for _, u in ipairs(activeUuids()) do if u ~= halsin.uuid then w[#w + 1] = u end end
    return w
end)() })
M.runTimers()
M.db("DB_GLO_PartyMembers_DefaultFaction")(H32, "PlayerFaction")
-- ... from HalsinWaiting, moved to HalsinInAct2 first, as the console repair does.
M.db("DB_State_Current"):Delete(H32, "SCL_LiftingTheCurse", nil)
M.db("DB_State_Current")(H32, "SCL_LiftingTheCurse", st("HalsinWaiting"))
M.broadcasts = {}
calls31 = {}
rr = tabReset()
check(rr and rr.accepted and rr.message:find("back on track") and not globalFlag(RECRUITABLE), "reset in camp: done at once")
check(calls31[1] == "progress " .. st("HalsinInAct2"), "reset from HalsinWaiting: moved to HalsinInAct2 first")
-- The console repair writes the same record.
Ext.Vars.GetModVariables(ModuleUUID).Halsin = nil
setGlobal(RECRUITABLE, true)
halsinConsole("repair")
check(Ext.Vars.GetModVariables(ModuleUUID).Halsin.reset == true, "console repair: recorded too")
-- Join early off again: plain 1.0.8 lock.
settings.halsin_early = nil
Ext.Vars.GetModVariables(ModuleUUID).Halsin = nil
check(halsinEntry().locked and halsinEntry().lockReason == Party.NOT_YET, "join early off: locked as before")
-- Clean up.
for _, db in ipairs({ "DB_PartOfTheTeam", "DB_InCamp", "DB_Players", "DB_PartyMembers" }) do M.db(db):Delete(H32) end
M.db("DB_GLO_PartyMembers_DefaultFaction"):Delete(H32, nil)
M.db("DB_CurrentLevel"):Delete("SCL_Main_A")
M.db("DB_State_Current"):Delete(H32, nil, nil)
M.db("DB_Dialogs"):Delete(H32, nil)
M.db("DB_OnlyOnce"):Delete("RecruitedFirstTime_Halsin")
setGlobal(RECRUITABLE, false)
setGlobal(ENTERED, false)
Osi.PROC_State_Progress, Osi.PROC_RemoveDialog, Osi.SetHasDialog, Osi.PROC_GlobalClearFlagAndCache = nil, nil, nil, nil
M.chars[halsin.uuid] = nil
settings.max_party_size = savedMax
M.runTimers()

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
