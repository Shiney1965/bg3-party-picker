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
local rosterHeld = nil
local rosterRequests, halsinRequests = 0, 0
local reply = {}
-- Apply: requests are kept; the reply is `applyReply`, or held back while it is "pending".
local applyRequests, applyReply, applyCallback = {}, { accepted = true, message = "Changing the party..." }, nil
local clientLog = {}

Ext = {
    Utils = { Print = function(s) clientLog[#clientLog + 1] = tostring(s) end },
    Net = {
        IsHost = function() return true end,
        CreateChannel = function(_, name)
            local ch = { name = name }
            function ch:SetHandler(fn) self.handler = fn end
            function ch:SetRequestHandler(fn) self.requestHandler = fn end
            function ch:RequestToServer(data, cb)
                if name == "Roster" then
                    rosterRequests = rosterRequests + 1
                    -- rosterHeld: replies are kept back and released in order by the test.
                    if rosterHeld then rosterHeld[#rosterHeld + 1] = cb else cb(reply) end
                elseif name == "HalsinReset" then
                    halsinRequests = halsinRequests + 1
                    cb({ accepted = true, message = "Sending Halsin to camp..." })
                elseif name == "Apply" then
                    applyRequests[#applyRequests + 1] = data
                    if applyReply == "pending" then applyCallback = cb else cb(applyReply) end
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
    -- A stray field from an older server draws nothing (1.1.0 has no Inspiration features).
    inspiration = { controls = true, points = 2, limit = 4 },
}
local tab = container()
tabCallback(tab)
local function noInspiration(root)
    for _, w in ipairs(root.Children) do
        if w.Label == "-" or w.Label == "+" or tostring(w.Label or ""):find("Inspiration") then return false end
    end
    return true
end
check(noInspiration(tab), "no - / + buttons and no Inspiration line")
check(channels.Inspiration == nil and channels.InspirationPoints == nil, "no Inspiration channels")

-- Ticks not yet applied: Wyll ticked, Gale unticked.
find(tab, "checkbox", "Wyll").OnChange(nil, true)
find(tab, "checkbox", "Gale").OnChange(nil, false)

-- 1. Maximum party size changed in Settings: the tab redraws by itself (reported in game 2026-10-27:
-- changes only appeared after Refresh), and the ticks survive the redraw.
local before = rosterRequests
settingSaved("max_party_size")
check(rosterRequests == before, "redraw waits for the slider to settle")
runTimers()
check(rosterRequests == before + 1, "one redraw")
check(noInspiration(tab), "still no Inspiration after the redraw")
check(find(tab, "checkbox", "Wyll").Checked == true and find(tab, "checkbox", "Gale").Checked == false,
    "ticks not yet applied are kept")
check(find(tab, "checkbox", "Tav  (you)").Checked == true, "locked member unchanged")

-- 2. A slider drag sends many changes: one redraw.
before = rosterRequests
for _ = 1, 5 do settingSaved("max_party_size") end
runTimers()
check(rosterRequests == before + 1, "a drag redraws once")

-- 3. Other settings and other mods' settings do not redraw.
before = rosterRequests
settingSaved("extend_raft")
settingSaved("max_party_size", "00000000-0000-0000-0000-000000000000")
settingSaved("inspiration_point_controls")
settingSaved("inspiration_limit")
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
settingSaved("halsin_early")
runTimers()
check(find(tab, "checkbox", "Karlach").Checked == false and find(tab, "checkbox", "Wyll").Checked == true
    and find(tab, "checkbox", "Gale").Checked == false, "game-side change shown; the player's changes kept")
withKarlach(true)
settingSaved("halsin_early")
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
settingSaved("halsin_early")
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

-- 9. 1.1.1 (docs/PLAN_1.1.1_review_fixes.md).
-- I. An MCM profile switch redraws the tab (MCM sends no per-setting event then), keeping the ticks.
check(subscribers["MCM_Profile_Activated"] ~= nil, "I: profile event subscribed")
find(tab, "checkbox", "Wyll").OnChange(nil, true)
local before9 = rosterRequests
subscribers["MCM_Profile_Activated"]({ profileName = "Other" })
subscribers["MCM_Profile_Activated"]({ fromProfile = "Default", toProfile = "Other" }) -- MCM emits twice
runTimers()
check(rosterRequests == before9 + 1 and find(tab, "checkbox", "Wyll").Checked == true,
    "I: one redraw for a profile switch, ticks kept")
-- J. The outcome of a change redraws the tab once it has happened.
before9 = rosterRequests
channels["Notice"].handler({ text = "Party updated. Joined: Wyll." })
runTimers()
check(rosterRequests == before9 + 1 and find(tab, "text", "Party updated. Joined: Wyll."), "J: a notice redraws the tab")

-- The pick-four window.
local windows = {}
Ext.IMGUI.NewWindow = function()
    local w = container()
    windows[#windows + 1] = w
    return w
end
local function picker(entries)
    reply = { entries = entries }
    channels["PickFour"].handler({ reason = "rest", size = 4 })
    return windows[1]
end
local function ticked(w, label) return find(w, "checkbox", label) and find(w, "checkbox", label).Checked end
local DEAD = { dead = true, active = true, locked = true, lockReason = "dead" }
local function dead(uuid, name)
    local e = { uuid = uuid, name = name }
    for k, v in pairs(DEAD) do e[k] = v end
    return e
end
local TAV = { uuid = "a", name = "Tav", active = true, locked = true, avatar = true }

-- A. Dead party members count towards the four: you + 2 dead + 2 alive asks for 4.
local w = picker({ TAV, dead("d1", "Gale"), dead("d2", "Wyll"),
    { uuid = "x", name = "Karlach", active = true }, { uuid = "y", name = "Laezel", active = true } })
local keep4 = find(w, "button", "Keep these 4")
check(keep4 and keep4.Disabled == false and find(w, "text", "Selected 4 of 4"), "A: 2 dead + 2 alive: asks for 4, can confirm")
check(ticked(w, "Karlach") == true and ticked(w, "Laezel") == false, "A: one living companion preselected")
keep4.OnClick()
local last = applyRequests[#applyRequests]
check(last and last.reason == "rest" and #last.uuids == 1 and last.uuids[1] == "x", "A: sends the one living companion kept")
-- you + 3 dead + 1 alive: nothing to choose, still confirmable.
w = picker({ TAV, dead("d1", "Gale"), dead("d2", "Wyll"), dead("d3", "Astarion"),
    { uuid = "x", name = "Karlach", active = true } })
keep4 = find(w, "button", "Keep these 4")
check(keep4 and keep4.Disabled == false and find(w, "text", "Nobody else can be chosen tonight."),
    "A: 3 dead + 1 alive: asks for 4, confirmable, says nobody else can be chosen")
-- Stuck party members (the server's own check) are kept and always sent.
w = picker({ TAV, { uuid = "s", name = "Shadowheart", active = true, stuck = "can't talk right now (DB_CantTalk_IgnoreCombat)" },
    { uuid = "x", name = "Karlach", active = true }, { uuid = "y", name = "Laezel", active = true },
    { uuid = "z", name = "Gale", active = true } })
local shLabel = nil
for _, k in ipairs(w.Children) do
    if k.kind == "checkbox" and tostring(k.Label):find("^Shadowheart") then shLabel = k end
end
check(shLabel and shLabel.Checked == true and shLabel.Disabled == true and tostring(shLabel.Label):find("can't leave now"),
    "A: a stuck member is shown kept, with the reason")
find(w, "button", "Keep these 4").OnClick()
last = applyRequests[#applyRequests]
local sent = {}
for _, u in ipairs(last.uuids) do sent[u] = true end
check(#last.uuids == 3 and sent.s and sent.x and sent.y, "A: the stuck member is sent with the two chosen")

-- D. One request at a time: both buttons are disabled until the answer; a refusal enables them again.
w = picker({ TAV, { uuid = "x", name = "Karlach", active = true }, { uuid = "y", name = "Laezel", active = true },
    { uuid = "z", name = "Gale", active = true }, { uuid = "q", name = "Wyll", active = true } })
applyReply = "pending"
find(w, "button", "Keep these 4").OnClick()
check(find(w, "button", "Keep these 4").Disabled == true and find(w, "button", "Keep everyone this time").Disabled == true,
    "D: both buttons disabled while the trim request runs")
local n9 = #applyRequests
applyCallback({ accepted = false, message = "A party change is already in progress." })
check(find(w, "button", "Keep these 4").Disabled == false and find(w, "button", "Keep everyone this time").Disabled == false,
    "D: a refusal enables them again")
applyReply = { accepted = true, message = "Changing the party..." }
check(n9 >= 1, "D: the trim request was sent")
check(not table.concat(clientLog, "\n"):find("could not draw"), "the picker drew without errors")

-- 10. 1.1.2 (docs/PLAN_1.1.2_live_roster.md).
reply = {
    maxSize = 6, setting = 6,
    entries = {
        { uuid = "a", name = "Tav", active = true, locked = true, avatar = true },
        { uuid = "b", name = "Gale", active = true },
        { uuid = "c", name = "Wyll", active = false },
    },
}
find(tab, "button", "Refresh").OnClick()
runTimers()
-- The server says someone on the tab changed: redraw, keeping ticks not yet applied.
check(channels.RosterChanged ~= nil and channels.RosterChanged.handler ~= nil, "10: RosterChanged handled")
find(tab, "checkbox", "Wyll").OnChange(nil, true)
before = rosterRequests
if channels.RosterChanged and channels.RosterChanged.handler then channels.RosterChanged.handler({}) end
runTimers()
check(rosterRequests == before + 1, "10: RosterChanged redraws the tab")
check(find(tab, "checkbox", "Wyll") and find(tab, "checkbox", "Wyll").Checked == true, "10: ... keeping the ticks")
-- The MCM window opens: redraw, keeping the status line.
check(subscribers["MCM_Window_Opened"] ~= nil, "10: MCM_Window_Opened subscribed")
channels["Notice"].handler({ text = "Party updated. Joined: Wyll." })
runTimers()
before = rosterRequests
if subscribers["MCM_Window_Opened"] then subscribers["MCM_Window_Opened"]({ playSound = true }) end
runTimers()
check(rosterRequests == before + 1, "10: opening the MCM window redraws the tab")
check(find(tab, "text", "Party updated. Joined: Wyll.") ~= nil, "10: ... keeping the status line")
-- A Refresh already in flight must not take the ticks kept for the redraw's own reply.
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "checkbox", "Wyll").OnChange(nil, true)
rosterHeld = {}
find(tab, "button", "Refresh").OnClick()   -- in flight
settingSaved("halsin_early")                -- the redraw that keeps Wyll ticked
runTimers()
local held = rosterHeld
rosterHeld = nil
for _, cb in ipairs(held) do cb(reply) end
check(#held == 2, "10: two roster requests in flight (got " .. #held .. ")")
check(find(tab, "checkbox", "Wyll") and find(tab, "checkbox", "Wyll").Checked == true,
    "10: the ticks survive a Refresh that was already in flight")
-- A refused Apply keeps the ticks and the reason, and redraws the list (someone may have left meanwhile).
find(tab, "checkbox", "Wyll").OnChange(nil, true)
applyReply = { accepted = false, message = "Gale is no longer with the party or in camp (the list was out of date)." }
before = rosterRequests
find(tab, "button", "Apply").OnClick()
runTimers()
applyReply = { accepted = true, message = "Changing the party..." }
check(rosterRequests == before + 1, "10: a refused Apply redraws the list")
check(find(tab, "checkbox", "Wyll") and find(tab, "checkbox", "Wyll").Checked == true, "10: ... keeping the ticks")
check(find(tab, "text", "Gale is no longer with the party or in camp (the list was out of date).") ~= nil,
    "10: ... and the reason")
-- A timer passes its own handle to the callback: drawn without kept ticks, no error.
local PartyTabM = Ext.Require("Client/PartyTab.lua")
local okT = pcall(PartyTabM.Refresh, 4242)
check(okT, "10: Refresh ignores a timer's argument")
check(not table.concat(clientLog, "\n"):find("could not"), "10: no drawing errors")

print(string.format("client: %d passed, %d failed", passed, failed))
if failed > 0 then error("client tests failed") end
