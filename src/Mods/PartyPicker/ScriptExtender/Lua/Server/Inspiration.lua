-- Party Picker (server): the party's Inspiration limit (docs/PLAN_inspiration_and_30.md, Part B).
-- MCM settings: "Inspiration limit" (4-30, default 4, the game's own) and "Match the party limit"
-- (the limit follows the Maximum party size setting). Party Picker only sets the limit; it never adds or
-- removes Inspiration points. The console command !pp_inspiration shows the limit and the party's points
-- (and can set a test limit until the next time the setting is applied).
-- In-game probe 2026-10-25: the limit is readable and writable, and the game keeps Inspiration for the
-- party, not per character (no character carries an InspirationPoint entry), so one value is enough.
--
-- Sources:
--   the game's definition: Shared.pak Public/Shared/ActionResourceDefinitions/ActionResourceDefinitions.lsx,
--     InspirationPoint a9c98304-08e7-44b5-aaf9-da2ef5a50672, MaxValue 4, PartyActionResource true;
--   Script Extender: Ext.StaticData type "ActionResource" with a writable MaxValue
--     (GameDefinitions/GuidResources.h, LuaScripts/Tests/StaticDataTests.lua), and each character's
--     ActionResources component entries with Amount / MaxAmount (Components/ActionResources.h);
--   Osiris (story_header.div): PartyGetActionResourceValue(player, name) -> amount,
--     GetActionResourceValuePersonal(player, name, level) -> amount.

local Party = Ext.Require("Server/Party.lua")

local Inspiration = {}

Inspiration.DEFINITION_UUID = PP.INSPIRATION_UUID
Inspiration.OSIRIS_KEY = "InspirationPoint"
-- Highest test limit the probe accepts (the planned setting goes to 30 as well).
Inspiration.PROBE_MAX = 30
-- The game's own limit, from its definition. Not read back from the game: after a reload the
-- resource bank still holds whatever Party Picker last wrote.
Inspiration.GAME_LIMIT = 4

local function definition()
    local ok, d = pcall(Ext.StaticData.Get, Inspiration.DEFINITION_UUID, "ActionResource")
    if ok and d ~= nil then return d end
    return nil
end

function Inspiration.CurrentLimit()
    local d = definition()
    if not d then return nil end
    local ok, v = pcall(function() return d.MaxValue end)
    return ok and v or nil
end

-- Writes the limit in the game's definition (memory only; nothing goes into the save).
function Inspiration.SetLimit(n)
    local d = definition()
    if not d then return false, "InspirationPoint definition not found" end
    local ok, err = pcall(function() d.MaxValue = n end)
    if not ok then return false, tostring(err) end
    return true
end

-- The game keeps these values as doubles; print 4 rather than 4.0.
local function num(v)
    if type(v) == "number" then return string.format("%g", v) end
    return tostring(v)
end

-- One character's InspirationPoint entries from the ActionResources component.
local function entriesOf(uuid)
    local ok, result = pcall(function()
        local ent = Ext.Entity.Get(uuid)
        local comp = ent and ent.ActionResources
        local resources = comp and comp.Resources
        if not resources then return "no ActionResources component" end
        local parts = {}
        local function add(list)
            for _, entry in ipairs(list) do
                parts[#parts + 1] = string.format("Amount %s / MaxAmount %s", num(entry.Amount), num(entry.MaxAmount))
            end
        end
        local direct = resources[Inspiration.DEFINITION_UUID]
        if direct then
            add(direct)
        else
            for key, list in pairs(resources) do
                if PP.BareUuid(tostring(key)) == Inspiration.DEFINITION_UUID then add(list) end
            end
        end
        if #parts == 0 then return "no InspirationPoint entry" end
        return table.concat(parts, "; ")
    end)
    return ok and result or ("read failed: " .. tostring(result))
end

-- The limit the settings ask for: 4 to 30.
function Inspiration.ChosenLimit()
    local n
    if PP.Setting("inspiration_match_party", false) == true then
        n = Party.MaxSize()
    else
        n = tonumber(PP.Setting("inspiration_limit", Inspiration.GAME_LIMIT)) or Inspiration.GAME_LIMIT
    end
    n = math.floor(n)
    if n < Inspiration.GAME_LIMIT then n = Inspiration.GAME_LIMIT end
    if n > Inspiration.PROBE_MAX then n = Inspiration.PROBE_MAX end
    return n
end

-- With "Match the party limit" ticked, the Inspiration limit slider shows the party limit. Reported in game
-- 2026-10-27: ticking the box left the slider where it was, and the slider could still be moved above the
-- party limit. MCM.Set saves the value and moves the open slider (BG3-MCM Shared/Classes/MCMAPI.lua,
-- SetSettingValue, sends MCM_INTERNAL_SETTING_SAVED to the clients) and sends no MCM_Setting_Saved, so this
-- does not loop.
function Inspiration.SyncSlider()
    if PP.Setting("inspiration_match_party", false) ~= true then return false end
    if MCM == nil or MCM.Set == nil then return false end
    local target = Inspiration.ChosenLimit()
    if tonumber(PP.Setting("inspiration_limit", nil)) == target then return false end
    local ok, written = pcall(MCM.Set, "inspiration_limit", target)
    return ok and written == true
end

-- The same, just after the last change: a slider sends a change for every step of a drag, so it is moved
-- back once the drag stops. MCM cannot disable a slider (its blueprint only has VisibleIf, which hides it),
-- so this holds it at the party limit instead.
local syncSeq = 0
function Inspiration.SyncSliderLater()
    syncSeq = syncSeq + 1
    local mySeq = syncSeq
    Ext.Timer.WaitForRealtime(500, function()
        if mySeq ~= syncSeq then return end
        pcall(Inspiration.SyncSlider)
    end)
end

-- Apply the chosen limit (and tell non-host clients in multiplayer). Logged only when it changes.
local lastLimit = nil
-- The total asked for by a points change that has not landed yet (plan Part F; cleared when it is checked,
-- and when a save or a level loads, where the check may never run), so a second request in that half
-- second counts from it rather than from the old number.
local pendingTarget = nil
local changeSeq = 0
-- The party's Inspiration points now, or nil (Osiris cannot be called while a save is loading).
local function pointsHeld()
    local host = Party.HostCharacter()
    if not host then return nil end
    local ok, v = pcall(Osi.PartyGetActionResourceValue, host, Inspiration.OSIRIS_KEY)
    if ok and type(v) == "number" then return v end
    return nil
end

function Inspiration.Apply(when)
    if when == "loading" or when == "session" then
        -- While a save loads, Osiris cannot read the points the save holds. Hold the limit wide open so
        -- nothing is capped on load (a fresh launch starts from the game's 4); the level start that follows
        -- sets the real value from the points held. Quiet: the level start logs the result.
        Inspiration.SetLimit(Inspiration.PROBE_MAX)
        lastLimit = nil
        pendingTarget = nil
        changeSeq = changeSeq + 1 -- a check still waiting belongs to the old game
        return
    end
    if when == "level" then
        pendingTarget = nil
        changeSeq = changeSeq + 1
    end
    local n = Inspiration.ChosenLimit()
    -- Never below the points the party holds, so the game has no reason to take any away (Party Picker
    -- never takes points on its own: plan decision, the author 2026-10-24). Lowered further once they are spent.
    do
        local held = pointsHeld()
        -- A raise that has not landed yet counts too, or it could land above the limit.
        if held ~= nil and pendingTarget ~= nil and pendingTarget > held then held = pendingTarget end
        if held == nil then
            -- The points cannot be read: never lower the limit now (it might go below what the party holds).
            local current = Inspiration.CurrentLimit()
            if type(current) == "number" and current > n then n = math.floor(current + 0.5) end
        end
        if held and held > n then
            n = math.ceil(held)
            if n ~= lastLimit then
                PP.Log("Inspiration limit kept at " .. n .. ": the party holds " .. n .. " points (spend them to lower it)")
            end
        end
    end
    local ok, err = Inspiration.SetLimit(n)
    if not ok then
        PP.Log("could not set the Inspiration limit: " .. tostring(err))
        return
    end
    if n ~= lastLimit then PP.Log("Inspiration limit set to " .. n) end
    lastLimit = n
    pcall(function() PP.Net.Inspiration:Broadcast({ limit = n }) end)
end

-- ---- Changing the points (plan Part F) -----------------------------------------------------------
-- Only when the player asks (Party tab buttons, or the console), and only with the setting "Show
-- Inspiration point controls" on. The game keeps Inspiration for the party; PartyIncreaseActionResourceValue
-- (story_header.div L293, REAL delta) changes it, PartyGetActionResourceValue (L294) reads it. Osiris REALs
-- arrive as floats, so totals are rounded.

function Inspiration.ControlsEnabled()
    return PP.Setting("inspiration_point_controls", false) == true
end

local function rounded(v) return math.floor(v + 0.5) end

-- For the Party tab: points, the setting's limit, and whether the controls are shown.
function Inspiration.TabInfo()
    local held = pointsHeld()
    return {
        controls = Inspiration.ControlsEnabled(),
        points = held and rounded(held) or nil,
        limit = Inspiration.ChosenLimit(),
    }
end

-- Change the party's points: opts.step (+1 / -1, from the tab: counted from the points the party holds
-- now, so a tab drawn before the game awarded points cannot remove them) or opts.target (console).
-- Raising is capped at the Inspiration limit setting; lowering is allowed down to 0. Returns ok, message.
function Inspiration.ChangePoints(opts, done)
    if not Inspiration.ControlsEnabled() then
        return false, 'Turn on "Show Inspiration point controls" in Settings first.'
    end
    local host = Party.HostCharacter()
    local held = pointsHeld()
    if not host or held == nil then return false, "The party's Inspiration cannot be read right now." end
    local current = pendingTarget or rounded(held)
    local target
    if opts.step then target = current + opts.step else target = opts.target end
    if type(target) ~= "number" or math.tointeger(target) == nil then return false, "A whole number, please." end
    local cap = Inspiration.ChosenLimit()
    if target < 0 then return false, "Inspiration can't go below 0." end
    if target > current and target > cap then
        return false, string.format("The Inspiration limit is %d; raise it in Settings first.", cap)
    end
    if target == current then return true, string.format("Inspiration is already %d.", current) end
    local limitNow = Inspiration.CurrentLimit()
    if type(limitNow) ~= "number" then return false, "The game's Inspiration definition cannot be read right now." end
    -- Make room first if needed (the limit never stands below the points the party will hold).
    if target > limitNow then
        local okLimit = Inspiration.SetLimit(target)
        if not okLimit then return false, "Could not raise the Inspiration limit to " .. target .. "." end
    end
    local ok, err = pcall(Osi.PartyIncreaseActionResourceValue, host, Inspiration.OSIRIS_KEY, target - current)
    if not ok then
        pcall(Inspiration.Apply, "points")
        return false, "Could not change Inspiration: " .. tostring(err)
    end
    local source = opts.step and "Party tab" or "console"
    PP.Log(string.format("Inspiration points %d -> %d asked (%s)", current, target, source))
    -- The game applies the change a moment later: read straight away, the points were still the old number
    -- (in game 2026-10-27, "Inspiration points 3 -> 3 (asked 4)" on every press, though the next press
    -- started from 4). So the result is read half a second later, for the latest request only (two quick
    -- clicks do not report a false difference): logged, the limit floored at it (it follows the points down
    -- again), and a message only if the game kept another number.
    changeSeq = changeSeq + 1
    local mySeq = changeSeq
    pendingTarget = target
    Ext.Timer.WaitFor(500, function()
        if mySeq ~= changeSeq then return end
        pendingTarget = nil
        pcall(Inspiration.Apply, "points")
        local later = pointsHeld()
        later = later and rounded(later) or nil
        if later == nil then return end
        if later == target then
            PP.Log(string.format("Inspiration points now %d", later))
        else
            local text = string.format("The game kept %d Inspiration (asked for %d).", later, target)
            PP.Log(text)
            if done then done(text) end
        end
    end)
    return true, string.format("Inspiration set to %d.", target)
end

-- !pp_inspiration_points        show the points and the limit
-- !pp_inspiration_points <n>    set the points to n (needs "Show Inspiration point controls")
function Inspiration.PointsConsole(arg)
    arg = arg and tostring(arg) or ""
    if arg ~= "" then
        local n = math.tointeger(tonumber(arg))
        if not n then
            PP.Log("usage: !pp_inspiration_points [whole number]")
            return
        end
        local _, message = Inspiration.ChangePoints({ target = n })
        PP.Log(message)
        return -- the result is logged half a second later (the change lands a moment after the request)
    end
    local info = Inspiration.TabInfo()
    PP.Log(string.format("Inspiration: %s of %d (controls %s)", tostring(info.points), info.limit,
        info.controls and "on" or "off"))
end

-- Send the current limit to the clients again (a player who joined later, multiplayer).
function Inspiration.Resend()
    if lastLimit then pcall(function() PP.Net.Inspiration:Broadcast({ limit = lastLimit }) end) end
end

-- Another mod that sets the same limit (compatibility only; the author: other party mods, use at your own risk).
-- Configurable Party Limit (Nexus 11172, meta.lsx UUID 16b5fbb6-...) sets both the party and the
-- Inspiration limit, and its Inspiration option can remove points above its own cap (its Server/_Init.lua,
-- read 2026-10-24 for compatibility only).
function Inspiration.WarnOtherMods()
    local ok, loaded = pcall(Ext.Mod.IsModLoaded, "16b5fbb6-72fe-4a08-814a-87a9fc0b14bc")
    if ok and loaded then
        PP.Log("WARNING: Configurable Party Limit is also active. It sets the same party-size and Inspiration "
            .. "limits as Party Picker; the two will overwrite each other. Use at your own risk.")
    end
end

function Inspiration.Report(say)
    say("Inspiration probe (Party Picker v" .. PP.VERSION .. "): limit in the game's definition = "
        .. num(Inspiration.CurrentLimit()) .. " (the game's own value is " .. Inspiration.GAME_LIMIT .. ")")
    local host = Party.HostCharacter()
    if host then
        local ok, v = pcall(Osi.PartyGetActionResourceValue, host, Inspiration.OSIRIS_KEY)
        say("  party total (PartyGetActionResourceValue) = " .. (ok and num(v) or ("failed: " .. tostring(v))))
    end
    for _, e in ipairs(Party.Roster()) do
        if e.active then
            local okP, personal = pcall(Osi.GetActionResourceValuePersonal, e.id, Inspiration.OSIRIS_KEY, 0)
            say(string.format("  %-24s personal %s; component: %s", e.name,
                okP and num(personal) or "?", entriesOf(e.uuid)))
        end
    end
end

-- !pp_inspiration            show
-- !pp_inspiration <4-30>     set a test limit, then show (never below the game's 4, so the limit
--                            is never pushed under points the party already holds); the setting
--                            replaces it the next time it is applied (a level load or a change)
-- !pp_inspiration reset      apply the setting again, then show
function Inspiration.Console(arg)
    arg = arg and tostring(arg) or ""
    if arg == "reset" then
        lastLimit = nil
        Inspiration.Apply("console")
    elseif arg ~= "" then
        local n = math.tointeger(tonumber(arg))
        if not n or n < Inspiration.GAME_LIMIT or n > Inspiration.PROBE_MAX then
            PP.Log("usage: !pp_inspiration [" .. Inspiration.GAME_LIMIT .. "-" .. Inspiration.PROBE_MAX .. " | reset]")
            return
        end
        local held = pointsHeld()
        if held and held > n then
            n = math.ceil(held)
            PP.Log("test limit raised to " .. n .. ": the party holds " .. n .. " points")
        end
        local ok, err = Inspiration.SetLimit(n)
        PP.Log(ok and ("Inspiration limit set to " .. n .. " (test)") or ("could not set the Inspiration limit: " .. err))
    end
    Inspiration.Report(PP.Log)
end

return Inspiration
