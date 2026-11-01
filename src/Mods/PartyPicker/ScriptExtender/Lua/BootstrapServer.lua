-- Party Picker (server).
Ext.Require("Shared/Common.lua")
local Party = Ext.Require("Server/Party.lua")
local Restrictions = Ext.Require("Server/Restrictions.lua")
local HouseOfHope = Ext.Require("Server/HouseOfHope.lua")
local LimitGuard = Ext.Require("Server/LimitGuard.lua")
local HalsinRepair = Ext.Require("Server/HalsinRepair.lua")
local RosterWatch = Ext.Require("Server/RosterWatch.lua")

local function rosterReply()
    local entries = {}
    local checkCombat = PP.Setting("block_in_combat", true) ~= false
    for _, e in ipairs(Party.Roster()) do
        -- stuck: a party member the game will not let go right now (the server's own check), so the
        -- pick-four window keeps them and "Send everyone to camp" leaves them (plan review 2026-10-31, 5).
        local stuck = nil
        if e.active and not e.locked then
            local ok, why = pcall(Party.LeaveBlockedReason, e.id, checkCombat)
            if ok then stuck = why end
        end
        -- joinBlocked: a camp member the game holds right now; Apply would refuse the whole change with them
        -- (final review 2026-11-01, finding 3). Not for the dead: they are drawn disabled, as before.
        local joinBlocked = nil
        if not e.active and not e.locked and not e.dead then
            local ok, why = pcall(Party.JoinBlockedReason, e.id, checkCombat)
            if ok then joinBlocked = why end
        end
        entries[#entries + 1] = {
            uuid = e.uuid, name = e.name, active = e.active, inCamp = e.inCamp,
            avatar = e.avatar, hireling = e.hireling, dead = e.dead, downed = e.downed == true,
            offStage = e.offStage == true,
            locked = e.locked == true, lockReason = e.lockReason,
            stuck = stuck, joinBlocked = joinBlocked,
        }
    end
    -- Who the tab now shows, so a death that takes someone off the team still redraws it.
    pcall(RosterWatch.Listed, entries)
    local pending = Restrictions.GetPending()
    return {
        entries = entries,
        -- Your own character is dead: the tab says so (plan 1.1.4 unit A; the server refuses the change itself).
        hostDead = (function()
            local ok, text = pcall(Party.HostDeadText)
            return ok and text or nil
        end)(),
        -- A party change is running (the tab keeps showing the ticks it sent until it is done, unit E).
        busy = Party.IsBusy(),
        maxSize = Party.EffectiveMaxSize(),
        setting = Party.MaxSize(),
        pending = pending and { reason = pending.reason, trimmed = pending.trimmed == true } or nil,
        -- "Let Halsin join early" ticked where it cannot apply (nil: it applies, or is off)
        halsinEarlyIdle = (function()
            local ok, text = pcall(HalsinRepair.EarlyIdleText)
            return ok and text or nil
        end)(),
        -- "Put Halsin's quest back on track" (nil: nothing to put back)
        halsin = (function()
            local ok, info = pcall(HalsinRepair.TabInfo)
            return ok and info or nil
        end)(),
    }
end

-- Only the host may change the party; in multiplayer other players' clients
-- see the tab read-only (the client checks Ext.Net.IsHost too).
-- NetChannel handlers receive a network peer id, while Osiris uses a user id;
-- bg3se Docs/API.md gives the conversion (peer & 0xffff0000) | 0x0001.
local function peerToUserId(peer)
    if math.type(peer) ~= "integer" then return nil end
    return (peer & 0xffff0000) | 0x0001
end

local function isHostUser(peer)
    local host = Party.HostCharacter()
    if not host then return false end
    local ok, hostUser = pcall(Osi.GetReservedUserID, host)
    if not ok or hostUser == nil then return false end
    return hostUser == peer or hostUser == peerToUserId(peer)
end

-- NetChannel only replies when the handler returns normally
-- (bg3se NetChannel.lua), so every handler is wrapped: an error must still
-- reach the client instead of leaving it waiting.
local function safeHandler(fn)
    return function(data, user)
        local ok, reply = pcall(fn, data, user)
        if ok then return reply end
        PP.Log("request failed: " .. tostring(reply))
        return { accepted = false, message = "Party Picker error: " .. tostring(reply), error = tostring(reply) }
    end
end

PP.Net.Roster:SetRequestHandler(safeHandler(function()
    return rosterReply()
end))

-- A refusal because your own character is dead: the tab shows it in the message window (plan 1.1.4 unit A).
local function refusedForDeath(accepted, message)
    if accepted then return nil end
    local ok, text = pcall(Party.HostDeadText)
    return (ok and text ~= nil and message == text) or nil
end

-- data = { uuids = {...}, reason = nil | "rest", keepAll = bool }
PP.Net.Apply:SetRequestHandler(safeHandler(function(data, user)
    if not isHostUser(user) then
        PP.Log("request refused: not from the host")
        return { accepted = false, message = "Only the host can change the party." }
    end
    data = data or {}
    if data.keepAll and data.reason then
        -- A trim still running must keep its record (review 2026-10-31, point 2).
        if Party.IsBusy() then
            PP.Log("request refused: A party change is already in progress.")
            return { accepted = false, message = "A party change is already in progress." }
        end
        Restrictions.BypassOnce(data.reason)
        return { accepted = true, message = "Keeping everyone this time. Press End the Day again." }
    end
    local opts = {}
    if data.reason then
        opts.limit = PP.RESTRICTED_SIZE
        opts.beforeChange = function(_, toRemove, activeBefore)
            Restrictions.MarkTrimming(data.reason, toRemove, activeBefore)
        end
    end
    local accepted, message = Party.Apply(data.uuids or {}, opts, function(result)
        Restrictions.Notice(result.message, result.ok and "info" or "warning")
        if data.reason then
            Restrictions.OnTrimmed(data.reason, result)
        elseif result.changed then
            -- A party chosen by hand replaces any trim waiting to be undone.
            Restrictions.ClearPending()
        end
    end)
    return { accepted = accepted, message = message, hostDead = refusedForDeath(accepted, message) }
end))

PP.Net.Restore:SetRequestHandler(safeHandler(function(_, user)
    if not isHostUser(user) then
        return { accepted = false, message = "Only the host can change the party." }
    end
    local accepted, message = Restrictions.Restore(function(result)
        Restrictions.Notice(result.message, result.ok and "info" or "warning")
    end)
    return { accepted = accepted, message = message, hostDead = refusedForDeath(accepted, message) }
end))

local function messageWindow(text)
    pcall(function() PP.Net.Message:Broadcast({ text = text }) end)
end

-- The Party tab's "Put Halsin's quest back on track" (docs/PLAN_halsin_early_option.md). Host only.
PP.Net.HalsinReset:SetRequestHandler(safeHandler(function(_, peer)
    if not isHostUser(peer) then
        return { accepted = false, message = "Only the host can change the party." }
    end
    local accepted, message = HalsinRepair.TabReset(messageWindow)
    return { accepted = accepted, message = message }
end))

Restrictions.Register()
HouseOfHope.Register()
RosterWatch.Register()

-- First arrival at Last Light: if Halsin joined early, say how to put his quest back on track.
-- FlagSet fires for every flag, so the check is a string compare first.
local ENTERED_HAVEN = PP.BareUuid(HalsinRepair.ENTERED_HAVEN_FLAG)
pcall(function()
    Ext.Osiris.RegisterListener("FlagSet", 3, "after", function(flag)
        if PP.BareUuid(flag) ~= ENTERED_HAVEN then return end
        -- After the story's own rules for the same event.
        Ext.Timer.WaitFor(1000, function()
            local ok, err = pcall(HalsinRepair.OnReachedLastLight, messageWindow)
            if not ok then PP.Log("Halsin notice failed: " .. tostring(err)) end
        end)
    end)
end)

-- Another party-limit mod in the load order: say so once a save has loaded.
pcall(function() Ext.Events.SessionLoaded:Subscribe(function() pcall(LimitGuard.WarnOtherMods) end) end)

-- The Lua restarts on every load, so the first LevelGameplayStarted of a Lua session is a load; later ones are
-- level changes (Act transitions), where the story is busy with its own moves (plan review 2026-11-01, point 5).
local gameplayStarted = false
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    pcall(Party.ApplyMaxSize)
    pcall(Restrictions.ExtendRaft)
    pcall(LimitGuard.CheckLoadedParty)
    if not gameplayStarted then
        gameplayStarted = true
        pcall(Restrictions.ResumeAfterLoad)
    end
end)

