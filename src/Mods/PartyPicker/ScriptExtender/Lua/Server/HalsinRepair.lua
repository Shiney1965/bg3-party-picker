-- Party Picker (server): !pp_halsin, the repair for a save where an earlier Party Picker added Halsin to the
-- party before the story made him recruitable (reported in game 2026-10-27; plan
-- docs/PLAN_halsin_recruit_gate.md). His Lifting the Curse states then never ran, so he never went to Last
-- Light and Art Cullagh's conversation never brought him in (Act2_HAV_LiftingTheCurse_CursedFist.txt
-- L241-250 needs state HalsinAtHaven).
--
--   !pp_halsin          report only.
--   !pp_halsin repair   put him back where the story expects him: in camp with his Act 2 camp dialog, not
--                       recruitable, so the game's own rules run again. Then talk to him in camp.
--   !pp_halsin haven    fallback after repair, if that conversation offers no way to send him to Last Light:
--                       the reaction the conversation would trigger.
-- Story files: the author's extract, Mods/GustavDev/Story/RawFiles/Goals/ unless noted.

local Party = Ext.Require("Server/Party.lua")

local HalsinRepair = {}

local H = "S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323"
local NULL_ID = "NULL_00000000-0000-0000-0000-000000000000"
local QUEST = "SCL_LiftingTheCurse"
local function state(name) return "SCL_LiftingTheCurse_State_" .. name end
-- His Act 2 camp dialog. CAMP_Halsin and CAMP_Halsin2 are the same resource (same id); the story sets it on
-- reaching the Shadow-Cursed Lands (Act2_GLO_LiftingTheCurse_SetUp.txt L130-134).
local CAMP_DIALOG = "CAMP_Halsin2_c0ab0f6f-3ffc-d06d-0d6d-d1aaef70dfe4"
local FIRST_RECRUIT = "RecruitedFirstTime_Halsin" -- QRY_OnlyOnce key, GLO_Companion_Halsin.txt L41-47

local FLAGS = {
    recruitable = Party.HALSIN_RECRUITABLE_FLAG,
    inAct2 = "GLO_LiftingTheCurse_State_HalsinIsInAct2_dd398e58-f86f-4676-affd-390d4acc615e",
    travelToHaven = "GLO_LiftingTheCurse_Event_TravelToHaven_a946f0b8-badb-435d-915d-2e6a45845c7c",
    liftingCurse = "HAV_LiftingTheCurse_State_HalsinLiftingCurse_1786f223-c61a-4683-b9ab-54a8f0aa8a97",
    atHaven = "HAV_LiftingTheCurse_State_HalsinAtHaven_5bb65571-a6ad-4c34-abd3-b1f407a9cafc",
    availableForFist = "HAV_LiftingTheCurse_State_HalsinAvailableForFist_38bd3ada-29d4-4a1d-900b-c58799aad3df",
    goToLake = "HAV_LiftingTheCurse_State_HalsinGoToLake_bc4cd1f7-5e60-40e1-a583-aa886fe5b682",
    artAwake = "SCL_AncientFist_State_HasWokenUpFist_45cddb53-edf5-4a9e-9943-898f55b29af3",
}
local FLAG_ORDER = { "recruitable", "inAct2", "travelToHaven", "liftingCurse", "atHaven", "availableForFist",
    "goToLake", "artAwake" }

local function say(msg) PP.Log("!pp_halsin: " .. msg) end

local function flag(key)
    local ok, v = pcall(Osi.GetFlag, FLAGS[key], NULL_ID)
    if not ok then return nil end
    return v == 1
end

-- The query needs exactly the table's column count, nils included (table.pack keeps trailing nils).
local function rows(db, ...)
    local args = table.pack(...)
    local ok, r = pcall(function() return Osi[db]:Get(table.unpack(args, 1, args.n)) end)
    if ok and type(r) == "table" then return r end
    return nil
end

local function inDb(db, id)
    local r = rows(db, id)
    return r ~= nil and next(r) ~= nil
