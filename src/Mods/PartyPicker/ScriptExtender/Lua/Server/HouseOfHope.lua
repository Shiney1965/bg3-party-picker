-- Party Picker (server): the House of Hope's Debtor's Attire for the whole party.
--
-- What the game does (GustavDev story, Act3b_LOW_HouseOfHope2.txt):
--   L70      when Hope's dialog that sets LOW_HouseOfHope_Event_HopeGrantsDisguise ends, the story
--            calls PROC_GlobalFlagReactionAfterDialog(flag) (Shared _Greevers_Little_Helpers.txt
--            L2661-2700: once, with the bare flag as the only argument).
--   L74-77   there are four pre-placed sets, DB_LOW_HouseOfHope_DebtorClothes(1..4, item).
--   L973-990 each DB_Players member, while the alarm is not raised, gets the next set (ToInventory
--            + Equip), so members five and up get none.
--   L992-999 equipping an item of a debtor template (L81-82) switches the wearer to the vanity
--            outfit with the game's own effect; L1024-1046 the alarm destroys any worn debtor-
--            template item; L2843-2852 "wear the clothes back" also works by template. So a copy
--            made from the same template behaves like the originals, cleanup included.
-- Party Picker gives a copy to each party member the game left out, inside the House of Hope.
-- Listeners and story tables only; no story file is replaced.

local Party = Ext.Require("Server/Party.lua")

local HouseOfHope = {}

local GRANT_FLAG = "bb82e10f-9c0f-5c16-9f1d-e482d9074ca8" -- LOW_HouseOfHope_Event_HopeGrantsDisguise
local FALLBACK_TEMPLATE = "ARM_Vanity_Prison_EternalDebtors_6f7d15a8-9bcb-45de-94c5-8c77424aaf42"
local TRIGGER_SET = "LOW_HouseOfHope" -- DB_TriggerEvents_TriggerSet rows, L13-14
-- The game's own four hand-outs run in the same PROC call; wait a moment so they have landed.
local HAND_OUT_DELAY_MS = 1000
-- A copy that never arrives (TemplateAddedTo not seen) is reported after this.
local EQUIP_TIMEOUT_MS = 10000

-- Holders waiting for their copy: bare uuid -> { name, template (bare uuid), batch }.
-- Each hand-out is a batch, so its timeout only clears its own entries.
local pending = {}
local batchCount = 0

-- Every column must be passed, nil for "any" (a story table's Get takes exactly its column
-- count); table.pack keeps trailing nils that { ... } would drop.
local function rows(dbName, ...)
    local args = table.pack(...)
    local ok, r = pcall(function() return Osi[dbName]:Get(table.unpack(args, 1, args.n)) end)
    return (ok and type(r) == "table") and r or {}
end

local function alarmRaised()
    return #rows("DB_LOW_HouseOfHope_AlarmIsReady", 1) > 0
end

