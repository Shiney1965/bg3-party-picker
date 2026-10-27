-- Party Picker (server).
Ext.Require("Shared/Common.lua")
local Party = Ext.Require("Server/Party.lua")
local Restrictions = Ext.Require("Server/Restrictions.lua")
local HouseOfHope = Ext.Require("Server/HouseOfHope.lua")
local Inspiration = Ext.Require("Server/Inspiration.lua")
local LimitGuard = Ext.Require("Server/LimitGuard.lua")

local function rosterReply()
    local entries = {}
    for _, e in ipairs(Party.Roster()) do
        entries[#entries + 1] = {
            uuid = e.uuid, name = e.name, active = e.active, inCamp = e.inCamp,
            avatar = e.avatar, hireling = e.hireling, dead = e.dead,
            offStage = e.offStage == true,
            locked = e.locked == true, lockReason = e.lockReason,
        }
    end
    local pending = Restrictions.GetPending()
    return {
        entries = entries,
        maxSize = Party.EffectiveMaxSize(),
        setting = Party.MaxSize(),
        inspiration = (function()
            local ok, info = pcall(Inspiration.TabInfo)
            return ok and info or nil
        end)(),
        pending = pending and { reason = pending.reason, trimmed = pending.trimmed == true } or nil,
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

-- data = { uuids = {...}, reason = nil | "rest", keepAll = bool }
PP.Net.Apply:SetRequestHandler(safeHandler(function(data, user)
    if not isHostUser(user) then
        PP.Log("request refused: not from the host")
        return { accepted = false, message = "Only the host can change the party." }
    end
    data = data or {}
    if data.keepAll and data.reason then
        Restrictions.BypassOnce(data.reason)
        return { accepted = true, message = "Keeping everyone this time. Press End the Day again." }
    end
    local opts = {}
    if data.reason then opts.limit = PP.RESTRICTED_SIZE end
    local accepted, message = Party.Apply(data.uuids or {}, opts, function(result)
        Restrictions.Notice(result.message, result.ok and "info" or "warning")
        if data.reason then
            Restrictions.OnTrimmed(data.reason, result)
        elseif result.changed then
            -- A party chosen by hand replaces any trim waiting to be undone.
            Restrictions.ClearPending()
        end
    end)
    return { accepted = accepted, message = message }
end))

PP.Net.Restore:SetRequestHandler(safeHandler(function(_, user)
    if not isHostUser(user) then
        return { accepted = false, message = "Only the host can change the party." }
    end
    local accepted, message = Restrictions.Restore(function(result)
        Restrictions.Notice(result.message, result.ok and "info" or "warning")
    end)
    return { accepted = accepted, message = message }
end))

-- Change the party's Inspiration points by one (Party tab, plan Part F). Host only.
PP.Net.InspirationPoints:SetRequestHandler(safeHandler(function(data, peer)
    if not isHostUser(peer) then
        return { accepted = false, message = "Only the host can change Inspiration." }
    end
    local step = data and math.tointeger(data.step)
    if step ~= 1 and step ~= -1 then return { accepted = false, message = "Bad request." } end
    -- Checked half a second later; a different result is told to the host in a message window.
    local accepted, message = Inspiration.ChangePoints({ step = step }, function(text)
        pcall(function() PP.Net.Message:Broadcast({ text = text }) end)
    end)
    return { accepted = accepted, message = message }
end))

Restrictions.Register()
HouseOfHope.Register()

-- The Inspiration limit: when a save starts loading (before its values are read; StatsLoaded does not
-- fire on the server, bg3se ScriptExtender.cpp OnStatsLoadGuarded), again when it has loaded, on every
-- level load, on setting changes, and for a player who joins later.
pcall(function() Ext.Events.SessionLoading:Subscribe(function() pcall(Inspiration.Apply, "loading") end) end)
pcall(function() Ext.Events.SessionLoaded:Subscribe(function()
    pcall(Inspiration.Apply, "session")
    pcall(Inspiration.WarnOtherMods)
end) end)
pcall(function() Ext.Osiris.RegisterListener("UserConnected", 3, "after", function() pcall(Inspiration.Resend) end) end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function()
    pcall(Inspiration.Apply, "level")
    pcall(Inspiration.SyncSlider) -- settings saved before 1.0.7 may hold an unmatched slider
    pcall(Party.ApplyMaxSize)
    pcall(Restrictions.ExtendRaft)
    pcall(LimitGuard.CheckLoadedParty)
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
        if payload.settingId == "inspiration_limit" or payload.settingId == "inspiration_match_party"
            or payload.settingId == "max_party_size" then
            pcall(Inspiration.Apply, "setting")
        end
        -- "Match the party limit": the Inspiration slider follows the party limit.
        if payload.settingId == "inspiration_match_party" then
            pcall(Inspiration.SyncSlider)
        elseif payload.settingId == "inspiration_limit" or payload.settingId == "max_party_size" then
            pcall(Inspiration.SyncSliderLater)
        end
    end)
end)
-- Another MCM profile may hold another limit.
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Profile_Activated"]:Subscribe(function()
        pcall(Inspiration.Apply, "profile")
        pcall(Inspiration.SyncSlider)
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

-- !pp_inspiration_points [n]: show or set the party's Inspiration points (plan Part F).
Ext.RegisterConsoleCommand("pp_inspiration_points", function(_, arg)
    local ok, err = pcall(Inspiration.PointsConsole, arg)
    if not ok then PP.Log("!pp_inspiration_points failed: " .. tostring(err)) end
end)

-- !pp_inspiration [4-30 | reset]: the Inspiration probe (docs/PLAN_inspiration_and_30.md, step 0).
Ext.RegisterConsoleCommand("pp_inspiration", function(_, arg)
    local ok, err = pcall(Inspiration.Console, arg)
    if not ok then PP.Log("!pp_inspiration failed: " .. tostring(err)) end
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

PP.Log("server loaded (v" .. PP.VERSION .. "). Console (server context): !pp_roster  !pp_set Name1,Name2  !pp_restore  !pp_size  !pp_forget Name  !pp_inspiration  !pp_inspiration_points")