end

-- The current Lifting the Curse state names (normally one).
local function currentStates()
    local out = {}
    for _, row in ipairs(rows("DB_State_Current", H, QUEST, nil) or {}) do out[#out + 1] = tostring(row[3]) end
    return out
end

local function yesNo(v)
    if v == nil then return "?" end
    return v and "yes" or "no"
end

function HalsinRepair.Report()
    local states = currentStates()
    say("state: " .. (#states > 0 and table.concat(states, ", ") or "(none)"))
    say(string.format("in party %s; in camp %s; team %s; dead %s; knocked out %s; perma-defeated %s",
        yesNo(inDb("DB_Players", H)), yesNo(inDb("DB_InCamp", H)), yesNo(inDb("DB_PartOfTheTeam", H)),
        yesNo((function()
            local ok, v = pcall(Osi.IsDead, H)
            if not ok then return nil end
            return v == 1
        end)()),
        yesNo(inDb("DB_KnockedOut", H)), yesNo(inDb("DB_PermaDefeated", H))))
    local parts = {}
    for _, k in ipairs(FLAG_ORDER) do parts[#parts + 1] = k .. " " .. yesNo(flag(k)) end
    say("flags: " .. table.concat(parts, "; "))
    local dialogs = {}
    for _, row in ipairs(rows("DB_Dialogs", H, nil) or {}) do dialogs[#dialogs + 1] = tostring(row[2]) end
    say("dialog: " .. (#dialogs > 0 and table.concat(dialogs, ", ") or "(none)"))
    say("first-recruit record (DB_OnlyOnce " .. FIRST_RECRUIT .. "): " .. yesNo(inDb("DB_OnlyOnce", FIRST_RECRUIT)))
    local levels = {}
    for _, row in ipairs(rows("DB_CurrentLevel", nil) or {}) do levels[#levels + 1] = tostring(row[1]) end
    say("level: " .. (#levels > 0 and table.concat(levels, ", ") or "?"))
    say("make a hard save before !pp_halsin repair or !pp_halsin haven.")
end

-- Why the repair cannot run now, or nil. `allowed` = state names it may start from.
local function refusal(allowed)
    if not inDb("DB_CurrentLevel", "SCL_Main_A") then
        return "only in the Shadow-Cursed Lands (Act 2, level SCL_Main_A)."
    end
    if not inDb("DB_PartOfTheTeam", H) then return "Halsin is not in your camp team." end
    -- A party change still running could add him after the repair, undoing it (review 2026-10-27).
    if Party.IsBusy() then return "a party change is still running. Wait a moment and try again." end
    if inDb("DB_Players", H) then
        return "Halsin is in the party. Send him to camp on the Party tab first (untick him, Apply), then run this again."
    end
    local okD, dead = pcall(Osi.IsDead, H)
    if not okD or dead == 1 then return "Halsin is dead (or his state could not be read)." end
    -- Not recruitable + knocked out = permanently defeated (Gustav GLO_Journal.txt L357-362).
    if inDb("DB_KnockedOut", H) or inDb("DB_PermaDefeated", H) then
        return "Halsin is knocked out or defeated. Revive him first."
    end
    if flag("artAwake") ~= false then return "Art Cullagh is already awake (or the flag could not be read)." end
    if flag("goToLake") ~= false then return "Halsin is already on his way to the lake ritual." end
    local states = currentStates()
    if #states ~= 1 or not allowed[states[1]] then
        return "his quest state is " .. (#states > 0 and table.concat(states, ", ") or "(none)")
            .. "; the repair only starts from " .. table.concat((function()
                local t = {}
                for k in pairs(allowed) do t[#t + 1] = k end
                table.sort(t)
                return t
            end)(), ", ") .. "."
    end
    return nil
end

local function call(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then say(what .. " failed: " .. tostring(err)) end
    return ok
end

function HalsinRepair.Repair()
    local why = refusal({ [state("HalsinWaiting")] = true, [state("HalsinInAct2")] = true,
        [state("HalsinAtCamp")] = true })
    if why then say("not repaired: " .. why); return false end
    local recruitable = flag("recruitable")
    if recruitable == nil then say("not repaired: the recruitable flag could not be read."); return false end
    if not recruitable then
        say("not repaired: Halsin is not marked recruitable, so the story's gate is already in place (nothing to undo).")
        return false
    end
    -- HalsinInAct2's own effects (Act2_GLO_LiftingTheCurse_SetUp.txt L121-128) if the state never got there.
    -- PROC_State_Progress only moves to a state of equal or higher priority (Shared _Global_StateProgression.txt
    -- L37-50) and can do nothing without an error, so the result is read back.
    if currentStates()[1] == state("HalsinWaiting") then
        if not call("moving his state to HalsinInAct2", Osi.PROC_State_Progress, H, QUEST, state("HalsinInAct2")) then
            return false
        end
        if currentStates()[1] ~= state("HalsinInAct2") then
            say("not repaired: the game did not move his state to HalsinInAct2; nothing else was changed.")
            return false
        end
    end
    -- His Act 2 camp dialog, as the story sets it on reaching the Shadow-Cursed Lands.
    if not call("removing his dialog", Osi.PROC_RemoveDialog, H) then return false end
    if not call("setting his camp dialog", function() Osi.DB_Dialogs(H, CAMP_DIALOG) end) then return false end
    call("SetHasDialog", Osi.SetHasDialog, H, 1)
    -- Not recruitable again, and his first real join runs the game's first-recruit block again (which sets
    -- the flag back, GLO_Companion_Halsin.txt L41-47). The Act 2 finale sets the flag only as a fallback
    -- (Act2_TWN_LiftingTheCurse_Finale.txt L153-181), so the record must go too (review 2026-10-27, B1).
    if not call("clearing the first-recruit record", function() Osi.DB_OnlyOnce:Delete(FIRST_RECRUIT) end) then
        return false
    end
    if not call("clearing the recruitable flag", Osi.PROC_GlobalClearFlagAndCache, FLAGS.recruitable) then
        return false
    end
    say("done. Talk to Halsin in camp and let him go ahead to Last Light. If that conversation has no such"
        .. " option, run !pp_halsin haven. Until he rejoins after Thaniel, a knockout is permanent for him (as in"
        .. " the unmodded game), and the Party tab keeps him locked.")
    HalsinRepair.Report()
    return true
end

function HalsinRepair.Haven()
    if flag("recruitable") ~= false then say("not done: run !pp_halsin repair first."); return false end
    if flag("travelToHaven") ~= false then say("not done: he has already been sent to Last Light."); return false end
    local why = refusal({ [state("HalsinInAct2")] = true, [state("HalsinAtCamp")] = true })
    if why then say("not done: " .. why); return false end
    -- What the camp conversation does (Act2_CAMP_LiftingTheCurse.txt L4, L56-63; the one-argument helper,
    -- Shared _Greevers_Little_Helpers.txt).
    if not call("setting TravelToHaven", Osi.PROC_GlobalSetFlagAndCache, FLAGS.travelToHaven) then return false end
    if not call("sending him to Last Light", Osi.PROC_GlobalFlagReactionAfterDialog, FLAGS.travelToHaven) then
        return false
    end
    say("done: Halsin is on his way to Last Light. Talk to Art Cullagh once Halsin is there.")
    HalsinRepair.Report()
    return true
end

function HalsinRepair.Console(arg)
    arg = string.lower(tostring(arg or ""))
    if arg == "" then HalsinRepair.Report()
    elseif arg == "repair" then HalsinRepair.Repair()
    elseif arg == "haven" then HalsinRepair.Haven()
    else say("usage: !pp_halsin  |  !pp_halsin repair  |  !pp_halsin haven  (make a hard save before repair or haven)") end
end

return HalsinRepair
