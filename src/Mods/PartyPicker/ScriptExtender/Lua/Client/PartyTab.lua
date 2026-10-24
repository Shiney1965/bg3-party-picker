-- Party Picker (client): the "Party" tab inside Mod Configuration Menu.
-- Lists everyone recruited; tick who should be in the party and press Apply.

local RosterList = Ext.Require("Client/RosterList.lua")

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

local function render(slot, reply)
    local root = slot.root
    RosterList.Clear(root)
    slot.status = nil

    local isHost = Ext.Net.IsHost()
    local entries = reply.entries or {}
    local limit = reply.maxSize or 4

    if reply.error then
        root:AddText("Could not read the party: " .. tostring(reply.error))
    end
    if not isHost then
        root:AddText("Only the host can change the party.")
    end
    root:AddText(string.format("Tick who should be in your party. Limit: %d (change it in Settings).", limit))
    root:AddSeparator()

    local countText
    local applyButton
    local function onChange(n)
        if countText then
            countText.Label = string.format("Selected %d of %d", n, limit)
        end
        if applyButton then applyButton.Disabled = (not isHost) or n > limit or n == 0 end
    end

    local list = RosterList.Draw(root, entries, { readOnly = not isHost, onChange = onChange })
    if #entries == 0 then root:AddText("Nobody recruited yet.") end

    root:AddSeparator()
    countText = root:AddText("")
    applyButton = root:AddButton("Apply")
    applyButton.OnClick = function()
        setStatus("Changing the party...")
        PP.Net.Apply:RequestToServer({ uuids = list:Selected() }, function(resp)
            setStatus(resp and resp.message or "No reply.")
            -- The change takes about a second; show the result afterwards.
            -- A refused request changed nothing: keep the ticks and the
            -- reason on screen instead of redrawing over them.
            if resp and resp.accepted then
                Ext.Timer.WaitForRealtime(1500, PartyTab.Refresh)
            end
        end)
    end
    local refresh = root:AddButton("Refresh")
    refresh.SameLine = true
    refresh.OnClick = function()
        setStatus("")
        slot.confirmCamp = false
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
    local movable, keepOffStage = 0, {}
    for _, e in ipairs(entries) do
        if e.active and not e.locked then
            if e.offStage then keepOffStage[#keepOffStage + 1] = e.uuid else movable = movable + 1 end
        end
    end
    if slot.confirmCamp then
        local text = string.format("Send %d party member%s to camp?", movable, movable == 1 and "" or "s")
        if #keepOffStage > 0 then
            text = text .. string.format(" (%d off stage stay%s.)", #keepOffStage, #keepOffStage == 1 and "s" or "")
        end
        root:AddText(text)
        local yes = root:AddButton("Yes, send them to camp")
        yes.IDContext = "PartyPicker_CampYes"
        yes.Disabled = (not isHost) or movable == 0
        yes.OnClick = function()
            yes.Disabled = true -- one request per confirmation
            slot.confirmCamp = false
            setStatus("Changing the party...")
            PP.Net.Apply:RequestToServer({ uuids = keepOffStage }, function(resp)
                setStatus(resp and resp.message or "No reply.")
                if resp and resp.accepted then
                    Ext.Timer.WaitForRealtime(1500, PartyTab.Refresh)
                else
                    PartyTab.Refresh()
                end
            end)
        end
        local cancel = root:AddButton("Cancel")
        cancel.IDContext = "PartyPicker_CampCancel"
        cancel.SameLine = true
        cancel.OnClick = function()
            slot.confirmCamp = false
            PartyTab.Refresh()
        end
    else
        local toCamp = root:AddButton("Send everyone to camp")
        toCamp.IDContext = "PartyPicker_CampAll"
        toCamp.SameLine = true
        toCamp.Disabled = (not isHost) or movable == 0
        toCamp.OnClick = function()
            slot.confirmCamp = true
            PartyTab.Refresh()
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
                Ext.Timer.WaitForRealtime(1500, PartyTab.Refresh)
            end)
        end
    end

    slot.status = root:AddText(lastStatus)
    onChange(list:Count())
end

function PartyTab.Refresh()
    if #roots == 0 then return end
    PP.Net.Roster:RequestToServer({}, function(reply)
        for _, slot in ipairs(roots) do
            local ok, err = pcall(render, slot, reply or {})
            if not ok then PP.Log("could not draw the Party list: " .. tostring(err)) end
        end
    end)
end

function PartyTab.SetStatus(text) setStatus(text) end

-- Our MCM page was opened: start with an empty status line, so a message
-- from an earlier visit is not taken for a fresh one.
function PartyTab.Activated()
    setStatus("")
    for _, slot in ipairs(roots) do slot.confirmCamp = false end
    PartyTab.Refresh()
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
