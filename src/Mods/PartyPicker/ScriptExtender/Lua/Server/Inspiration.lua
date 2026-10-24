-- Party Picker (server): the party's Inspiration limit.
-- For now only the probe (docs/PLAN_inspiration_and_30.md, step 0): the console command
-- !pp_inspiration shows the limit and each party member's points, and can set a test limit, so an
-- in-game run shows how the game treats a higher limit before any setting is built on it.
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

Inspiration.DEFINITION_UUID = "a9c98304-08e7-44b5-aaf9-da2ef5a50672"
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
--                            is never pushed under points the party already holds)
-- !pp_inspiration reset      set the game's own 4, then show
function Inspiration.Console(arg)
    arg = arg and tostring(arg) or ""
    if arg == "reset" then
        local ok, err = Inspiration.SetLimit(Inspiration.GAME_LIMIT)
        PP.Log(ok and ("Inspiration limit set to " .. Inspiration.GAME_LIMIT) or ("could not set the Inspiration limit: " .. err))
    elseif arg ~= "" then
        local n = math.tointeger(tonumber(arg))
        if not n or n < Inspiration.GAME_LIMIT or n > Inspiration.PROBE_MAX then
            PP.Log("usage: !pp_inspiration [" .. Inspiration.GAME_LIMIT .. "-" .. Inspiration.PROBE_MAX .. " | reset]")
            return
        end
        local ok, err = Inspiration.SetLimit(n)
        PP.Log(ok and ("Inspiration limit set to " .. n .. " (test)") or ("could not set the Inspiration limit: " .. err))
    end
    Inspiration.Report(PP.Log)
end

return Inspiration
