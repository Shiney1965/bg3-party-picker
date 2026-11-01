-- Party Picker (client): the "Party" tab inside Mod Configuration Menu.
-- Lists everyone recruited; tick who should be in the party and press Apply.

local RosterList = Ext.Require("Client/RosterList.lua")
local MessageWindow = Ext.Require("Client/MessageWindow.lua")

local PartyTab = {}

-- Containers we draw into: the MCM tab and/or the !pp window. Each keeps
-- its own status line.
local roots = {}

-- The last status text. Redrawing the list makes a new status line, so the
-- text is kept here and put back; otherwise a message such as a refusal
-- vanishes with the next redraw (reported in game 2026-10-12).
local lastStatus = ""

local function setStatus(text)
    lastStatus = tostring(text or "")
    for _, r in ipairs(roots) do
        if r.status then pcall(function() r.status.Label = lastStatus end) end
    end
end

-- Roster requests are numbered, so a reply requested before a press cannot be taken for its outcome.
local reqSeq = 0

-- uuids -> true, for a list of uuids.
local function set(uuids)
    local s = {}
    for _, u in ipairs(uuids or {}) do s[u] = true end
    return s
end

-- An accepted change: what it sent is shown until a reply requested after it says the change is done
-- (`busy` false), and only ticks changed after the press are kept (final review 2026-11-01, finding 7).
-- Two sets, as "Send everyone to camp" sends fewer than are ticked on screen (diff review 2026-11-01):
-- sentTicks = shown while the change runs; baseline = what the list on screen was drawn from (the ticks
-- on screen at the press, then sentTicks once a busy reply drew them, then nothing: the party), so the
-- ticks kept are only the player's own (re-review 2026-11-01).
local function sent(slot, sentUuids, screenUuids)
    slot.sentTicks, slot.baseline, slot.sentSeq = set(sentUuids), set(screenUuids or sentUuids), reqSeq
end