-- The debtor templates the game recognises (L81-82): full strings, and a set of bare uuids.
local function debtorTemplates()
    local list, set = {}, {}
    for _, row in ipairs(rows("DB_LOW_HouseOfHope_DebtorTemplates", nil)) do
        local u = PP.BareUuid(row[1])
        if u and not set[u] then list[#list + 1] = row[1]; set[u] = true end
    end
    if #list == 0 then
        list[1] = FALLBACK_TEMPLATE
        set[PP.BareUuid(FALLBACK_TEMPLATE)] = true
    end
    return list, set
end

-- The template of the set the game hands out first, if it is a debtor template; else the
-- known vanity template.
local function templateToCopy(templateSet)
    for _, row in ipairs(rows("DB_LOW_HouseOfHope_DebtorClothes", 1, nil)) do
        local ok, t = pcall(Osi.GetTemplate, row[2])
        if ok and type(t) == "string" and templateSet[PP.BareUuid(t) or ""] then return t end
    end
    return FALLBACK_TEMPLATE
end

-- Who holds one of the game's four sets now (covers a hand-out still landing).
local function originalHolders()
    local holders = {}
    for _, row in ipairs(rows("DB_LOW_HouseOfHope_DebtorClothes", nil, nil)) do
        local ok, owner = pcall(Osi.GetInventoryOwner, row[2])
        local u = ok and PP.BareUuid(owner)
        if u then holders[u] = true end
    end
    return holders
end

local function holdsAttire(id, templates)
    for _, t in ipairs(templates) do
        local ok, item = pcall(Osi.GetItemByTemplateInInventory, t, id)
        if ok and item ~= nil and item ~= "" then return true end
    end
    return false
end

-- The game's own test, QRY_TriggerEvents_InTriggerSet (Shared GLO_TriggerEvents.txt): inside any
-- trigger of the set.
local function inHouseOfHope(id)
    for _, row in ipairs(rows("DB_TriggerEvents_TriggerSet", TRIGGER_SET, nil)) do
        local ok, v = pcall(Osi.IsInTrigger, id, row[2])
        if ok and v == 1 then return true end
    end
    return false
end

function HouseOfHope.HandOut()
    if PP.Setting("hope_attire_everyone", true) == false then return end
    if alarmRaised() then return end
    local templates, templateSet = debtorTemplates()
    local template = templateToCopy(templateSet)
    local templateUuid = PP.BareUuid(template)
    local holders = originalHolders()
    batchCount = batchCount + 1
    local batch = batchCount
    local given, skipped = {}, {}
    for _, e in ipairs(Party.Roster()) do
        local u = e.uuid
        if e.active and not e.dead and not e.offStage and not pending[u] and not holders[u]
            and not holdsAttire(e.id, templates) then
            if not inHouseOfHope(e.id) then
                skipped[#skipped + 1] = e.name
            else
                -- Recorded before the call, in case the engine reports the new item inside it.
                pending[u] = { name = e.name, template = templateUuid, batch = batch }
                local ok, err = pcall(Osi.TemplateAddTo, template, e.id, 1, 0)
                if ok then
                    given[#given + 1] = e.name
                else
                    pending[u] = nil
                    PP.Log("House of Hope: could not give the Debtor's Attire to " .. e.name .. ": " .. tostring(err))
                end
            end
        end
    end
    if #skipped > 0 then
        PP.Log("House of Hope: no Debtor's Attire for " .. table.concat(skipped, ", ") .. " (not in the House of Hope)")
    end
    if #given == 0 then return end
    PP.Log("House of Hope: giving the Debtor's Attire to " .. #given .. " more party member(s): " .. table.concat(given, ", "))
    Ext.Timer.WaitFor(EQUIP_TIMEOUT_MS, function()
        for u, p in pairs(pending) do
            if p.batch == batch then
                PP.Log("House of Hope: the Debtor's Attire for " .. p.name .. " did not arrive")
                pending[u] = nil
            end
        end
    end)
end

-- A copy arrived: wear it, with the call the game uses at L990.
function HouseOfHope.OnTemplateAdded(template, item, holder)
    local u = PP.BareUuid(holder)
    local p = u and pending[u]
    if not p or PP.BareUuid(template) ~= p.template then return end
    pending[u] = nil
    if alarmRaised() then return end
    local ok, err = pcall(Osi.Equip, holder, item, 0, 0, 0)
    if not ok then
        PP.Log("House of Hope: could not put the Debtor's Attire on " .. p.name .. ": " .. tostring(err))
    end
end

function HouseOfHope.Register()
    Ext.Osiris.RegisterListener("PROC_GlobalFlagReactionAfterDialog", 1, "after", function(flag)
        if PP.BareUuid(flag) ~= GRANT_FLAG then return end
        Ext.Timer.WaitFor(HAND_OUT_DELAY_MS, function()
            local ok, err = pcall(HouseOfHope.HandOut)
            if not ok then PP.Log("House of Hope: hand-out failed: " .. tostring(err)) end
        end)
    end)
    Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(template, item, holder, _)
        if next(pending) == nil then return end
        local ok, err = pcall(HouseOfHope.OnTemplateAdded, template, item, holder)
        if not ok then PP.Log("House of Hope: equip failed: " .. tostring(err)) end
    end)
end

return HouseOfHope
