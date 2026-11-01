-- Party Picker (client): one checkbox per character, used by both the MCM
-- Party tab and the pick-four window.

local RosterList = {}

-- Children is a live array; copy before destroying or half are skipped.
function RosterList.Clear(parent)
    local kids = {}
    for _, child in ipairs(parent.Children or {}) do kids[#kids + 1] = child end
    for _, child in ipairs(kids) do pcall(function() child:Destroy() end) end
end

local function label(e)
    local tags = {}
    if e.avatar then tags[#tags + 1] = "you" end
    if e.hireling then tags[#tags + 1] = "hireling" end
    if e.dead then tags[#tags + 1] = "dead" end
    -- Downed (the server reads the story's DB_Downed), also for the character you control, which is locked.
    if e.active and e.downed and not e.dead then tags[#tags + 1] = "downed" end
    if not e.active and e.inCamp then tags[#tags + 1] = "in camp" end
    -- An off-stage member already in the party: the game will not move them.
    if e.active and e.offStage then tags[#tags + 1] = "off stage" end
    -- A party member the game holds right now (the server's check): it will refuse sending them to camp.
    if e.active and e.stuck and not e.locked then tags[#tags + 1] = "can't leave now" end
    -- A camp member the game holds right now (the server's join check): Apply would refuse (1.1.4 unit C).
    if not e.active and e.joinBlocked and not e.locked and not e.dead then tags[#tags + 1] = "can't join now" end
    -- The lock reason only when no tag says it already: a dead party member read "(dead, dead)" (2026-11-01).
    if e.locked and e.lockReason and not e.avatar then
        local repeated = false
        for _, t in ipairs(tags) do if t == e.lockReason then repeated = true end end
        if not repeated then tags[#tags + 1] = e.lockReason end
    end
    if #tags == 0 then return e.name end
    return e.name .. "  (" .. table.concat(tags, ", ") .. ")"
end

-- The game blocks dismissing the dead (DB_CantTalk -> DB_BlockDismissable, _GLO_Shared_PartyMembers.txt
-- L241-249); Withers can revive them, or dismiss a dead companion (GLO_Jergal.txt L537-576, L1099-1185).
function RosterList.DeadText(e)
    return tostring(e.name) .. " is dead. Dead party members cannot be removed from the party here. Revive them "
        .. "first (a scroll, a spell, or Withers once he is at your camp), or ask Withers to dismiss them."
end

-- The story table in brackets means nothing in a message (the log keeps it).
local function plainReason(why)
    return (string.gsub(tostring(why), " %([%u_][%w_]*%)", ""))
end

-- A camp member the game holds right now (e.joinBlocked: the server's Party.JoinBlockedReason).
function RosterList.JoinHeldText(e)
    return tostring(e.name) .. " " .. plainReason(e.joinBlocked) .. ", so they can't join the party right now. "
        .. "Press Refresh once that has changed."
end

-- A party member the game holds right now (e.stuck: the server's Party.LeaveBlockedReason, written to follow the
-- name).
function RosterList.HeldText(e)
    local why = e.downed and "is downed" or plainReason(e.stuck)
    if e.offStage and not e.downed and string.find(why, "cannot travel", 1, true) then
        why = why .. ": they are off stage (not present in the world)"
    end
    return tostring(e.name) .. " " .. why .. ", so they can't leave the party right now. Press Refresh once that "
        .. "has changed."
end

-- Draws the list into `parent`.
-- opts.limit: how many may be ticked in total (locked members count).
-- opts.preselect(entry) -> bool: initial tick for unlocked entries.
-- opts.readOnly: draw everything disabled.
-- opts.onChange(count): called after every tick change.
-- opts.onLocked(entry, text): called when the box of a dead or held party member is clicked (it stays ticked).
-- Returns an object with :Selected() (unlocked uuids ticked) and :Count().
function RosterList.Draw(parent, entries, opts)
    opts = opts or {}
    local ticked = {}
    local list = { entries = entries }

    local function count()
        local n = 0
        for _, e in ipairs(entries) do
            if ticked[e.uuid] then n = n + 1 end
        end
        return n
    end

    for _, e in ipairs(entries) do
        -- A dead or held party member answers a click with the reason instead of being unticked (plan
        -- docs/PLAN_1.1.3_dead_member_notice.md, units B and G). Dead: locked as "dead" only, so a dead player
        -- character (locked as "player character") stays as it was. Held: not locked, so it stays in
        -- Selected() and Apply keeps it in the party.
        -- A camp member the game holds (1.1.4 unit C) is fixed the same way, but unticked; not the dead, who
        -- stay disabled (every dead character is in DB_CantMove).
        local fixedText, fixedTick = nil, true
        if e.active and not opts.readOnly then
            if e.locked and e.lockReason == "dead" then
                fixedText = RosterList.DeadText(e)
            elseif not e.locked and e.stuck then
                fixedText = RosterList.HeldText(e)
            end
        elseif not opts.readOnly and not e.locked and not e.dead and e.joinBlocked then
            fixedText, fixedTick = RosterList.JoinHeldText(e), false
        end
        local initial
        if fixedText then
            -- Always as they are: an untick (or tick) kept from before they were held is dropped.
            initial = fixedTick
        elseif e.locked then
            -- Locked members stay as they are: ticked if in the party.
            initial = e.active == true
        elseif opts.preselect then
            initial = opts.preselect(e) == true
        else
            initial = e.active == true
        end
        if e.dead and not e.locked then initial = false end
        ticked[e.uuid] = initial

        -- Clickable (a disabled box reports no click), with grey text.
        local cb = parent:AddCheckbox(label(e), initial)
        pcall(function() cb.IDContext = "pp_" .. e.uuid end)
        if fixedText then
            pcall(function() cb:SetColor("Text", { 0.5, 0.5, 0.5, 1.0 }) end)
        elseif e.locked or e.dead or opts.readOnly then
            cb.Disabled = true
        end
        cb.OnChange = function(_, checked)
            if fixedText then
                -- Ticked again whatever the click did; pcall, as the list may have been redrawn before this
                -- queued call runs.
                pcall(function() cb.Checked = fixedTick end)
                ticked[e.uuid] = fixedTick
                if opts.onLocked then pcall(opts.onLocked, e, fixedText) end
                return
            end
            ticked[e.uuid] = checked == true
            if opts.onChange then opts.onChange(count()) end
        end
    end

    function list:Selected()
        local out = {}
        for _, e in ipairs(entries) do
            if ticked[e.uuid] and not e.locked then out[#out + 1] = e.uuid end
        end
        return out
    end

    function list:Count() return count() end

    return list
end

return RosterList
