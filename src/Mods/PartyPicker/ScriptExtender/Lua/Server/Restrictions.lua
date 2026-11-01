-- Party Picker (server): the two places where the game's own scripts only
-- handle four party members, and what this mod does about each.
--
-- 1. Long rest. PROC_Camp_PlacePlayersInBed (Shared goal GLO_Camp.txt) puts
--    exactly four players into the four camp beds; anyone else is left out,
--    and other party-size mods report rests going wrong as a result.
--    The camp flow has a supported way to refuse End the Day with a story
--    reason: QRY_Camp_CheckPlayersReadyForNightModeStoryReasons adds a row to
--    DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason, the request fails,
--    and PROC_Camp_TryEnterNightModeFailed(player, reason) is called (the game
--    uses this for "REALLY_BlockFastTravel"). We add our own reason when the
--    party is larger than four, ask which four to keep, and put the others
--    back after LongRestFinished.
--
-- 2. The Ebonlake raft to Grymforge (Act 1 goal Act1_UND_EbonLake.txt). The
--    raft takes the whole party aboard (PROC_UND_EbonLake_Raft_ComposeCrew
--    adds every DB_Players member in the party group) but lands them by index
--    from DB_UND_EbonLake_Raft_Locations_PlayerPositions, which has indexes
--    1-4 per dock; boarding hides and freezes the whole crew (L490-497) and
--    landing only releases those with a position row (L589-609), so members 5+
--    stay hidden and frozen. No choice is needed here: we add indexes 5 up to
--    the party maximum (or the party's actual size, if larger), reusing the
--    existing positions, so everyone lands. The single-player raft path starts the dialog without a
--    ready check, so holding the crossing is not possible anyway.
--
-- Both use listeners and story databases only; no story file is replaced.

local Party = Ext.Require("Server/Party.lua")

local Restrictions = {}

local REST_REASON = "PartyPicker_PartyLargerThanFour"
local RAFT_POSITIONS_DB = "DB_UND_EbonLake_Raft_Locations_PlayerPositions"
local RESTORE_DELAY_MS = 2000
local RESTORE_RETRY_MS = 3000
local RESTORE_TRIES = 5

-- Pending trim, saved with the game so a save/load between trimming and
-- restoring does not lose the party (registered in Shared/Common.lua):
--   { party = {uuid...}  members before the trim,
--     trimmed = bool     true once someone was actually sent to camp,
--     reason = "rest" }
local function vars() return Ext.Vars.GetModVariables(ModuleUUID) end

function Restrictions.GetPending()
    local ok, p = pcall(function() return vars().Pending end)
    if ok and type(p) == "table" and type(p.party) == "table" then return p end
    return nil
end

-- Whole-table assignment: writes to sub-fields are not saved (API.md). Returns whether the write worked
-- (final review 2026-11-01, finding 8).
local function setPending(p)
    local ok, err = pcall(function() vars().Pending = p end)
    if not ok then PP.Log("could not save the restore record: " .. tostring(err)) end
    return ok
end

function Restrictions.ClearPending() setPending(nil) end

-- "Keep everyone this time" skips the next hold of that kind.
local bypassOnce = {}

-- The auto_restore=false reminder was shown for the current trim (cleared when a trim starts).
local reminded = false

local BYPASS_EXPIRES_MS = 120000

-- One counter per reason: an older press's expiry must not end a newer press early (finding 10).
local bypassSeq = {}
function Restrictions.BypassOnce(reason)
    bypassOnce[reason] = true
    bypassSeq[reason] = (bypassSeq[reason] or 0) + 1
    local mine = bypassSeq[reason]
    -- Only for the End the Day press that follows, not one much later.
    Ext.Timer.WaitForRealtime(BYPASS_EXPIRES_MS, function()
        if bypassSeq[reason] == mine then bypassOnce[reason] = nil end
    end)
    local p = Restrictions.GetPending()
    -- Only drop a record nobody was trimmed for; an earlier trim still
    -- waiting to be restored must survive.
    if p and not p.trimmed then setPending(nil) end
end

-- window: also in the message window (host only), for outcomes the player may not be looking at: the
-- automatic restore's warnings come while the Party tab is closed (final review 2026-11-01, finding 2).
-- hostOnly: about the host's own character; other players' clients do not show it.
function Restrictions.Notice(text, kind, window, hostOnly)
    PP.Log(text)
    pcall(function() PP.Net.Notice:Broadcast({ text = text, kind = kind or "info", hostOnly = hostOnly or nil }) end)
    if window then pcall(function() PP.Net.Message:Broadcast({ text = text }) end) end
end

local function overFour()
    return Party.ActiveCount() > PP.RESTRICTED_SIZE
end

-- Ask the host which four to keep.
local function ask(reason)
    local p = Restrictions.GetPending()
    if p and p.trimmed then
        -- Already trimmed once and not yet restored: keep the original list. A new table without `rested`:
        -- this is a new night, not yet rested (re-review 2026-11-01).
        p = { reason = reason, party = p.party, trimmed = true }
    else
        p = { reason = reason, party = Party.ActiveUuids(), trimmed = false }
    end
    setPending(p)
    PP.Net.PickFour:Broadcast({ reason = reason, size = PP.RESTRICTED_SIZE })
end

-- Called by Party.Apply just before the picker's choice sends anyone to camp, in the same Lua call, so a
-- save made while the trim runs already has the record marked (review 2026-10-31, point 1). If the record
-- is gone (a hand change on the Party tab cleared it while the picker was open), it is made again from
-- the party as it was before this change.
function Restrictions.MarkTrimming(reason, toRemove, activeBefore)
    if not toRemove or #toRemove == 0 then return end
    reminded = false
    local p = Restrictions.GetPending()
    if p and p.trimmed then return end
    -- A new table: writes to sub-fields are not saved (API.md). If it is not saved, the trim must not go ahead
    -- (Party.Apply refuses when this raises; final review 2026-11-01, finding 8).
    local ok = setPending({ reason = reason, party = (p and p.party) or activeBefore or {}, trimmed = true })
    local back = Restrictions.GetPending()
    if not ok or not back or not back.trimmed then error("the restore record was not saved") end
end

-- Called after the picker's choice was carried out (fully or partly).
function Restrictions.OnTrimmed(reason, result)
    local p = Restrictions.GetPending()
    if not p then return end
    if result and result.changed then
        p.trimmed = true
        setPending(p)
    end
    if result and result.ok and reason == "rest" then
        Restrictions.Notice("Party trimmed to four for the night. Press End the Day again.")
    end
end

-- Bring back the members who were sent to camp by a trim. Never sends
-- anyone to camp: whoever is in the party now stays, and returning members
-- only fill free places up to the limit. Members who cannot come back at all (dead, locked, gone, no
-- room) are named in the message; the record is still cleared, and the player adds them on the Party
-- tab once they can join (review 2026-10-31, point 4). Returns accepted, message, nothingToDo, skipped
-- (the list of { name, why } of the nothing-to-do case; the result of a change carries its own).
function Restrictions.Restore(done)
    local p = Restrictions.GetPending()
    if not p then
        return false, "There is no trimmed party to restore."
    end
    local accepted, message, nothingToDo, skipped = Party.Apply(p.party, { addOnly = true }, function(result)
        if result.ok then setPending(nil) end
        if done then done(result) end
    end)
    if nothingToDo then
        setPending(nil)
        skipped = skipped or {}
        if #skipped > 0 then
            return true, "Nobody else could come back: " .. Party.SkippedText(skipped) .. ".", true, skipped
        end
        return true, "Everyone is already back.", true, skipped
    end
    return accepted, message, false, {}
end

local GIVE_UP_HINT = "Use Restore on the Party tab. Choosing the party by hand on the Party tab ends the wait."

-- Waking up fires two triggers (LongRestFinished and the end of camp night). Each call starts a new run;
-- an older run stops scheduling attempts, but a success it reports is always shown.
-- The party has rested since the trim (the wake-up triggers): from then on the record may be resumed after a
-- load or a revive. A new table: writes to sub-fields are not saved (API.md).
local function markRested()
    local p = Restrictions.GetPending()
    if not p or not p.trimmed or p.rested then return end
    setPending({ reason = p.reason, party = p.party, trimmed = true, rested = true })
end

local autoRun = 0
-- quiet: a run started by loading a save (ResumeAfterLoad) gives up in the status line only, as the player
-- has just loaded and the Restore button is there (plan review 2026-11-01, point 5).
local deadWarned = false
local function autoRestore(quiet)
    local p = Restrictions.GetPending()
    if not p or not p.trimmed then return end
    autoRun = autoRun + 1
    local run = autoRun
    local tries = 0
    local function attempt()
        -- Another trigger (or the player) may have finished the job already.
        local current = Restrictions.GetPending()
        if not current or not current.trimmed then return end
        if run ~= autoRun then return end
        -- Your own character dead: every change is refused, so no retries; one warning per death. The restore
        -- starts again when they are revived (the Resurrected listener below).
        local deadText = Party.HostDeadText()
        if deadText then
            if not deadWarned then
                deadWarned = true
                Restrictions.Notice("The rest of your party is waiting in camp. " .. deadText, "warning", not quiet, true)
            end
            return
        end
        deadWarned = false
        if PP.Setting("auto_restore", true) == false then
            -- Once per trim, however far apart the two wake-up triggers come (diff review 2026-10-31).
            if not reminded then
                reminded = true
                Restrictions.Notice("The rest of your party is waiting in camp. Use Restore on the Party tab to bring them back.")
            end
            return
        end
        tries = tries + 1
        local accepted, message, nothingToDo, skipped = Restrictions.Restore(function(result)
            if result.ok then
                -- Back, but someone could not come (the skipped list): a warning in the message window too.
                local someone = result.skipped and #result.skipped > 0
                Restrictions.Notice(result.message, someone and "warning" or "info", someone and not quiet)
            elseif run ~= autoRun then
                PP.Log("restore incomplete (a newer attempt follows): " .. tostring(result.message))
            elseif tries < RESTORE_TRIES then
                PP.Log("restore incomplete, trying again: " .. tostring(result.message))
                Ext.Timer.WaitFor(RESTORE_RETRY_MS, attempt)
            else
                Restrictions.Notice(tostring(result.message) .. " " .. GIVE_UP_HINT, "warning", not quiet)
            end
        end)
        if accepted then
            -- Someone left out (the skipped list): a warning, not info.
            if nothingToDo then
                local someone = skipped and #skipped > 0
                Restrictions.Notice(message, someone and "warning" or "info", someone and not quiet)
            end
            return
        end
        if tries < RESTORE_TRIES then
            PP.Log("restore refused, trying again: " .. tostring(message))
            Ext.Timer.WaitFor(RESTORE_RETRY_MS, attempt)
        else
            Restrictions.Notice("Could not bring the party back yet (" .. tostring(message) .. "). " .. GIVE_UP_HINT,
                "warning", not quiet)
        end
    end
    -- The delay also merges the two wake-up triggers into one run.
    Ext.Timer.WaitFor(RESTORE_DELAY_MS, attempt)
end

-- A save loaded with members still waiting in camp after a long rest (saved after the wake-up, or after the
-- tries gave up): try again, unless it is camp night (the end of the night starts it). Called on the first
-- LevelGameplayStarted of a Lua session only, i.e. after a load (final review 2026-11-01, finding 9).
function Restrictions.ResumeAfterLoad()
    local p = Restrictions.GetPending()
    -- Only once the party has rested: a save between "Keep these 4" and the second End the Day must keep the
    -- trim (diff review 2026-11-01).
    if not p or not p.trimmed or not p.rested then return end
    local ok, rows = pcall(function() return Osi.DB_Camp_NightMode:Get(1) end)
    if ok and type(rows) == "table" and next(rows) ~= nil then return end
    autoRestore(true)
end

-- Raft: add landing positions 5..N for every dock, cycling through the
-- existing positions 1..4 of that dock. N is the party maximum, or the number
-- of party rows if the story has made the party larger than that
-- (_GLO_Shared_PartyMembers.txt L134-155). Only runs where the raft goal's rows
-- exist; inserting an existing row is a no-op.
function Restrictions.ExtendRaft()
    if PP.Setting("extend_raft", true) == false then return 0 end
    local ok, rows = pcall(function() return Osi[RAFT_POSITIONS_DB]:Get(nil, nil, nil) end)
    if not ok or type(rows) ~= "table" or #rows == 0 then return 0 end
    local byFlag = {}
    for _, row in ipairs(rows) do
        local flag, index, trigger = row[1], tonumber(row[2]), row[3]
        if flag and index and trigger then
            byFlag[flag] = byFlag[flag] or {}
            byFlag[flag][index] = trigger
        end
    end
    local okP, players = pcall(function() return Osi.DB_Players:Get(nil) end)
    local partyRows = (okP and type(players) == "table") and #players or 0
    local maxIndex = math.max(PP.MAX_PARTY_SIZE, partyRows)
    local added = 0
    for flag, positions in pairs(byFlag) do
        if positions[1] and positions[2] and positions[3] and positions[4] then
            for i = 5, maxIndex do
                if not positions[i] then
                    local trigger = positions[((i - 1) % 4) + 1]
                    local okInsert = pcall(function() Osi[RAFT_POSITIONS_DB](flag, i, trigger) end)
                    if okInsert then added = added + 1 end
                end
            end
        end
    end
    if added > 0 then PP.Log("raft: added " .. added .. " landing positions") end
    return added
end

function Restrictions.Register()
    -- Long rest: refuse End the Day while the party is larger than four.
    -- "before" so our row is added after QRY_Camp_CheckPlayersReadyForNightMode
    -- has cleared old reasons and before the readiness test reads them.
    Ext.Osiris.RegisterListener("QRY_Camp_CheckPlayersReadyForNightModeStoryReasons", 0, "before", function()
        if PP.Setting("prompt_long_rest", true) == false then return end
        if not overFour() then return end
        if bypassOnce.rest then bypassOnce.rest = nil; return end
        local ok, err = pcall(function()
            Osi.DB_Camp_PlayerNotReadyForNightMode_CustomStoryReason(REST_REASON)
        end)
        if not ok then PP.Log("could not hold the long rest: " .. tostring(err)) end
    end)

    Ext.Osiris.RegisterListener("PROC_Camp_TryEnterNightModeFailed", 2, "after", function(_, reason)
        if reason ~= REST_REASON then return end
        PP.Log("long rest held: party is larger than four")
        ask("rest")
    end)

    Ext.Osiris.RegisterListener("LongRestFinished", 0, "after", function()
        markRested()
        autoRestore()
    end)

    -- Your own character revived (plan 1.1.4 unit A): a restore that waited for it starts again, once the
    -- party has rested.
    Ext.Osiris.RegisterListener("Resurrected", 1, "after", function(id)
        local p = Restrictions.GetPending()
        if not p or not p.rested then return end
        local okA, rows = pcall(function() return Osi.DB_Avatars:Get(id) end)
        if okA and type(rows) == "table" and next(rows) ~= nil then autoRestore() end
    end)

    -- Party changes are blocked during camp night (CampNightMode); try again
    -- once the camp switches back to day (GLO_Camp.txt DB_Camp_NightMode).
    Ext.Osiris.RegisterListener("DB_Camp_NightMode", 1, "afterDelete", function()
        markRested()
        autoRestore()
    end)

    -- The raft goal's rows may only appear after the level started (the
    -- Underdark is in the Act 1 level), so extend again just before the
    -- crew is landed: PROC_UND_EbonLake_DisembarkCrew reads the table.
    Ext.Osiris.RegisterListener("PROC_UND_EbonLake_DisembarkCrew", 1, "before", function()
        Restrictions.ExtendRaft()
    end)
end

return Restrictions
