-- Party Picker (client): the window that appears when the game needs a party
-- of four (long rest) and the party is larger.

local RosterList = Ext.Require("Client/RosterList.lua")

local PickFour = {}

local window = nil

-- With "Bring the party back after the rest" off, the others only get a reminder in the morning
-- (Server/Restrictions.lua autoRestore), so the text says so (final review 2026-11-01, finding 12).
local function intro(reason)
    if reason ~= "rest" then return nil end
    local lines = {
        "The camp has four beds, and the game only puts four party members to bed.",
        "Choose who stays with you tonight. The others wait in camp",
    }
    if PP.Setting("auto_restore", true) == false then
        lines[#lines + 1] = "until you press Restore on the Party tab after the rest."
    else
        lines[#lines + 1] = "and rejoin when you wake up."
    end
    return lines
end

local function ensureWindow()
    if window then
        RosterList.Clear(window)
        return window
    end
    window = Ext.IMGUI.NewWindow("Party Picker")
    window.Closeable = true
    window.AlwaysAutoResize = true
    pcall(function()
        local size = Ext.IMGUI.GetViewportSize()
        if size and size[1] and size[2] then
            -- FirstUseEver so the player can still drag it elsewhere.
            window:SetPos({ math.floor(size[1] * 0.5) - 250, math.floor(size[2] * 0.2) }, "FirstUseEver")
        end
    end)
    return window
end

local function close()
    if window then window.Open = false end
end

local function showMessage(text)
    local w = ensureWindow()
    w:AddText(tostring(text))
    local ok = w:AddButton("OK")
    ok.OnClick = close
    w.Open = true
end

local function render(reason, size, reply)
    local w = ensureWindow()
    for _, line in ipairs(intro(reason) or { "Choose " .. size .. " party members." }) do
        w:AddText(line)
    end
    -- A failed roster read: no list to choose from; only "Keep everyone this time" (finding 11).
    if reply.error then w:AddText("Could not read the party: " .. tostring(reply.error)) end
    -- Your own character is dead: the server refuses the trim (plan 1.1.4 unit A).
    if reply.hostDead then w:AddText(tostring(reply.hostDead)) end
    w:AddSeparator()

    -- Party members the game will not let go right now (`stuck`, the server's own check) are drawn
    -- locked and always sent, as the server would refuse the whole change without them.
    local entries, stuck = {}, {}
    for i, e in ipairs(reply.entries or {}) do
        if e.active and not e.locked and e.stuck then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            -- The story table in brackets left out of the label, as in RosterList.HeldText (diff review 2026-11-01).
            copy.locked, copy.lockReason = true,
                "can't leave now: " .. (string.gsub(tostring(e.stuck), " %([%u_][%w_]*%)", ""))
            entries[i] = copy
            stuck[#stuck + 1] = e.uuid
        elseif not e.active and not e.locked and not e.dead and e.joinBlocked then
            -- A camp member the game holds: the server would refuse them, so they are locked here and not
            -- counted as optional (final review 2026-11-01, finding 3).
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            copy.locked, copy.lockReason = true,
                "can't join now: " .. (string.gsub(tostring(e.joinBlocked), " %([%u_][%w_]*%)", ""))
            entries[i] = copy
        else
            entries[i] = e
        end
    end

    -- Mandatory: party members this mod keeps whatever is ticked (players' characters, the dead, the
    -- stuck). They count towards the four (the server keeps them: Server/Party.lua Apply), so the dead
    -- are counted too (review 2026-10-31, point 7). Optional: anyone else alive, in the party or in camp.
    local mandatory, optional = 0, 0
    for _, e in ipairs(entries) do
        if e.locked and e.active then mandatory = mandatory + 1
        elseif not e.locked and not e.dead then optional = optional + 1 end
    end
    local need = math.min(size, mandatory + optional)

    -- Start from the members already in the party, in roster order
    -- (your own character first), up to the size.
    local taken = mandatory
    local pre = {}
    for _, e in ipairs(entries) do
        if e.active and not e.locked and not e.dead and taken < size then
            pre[e.uuid] = true
            taken = taken + 1
        end
    end

    if mandatory > size then
        -- Several players' characters (or members the game holds): this mod never moves those.
        w:AddText(string.format("%d party members cannot be sent to camp right now,", mandatory))
        w:AddText("so the party cannot be trimmed to four here.")
    elseif optional == 0 or mandatory == need then
        w:AddText("Nobody else can be chosen tonight.")
    end
    local lockedCount = mandatory

    local countText, confirm, status
    local requestRunning = false
    local function onChange(n)
        if countText then countText.Label = string.format("Selected %d of %d", n, need) end
        if confirm then
            confirm.Disabled = requestRunning or (n ~= need) or lockedCount > size or reply.error ~= nil
        end
    end

    local list = RosterList.Draw(w, entries, {
        preselect = function(e) return pre[e.uuid] == true end,
        onChange = onChange,
        -- A click on a dead party member: the reason in this window's status line.
        onLocked = function(_, text) if status then status.Label = text end end,
    })

    w:AddSeparator()
    countText = w:AddText("")
    status = w:AddText("")

    -- One request at a time: the first click on either button disables both until the server has
    -- answered; a refusal enables them again (review 2026-10-31, point 2).
    local keepAll
    local function setBusy(on)
        requestRunning = on
        onChange(list:Count())
        if keepAll then keepAll.Disabled = on end
    end

    confirm = w:AddButton("Keep these " .. need)
    confirm.OnClick = function()
        setBusy(true)
        status.Label = "Changing the party..."
        local uuids = list:Selected()
        for _, u in ipairs(stuck) do uuids[#uuids + 1] = u end
        PP.Net.Apply:RequestToServer({ uuids = uuids, reason = reason }, function(resp)
            if resp and resp.accepted then
                -- The server sends a Notice with the outcome; it replaces this window.
                status.Label = resp.message or ""
            else
                status.Label = (resp and resp.message) or "No reply."
                setBusy(false)
            end
        end)
    end

    keepAll = w:AddButton("Keep everyone this time")
    keepAll.SameLine = true
    keepAll.OnClick = function()
        setBusy(true)
        PP.Net.Apply:RequestToServer({ reason = reason, keepAll = true }, function(resp)
            if resp and resp.accepted then
                RosterList.Clear(w)
                showMessage(resp.message or "")
            else
                status.Label = (resp and resp.message) or "No reply."
                setBusy(false)
            end
        end)
    end

    onChange(list:Count())
    w.Open = true
end

function PickFour.Show(reason, size)
    if not Ext.Net.IsHost() then return end
    size = size or 4
    PP.Net.Roster:RequestToServer({}, function(reply)
        local ok, err = pcall(render, reason, size, reply or {})
        if not ok then PP.Log("could not draw the picker: " .. tostring(err)) end
    end)
end

-- Outcome of a party change started from this window.
function PickFour.Notice(text)
    if window and window.Open then
        RosterList.Clear(window)
        showMessage(text)
    end
end

return PickFour