-- Remember everyone who joins the active party (see Party.Remember).
-- The story can add members itself (e.g. GLO_Jergal.txt L983-987), so the limit
-- is re-applied (never below the party; quiet unless it changes).
Ext.Osiris.RegisterListener("DB_Players", 1, "after", function(id)
    pcall(Party.Remember, id)
    if not Party.IsBusy() then pcall(Party.ApplyMaxSize) end
end)

-- MCM fires this in both contexts (BG3-MCM Server/MCMServer.lua).
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
        if not payload or payload.modUUID ~= ModuleUUID then return end
        if payload.settingId == "max_party_size" then
            pcall(Party.ApplyMaxSize)
            pcall(LimitGuard.OnSettingChanged)
        end
        if payload.settingId == "extend_raft" then Restrictions.ExtendRaft() end
    end)
end)
-- Another MCM profile may hold another limit.
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Profile_Activated"]:Subscribe(function()
        -- A slider check still waiting belongs to the old profile (review 2026-10-31, point 6).
        pcall(LimitGuard.Cancel)
        pcall(Party.ApplyMaxSize)
        pcall(LimitGuard.CheckLoadedParty)
    end)
end)

-- Console fallback (server context): !pp_roster, !pp_size, !pp_restore,
-- !pp_set Name1,Name2,...   Names are matched case-insensitively.
-- Each line ends with the story tables the character is in and their faction.
local function sourcesText(id)
    local dbs, faction = Party.Sources(id)
    return string.format(" [in: %s; faction: %s; id: %s]", dbs, tostring(faction), tostring(id))
