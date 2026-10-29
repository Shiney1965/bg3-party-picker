-- Party Picker (server): read the roster and change the active party.
--
-- Recruiting and dismissing go through the same story procedures the game's
-- own buttons and dialogs use, so the story's bookkeeping (factions, camp,
-- DB_Players, the party-full flag, hireling flags) stays consistent:
--   origin to party     PROC_GLO_PartyMembers_CheckAdd(origin, avatar)
--   origin to camp      PROC_GLO_PartyMembers_Remove(origin, avatar, 1)
--   hireling to party   PROC_Hirelings_TakeFromCamp(hireling, avatar)   (from camp)
--                       PROC_Hirelings_AddToParty(hireling, avatar)     (otherwise)
--   hireling to camp    PROC_GLO_PartyMembers_Remove(hireling, avatar, 0)
--                       + PROC_Hirelings_SendToCamp(hireling)
-- Sources: Shared goal _GLO_Shared_PartyMembers.txt, SharedDev Hirelings.txt
-- (L447-458, L670-682, L1095-1096). See docs/RESEARCH.md.

local Party = {}

-- Each change waits for the story to finish the previous step.
local ADD_DELAY_MS = 250
local VERIFY_DELAY_MS = 600

local HIRELING_IN_CAMP_FLAG = "Hireling_State_InCamp_e33aa0df-fcfc-4a30-8169-516d3956f02a"

local busy = false

-- True while Apply is adding and removing members. The DB_Players listener does
-- not re-apply the limit then: each added row would lower it to the party so far
-- and stop the next joiner (review 2026-10-25). Apply re-applies it once at the end.
function Party.IsBusy() return busy end

-- First column of a story table; `arity` is the table's column count (1 if omitted).
local function column1(dbName, arity)
    local out = {}
    local ok, rows = pcall(function()
        if arity == 2 then return Osi[dbName]:Get(nil, nil) end
        return Osi[dbName]:Get(nil)
    end)
    if ok and type(rows) == "table" then
        for _, row in ipairs(rows) do
            if row[1] ~= nil then out[#out + 1] = row[1] end
        end
    end
    return out
end

local function uuidSet(dbName, arity)
    local set = {}
    for _, id in ipairs(column1(dbName, arity)) do
        local u = PP.BareUuid(id)
        if u then set[u] = true end
    end
    return set
end

local function isTrue(fn, ...)
    local ok, v = pcall(fn, ...)
    return ok and (v == 1 or v == true)
end

-- Is `id` in a one-column story table?
local function inDb(dbName, id)
    local ok, rows = pcall(function() return Osi[dbName]:Get(id) end)
    return ok and type(rows) == "table" and next(rows) ~= nil
end

-- Off stage = not present in the world. The story records it in DB_OffStage
-- (__AAA_FirstGoal.txt L1282-1285) and treats such a character as unable to
-- move (L2285-2291, L2325-2331). The companion add rule never puts anyone on
-- stage (_GLO_Shared_PartyMembers.txt L501-528), so an off-stage recruit
-- joins as an absent party member and at once gets the fast-travel block
-- (_Waypoints.txt L188-194). Seen in game 2026-10-12 with a hireling another
-- mod had hired and parked off stage. Such characters are never recruited.
local OFF_STAGE = "not available: off stage (not present in the world)"

-- DB_OffStage is filled by an engine event, so a character who was never on
-- stage has no row; the game's IsOnStage query (the story uses it,
-- GLO_Camp.txt L1715) covers that. Either signal counts.
local function isOffStage(id)
    if inDb("DB_OffStage", id) then return true end
    local ok, v = pcall(Osi.IsOnStage, id)
    return ok and v == 0
end

