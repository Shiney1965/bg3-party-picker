-- Party Picker (server): tell the clients to redraw the Party tab when the game changes someone on it
-- (docs/PLAN_1.1.2_live_roster.md). Nothing runs between events: each listener below is one of the
-- game's own one-off events, and for anyone not on the tab it costs a lookup or two.

local RosterWatch = {}

-- Bare uuids of the last roster sent to a client. An "after" listener runs after the story's own rules
-- for the event, and a permadeath mod may already have taken the character out of the party and the
-- team by then (Companion Permadeath, ZZZ_Permadeath.txt L60-67), so the party tables alone can miss them.
local listed = {}

function RosterWatch.Listed(entries)
    local set = {}
    for _, e in ipairs(entries or {}) do
        if e.uuid then set[e.uuid] = true end
    end
    listed = set
end

local function inDb(dbName, id)
    local ok, rows = pcall(function() return Osi[dbName]:Get(id) end)
    return ok and type(rows) == "table" and next(rows) ~= nil
end

local function counts(id)
    local u = PP.BareUuid(id)
    if not u then return false end
    if listed[u] then return true end
    return inDb("DB_Players", id) or inDb("DB_PartOfTheTeam", id)
end

-- One message for a burst of events (a combat with several deaths). 1500 ms because the story marks a
-- member downed only after its own 500 ms check (__AAA_FirstGoal.txt L1187-1203), and the redraw must
-- come after that. Real time, so a paused game still redraws.
local seq = 0
local function changed()
    seq = seq + 1
    local mySeq = seq
    Ext.Timer.WaitForRealtime(1500, function()
        if mySeq ~= seq then return end
        pcall(function() PP.Net.RosterChanged:Broadcast({}) end)
    end)
end

-- always: redraw whoever it is (a change of control can move away from someone on the tab to someone who is
-- not, e.g. a summon; a first recruit may not be in the party tables yet when the event runs).
local function watch(event, arity, always)
    local ok, err = pcall(function()
        Ext.Osiris.RegisterListener(event, arity, "after", function(id)
            if always then changed() return end
            local okC, yes = pcall(counts, id)
            if okC and yes then changed() end
        end)
    end)
    if not ok then PP.Log("could not watch " .. event .. " (the Party tab will not follow it): " .. tostring(err)) end
end

-- story_header.div: Died L312, Resurrected L313, DownedChanged L391, LeftCombat L1201 (a redraw during a
-- fight shows everyone "in combat"; this one puts the tab right when the fight ends). 1.1.3
-- (docs/PLAN_1.1.3_dead_member_notice.md, unit F): CharacterJoinedParty L369 and CharacterLeftParty L370
-- (recruiting and dismissing in the game's own conversations), GainedControl L380 (the "you are controlling
-- them" lock follows), MoveCapabilityChanged L386 (the engine holds a member for a moment after they get up).
function RosterWatch.Register()
    watch("Died", 1)
    watch("Resurrected", 1)
    watch("DownedChanged", 2)
    watch("LeftCombat", 2)
    watch("CharacterJoinedParty", 1, true)
    watch("CharacterLeftParty", 1)
    watch("GainedControl", 1, true)
    watch("MoveCapabilityChanged", 2)
end

return RosterWatch
