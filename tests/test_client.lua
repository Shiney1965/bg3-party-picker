-- Client-side scenarios for the Party tab against a small fake of Script Extender's IMGUI.
-- Run with: python3 tests/run_tests.py

local passed, failed = 0, 0
local function check(cond, what)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. what) end
end

-- Fake IMGUI: containers keep their children in order; widgets can be destroyed.
local function container()
    local c = { Children = {} }
    local function add(kind, label, checked)
        local w = { kind = kind, Label = label, Checked = checked }
        function w:Destroy()
            for i, k in ipairs(c.Children) do
                if k == w then table.remove(c.Children, i) return end
            end
        end
        c.Children[#c.Children + 1] = w
        return w
    end
    function c:AddText(t) return add("text", t) end
    function c:AddButton(t) return add("button", t) end
    function c:AddCheckbox(t, v) return add("checkbox", t, v) end
    function c:AddSeparator() return add("separator") end
    return c
end

local timers, subscribers, channels, required = {}, {}, {}, {}
local rosterRequests, halsinRequests = 0, 0
local reply = {}

Ext = {
    Utils = { Print = function() end },
    Net = {
        IsHost = function() return true end,
        CreateChannel = function(_, name)
            local ch = { name = name }
            function ch:SetHandler(fn) self.handler = fn end
            function ch:SetRequestHandler(fn) self.requestHandler = fn end
            function ch:RequestToServer(data, cb)
                if name == "Roster" then
                    rosterRequests = rosterRequests + 1
                    cb(reply)
                elseif name == "HalsinReset" then
                    halsinRequests = halsinRequests + 1
                    cb({ accepted = true, message = "Sending Halsin to camp..." })
                end
            end
            channels[name] = ch
            return ch
        end,
    },
    Require = function(path)
        if required[path] == nil then
            local fn = assert(loadfile(LUA_ROOT .. "/" .. path))
            required[path] = fn() or true
        end
        return required[path]
    end,
    Timer = {
        WaitFor = function(_, fn) timers[#timers + 1] = fn end,
        WaitForRealtime = function(_, fn) timers[#timers + 1] = fn end,
    },
    Vars = { RegisterModVariable = function() end },
    IMGUI = {
        NewWindow = function() return container() end,
        GetViewportSize = function() return { 1920, 1080 } end,
    },
    ModEvents = { BG3MCM = setmetatable({}, { __index = function(_, eventName)
        return { Subscribe = function(_, fn) subscribers[eventName] = fn end }
    end }) },
    RegisterConsoleCommand = function() end,
}
ModuleUUID = "f8e3db24-5fe8-40e0-a2d5-eaaf1013aea9"
local tabCallback = nil
MCM = { InsertModMenuTab = function(args) tabCallback = args.tabCallback end }

local function runTimers()
    local guard = 0
    while #timers > 0 do
        guard = guard + 1
        assert(guard < 100, "timer loop")
        table.remove(timers, 1)()
    end
end

local function find(root, kind, label)
    for _, w in ipairs(root.Children) do
        if w.kind == kind and w.Label == label then return w end
    end
    return nil
end

local function settingSaved(settingId, modUUID)
    subscribers["MCM_Setting_Saved"]({ modUUID = modUUID or ModuleUUID, settingId = settingId, value = 1 })
end

dofile(LUA_ROOT .. "/BootstrapClient.lua")
check(tabCallback ~= nil and subscribers["MCM_Setting_Saved"] ~= nil, "Party tab added; setting event subscribed")

reply = {
    maxSize = 6, setting = 6,
    entries = {
        { uuid = "a", name = "Tav", active = true, locked = true, avatar = true },
        { uuid = "b", name = "Gale", active = true },
        { uuid = "c", name = "Wyll", active = false },
    },
    inspiration = { controls = false, points = 2, limit = 4 },
}
local tab = container()
tabCallback(tab)
check(find(tab, "button", "+") == nil, "controls off: no + button")

-- Ticks not yet applied: Wyll ticked, Gale unticked.
find(tab, "checkbox", "Wyll").OnChange(nil, true)
find(tab, "checkbox", "Gale").OnChange(nil, false)

-- 1. "Show Inspiration point controls" ticked in Settings: the tab redraws by itself (reported in game
-- 2026-10-27: the buttons only appeared after Refresh), and the ticks survive the redraw.
reply.inspiration.controls = true
local before = rosterRequests
settingSaved("inspiration_point_controls")
check(rosterRequests == before, "redraw waits for the slider to settle")
runTimers()
check(rosterRequests == before + 1, "one redraw")
check(find(tab, "button", "+") ~= nil and find(tab, "button", "-") ~= nil, "the - and + buttons appear")
check(find(tab, "text", "Inspiration: 2 of 4") ~= nil, "the Inspiration line appears")
check(find(tab, "checkbox", "Wyll").Checked == true and find(tab, "checkbox", "Gale").Checked == false,
    "ticks not yet applied are kept")
check(find(tab, "checkbox", "Tav  (you)").Checked == true, "locked member unchanged")

-- 2. A slider drag sends many changes: one redraw.
before = rosterRequests
for _ = 1, 5 do settingSaved("inspiration_limit") end
runTimers()
check(rosterRequests == before + 1, "a drag redraws once")

-- 3. Other settings and other mods' settings do not redraw.
before = rosterRequests
settingSaved("extend_raft")
settingSaved("inspiration_point_controls", "00000000-0000-0000-0000-000000000000")
runTimers()
check(rosterRequests == before, "unrelated changes ignored")

-- 4. A new recruit since the last draw starts from the party, as before.
-- (A new table, as every reply from the server is.)
local grown = {}
for i, e in ipairs(reply.entries) do grown[i] = e end
grown[#grown + 1] = { uuid = "d", name = "Karlach", active = true }
reply.entries = grown
settingSaved("max_party_size")
runTimers()
check(find(tab, "checkbox", "Karlach").Checked == true and find(tab, "checkbox", "Wyll").Checked == true,
    "new entry from the party, kept ticks still kept")

-- 4b. A change the game made meanwhile shows as it is; only the player's own changes are carried.
-- (The player ticked Wyll and unticked Gale; the game sends Karlach, untouched, to camp, then back.)
local function withKarlach(active)
    local list = {}
    for i, e in ipairs(reply.entries) do list[i] = e end
    list[4] = { uuid = "d", name = "Karlach", active = active }
    reply.entries = list
end
withKarlach(false)
settingSaved("inspiration_limit")
runTimers()
check(find(tab, "checkbox", "Karlach").Checked == false and find(tab, "checkbox", "Wyll").Checked == true
    and find(tab, "checkbox", "Gale").Checked == false, "game-side change shown; the player's changes kept")
withKarlach(true)
settingSaved("inspiration_limit")
runTimers()
check(find(tab, "checkbox", "Karlach").Checked == true, "and again when the game brings her back")

-- 5. The limit guard's message redraws too (its write-back sends no setting event).
before = rosterRequests
channels["Message"].handler({ text = "The party limit can't be lower than your party (8). It has been set to 8." })
runTimers()
check(rosterRequests == before + 1, "message from the limit guard redraws the tab")

-- 6. Refresh starts again from the party.
find(tab, "button", "Refresh").OnClick()
check(find(tab, "checkbox", "Wyll").Checked == false and find(tab, "checkbox", "Gale").Checked == true,
    "Refresh resets the ticks to the party")

-- 7. Opening the page again starts from the party, even with a redraw still waiting.
find(tab, "checkbox", "Wyll").OnChange(nil, true)
settingSaved("inspiration_limit")
subscribers["MCM_Mod_Tab_Activated"]({ modUUID = ModuleUUID })
check(find(tab, "checkbox", "Wyll").Checked == false, "page opened: from the party")
before = rosterRequests
runTimers()
check(rosterRequests == before and find(tab, "checkbox", "Wyll").Checked == false,
    "the redraw that was waiting is cancelled by opening the page")

-- 8. "Put Halsin's quest back on track" (docs/PLAN_halsin_early_option.md): only when the server sends
-- `halsin`; disabled with the reason; otherwise asks once, then one request.
local BUTTON = "Put Halsin's quest back on track"
local YES = "Yes, put it back on track"
check(find(tab, "button", BUTTON) == nil, "no halsin in the reply: no section")
reply.halsin = { inParty = true, why = "Available once your party has reached Last Light." }
find(tab, "button", "Refresh").OnClick()
check(find(tab, "button", BUTTON) and find(tab, "button", BUTTON).Disabled == true
    and find(tab, "text", "Available once your party has reached Last Light."), "not yet: button disabled, reason shown")
reply.halsin = { inParty = true }
find(tab, "button", "Refresh").OnClick()
check(find(tab, "button", BUTTON).Disabled == false, "available: button enabled")
find(tab, "button", BUTTON).OnClick()
check(find(tab, "button", YES) and find(tab, "button", "Cancel") and halsinRequests == 0, "first click asks; nothing sent")
find(tab, "button", "Cancel").OnClick()
check(find(tab, "button", BUTTON) and halsinRequests == 0, "Cancel: back to the button, nothing sent")
find(tab, "button", BUTTON).OnClick()
find(tab, "button", YES).OnClick()
check(halsinRequests == 1, "Yes: one request")
runTimers()
check(find(tab, "button", YES) == nil, "after the request: no confirmation left")
-- A confirmation does not come back by itself after the button was unavailable.
find(tab, "button", BUTTON).OnClick()
reply.halsin = { inParty = true, why = "a party change is still running. Wait a moment and try again." }
find(tab, "button", "Refresh").OnClick()
reply.halsin = { inParty = true }
subscribers["MCM_Mod_Tab_Activated"]({ modUUID = ModuleUUID })
check(find(tab, "button", YES) == nil and find(tab, "button", BUTTON), "page reopened: no stale confirmation")
reply.halsin = nil

print(string.format("client: %d passed, %d failed", passed, failed))
if failed > 0 then error("client tests failed") end