local function names(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.name end
    return table.concat(out, ", ")
end

-- Characters that are never offered in the party list.
-- Withers (S_GLO_JergalAvatar, SharedDev story Hirelings.txt:715) lives in
-- camp with the team but is not a party member.
local NEVER_LIST = {
    ["0133f2ad-e121-4590-b5f0-a79413919805"] = "Withers",
}

-- Summons and followers (familiars, conjured creatures, raised dead, pets
-- that follow the party) never take a party slot; their summoner controls
-- them. Any one of these signals is enough:
--   Osi.IsSummon / Osi.IsPartyFollower (built-in queries),
--   DB_PlayerSummons / DB_PartyFollowers (Shared story __AAA_FirstGoal.txt),
--   the entity's IsSummon / PartyFollower components.
local function companionFilter()
    local summons = uuidSet("DB_PlayerSummons")
    local followers = uuidSet("DB_PartyFollowers")
    return function(id)
        local u = PP.BareUuid(id)
        if not u then return false, "no uuid" end
        if NEVER_LIST[u] then return false, NEVER_LIST[u] end
        if summons[u] then return false, "summon" end
        if followers[u] then return false, "follower" end
        if isTrue(Osi.IsSummon, id) then return false, "summon" end
        if isTrue(Osi.IsPartyFollower, id) then return false, "follower" end
        local okE, why = pcall(function()
            local e = Ext.Entity.Get(u)
            if e and e.IsSummon then return "summon" end
            if e and e.PartyFollower then return "follower" end
            return nil
        end)
        if okE and why then return false, why end
        return true
    end
end

-- Who may appear in the list at all. DB_PartOfTheTeam also holds camp
-- followers and camp pets (seen in game 2026-10-11: Volo, Elminster, the
-- Oathbreaker Knight, Scratch, Tara, Shovel, Bernard). Besides player
-- characters and hirelings, a character is listed when the story marks them
-- as a companion (Shared story copies, see docs/RESEARCH.md):
--   DB_OriginNPCAlignment: dismissing a companion to camp requires it
--     (_GLO_Shared_Origins.txt L439-450); in camp, a character without it is
--     given the camp-follower faction (GLO_Camp.txt L2785-2806). Hirelings
--     get it on hiring (SharedDev Hirelings.txt L745).
--   DB_GLO_PartyMembers_OriginalAlignment: copied from it and from hiring
--     (_GLO_Shared_Origins.txt L238-240); the game's dismissal procedure
--     needs it (_GLO_Shared_PartyMembers.txt L1297-1305).
--   DB_GLO_PartyMembers_DefaultFaction: written when a party member is
--     dismissed (_GLO_Shared_PartyMembers.txt L1313), removed on rejoining
--     (L523).
-- Anyone this mod has seen in the active party also counts, for companions
-- added by other mods that the story does not mark.
local COMPANION_DBS = {
    "DB_OriginNPCAlignment", "DB_GLO_PartyMembers_OriginalAlignment", "DB_GLO_PartyMembers_DefaultFaction",
}

local function seenVar()
    local ok, seen = pcall(function() return Ext.Vars.GetModVariables(ModuleUUID).Seen end)
    return (ok and type(seen) == "table") and seen or {}
end

local function rememberActive(isCompanion, ids)
    local seen, changed = {}, false
    for u, v in pairs(seenVar()) do seen[u] = v end
    for _, id in ipairs(ids or column1("DB_Players")) do
        local u = PP.BareUuid(id)
        if u and not seen[u] and isCompanion(id) then seen[u] = true; changed = true end
    end
    -- Whole-table assignment: writes to sub-fields are not saved (API.md).
    if changed then pcall(function() Ext.Vars.GetModVariables(ModuleUUID).Seen = seen end) end
    return seen
end

local CAMP_ONLY = "camp only (not marked as a companion or hireling, never seen in your party)"

-- Hireling templates (the characters Withers can create) get the companion
-- marks with the Hirelings faction before anyone hires them (SharedDev
-- Hirelings.txt L280-285, DB_Hirelings_HACK_Classes). A hireling is only a
-- party member once hired (DB_Hirelings_Hired, L496-513), so those marks
-- never count on their own.
local HIRELINGS_FACTION = "b7b47ac8-8e29-4984-b8c5-f35b66d8265a"
local NOT_HIRED = "hireling not hired (not created at Withers in this game)"

local function rows2(dbName)
    local ok, rows = pcall(function() return Osi[dbName]:Get(nil, nil) end)
    return (ok and type(rows) == "table") and rows or {}
end

local function hirelingTemplates()
    local set = {}
    local ok, rows = pcall(function() return Osi.DB_Hirelings_HACK_Classes:Get(nil, nil, nil) end)
    for _, row in ipairs((ok and type(rows) == "table") and rows or {}) do
        local u = PP.BareUuid(row[2])
        if u then set[u] = true end
    end
    return set
end

local function rosterFilter()
    local isCompanion = companionFilter()
    local seen = rememberActive(isCompanion)
    local players = uuidSet("DB_Players")
    local avatars = uuidSet("DB_Avatars")
    for u in pairs(uuidSet("DB_DismissedAvatar")) do avatars[u] = true end
    local hired = uuidSet("DB_Hirelings_Hired")
    local hirelingType = hirelingTemplates()
    local aligned = {}
    for _, db in ipairs(COMPANION_DBS) do
        for _, row in ipairs(rows2(db)) do
            local u = PP.BareUuid(row[1])
            if u then
                if PP.BareUuid(row[2]) == HIRELINGS_FACTION then hirelingType[u] = true
                else aligned[u] = true end
            end
        end
    end
    return function(id)
        local ok, why = isCompanion(id)
        if not ok then return false, why end
        local u = PP.BareUuid(id)
        -- Anyone in the party now stays listed, so they can be sent away.
        if players[u] or avatars[u] or hired[u] then return true end
        if hirelingType[u] then return false, NOT_HIRED end
        if aligned[u] or seen[u] then return true end
        return false, CAMP_ONLY
    end
end

-- Called when someone joins the active party (DB_Players listener), so a
-- companion is remembered even if the Party tab is never opened meanwhile.
function Party.Remember(id)
    rememberActive(companionFilter(), { id })
end

-- !pp_forget: drop someone from the remembered list. Returns true if they were in it.
function Party.Forget(uuid)
    local seen, found = {}, false
    for u, v in pairs(seenVar()) do
        if u == uuid then found = true else seen[u] = v end
    end
    if found then pcall(function() Ext.Vars.GetModVariables(ModuleUUID).Seen = seen end) end
    return found
end

local function userOf(id)
    local ok, u = pcall(Osi.GetReservedUserID, id)
    if ok then return u end
    return nil
end

-- The character the host is controlling right now. The game's own scripts
-- note this can be a companion rather than the avatar
-- (_GLO_Shared_Origins.txt: "GetHostCharacter(_Avatar) AND NOT DB_Avatars").
function Party.HostCharacter()
    local ok, host = pcall(Osi.GetHostCharacter)
    if ok then return host end
    return nil
end

-- The host's own avatar: the one to recruit and dismiss "by", as the game's
-- dialogs do. Falls back to the controlled character.
function Party.HostAvatar()
    local controlled = Party.HostCharacter()
    if not controlled then return nil end
    if #Osi.DB_Avatars:Get(controlled) > 0 then return controlled end
    local hostUser = userOf(controlled)
    local players = uuidSet("DB_Players")
    for _, id in ipairs(column1("DB_Avatars")) do
        if userOf(id) == hostUser and players[PP.BareUuid(id)] then return id end
    end
    return controlled
end

function Party.DisplayName(id)
    local name = nil
    pcall(function()
        local handle = Osi.GetDisplayName(id)
        if handle then name = Ext.Loca.GetTranslatedString(handle) end
    end)
    if name == nil or name == "" then
        pcall(function()
            local e = Ext.Entity.Get(PP.BareUuid(id))
            name = e.DisplayName.Name:Get()
        end)
    end
    if name == nil or name == "" then return tostring(id) end
    return name
end

function Party.MaxSize()
    local n = tonumber(PP.Setting("max_party_size", 6)) or 6
    if n < PP.RESTRICTED_SIZE then n = PP.RESTRICTED_SIZE end
    if n > PP.MAX_PARTY_SIZE then n = PP.MAX_PARTY_SIZE end
    return math.floor(n)
end

-- The party Party Picker must make room for: everyone in it now (summons and
-- followers not counted), or, while a long-rest trim is waiting to be
-- restored, the party as it was before the trim (Restrictions keeps that list
-- in the saved mod variable "Pending"), so a lower setting never strands the
-- members waiting in camp.
function Party.PartyFloor()
    local n = Party.ActiveCount()
    local ok, p = pcall(function() return Ext.Vars.GetModVariables(ModuleUUID).Pending end)
    if ok and type(p) == "table" and p.trimmed and type(p.party) == "table" and #p.party > n then
        n = #p.party
    end
    return n
end

-- The limit actually used: the setting, but never below the party (plan
-- docs/PLAN_inspiration_and_30.md, Part D). Applied to the game, and checked
-- by Apply and Restore.
function Party.EffectiveMaxSize()
    return math.max(Party.MaxSize(), Party.PartyFloor())
end

-- Re-applied on every level load: the override is not known to survive a
-- save (Brawl re-applies it the same way). Also re-applied whenever the party
-- or the setting changes; the log line only when the value changes.
local lastApplied = nil
function Party.ApplyMaxSize()
    local n = Party.EffectiveMaxSize()
    local ok, err = pcall(function()
        Osi.SetMaxPartySizeOverride(n)
        Osi.PROC_CheckPartyFull()
    end)
    if ok then
        if n ~= lastApplied then PP.Log("party size limit set to " .. n) end
        lastApplied = n
    else
        PP.Log("could not set the party size limit: " .. tostring(err))
    end
end

-- Companions the story keeps in camp before they can be recruited. The game
-- gates them by dialog only, and CheckAdd checks only the player-count flag
-- (_GLO_Shared_PartyMembers.txt L478-482), so adding one from camp skips their
-- story (reported in game 2026-10-27: Halsin, added in Act 2, never went to
-- Last Light to sit with Art Cullagh).
--   Halsin: recruitable once GLO_LiftingTheCurse_State_HalsinRecruitable is
--     set, by his first real join (GLO_Companion_Halsin.txt L41-47) or the
--     Act 2 fallbacks (Act2_TWN_LiftingTheCurse_Finale.txt L153-181).
--   Minthara, Minsc: DB_GLO_PartyMembers_BlockRecruitmentDialog until the
--     story allows it (GLO_Companion_Minthara.txt L13, GLO_Companion_Minsc.txt
--     L49; read at _GLO_Shared_Origins.txt L320-324).
local HALSIN_UUID = "7628bc0e-52b8-42a7-856a-13a6fd413323"
Party.HALSIN_RECRUITABLE_FLAG = "GLO_LiftingTheCurse_State_HalsinRecruitable_2c8b6be0-558d-485c-b4f2-93ec1926a2fa"
local NULL_ID = "NULL_00000000-0000-0000-0000-000000000000"
local NOT_YET = "not recruitable yet: they join later in the story (talk to them)"
Party.HALSIN_UUID, Party.NOT_YET = HALSIN_UUID, NOT_YET
-- The "Let Halsin join early" setting (docs/PLAN_halsin_early_option.md). Server/HalsinRepair.lua sets
-- this (it requires this file, so it cannot be required from here): returns nil when the setting may
-- let a not-yet-recruitable Halsin join now, else the reason he stays locked.
Party.HalsinEarlyGate = nil

-- Why a character not in the party may not join yet, or nil.
local flagReadFailLogged = false
local function notRecruitableReason(e)
    if e.uuid == HALSIN_UUID then
        -- A failed read counts as not recruitable, whatever the setting: never skip his story by mistake.
        local ok, v = pcall(Osi.GetFlag, Party.HALSIN_RECRUITABLE_FLAG, NULL_ID)
        if not ok and not flagReadFailLogged then
            flagReadFailLogged = true
            PP.Log("could not read Halsin's recruitable flag (" .. tostring(v) .. "); he stays locked")
        end
        if not ok then return NOT_YET end
        if v ~= 1 then
            local gate = Party.HalsinEarlyGate
            local okGate, why = true, NOT_YET
            if gate then okGate, why = pcall(gate) end
            if not okGate then return NOT_YET end
            if why then return why end
        end
    end
    if inDb("DB_GLO_PartyMembers_BlockRecruitmentDialog", e.id) then return NOT_YET end
    return nil
end

-- Everyone the player could choose from.
-- Each entry: id (Osiris string), uuid, name, active, inCamp, avatar,
-- hireling, dead, locked (this mod never moves them), lockReason.
function Party.Roster()
    local controlled = Party.HostCharacter()
    local hostUser = controlled and userOf(controlled) or nil

    local entries, byUuid = {}, {}
    local function add(id, field)
        local u = PP.BareUuid(id)
        if not u then return end
        local e = byUuid[u]
        if not e then
            e = { id = id, uuid = u }
            byUuid[u] = e
            entries[#entries + 1] = e
        end
        e[field] = true
    end
    for _, id in ipairs(column1("DB_PartOfTheTeam")) do add(id, "team") end
    for _, id in ipairs(column1("DB_Hirelings_Hired")) do add(id, "hireling") end
    for _, id in ipairs(column1("DB_Players")) do add(id, "active") end

    local avatars = uuidSet("DB_Avatars")
    local dismissedAvatars = uuidSet("DB_DismissedAvatar")
    local inCamp = uuidSet("DB_InCamp")
    local controlledUuid = PP.BareUuid(controlled)

    local listable = rosterFilter()
    local out = {}
    for _, e in ipairs(entries) do
        if listable(e.id) then
            e.avatar = avatars[e.uuid] == true
            e.inCamp = inCamp[e.uuid] == true
            e.dead = isTrue(Osi.IsDead, e.id)
            e.name = Party.DisplayName(e.id)
            e.active = e.active == true
            e.hireling = e.hireling == true
            e.offStage = isOffStage(e.id)
            if e.avatar or dismissedAvatars[e.uuid] then
                -- Avatars (including dismissed ones, which stay in
                -- DB_PartOfTheTeam) are never recruited or dismissed here.
                e.avatar = true
                e.locked, e.lockReason = true, "player character"
            elseif e.active and e.dead then
                -- Never send a body to camp; the game handles revival.
                e.locked, e.lockReason = true, "dead"
            elseif e.active and e.uuid == controlledUuid then
                e.locked, e.lockReason = true, "you are controlling them"
            elseif e.active and hostUser ~= nil then
                local user = userOf(e.id)
                if user ~= nil and user ~= hostUser then
                    e.locked, e.lockReason = true, "controlled by another player"
                end
            elseif not e.active and e.offStage then
                e.locked, e.lockReason = true, OFF_STAGE
            elseif not e.active then
                local why = notRecruitableReason(e)
                if why then e.locked, e.lockReason = true, why end
            end
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b)
        if a.avatar ~= b.avatar then return a.avatar end
        return a.name < b.name
    end)
    return out
