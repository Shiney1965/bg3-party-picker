-- A small fake of the parts of Script Extender and Osiris that Party Picker
-- touches, so the server logic can run outside the game.
-- It models the story procedures only as far as docs/RESEARCH.md documents
-- them; passing here does not prove the mod works in game (see TESTING.md).

local M = {}

M.LUA_ROOT = LUA_ROOT -- set by the runner
M.log = {}
M.timers = {}
M.longTimers = {}
M.listeners = {}
M.broadcasts = {}
M.console = {}
M.mcmSubscribers = {}
M.events = {}

local function uuidOf(id) return string.sub(id, -36) end

-- Osiris databases ---------------------------------------------------------
local dbs = {}
local function newDb(name)
    local db = { name = name, rows = {} }
    -- A story table has a fixed column count; asking with another count is
    -- an error in the game, so it is one here (known once a row was added).
    function db:Get(...)
        local n = select("#", ...)
        if self.arity and n ~= self.arity then
            error(name .. " has " .. self.arity .. " column(s), asked with " .. n)
        end
        local filter = { ... }
        local out = {}
        for _, row in ipairs(self.rows) do
            local match = true
            for i = 1, select("#", ...) do
                if filter[i] ~= nil and uuidOf(tostring(filter[i])) ~= uuidOf(tostring(row[i])) then
                    match = false
                end
            end
            if match then out[#out + 1] = row end
        end
        return out
    end
    function db:Delete(...)
        local filter = { ... }
        local keep = {}
        for _, row in ipairs(self.rows) do
            local match = true
            for i = 1, select("#", ...) do
                if filter[i] ~= nil and uuidOf(tostring(filter[i])) ~= uuidOf(tostring(row[i])) then
                    match = false
                end
            end
            if not match then keep[#keep + 1] = row end
        end
        self.rows = keep
    end
    setmetatable(db, {
        __call = function(self, ...)
            local row = { ... }
            self.arity = self.arity or select("#", ...)
            if #self:Get(...) == 0 then
                self.rows[#self.rows + 1] = row
                -- Script Extender calls a story table's "after" listener on each insert.
                local fn = M.listeners[name .. "/" .. self.arity .. "/after"]
                if fn then fn(...) end
            end
        end,
    })
    return db
end

function M.db(name)
    if not dbs[name] then dbs[name] = newDb(name) end
    return dbs[name]
end

-- World state --------------------------------------------------------------
M.chars = {}   -- uuid -> { id, name, user, summon, dead, inCombat }
M.maxOverride = nil
M.readyCheckBlocked = {}
M.teleported = {}

function M.addChar(name, uuid, opts)
    opts = opts or {}
    local c = { id = name .. "_" .. uuid, uuid = uuid, name = name, user = opts.user or 65537,
        summon = opts.summon, dead = opts.dead, inCombat = opts.inCombat, follower = opts.follower,
        entitySummon = opts.entitySummon, entityFollower = opts.entityFollower }
    M.chars[uuid] = c
    return c
end

local function char(id) return M.chars[uuidOf(id)] end

local function playerCount()
    local n = 0
    for _, row in ipairs(M.db("DB_Players").rows) do
        if not (char(row[1]) or {}).summon then n = n + 1 end
    end
    return n
end

local Osi = {}
M.Osi = Osi

-- The character the host controls; may be a companion (M.controlled).
function Osi.GetHostCharacter() return (M.controlled or M.host).id end
function Osi.GetReservedUserID(id) return (char(id) or {}).user end
-- `summon` = the game's IsSummon query says so; `entitySummon` = only the
-- entity's IsSummon component says so (the case seen in game 2026-10-11).
function Osi.IsSummon(id) return (char(id) or {}).summon and 1 or 0 end
function Osi.IsPartyFollower(id) return (char(id) or {}).follower and 1 or 0 end
function Osi.IsDead(id) return (char(id) or {}).dead and 1 or 0 end
function Osi.IsInCombat(id) return (char(id) or {}).inCombat and 1 or 0 end
function Osi.GetDisplayName(id) return "h_" .. uuidOf(id) end
function Osi.GetFaction(id) return (char(id) or {}).faction end
function Osi.GetMaxPartySize() return M.maxOverride or 4 end
function Osi.SetMaxPartySizeOverride(n) M.maxOverride = n end
function Osi.PROC_CheckPartyFull() M.partyFull = playerCount() >= Osi.GetMaxPartySize() end
function Osi.IsInPartyWith(a, b)
    local inP = function(x) return #M.db("DB_Players"):Get(x) > 0 end
    return (inP(a) and inP(b)) and 1 or 0
end
-- Script Extender matches Osiris functions by exact argument count; the
-- header has overloads with 5, 6 and 8 arguments (Osi.lua).
function Osi.TeleportTo(...)
    local n = select("#", ...)
    assert(n == 5 or n == 6 or n == 8, "TeleportTo has no overload with " .. n .. " arguments")
    M.teleported[#M.teleported + 1] = uuidOf((...))
end
M.flags = {}
function Osi.GetFlag(flag, obj) return M.flags[flag .. "|" .. uuidOf(obj)] and 1 or 0 end

-- Items and triggers (House of Hope). An item is { id, template, owner (bare uuid) }.
-- TemplateAddTo does not create the item at once: it queues it, and the test delivers it
-- with M.deliverItems(), which also fires TemplateAddedTo, as the engine reports it.
M.items = {}
M.queuedItems = {}
M.equipped = {}      -- bare uuid -> item id
M.inTrigger = {}     -- "trigger|uuid" -> true
local itemCount = 0
function M.addItem(template, ownerId, id)
    itemCount = itemCount + 1
    local item = { id = id or ("ITEM_" .. string.format("00000000-0000-0000-0000-%012d", 900 + itemCount)),
        template = template, owner = ownerId and uuidOf(ownerId) or nil }
    M.items[uuidOf(item.id)] = item
    return item
end
function Osi.GetTemplate(itemId)
    local item = M.items[uuidOf(itemId)]
    return item and item.template or nil
end
function Osi.GetInventoryOwner(itemId)
    local item = M.items[uuidOf(itemId)]
    if not item or not item.owner then return nil end
    return M.chars[item.owner] and M.chars[item.owner].id or nil
end
function Osi.GetItemByTemplateInInventory(template, ownerId)
    for _, item in pairs(M.items) do
        if item.owner == uuidOf(ownerId) and uuidOf(item.template) == uuidOf(template) then return item.id end
    end
    return nil
end
function Osi.TemplateAddTo(template, ownerId, count, notify)
    assert(count == 1 and notify == 0, "TemplateAddTo called as the game does: (template, holder, 1, 0)")
    M.queuedItems[#M.queuedItems + 1] = { template = template, owner = ownerId }
end
function M.deliverItems()
    local queue = M.queuedItems
    M.queuedItems = {}
    for _, q in ipairs(queue) do
        local item = M.addItem(q.template, q.owner)
        local fn = M.listeners["TemplateAddedTo/4/after"]
        if fn then fn(q.template, item.id, q.owner, "") end
    end
end
function Osi.Equip(charId, itemId, ...)
    local n = select("#", ...)
    assert(n == 0 or n == 3, "Equip has overloads with 2 and 5 arguments")
    M.equipped[uuidOf(charId)] = itemId
end
-- Static data: just the game's Inspiration definition (Shared ActionResourceDefinitions.lsx).
M.staticData = { ["a9c98304-08e7-44b5-aaf9-da2ef5a50672"] = { Name = "InspirationPoint", MaxValue = 4.0 } }
M.partyInspiration = 0
function Osi.PartyGetActionResourceValue(player, name)
    assert(name == "InspirationPoint", "unexpected resource " .. tostring(name))
    return M.partyInspiration
end
function Osi.GetActionResourceValuePersonal(player, name, level)
    assert(level == 0, "level argument")
    return M.partyInspiration
end
-- Inspiration points must never be changed by Party Picker: these fail the test if called.
-- Point changes are recorded; only Party Picker's explicit control (plan Part F) may make them, and the
-- tests check that no other path does. Osiris REALs come back as floats.
M.pointChanges = {}
M.capAtLimit = false     -- when true, the game caps the total at the Inspiration definition's MaxValue
M.keepPoints = nil       -- when a number, the game keeps that total whatever is asked
M.delayPoints = false    -- when true, the change lands on the next timer tick, as in the game (2026-10-27)
local function landPoints(delta)
    local total = M.partyInspiration + delta
    if M.capAtLimit then
        local max = M.staticData["a9c98304-08e7-44b5-aaf9-da2ef5a50672"].MaxValue
        if total > max then total = max end
    end
    if M.keepPoints then total = M.keepPoints end
    M.partyInspiration = total * 1.0
end
function Osi.PartyIncreaseActionResourceValue(player, name, delta)
    assert(name == "InspirationPoint", "unexpected resource " .. tostring(name))
    M.pointChanges[#M.pointChanges + 1] = delta
    if M.delayPoints then
        table.insert(M.timers, function() landPoints(delta) end)
    else
        landPoints(delta)
    end
end
function Osi.GiveInspirationPoints() error("GiveInspirationPoints called: Party Picker must never change points") end
function Osi.IsInTrigger(id, trigger)
    return M.inTrigger[uuidOf(trigger) .. "|" .. uuidOf(id)] and 1 or 0
end
M.counters = { Hirelings_InCamp_Count = 0 }
local IN_CAMP_FLAG = "Hireling_State_InCamp_e33aa0df-fcfc-4a30-8169-516d3956f02a"
local HIRED_FLAG = "Hireling_State_Hired_0052da16-4401-4873-8176-16336d8942da"
local function setFlag(flag, obj, on) M.flags[flag .. "|" .. uuidOf(obj)] = on or nil end
-- SharedDev Hirelings.txt L447-451, L670-675.
function Osi.PROC_Hirelings_SendToCamp(h)
    setFlag(HIRED_FLAG, h, false)
    setFlag(IN_CAMP_FLAG, h, true)
    M.counters.Hirelings_InCamp_Count = M.counters.Hirelings_InCamp_Count + 1
end
function Osi.PROC_Hirelings_TakeFromCamp(h, avatar)
    Osi.PROC_Hirelings_AddToParty(h, avatar)
    M.counters.Hirelings_InCamp_Count = M.counters.Hirelings_InCamp_Count - 1
end
function Osi.AttachToPartyGroup() end
function Osi.SetReadyCheckBlocked(id, v) M.readyCheckBlocked[uuidOf(id)] = v end

-- Story rules that react to table changes. Line numbers are from the game's
-- own story files (Shared/SharedDev goals), see docs/RESEARCH.md.
--
-- Off stage: WentOnStage(obj,0) adds DB_OffStage (__AAA_FirstGoal.txt
-- L1282-1285), which makes the object DB_CantMove (L2285-2291, L2325-2331).
-- A DB_Players member who is DB_CantMove gets the fast-travel block
-- (_Waypoints.txt L188-194); it is lifted when either stops being true
-- (L196-210).
function M.storyRules(id)
    local blocked = #M.db("DB_Players"):Get(id) > 0 and #M.db("DB_CantMove"):Get(id) > 0
    if blocked then
        M.db("DB_FastTravelBlock_CantMove_StatusSet")(id)
    else
        M.db("DB_FastTravelBlock_CantMove_StatusSet"):Delete(id)
    end
end

-- The game's own query (the story uses it: GLO_Camp.txt L1715, L2357).
function Osi.IsOnStage(id) return (char(id) or {}).offStage and 0 or 1 end

function M.setOnStage(ch, on)
    ch.offStage = not on or nil
    if on then
        M.db("DB_OffStage"):Delete(ch.id)
        M.db("DB_CantMove"):Delete(ch.id)
    else
        M.db("DB_OffStage")(ch.id)
        M.db("DB_CantMove")(ch.id)
    end
    M.storyRules(ch.id)
end

-- PROC_GLO_PartyMembers_CheckAdd only adds while the party-full flag is
-- clear (_GLO_Shared_PartyMembers.txt L477-482).
function Osi.PROC_GLO_PartyMembers_CheckAdd(origin, player)
    Osi.PROC_CheckPartyFull()
    if M.partyFull then return end
    Osi.PROC_GLO_PartyMembers_Add(origin, player)
end

-- The companion add rule runs once per DB_GLO_PartyMembers_DefaultFaction
-- row and does nothing without one (L501-528). It never puts the character
-- on stage. The hireling hook marks a hireling template as hired
-- (Hirelings.txt L502-513).
function Osi.PROC_GLO_PartyMembers_Add(origin, player)
    if #M.db("DB_DismissedAvatar"):Get(origin) > 0 then return end
    for _, row in ipairs(M.db("DB_GLO_PartyMembers_DefaultFaction"):Get(origin, nil)) do
        local ch = char(origin)
        if ch then ch.faction = row[2] end
        M.db("DB_Players")(origin)
        M.db("DB_PartyMembers")(origin)
        M.db("DB_PartOfTheTeam")(origin)
        M.db("DB_GLO_PartyMembers_DefaultFaction"):Delete(origin, row[2])
        M.db("DB_InCamp"):Delete(origin)
        Osi.PROC_CheckPartyFull()
        if #M.db("DB_Hirelings_HACK_Classes"):Get(nil, origin, nil) > 0 then
            M.db("DB_Hirelings_Hired")(origin)
            setFlag(IN_CAMP_FLAG, origin, false)
            setFlag(HIRED_FLAG, origin, true)
        end
        M.storyRules(origin)
    end
end

-- A hireling is given one of three factions no hired hireling is using
-- right now, as a DefaultFaction row, before the add (Hirelings.txt L453-500).
local HIRELING_FACTIONS = {
    "Hireling1_9459fd54-cdc5-458f-8aa0-fc6ea18c888f",
    "Hireling2_c98e5185-9ef4-4c5d-8789-ff889d22d27c",
    "Hireling3_3987f3d3-1d27-4c0d-b098-3b3b96a0b3e1",
}
function Osi.PROC_Hirelings_AddToParty(h, avatar)
    Osi.PROC_CheckPartyFull()
    for _, faction in ipairs(HIRELING_FACTIONS) do
        local inUse = false
        for _, row in ipairs(M.db("DB_Hirelings_Hired").rows) do
            if (char(row[1]) or {}).faction == faction then inUse = true end
        end
        if not inUse then
            M.db("DB_GLO_PartyMembers_DefaultFaction")(h, faction)
            break
        end
    end
    Osi.PROC_GLO_PartyMembers_CheckAdd(h, avatar)
end

-- Turning a member back into an NPC needs their original alignment and
-- DB_PartyMembers; without them nothing happens and they stay in DB_Players
-- (_GLO_Shared_PartyMembers.txt L1298-1321). Team members then go to camp
-- (_GLO_Shared_Origins.txt L439-450, Hirelings.txt L684-691).
local function makeNPC(member)
    local alignment = M.db("DB_GLO_PartyMembers_OriginalAlignment"):Get(member, nil)[1]
    if not alignment or #M.db("DB_PartyMembers"):Get(member) == 0 then return end
    local ch = char(member) or {}
    M.db("DB_Players"):Delete(member)
    M.db("DB_PartyMembers"):Delete(member)
    M.db("DB_GLO_PartyMembers_DefaultFaction")(member, ch.faction or "PlayerFaction")
    ch.faction = alignment[2]
    M.storyRules(member)
    if #M.db("DB_PartOfTheTeam"):Get(member) > 0 then M.db("DB_InCamp")(member) end
end

-- Unforced removal only goes ahead when the member's user has another
-- character in DB_Players; forced removal always does (L658-699).
function Osi.PROC_GLO_PartyMembers_Remove(member, dismisser, force)
    assert(dismisser ~= nil and force ~= nil, "two-argument Remove")
    assert(#M.db("DB_Avatars"):Get(member) == 0, "avatar removed")
    local goAhead = force == 1
    for _, row in ipairs(M.db("DB_Players").rows) do
        if uuidOf(row[1]) ~= uuidOf(member) and (char(row[1]) or {}).user == (char(member) or {}).user then
            goAhead = true
        end
    end
    if goAhead then makeNPC(member) end
    Osi.PROC_CheckPartyFull()
end

setmetatable(Osi, {
    __index = function(_, k)
        if string.sub(k, 1, 3) == "DB_" then return M.db(k) end
        return nil
    end,
})

-- Script Extender ----------------------------------------------------------
local required = {}
local modVars = {}

local function channel(name)
    local ch = { name = name }
    function ch:SetHandler(fn) self.handler = fn end
    function ch:SetRequestHandler(fn) self.requestHandler = fn end
    function ch:Broadcast(data) M.broadcasts[#M.broadcasts + 1] = { channel = name, data = data } end
    function ch:SendToServer(data) return self.handler(data, M.hostPeer) end
    function ch:RequestToServer(data, cb) cb(self.requestHandler(data, M.hostPeer)) end
    return ch
end

M.Ext = {
    Utils = { Print = function(s) M.log[#M.log + 1] = s end },
    Net = {
        CreateChannel = function(_, name) return channel(name) end,
        IsHost = function() return true end,
    },
    Require = function(path)
        if required[path] == nil then
            local fn = assert(loadfile(M.LUA_ROOT .. "/" .. path))
            required[path] = fn() or true
        end
        return required[path]
    end,
    Timer = {
        -- Timers of ten seconds or more are timeouts and expiry timers; tests fire them
        -- explicitly with M.runLongTimers(). (Every working delay in the mod is 3 s or less.)
        WaitFor = function(ms, fn) table.insert(ms >= 10000 and M.longTimers or M.timers, fn) end,
        WaitForRealtime = function(ms, fn) table.insert(ms >= 10000 and M.longTimers or M.timers, fn) end,
    },
    Vars = {
        RegisterModVariable = function() end,
        GetModVariables = function() return modVars end,
    },
    Osiris = {
        RegisterListener = function(name, arity, when, fn)
            M.listeners[name .. "/" .. arity .. "/" .. when] = fn
        end,
    },
    Loca = {
        GetTranslatedString = function(h)
            local c = M.chars[string.sub(h, 3)]
            return c and c.name or ""
        end,
    },
    Entity = { Get = function(u)
        local c = M.chars[u]
        if not c then return nil end
        return { IsSummon = c.entitySummon and {} or nil, PartyFollower = c.entityFollower and {} or nil,
            ActionResources = c.actionResources }
    end },
    -- MCM events: subscribers are kept so tests can fire them (M.mcmEvent).
    ModEvents = { BG3MCM = setmetatable({}, { __index = function(_, eventName)
        return { Subscribe = function(_, fn) M.mcmSubscribers[eventName] = fn end }
    end }) },
    RegisterConsoleCommand = function(name, fn) M.console[name] = fn end,
    -- Ext.Events: subscribers are kept so tests can fire them (StatsLoaded, SessionLoaded).
    Events = setmetatable({}, { __index = function(_, eventName)
        return { Subscribe = function(_, fn) M.events[eventName] = fn end }
    end }),
    StaticData = { Get = function(uuid, kind)
        assert(kind == "ActionResource", "static data type")
        return M.staticData[uuid]
    end },
}

function M.runTimers()
    local guard = 0
    while #M.timers > 0 do
        guard = guard + 1
        assert(guard < 100, "timer loop")
        local fn = table.remove(M.timers, 1)
        fn()
    end
end

function M.runLongTimers()
    local list = M.longTimers
    M.longTimers = {}
    for _, fn in ipairs(list) do fn() end
end

function M.fire(name, arity, when, ...)
    local fn = M.listeners[name .. "/" .. arity .. "/" .. when]
    assert(fn, "no listener " .. name)
    return fn(...)
end

function M.mcmEvent(eventName, payload)
    local fn = M.mcmSubscribers[eventName]
    assert(fn, "no subscriber for " .. eventName)
    return fn(payload)
end

function M.messages()
    local out = {}
    for _, b in ipairs(M.broadcasts) do
        if b.channel == "Message" then out[#out + 1] = b.data.text end
    end
    return out
end

function M.activeNames()
    local out = {}
    for _, row in ipairs(M.db("DB_Players").rows) do out[#out + 1] = char(row[1]).name end
    table.sort(out)
    return table.concat(out, ",")
end

return M
