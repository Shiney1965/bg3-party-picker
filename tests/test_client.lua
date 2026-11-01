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
        function w:SetColor(name, value) self.color = { name, value } end
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

-- 11. 1.1.3 (docs/PLAN_1.1.3_dead_member_notice.md): a dead party member says why it cannot be unticked.
local MW = Ext.Require("Client/MessageWindow.lua")
local shown = {}
local showOrig = MW.Show
MW.Show = function(t) shown[#shown + 1] = t; return showOrig(t) end
local DEAD_TEXT = "Gale is dead. Dead party members cannot be removed from the party here. Revive them first "
    .. "(a scroll, a spell, or Withers once he is at your camp), or ask Withers to dismiss them."
reply = {
    maxSize = 6, setting = 6,
    entries = {
        { uuid = "a", name = "Tav", active = true, locked = true, avatar = true, lockReason = "player character" },
        { uuid = "b", name = "Gale", active = true, dead = true, locked = true, lockReason = "dead" },
        { uuid = "c", name = "Wyll", active = true },
        { uuid = "d", name = "Karlach", inCamp = true, dead = true },
    },
}
find(tab, "button", "Refresh").OnClick()
runTimers()
local gale = find(tab, "checkbox", "Gale  (dead)")
check(gale ~= nil, "11: a dead party member reads \"Gale  (dead)\", not \"(dead, dead)\"")
check(gale and gale.Checked == true and gale.Disabled ~= true, "11: ... ticked and clickable")
check(gale and gale.color and gale.color[1] == "Text", "11: ... its text drawn grey")
check(find(tab, "text", "Selected 3 of 6") ~= nil, "11: count before the click")
-- What ImGui does on a click: the box flips, then the queued OnChange runs.
local nApply = #applyRequests
if gale then gale.Checked = false; gale.OnChange(nil, false) end
check(gale and gale.Checked == true, "11: clicking it ticks it again")
check(find(tab, "text", DEAD_TEXT) ~= nil, "11: ... the reason is on the status line")
check(shown[#shown] == DEAD_TEXT, "11: ... and in the message window")
check(#applyRequests == nApply and find(tab, "text", "Selected 3 of 6") ~= nil, "11: ... no request, count unchanged")
-- Guards (already so in 1.1.2): Apply never sends the dead member; the others stay disabled.
find(tab, "button", "Apply").OnClick()
local sentGale = false
for _, u in ipairs((applyRequests[#applyRequests] or {}).uuids or {}) do if u == "b" then sentGale = true end end
check(#applyRequests == nApply + 1 and not sentGale, "11: guard: Apply does not send the dead member")
runTimers()
local karlach = find(tab, "checkbox", "Karlach  (dead, in camp)")
check(karlach and karlach.Disabled == true and karlach.Checked == false, "11: guard: a dead camp member stays disabled")
check(find(tab, "checkbox", "Tav  (you)") and find(tab, "checkbox", "Tav  (you)").Disabled == true,
    "11: guard: your own character stays disabled")
-- A dead player character is locked as "player character": no notice, still disabled.
reply.entries[1] = { uuid = "a", name = "Tav", active = true, locked = true, avatar = true, dead = true,
    lockReason = "player character" }
find(tab, "button", "Refresh").OnClick()
runTimers()
local tavDead = find(tab, "checkbox", "Tav  (you, dead)")
check(tavDead and tavDead.Disabled == true, "11: a dead player character stays disabled")
-- Read-only (not the host): the dead member's box is disabled like every other.
local isHostOrig = Ext.Net.IsHost
Ext.Net.IsHost = function() return false end
find(tab, "button", "Refresh").OnClick()
runTimers()
check(find(tab, "checkbox", "Gale  (dead)") and find(tab, "checkbox", "Gale  (dead)").Disabled == true,
    "11: guard: read-only, the dead member is disabled")
local shownRO = #shown
if find(tab, "checkbox", "Gale  (dead)") then find(tab, "checkbox", "Gale  (dead)").OnChange(nil, false) end
check(#shown == shownRO, "11: guard: read-only, no message window")
Ext.Net.IsHost = isHostOrig
find(tab, "button", "Refresh").OnClick()
runTimers()
-- Pick-four window: the click re-ticks and the reason goes to the window's own status line.
w = picker({ TAV, dead("d1", "Gale"), { uuid = "x", name = "Karlach", active = true },
    { uuid = "y", name = "Laezel", active = true }, { uuid = "z", name = "Wyll", active = true } })
local pgale = find(w, "checkbox", "Gale  (dead)")
check(pgale and pgale.Disabled ~= true, "11: pick-four: the dead member is clickable")
local shownPF = #shown
if pgale then pgale.Checked = false; pgale.OnChange(nil, false) end
check(pgale and pgale.Checked == true and find(w, "text", DEAD_TEXT) ~= nil, "11: pick-four: re-ticked, reason shown")
check(find(w, "text", "Selected 4 of 4") ~= nil, "11: pick-four: count unchanged")
check(#shown == shownPF, "11: pick-four: no message window over the picker")
check(not table.concat(clientLog, "\n"):find("could not"), "11: no drawing errors")

-- 12. 1.1.3 units G and H: a member the game holds stays ticked and says why; downed shows even when locked.
local HELD_TEXT = "Gale is downed, so they can't leave the party right now. Press Refresh once that has changed."
reply = {
    maxSize = 6, setting = 6,
    entries = {
        { uuid = "a", name = "Tav", active = true, locked = true, avatar = true, lockReason = "player character" },
        { uuid = "b", name = "Gale", active = true, downed = true,
          stuck = "cannot travel right now (DB_FastTravelBlock_CantMove_StatusSet)" },
        { uuid = "c", name = "Wyll", active = true,
          stuck = "can't talk right now (in a conversation, wild shape, or similar) (DB_CantTalk_IgnoreCombat)" },
        { uuid = "e", name = "Laezel", active = true, downed = true, locked = true, lockReason = "you are controlling them" },
        { uuid = "f", name = "Karlach", active = true },
    },
}
find(tab, "button", "Refresh").OnClick()
runTimers()
local hg = find(tab, "checkbox", "Gale  (downed, can't leave now)")
check(hg and hg.Checked == true and hg.Disabled ~= true and hg.color, "12: a held member is ticked, clickable, grey")
local lz = find(tab, "checkbox", "Laezel  (downed, you are controlling them)")
check(lz and lz.Disabled == true, "12: downed shows for the character you control (still locked)")
local beforeR = rosterRequests
if hg then hg.Checked = false; hg.OnChange(nil, false) end
check(hg and hg.Checked == true and find(tab, "text", HELD_TEXT) ~= nil and shown[#shown] == HELD_TEXT,
    "12: clicking a held member ticks it again and says why")
runTimers()
check(rosterRequests == beforeR + 1, "12: ... and redraws, in case it has passed")
local wy = find(tab, "checkbox", "Wyll  (can't leave now)")
if wy then wy.Checked = false; wy.OnChange(nil, false) end
check(shown[#shown] == "Wyll can't talk right now (in a conversation, wild shape, or similar), so they can't leave "
    .. "the party right now. Press Refresh once that has changed.", "12: the reason without the story table name")
-- Apply keeps a held member: their uuid is sent (the server would otherwise try to send them to camp).
find(tab, "button", "Apply").OnClick()
local sent12 = {}
for _, u in ipairs((applyRequests[#applyRequests] or {}).uuids or {}) do sent12[u] = true end
check(sent12.b and sent12.c and sent12.f, "12: Apply sends the held members as staying")
runTimers()
-- An untick kept from before the member was held is dropped when they become held.
reply.entries[2] = { uuid = "b", name = "Gale", active = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
local g2 = find(tab, "checkbox", "Gale")
if g2 then g2.Checked = false; g2.OnChange(nil, false) end
reply.entries[2] = { uuid = "b", name = "Gale", active = true, downed = true,
    stuck = "cannot travel right now (DB_FastTravelBlock_CantMove_StatusSet)" }
settingSaved("halsin_early")
runTimers()
local g3 = find(tab, "checkbox", "Gale  (downed, can't leave now)")
check(g3 and g3.Checked == true, "12: an untick not yet applied is dropped once the member is held")
find(tab, "button", "Apply").OnClick()
local sent12b = false
for _, u in ipairs((applyRequests[#applyRequests] or {}).uuids or {}) do if u == "b" then sent12b = true end end
check(sent12b, "12: ... and Apply sends them as staying")
runTimers()
check(not table.concat(clientLog, "\n"):find("could not"), "12: no drawing errors")

-- 13. 1.1.3 unit I: "Let Halsin join early" ticked where it cannot apply.
local IDLE = "\"Let Halsin join early\" has no effect in this game: his quest at Last Light is under way, so he can "
    .. "join once Thaniel is saved, as in the base game. The setting stays ticked for your other saves."
reply.halsinEarlyIdle = IDLE
local shown13 = #shown
subscribers["MCM_Setting_Saved"]({ modUUID = ModuleUUID, settingId = "halsin_early", value = true })
runTimers()
check(#shown == shown13 + 1 and shown[#shown] == IDLE, "13: ticking it says why at once")
local tabText = {}
for _, k in ipairs(tab.Children) do if k.kind == "text" then tabText[#tabText + 1] = tostring(k.Label) end end
check(table.concat(tabText, " "):find("has no effect in this game", 1, true), "13: the Party tab says it too")
shown13 = #shown
subscribers["MCM_Setting_Saved"]({ modUUID = ModuleUUID, settingId = "halsin_early", value = false })
runTimers()
check(#shown == shown13, "13: unticking it says nothing")
reply.halsinEarlyIdle = nil
shown13 = #shown
subscribers["MCM_Setting_Saved"]({ modUUID = ModuleUUID, settingId = "halsin_early", value = true })
runTimers()
check(#shown == shown13, "13: no message when it applies")

-- 14. 1.1.4 (docs/PLAN_1.1.4_final_review_fixes.md).
local DEAD_PC = "Your character (Tav) is dead. Party Picker can't change the party until they are revived (a "
    .. "scroll, a spell, or Withers once he is at your camp)."
local function tabTexts()
    local t = {}
    for _, k in ipairs(tab.Children) do if k.kind == "text" then t[#t + 1] = tostring(k.Label) end end
    return table.concat(t, " ")
end
reply = {
    maxSize = 6, setting = 6, hostDead = DEAD_PC,
    entries = {
        { uuid = "a", name = "Tav", active = true, locked = true, avatar = true, dead = true, lockReason = "player character" },
        { uuid = "b", name = "Gale", active = true },
        { uuid = "c", name = "Wyll", active = false, inCamp = true },
        { uuid = "d", name = "Minsc", active = false, inCamp = true,
          joinBlocked = "can't move right now (in a conversation, knocked out, or similar) (DB_CantMove)" },
    },
}
find(tab, "button", "Refresh").OnClick()
runTimers()
check(tabTexts():find("is dead. Party Picker can't change the party", 1, true), "14A: the tab says your character is dead")
-- A refusal for death opens the message window.
applyReply = { accepted = false, message = DEAD_PC, hostDead = true }
local shown14 = #shown
find(tab, "checkbox", "Gale").OnChange(nil, false)
find(tab, "button", "Apply").OnClick()
check(#shown == shown14 + 1 and shown[#shown] == DEAD_PC, "14A: the refusal comes in the message window")
applyReply = { accepted = true, message = "Changing the party..." }
runTimers()
reply.hostDead = nil
reply.entries[1] = { uuid = "a", name = "Tav", active = true, locked = true, avatar = true, lockReason = "player character" }
-- C. A camp member the game holds: fixed unticked, a click says why, Apply never sends them.
find(tab, "button", "Refresh").OnClick()
runTimers()
local minsc = find(tab, "checkbox", "Minsc  (in camp, can't join now)")
check(minsc and minsc.Checked == false and minsc.Disabled ~= true, "14C: a held camp member: unticked, clickable")
if minsc then minsc.Checked = true; minsc.OnChange(nil, true) end
check(minsc and minsc.Checked == false and shown[#shown] == "Minsc can't move right now (in a conversation, knocked "
    .. "out, or similar), so they can't join the party right now. Press Refresh once that has changed.",
    "14C: clicking keeps it unticked and says why")
runTimers()
find(tab, "button", "Apply").OnClick()
local sentMinsc = false
for _, u in ipairs((applyRequests[#applyRequests] or {}).uuids or {}) do if u == "d" then sentMinsc = true end end
check(not sentMinsc, "14C: Apply does not send them")
runTimers()
-- D. The combat setting redraws the tab.
local beforeD = rosterRequests
settingSaved("block_in_combat")
runTimers()
check(rosterRequests > beforeD, "14D: block_in_combat redraws the tab")
-- E. A tick made after an accepted Apply survives the redraw after it; the change itself shows as it is.
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "checkbox", "Gale").OnChange(nil, false)
find(tab, "button", "Apply").OnClick()             -- accepted: Gale goes to camp
find(tab, "checkbox", "Wyll  (in camp)").OnChange(nil, true) -- ticked after the press
reply.entries[2] = { uuid = "b", name = "Gale", active = false, inCamp = true }
runTimers()
check(find(tab, "checkbox", "Wyll  (in camp)") and find(tab, "checkbox", "Wyll  (in camp)").Checked == true,
    "14E: a tick made after the press survives the redraw")
check(find(tab, "checkbox", "Gale  (in camp)") and find(tab, "checkbox", "Gale  (in camp)").Checked == false,
    "14E: the change shows as it is")
-- E. While the change runs (busy), the ticks it sent are shown, not the party as it was.
reply.entries[2] = { uuid = "b", name = "Gale", active = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "checkbox", "Gale").OnChange(nil, false)
find(tab, "button", "Apply").OnClick()
reply.busy = true
runTimers()
check(find(tab, "checkbox", "Gale") and find(tab, "checkbox", "Gale").Checked == false,
    "14E: while the change runs, Gale shows as sent (unticked)")
reply.busy = nil
reply.entries[2] = { uuid = "b", name = "Gale", active = false, inCamp = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
-- E. Cancel on "Send everyone to camp" keeps the ticks not yet applied.
reply.entries[2] = { uuid = "b", name = "Gale", active = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "checkbox", "Wyll  (in camp)").OnChange(nil, true)
find(tab, "button", "Send everyone to camp").OnClick()
runTimers()
find(tab, "button", "Cancel").OnClick()
runTimers()
check(find(tab, "checkbox", "Wyll  (in camp)") and find(tab, "checkbox", "Wyll  (in camp)").Checked == true,
    "14E: Cancel keeps the ticks not yet applied")
-- E. "Send everyone to camp" > Yes: those sent to camp are not shown ticked afterwards (diff review 2026-11-01).
reply.entries[2] = { uuid = "b", name = "Gale", active = true }
reply.entries[3] = { uuid = "c", name = "Wyll", active = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "button", "Send everyone to camp").OnClick()
runTimers()
find(tab, "button", "Yes, send them to camp").OnClick()
reply.entries[2] = { uuid = "b", name = "Gale", active = false, inCamp = true }
reply.entries[3] = { uuid = "c", name = "Wyll", active = false, inCamp = true }
runTimers()
check(find(tab, "checkbox", "Gale  (in camp)") and find(tab, "checkbox", "Gale  (in camp)").Checked == false
    and find(tab, "checkbox", "Wyll  (in camp)").Checked == false, "14E: after Send everyone to camp, they show unticked")
subscribers["MCM_Window_Opened"]({})
runTimers()
check(find(tab, "checkbox", "Gale  (in camp)").Checked == false and find(tab, "checkbox", "Wyll  (in camp)").Checked == false,
    "14E: ... and stay unticked on the next redraw")
reply.entries[3] = { uuid = "c", name = "Wyll", active = false, inCamp = true }
-- E. "Send everyone to camp" with a redraw while it still runs, then the game leaves Gale in the party: he shows
-- ticked again (re-review 2026-11-01: the baseline is what the list was drawn from).
reply.entries[2] = { uuid = "b", name = "Gale", active = true }
reply.entries[3] = { uuid = "c", name = "Wyll", active = true }
find(tab, "button", "Refresh").OnClick()
runTimers()
find(tab, "button", "Send everyone to camp").OnClick()
runTimers()
find(tab, "button", "Yes, send them to camp").OnClick()
reply.busy = true
runTimers()                                   -- the 1.5 s redraw comes while the change runs
reply.busy = nil                              -- done: Wyll went, Gale "did not leave"
reply.entries[3] = { uuid = "c", name = "Wyll", active = false, inCamp = true }
subscribers["MCM_Window_Opened"]({})
runTimers()
check(find(tab, "checkbox", "Gale") and find(tab, "checkbox", "Gale").Checked == true
    and find(tab, "checkbox", "Wyll  (in camp)") and find(tab, "checkbox", "Wyll  (in camp)").Checked == false,
    "14E: a change that left someone in the party shows them ticked again")
-- A. A notice about the host's own character is not shown to other players.
Ext.Net.IsHost = function() return false end
local statusBefore = find(tab, "text", "HOSTONLY")
channels["Notice"].handler({ text = "HOSTONLY", kind = "warning", hostOnly = true })
check(statusBefore == nil and find(tab, "text", "HOSTONLY") == nil, "14A: a host-only notice: not in other players' status line")
Ext.Net.IsHost = isHostOrig
-- A. Another player (not the host) does not see the host's "your character is dead" line.
reply.hostDead = DEAD_PC
Ext.Net.IsHost = function() return false end
find(tab, "button", "Refresh").OnClick()
runTimers()
check(not tabTexts():find("is dead. Party Picker", 1, true), "14A: not shown to other players")
Ext.Net.IsHost = isHostOrig
reply.hostDead = nil
-- Pick-four window: a failed roster read, your character dead, a held camp member, auto-restore off.
local w14 = picker({ TAV, { uuid = "x", name = "Karlach", active = true }, { uuid = "y", name = "Laezel", active = true },
    { uuid = "z", name = "Gale", active = true }, { uuid = "q", name = "Wyll", active = true },
    { uuid = "m", name = "Minsc", inCamp = true, joinBlocked = "can't move right now (in a conversation) (DB_CantMove)" } })
local mins4 = find(w14, "checkbox", "Minsc  (in camp, can't join now: can't move right now (in a conversation))")
check(mins4 and mins4.Disabled == true and find(w14, "text", "Selected 4 of 4"), "14C: pick-four: held camp member locked, not optional")
reply = { error = "boom", entries = {} }
channels["PickFour"].handler({ reason = "rest", size = 4 })
local wErr = windows[1]
check(find(wErr, "text", "Could not read the party: boom") and find(wErr, "button", "Keep these 0")
    and find(wErr, "button", "Keep these 0").Disabled == true, "14I: pick-four: a failed read says so, no trim")
reply = { hostDead = DEAD_PC, entries = { TAV } }
channels["PickFour"].handler({ reason = "rest", size = 4 })
check(find(windows[1], "text", DEAD_PC), "14A: pick-four: says your character is dead")
MCM.Get = function(id) if id == "auto_restore" then return false end end
reply = { entries = { TAV } }
channels["PickFour"].handler({ reason = "rest", size = 4 })
check(find(windows[1], "text", "until you press Restore on the Party tab after the rest."), "14J: auto-restore off: the text says so")
MCM.Get = nil
check(not table.concat(clientLog, "\n"):find("could not"), "14: no drawing errors")
MW.Show = showOrig

print(string.format("client: %d passed, %d failed", passed, failed))
if failed > 0 then error("client tests failed") end