local function render(slot, reply, keep, seq)
    local root = slot.root
    RosterList.Clear(root)
    slot.status = nil
    if slot.sentTicks and (seq or 0) > (slot.sentSeq or 0) and not reply.busy then slot.sentTicks = nil end
    local sentTicks = slot.sentTicks
    slot.baseline = sentTicks

    local isHost = Ext.Net.IsHost()
    local entries = reply.entries or {}
    local limit = reply.maxSize or 4

    if reply.error then
        root:AddText("Could not read the party: " .. tostring(reply.error))
    end
    if not isHost then
        root:AddText("Only the host can change the party.")
    end
    local setting = reply.setting or limit
    if limit > setting then
        root:AddText(string.format("Tick who should be in your party. Limit: %d (your setting %d, raised to fit the party).", limit, setting))
    else
        root:AddText(string.format("Tick who should be in your party. Limit: %d (change it in Settings).", limit))
    end
    -- Your own character is dead (plan 1.1.4 unit A): the server refuses every change until they are revived.
    -- The host's character: not shown to other players (diff review 2026-11-01).
    if reply.hostDead and isHost then
        for _, line in ipairs(MessageWindow.Wrap(tostring(reply.hostDead), 100)) do root:AddText(line) end
    end
    -- "Let Halsin join early" ticked where it cannot apply (the server's HalsinRepair.EarlyIdleText).
    if reply.halsinEarlyIdle then
        for _, line in ipairs(MessageWindow.Wrap(tostring(reply.halsinEarlyIdle), 100)) do root:AddText(line) end
    end
    root:AddSeparator()

    local countText
    local applyButton
    local function onChange(n)
        if countText then
            countText.Label = string.format("Selected %d of %d%s", n, limit, n > limit and " (over the limit)" or "")
        end
        -- Over the limit, Apply stays clickable and explains instead (plan Part E).
        if applyButton then applyButton.Disabled = (not isHost) or n == 0 end
    end

    -- After a settings change the ticks not yet applied are kept (PartyTab.SettingChanged); each reply
    -- draws with the copy made for its own request, so a Refresh already in flight cannot take them.
    local preselect = nil
    if keep or sentTicks then
        preselect = function(e)
            if keep and keep[e.uuid] ~= nil then return keep[e.uuid] end
            if sentTicks then return sentTicks[e.uuid] == true end
            return e.active == true
        end
    end
    -- A click on a dead or held party member: the reason in the status line and in the message window, and a
    -- redraw (ticks kept), in case what held them has already passed (plan review 2026-11-01, unit G).
    local function onLocked(_, text)
        setStatus(text)
        MessageWindow.Show(text)
        pcall(PartyTab.SettingChanged)
    end
    local list = RosterList.Draw(root, entries, { readOnly = not isHost, onChange = onChange, preselect = preselect,
        onLocked = onLocked })
    slot.list, slot.entries = list, entries
    if #entries == 0 then root:AddText("Nobody recruited yet.") end

    root:AddSeparator()
    countText = root:AddText("")
    applyButton = root:AddButton("Apply")
    applyButton.OnClick = function()
        local n = list:Count()
        if n > limit then
            local over = n - limit
            MessageWindow.Show(string.format("You have ticked %d, but the party limit is %d. Untick %d, or raise "
                .. "the Maximum party size in Settings.", n, limit, over))
            return
        end
        setStatus("Changing the party...")
        local uuids = list:Selected()
        PP.Net.Apply:RequestToServer({ uuids = uuids }, function(resp)
            setStatus(resp and resp.message or "No reply.")
            if resp and resp.hostDead then MessageWindow.Show(resp.message) end
            -- The change takes about a second; show the result afterwards.
            -- A refused request changed nothing: keep the ticks and the reason on screen, but redraw the
            -- list, so someone who has left the party meanwhile drops out of it (diff review 2026-10-31).
            if resp and resp.accepted then
                sent(slot, uuids)
                Ext.Timer.WaitForRealtime(1500, PartyTab.Redraw)
            else
                pcall(PartyTab.SettingChanged)
            end
        end)
    end
    local refresh = root:AddButton("Refresh")
    refresh.SameLine = true
    refresh.OnClick = function()
        setStatus("")
        slot.confirmCamp = false
        slot.confirmHalsin = false
        slot.sentTicks, slot.baseline = nil, nil
        PartyTab.Refresh()
    end

    -- One click to camp for everyone who can go. The request is the same as
    -- Apply with nobody else ticked, so the server keeps the locked members
    -- (you, the character you control, other players' characters, the dead)
    -- and makes every check Apply makes. Party members who are off stage are
    -- kept as well: the game does not move them (see RosterList), and asking
    -- would refuse the whole request. It asks once first; every redraw goes
    -- through PartyTab.Refresh, which fetches the party again, so the count
    -- is current and no button is destroyed while its own click is running.
    -- Members the game holds right now (`stuck`) are kept the same way.
    local movable, keepOffStage, staying, avatarName = 0, {}, 0, nil
    local heldCount = 0
    for _, e in ipairs(entries) do
        if e.active and not e.locked then
            if e.offStage or e.stuck then keepOffStage[#keepOffStage + 1] = e.uuid else movable = movable + 1 end
            if e.stuck and not e.offStage then heldCount = heldCount + 1 end
        end
        if e.active and e.locked then staying = staying + 1 end
        if e.active and e.avatar and not avatarName then avatarName = e.name end
    end
    staying = staying + #keepOffStage
    if slot.confirmCamp then
        local text = string.format("Send %d party member%s to camp?", movable, movable == 1 and "" or "s")
        local offCount = #keepOffStage - heldCount
        if offCount > 0 then
            text = text .. string.format(" (%d off stage stay%s.)", offCount, offCount == 1 and "s" or "")
        end
        if heldCount > 0 then
            text = text .. string.format(" (%d who can't leave right now stay%s.)", heldCount, heldCount == 1 and "s" or "")
        end
        root:AddText(text)
        local yes = root:AddButton("Yes, send them to camp")
        yes.IDContext = "PartyPicker_CampYes"
        yes.Disabled = (not isHost) or movable == 0
        yes.OnClick = function()
            yes.Disabled = true -- one request per confirmation
            slot.confirmCamp = false
            setStatus("Changing the party...")
            local onScreen = slot.list and slot.list:Selected() or {}
            PP.Net.Apply:RequestToServer({ uuids = keepOffStage }, function(resp)
                setStatus(resp and resp.message or "No reply.")
                if resp and resp.hostDead then MessageWindow.Show(resp.message) end
                if resp and resp.accepted then
                    sent(slot, keepOffStage, onScreen)
                    -- Alone afterwards: the game hides the party portraits for a party of
                    -- one (Game.pak PlayerPortraits.xaml L194-207), which looks as if the
                    -- character has gone (reported in game 2026-10-25). Say what happened.
                    if staying == 1 then
                        -- Checked once the change is done (it takes about a second): only if the party
                        -- really is down to one.
                        Ext.Timer.WaitForRealtime(1500, function()
                            PP.Net.Roster:RequestToServer({}, function(after)
                                local active = 0
                                for _, e in ipairs((after and after.entries) or {}) do
                                    if e.active then active = active + 1 end
                                end
                                if active ~= 1 then return end
                                MessageWindow.Show(string.format("Everyone else has gone to camp. The game hides "
                                    .. "the party portraits when your character is alone, but %s is still with "
                                    .. "you and under your control. To bring companions back, tick them on the "
                                    .. "Party tab and press Apply. If you are in camp, leave camp the usual way "
                                    .. "to return to the world.", avatarName or "your character"))
                            end)
                        end)
                    end
                    Ext.Timer.WaitForRealtime(1500, PartyTab.Redraw)
                else
                    PartyTab.Redraw()
                end
            end)
        end
        local cancel = root:AddButton("Cancel")
        cancel.IDContext = "PartyPicker_CampCancel"
        cancel.SameLine = true
        cancel.OnClick = function()
            slot.confirmCamp = false
            PartyTab.Redraw()
        end
    else
        local toCamp = root:AddButton("Send everyone to camp")
        toCamp.IDContext = "PartyPicker_CampAll"
        toCamp.SameLine = true
        toCamp.Disabled = (not isHost) or movable == 0
        toCamp.OnClick = function()
            slot.confirmCamp = true
            PartyTab.Redraw()
        end
    end

    if reply.pending and reply.pending.trimmed then
        root:AddSeparator()
        root:AddText("Some of your party are waiting in camp after a long rest.")
        local restore = root:AddButton("Restore")
        restore.Disabled = not isHost
        restore.OnClick = function()
            setStatus("Restoring...")
            PP.Net.Restore:RequestToServer({}, function(resp)
                setStatus(resp and resp.message or "No reply.")
                if resp and resp.hostDead then MessageWindow.Show(resp.message) end
                Ext.Timer.WaitForRealtime(1500, PartyTab.Redraw)
            end)
        end
    end

    -- Halsin joined before the story allowed it (docs/PLAN_halsin_early_option.md): the server sends
    -- `halsin` only then. Asks once first, as "Send everyone to camp" does.
    local hal = reply.halsin
    if hal then
        root:AddSeparator()
        root:AddText("Halsin joined before the story allowed it, so his quest at Last Light won't start by itself.")
        root:AddText("Before talking to Art Cullagh, put it back on track here.")
        if hal.why then
            root:AddText(tostring(hal.why))
            slot.confirmHalsin = false -- a confirmation must not come back by itself later
        end
        if slot.confirmHalsin and not hal.why then
            root:AddText((hal.inParty and "This sends Halsin to camp and puts" or "This puts")
                .. " his quest back where the story expects it. Make a hard save first. Continue?")
            local yes = root:AddButton("Yes, put it back on track")
            yes.IDContext = "PartyPicker_HalsinYes"
            yes.Disabled = not isHost
            yes.OnClick = function()
                yes.Disabled = true -- one request per confirmation
                slot.confirmHalsin = false
                setStatus("Putting Halsin's quest back on track...")
                PP.Net.HalsinReset:RequestToServer({}, function(resp)
                    setStatus(resp and resp.message or "No reply.")
                    -- Sending him to camp takes about a second; the outcome comes in a message window.
                    if resp and resp.accepted then
                        Ext.Timer.WaitForRealtime(1500, PartyTab.Redraw)
                    else
                        PartyTab.Redraw()
                    end
                end)
            end
            local cancel = root:AddButton("Cancel")
            cancel.IDContext = "PartyPicker_HalsinCancel"
            cancel.SameLine = true
            cancel.OnClick = function()
                slot.confirmHalsin = false
                PartyTab.Redraw()
            end
        else
            local button = root:AddButton("Put Halsin's quest back on track")
            button.IDContext = "PartyPicker_HalsinReset"
            button.Disabled = (not isHost) or hal.why ~= nil
            button.OnClick = function()
                slot.confirmHalsin = true
                PartyTab.Redraw()
            end
        end
    end

    slot.status = root:AddText(lastStatus)
    onChange(list:Count())
end

-- keepBySlot (optional): slot -> { uuid = ticked } for ticks not yet applied, drawn with this reply only.
-- Timers may pass their own argument, so anything but a table means none.
function PartyTab.Refresh(keepBySlot)
    if #roots == 0 then return end
    if type(keepBySlot) ~= "table" then keepBySlot = nil end
    reqSeq = reqSeq + 1
    local mySeq = reqSeq
    PP.Net.Roster:RequestToServer({}, function(reply)
        for _, slot in ipairs(roots) do
            local ok, err = pcall(render, slot, reply or {}, keepBySlot and keepBySlot[slot] or nil, mySeq)
            if not ok then PP.Log("could not draw the Party list: " .. tostring(err)) end
        end
    end)
end

function PartyTab.SetStatus(text) setStatus(text) end

-- A setting the tab shows was changed in Settings (or written back by the limit guard): redraw, so
-- the limit line and the locks follow without pressing Refresh (reported in game 2026-10-27). A slider
-- sends a change for every step, so only the last one in half a second redraws. Ticks not yet applied
-- are kept. Also used when the party changed in the game (RosterChanged) and when the MCM window opens.
local settingSeq = 0

-- Redraw now, keeping the ticks the player has not applied yet (final review 2026-11-01, finding 7: the
-- redraws after a change, a confirmation or a Cancel used to start fresh and drop them). Timers pass their
-- own argument; it is ignored.
function PartyTab.Redraw()
    local keepBySlot = {}
    for _, slot in ipairs(roots) do
        if slot.list and slot.entries then
            -- Only the ticks the player changed: anything else shows the party as it is now, so a
            -- change the game made meanwhile is not undone by the next Apply. While a change runs, the
            -- baseline is what the list was drawn from instead of the party.
            local selected = {}
            for _, uuid in ipairs(slot.list:Selected()) do selected[uuid] = true end
            local keep = {}
            for _, e in ipairs(slot.entries) do
                local ticked = selected[e.uuid] == true
                local was
                if slot.baseline then was = slot.baseline[e.uuid] == true else was = e.active == true end
                if not e.locked and not e.dead and ticked ~= was then keep[e.uuid] = ticked end
            end
            keepBySlot[slot] = keep
        end
    end
    -- pcall: this may run when no game is loaded (MCM opened at the main menu).
    local ok, err = pcall(PartyTab.Refresh, keepBySlot)
    if not ok then PP.Log("could not redraw the Party tab: " .. tostring(err)) end
end

function PartyTab.SettingChanged()
    settingSeq = settingSeq + 1
    local mySeq = settingSeq
    Ext.Timer.WaitForRealtime(500, function()
        if mySeq ~= settingSeq then return end
        PartyTab.Redraw()
    end)
end

-- Our MCM page was opened: start with an empty status line, so a message
-- from an earlier visit is not taken for a fresh one.
function PartyTab.Activated()
    settingSeq = settingSeq + 1 -- a redraw still waiting would carry the old ticks over
    setStatus("")
    for _, slot in ipairs(roots) do
        slot.confirmCamp = false
        slot.confirmHalsin = false
    end
    PartyTab.Refresh()
end

-- "Let Halsin join early" was just ticked: if it cannot apply in this game, say why at once, whether or not
-- the Party tab was ever drawn (the author, 2026-11-01).
function PartyTab.HalsinEarlyTicked()
    PP.Net.Roster:RequestToServer({}, function(reply)
        local text = reply and reply.halsinEarlyIdle
        if text then MessageWindow.Show(text) end
    end)
end

-- Draw into any IMGUI container (the MCM tab, or a standalone window).
function PartyTab.Attach(container)
    local known = false
    for _, slot in ipairs(roots) do
        if slot.root == container then known = true end
    end
    if not known then roots[#roots + 1] = { root = container } end
    container:AddText("Loading...")
    PartyTab.Refresh()
end

return PartyTab