end

Ext.RegisterConsoleCommand("pp_roster", function()
    PP.Log("Party Picker v" .. PP.VERSION .. " roster:")
    for _, e in ipairs(Party.Roster()) do
        PP.Log(string.format("%-24s %s%s%s%s%s", e.name,
            e.active and "ACTIVE " or "camp   ",
            e.avatar and "avatar " or "",
            e.hireling and "hireling " or "",
            e.dead and "dead " or "",
            e.locked and ("locked(" .. tostring(e.lockReason) .. ")") or "") .. sourcesText(e.id))
    end
    for _, x in ipairs(Party.Excluded()) do
        PP.Log(string.format("%-24s not listed: %s (in %s)", x.name, x.why, x.db) .. sourcesText(x.id))
    end
    PP.Log(string.format("active %d, limit %d (game reports %s)", Party.ActiveCount(), Party.MaxSize(),
        tostring(select(2, pcall(Osi.GetMaxPartySize)))))
end)

-- !pp_forget Name: remove a character from the "seen in your party" record,
-- e.g. if someone who is not a party member got listed that way.
Ext.RegisterConsoleCommand("pp_forget", function(_, ...)
    local name = string.lower((table.concat({ ... }, " "):gsub("^%s+", ""):gsub("%s+$", "")))
    local hits = 0
    for _, db in ipairs({ "DB_PartOfTheTeam", "DB_Hirelings_Hired", "DB_Players" }) do
        local ok, rows = pcall(function() return Osi[db]:Get(nil) end)
        for _, row in ipairs(ok and rows or {}) do
            if string.lower(Party.DisplayName(row[1])) == name and Party.Forget(PP.BareUuid(row[1])) then
                hits = hits + 1
            end
        end
    end
    PP.Log(hits > 0 and ("forgot " .. hits .. " character(s) named " .. name)
        or ("nobody named " .. name .. " in the seen record (see !pp_roster)"))
end)

-- !pp_halsin [repair | haven]: report on, or repair, a Halsin added before the story made him recruitable
-- (docs/PLAN_halsin_recruit_gate.md; the Party tab button does the same repair from 1.0.9).
Ext.RegisterConsoleCommand("pp_halsin", function(_, arg)
    local ok, err = pcall(HalsinRepair.Console, arg)
    if not ok then PP.Log("!pp_halsin failed: " .. tostring(err)) end
end)

Ext.RegisterConsoleCommand("pp_size", function()
    Party.ApplyMaxSize()
end)

Ext.RegisterConsoleCommand("pp_restore", function()
    local accepted, message = Restrictions.Restore(function(result) PP.Log(result.message) end)
    PP.Log(message)
end)

Ext.RegisterConsoleCommand("pp_set", function(_, ...)
    local text = table.concat({ ... }, " ")
    local wanted, missing = {}, {}
    local roster = Party.Roster()
    for name in string.gmatch(text, "[^,]+") do
        name = string.lower((name:gsub("^%s+", ""):gsub("%s+$", "")))
        local found = nil
        for _, e in ipairs(roster) do
            if string.lower(e.name) == name then found = e end
        end
        if found then wanted[#wanted + 1] = found.uuid else missing[#missing + 1] = name end
    end
    if #missing > 0 then
        PP.Log("not found: " .. table.concat(missing, ", ") .. " (see !pp_roster)")
        return
    end
    local accepted, message = Party.Apply(wanted, nil, function(result) PP.Log(result.message) end)
    PP.Log(message)
end)

PP.Log("server loaded (v" .. PP.VERSION .. "). Console (server context): !pp_roster  !pp_set Name1,Name2  !pp_restore  !pp_size  !pp_forget Name  !pp_halsin")