end

function Party.ActiveCount()
    local isCompanion = companionFilter()
    local n = 0
    for _, id in ipairs(column1("DB_Players")) do
        if isCompanion(id) then n = n + 1 end
    end
    return n
end

-- For !pp_roster: everyone the story tables mention and why each is or is
-- not offered.
function Party.Excluded()
    local isCompanion = rosterFilter()
    local seen, out = {}, {}
    for _, db in ipairs({ "DB_PartOfTheTeam", "DB_Hirelings_Hired", "DB_Players" }) do
        for _, id in ipairs(column1(db)) do
            local u = PP.BareUuid(id)
            if u and not seen[u] then
                seen[u] = true
                local ok, why = isCompanion(id)
                if not ok then out[#out + 1] = { id = id, name = Party.DisplayName(id), why = why, db = db } end
            end
        end
    end
    return out
end

-- For !pp_roster: which story tables a character is in, and their faction,
-- so a wrongly listed character shows where it came from.
local SOURCE_DBS = {
    { "DB_PartOfTheTeam", "team" }, { "DB_Hirelings_Hired", "hired" }, { "DB_Players", "players" },
    { "DB_OriginNPCAlignment", "aligned", 2 }, { "DB_GLO_PartyMembers_OriginalAlignment", "origalign", 2 },
    { "DB_GLO_PartyMembers_DefaultFaction", "dismissed", 2 }, { "DB_Origins", "origin" },
    { "DB_PartyMembers", "partymembers" }, { "DB_InCamp", "incamp" },
    { "DB_Avatars", "avatar" }, { "DB_PartyFollowers", "followers" }, { "DB_PlayerSummons", "summons" },
    -- Why the game may refuse to move someone (see OFF_STAGE and BLOCKING_DBS).
    { "DB_OffStage", "offstage" }, { "DB_CantMove", "cantmove" }, { "DB_CantAct", "cantact" },
    { "DB_FastTravelBlock_CantMove_StatusSet", "travelblock" },
}

-- Hireling state flags (SharedDev Hirelings.txt L511-512, L673-674).
local HIRELING_FLAGS = {
    { "Hireling_State_InCamp_e33aa0df-fcfc-4a30-8169-516d3956f02a", "campflag" },
    { "Hireling_State_Hired_0052da16-4401-4873-8176-16336d8942da", "hiredflag" },
}

-- A lookup that fails is shown with "?" so it is not mistaken for "not in it".
function Party.Sources(id)
    local found = {}
    if seenVar()[PP.BareUuid(id) or ""] then found[#found + 1] = "seen" end
    for _, spec in ipairs(SOURCE_DBS) do
        local ok, rows = pcall(function()
            if spec[3] == 2 then return Osi[spec[1]]:Get(id, nil) end
            return Osi[spec[1]]:Get(id)
        end)
        if not ok then
            found[#found + 1] = spec[2] .. "?"
        elseif type(rows) == "table" and next(rows) ~= nil then
            found[#found + 1] = spec[2]
        end
    end
    local okT, tpl = pcall(function() return Osi.DB_Hirelings_HACK_Classes:Get(nil, id, nil) end)
    if not okT then found[#found + 1] = "hiretemplate?"
    elseif type(tpl) == "table" and next(tpl) ~= nil then found[#found + 1] = "hiretemplate" end
    for _, spec in ipairs(HIRELING_FLAGS) do
        if isTrue(Osi.GetFlag, spec[1], id) then found[#found + 1] = spec[2] end
    end
    -- The summon/follower signals companionFilter uses besides the tables.
    local function query(label, fn)
        local ok, v = pcall(fn, id)
        if not ok then found[#found + 1] = label .. "?"
        elseif v == 1 or v == true then found[#found + 1] = label end
    end
    query("IsSummon", Osi.IsSummon)
    query("IsPartyFollower", Osi.IsPartyFollower)
    local okS, onStage = pcall(Osi.IsOnStage, id)
    if not okS then found[#found + 1] = "IsOnStage?"
    elseif onStage == 0 then found[#found + 1] = "IsOnStage=0" end
    local okE, comps = pcall(function()
        local e = Ext.Entity.Get(PP.BareUuid(id))
        if not e then return "no-entity" end
        local out = {}
        if e.IsSummon then out[#out + 1] = "entity.IsSummon" end
        if e.PartyFollower then out[#out + 1] = "entity.PartyFollower" end
        return table.concat(out, ",")
    end)
    if not okE then found[#found + 1] = "entity?"
    elseif comps ~= "" then found[#found + 1] = comps end
    local okF, faction = pcall(Osi.GetFaction, id)
    return table.concat(found, ","), okF and tostring(faction) or "?"
end

function Party.ActiveUuids()
    local out = {}
    for _, e in ipairs(Party.Roster()) do
        if e.active then out[#out + 1] = e.uuid end
    end
    return out
end

-- Why a character cannot be moved right now, or nil. Mirrors the checks the
-- Focus Lodestones recruit/dismiss code makes (see docs/RESEARCH.md).
local BLOCKING_DBS = {
    { "DB_InDangerZone", 2 },
    { "DB_FastTravelBlock_BlockedZone_StatusSet", 1 },
    { "DB_FastTravelBlock_CantMove_StatusSet", 1 },
    { "DB_FastTravelBlock_Arrested_StatusSet", 1 },
    { "DB_FastTravelBlock_CampNightMode_StatusSet", 1 },
    { "DB_FastTravelBlock_FugitiveInPrison_StatusSet", 2 },
}

function Party.BlockedReason(id, checkCombat)
    if checkCombat and isTrue(Osi.IsInCombat, id) then return "is in combat" end
    for _, spec in ipairs(BLOCKING_DBS) do
        local name, arity = spec[1], spec[2]
        local ok, rows = pcall(function()
            if arity == 2 then return Osi[name]:Get(id, nil) end
            return Osi[name]:Get(id)
        end)
        if ok and type(rows) == "table" and next(rows) ~= nil then
            return "cannot travel right now (" .. name .. ")"
        end
    end
    return nil
end

local function sendToCamp(e, avatar)
    if e.hireling then
        local ok, err = pcall(Osi.PROC_GLO_PartyMembers_Remove, e.id, avatar, 0)
        if not ok then PP.Log("remove failed for " .. e.name .. ": " .. tostring(err)) end
        -- PROC_Hirelings_SendToCamp only sets the in-camp flag and counter
        -- (Hirelings.txt L670-675). It must not run for a hireling the game
        -- left in the party (the removal has conditions of its own,
        -- _GLO_Shared_PartyMembers.txt L658-699, L1298-1307).
        if inDb("DB_Players", e.id) then
            PP.Log("the game did not remove " .. e.name .. "; hireling camp state left unchanged")
        else
            ok, err = pcall(Osi.PROC_Hirelings_SendToCamp, e.id)
            if not ok then PP.Log("hireling camp state not set for " .. e.name .. ": " .. tostring(err)) end
        end
    else
        local ok, err = pcall(Osi.PROC_GLO_PartyMembers_Remove, e.id, avatar, 1)
        if not ok then PP.Log("remove failed for " .. e.name .. ": " .. tostring(err)) end
    end
end

local function bringIn(e, avatar)
    local ok, err
    if e.hireling then
        if isTrue(Osi.GetFlag, HIRELING_IN_CAMP_FLAG, e.id) then
            ok, err = pcall(Osi.PROC_Hirelings_TakeFromCamp, e.id, avatar)
        else
            ok, err = pcall(Osi.PROC_Hirelings_AddToParty, e.id, avatar)
        end
    else
        ok, err = pcall(Osi.PROC_GLO_PartyMembers_CheckAdd, e.id, avatar)
    end
    if not ok then PP.Log("add failed for " .. e.name .. ": " .. tostring(err)) end
end

-- Change the party.
--   wanted:  list of uuids that should end up in the party (locked members
--            are kept regardless).
--   opts.limit:     max total size (default: configured maximum)
--   opts.addOnly:   never send anyone to camp; add `wanted` members who are
--                   not in the party, as far as the limit allows
--   done(result):   called once verified; result = { ok, message, changed }
-- Returns accepted, message. When accepted is false nothing was changed;
-- `nothingToDo` is true when the party already matched.
function Party.Apply(wanted, opts, done)
    opts = opts or {}
    done = done or function() end
    -- Every refusal goes to the log: on the Party tab it is only a line of
    -- text (reported in game 2026-10-12, where nothing showed why a member
    -- could not be sent to camp).
    local function refuse(message)
        PP.Log("request refused: " .. tostring(message))
        return false, message
    end
    if busy then return refuse("A party change is already in progress.") end
    local avatar = Party.HostAvatar()
    if not avatar then return refuse("No host character found.") end
    local limit = opts.limit or Party.EffectiveMaxSize()

    local roster = Party.Roster()
    local byUuid = {}
    for _, e in ipairs(roster) do byUuid[e.uuid] = e end

    -- addOnly: wanted members who are off stage right now. They are not
    -- added (see OFF_STAGE) but the request must not count as complete, or a
    -- restore would forget them (the camp hides benched companions at night,
    -- GLO_Camp.txt L1630-1649).
    local waiting = {}
    local keep, count = {}, 0
    for _, e in ipairs(roster) do
        if e.locked and e.active then keep[e.uuid] = true; count = count + 1 end
        if opts.addOnly and e.active and not keep[e.uuid] then keep[e.uuid] = true; count = count + 1 end
    end
    for _, u in ipairs(wanted or {}) do
        local e = byUuid[u]
        if e and not keep[u] and not e.dead and not (e.locked and not e.active) then
            if opts.addOnly and count >= limit then break end
            keep[u] = true; count = count + 1
        elseif not e and not opts.addOnly then
            return refuse("Unknown character " .. tostring(u) .. ".")
        elseif e and e.dead and not opts.addOnly then
            return refuse(e.name .. " is dead.")
        elseif e and e.locked and not e.active and not opts.addOnly then
            -- The tab never sends a locked character; this is a list drawn
            -- before they became unavailable, or !pp_set.
            return refuse(e.name .. " cannot join: " .. tostring(e.lockReason) .. ". Press Refresh.")
        elseif e and e.offStage and not e.active and opts.addOnly then
            waiting[#waiting + 1] = e
        end
    end
    if count > limit and not opts.addOnly then
        return refuse(string.format("%d selected, but the limit is %d.", count, limit))
    end
    if count == 0 then return refuse("Nobody selected.") end

    local toRemove, toAdd = {}, {}
    for _, e in ipairs(roster) do
        if e.active and not keep[e.uuid] then toRemove[#toRemove + 1] = e end
        if keep[e.uuid] and not e.active then toAdd[#toAdd + 1] = e end
    end
    if #toRemove == 0 and #toAdd == 0 then
        if #waiting > 0 then
            return refuse(names(waiting) .. " cannot rejoin yet: off stage (not present in the world).")
        end
        return false, "The party is already like that.", true
    end

    local checkCombat = PP.Setting("block_in_combat", true) ~= false
    local why = Party.BlockedReason(avatar, checkCombat)
    if why then return refuse("Party changes are blocked: your character " .. why .. ".") end
    for _, list in ipairs({ toRemove, toAdd }) do
        for _, e in ipairs(list) do
            why = Party.BlockedReason(e.id, checkCombat)
            if why and e.offStage and string.find(why, "cannot travel", 1, true) then
                why = why .. ": they are off stage (not present in the world)"
            end
            if why then return refuse(e.name .. " " .. why .. ".") end
        end
    end

    PP.Log(string.format("request: join [%s]; send to camp [%s]", names(toAdd), names(toRemove)))
    busy = true
    -- Room for the new members before anyone is added: CheckAdd does nothing
    -- while the story's party-full flag is set.
    pcall(Osi.SetMaxPartySizeOverride, math.max(Party.EffectiveMaxSize(), count))

    for _, e in ipairs(toRemove) do sendToCamp(e, avatar) end
    pcall(Osi.PROC_CheckPartyFull)

    -- Any error in the delayed steps must still release `busy` and report.
    local function guarded(fn)
        return function()
            local ok, err = pcall(fn)
            if not ok then
                busy = false
                pcall(Party.ApplyMaxSize)
                PP.Log("party change failed: " .. tostring(err))
                done({ ok = false, changed = true, message = "Party change failed: " .. tostring(err) })
            end
        end
    end

    Ext.Timer.WaitFor(ADD_DELAY_MS, guarded(function()
        for _, e in ipairs(toAdd) do bringIn(e, avatar) end

        Ext.Timer.WaitFor(VERIFY_DELAY_MS, guarded(function()
            local failed = {}
            local avatarInCamp = next(Osi.DB_InCamp:Get(avatar) or {}) ~= nil
            local bring = PP.Setting("teleport_joiners", true) ~= false
            for _, e in ipairs(toAdd) do
                if isTrue(Osi.IsInPartyWith, e.id, avatar) then
                    if bring and not avatarInCamp then
                        -- Same 6-argument form the raft script uses.
                        pcall(Osi.TeleportTo, e.id, avatar, "", 0, 1, 1)
                        pcall(Osi.AttachToPartyGroup, e.id, avatar)
                    end
                else
                    failed[#failed + 1] = e.name .. " did not join"
                end
            end
            for _, e in ipairs(toRemove) do
                if isTrue(Osi.IsInPartyWith, e.id, avatar) then
                    failed[#failed + 1] = e.name .. " did not leave"
                end
            end
            for _, e in ipairs(waiting) do
                failed[#failed + 1] = e.name .. " is off stage and could not rejoin yet"
            end
            busy = false
            pcall(Party.ApplyMaxSize)
            if #failed == 0 then
                -- Names, not counts, so it is plain who moved.
                local parts = { "Party updated." }
                if #toAdd > 0 then parts[#parts + 1] = "Joined: " .. names(toAdd) .. "." end
                if #toRemove > 0 then parts[#parts + 1] = "Sent to camp: " .. names(toRemove) .. "." end
                done({ ok = true, changed = true, message = table.concat(parts, " ") })
            else
                done({ ok = false, changed = true,
                    message = "Party partly updated. " .. table.concat(failed, "; ") .. "." })
            end
        end))
    end))
    return true, "Changing the party..."
end

return Party
