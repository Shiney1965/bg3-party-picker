-- Party Picker (server): the party-size limit is never below the party.
-- Plan docs/PLAN_inspiration_and_30.md, Part D (the author, 2026-10-25: "if you attempt to set the limit below the
-- current party number the mod should block that action and set it to the current party number, and tell
-- the user to reduce the party").
--
-- Party.EffectiveMaxSize() already never goes below the party. This module handles the two ways the setting
-- can end up below it, and tells the host:
--   * the host moves the slider below the party: once the slider has been still for a moment, the setting is
--     written back to the party count (MCM.Set) and a message explains why;
--   * a save loads (or an MCM profile is switched) with a bigger party than the setting: the setting is NOT
--     written back, because MCM settings are shared by every save; the message says this game uses the
--     bigger number and the setting stays.
--
-- MCM facts (BG3-MCM v1.41 source): MCM.Set(id, value) returns true or false (false without raising, e.g. a
-- value outside the slider's range), saves to the profile, moves an open slider, and emits no
-- MCM_Setting_Saved unless asked to, so writing back here does not loop. MCM_Setting_Saved arrives many times
-- during one drag.

local Party = Ext.Require("Server/Party.lua")

local LimitGuard = {}

local SETTING = "max_party_size"
-- How long the slider must be still before the setting is checked (real time, so a game paused in the
-- menu does not delay it).
local SETTLE_MS = 1500
-- After a level has loaded, wait for other mods' load-time party changes before counting.
local LOAD_CHECK_MS = 3000

local generation = 0
-- The load message is shown once per party size and setting, not on every level load of a session.
local lastLoadNotice = nil

local function message(text)
    PP.Log(text)
    pcall(function() PP.Net.Message:Broadcast({ text = text }) end)
end

-- The slider moved. The effective limit has already been applied (BootstrapServer); this checks the
-- setting once the slider is still.
function LimitGuard.OnSettingChanged()
    generation = generation + 1
    local mine = generation
    Ext.Timer.WaitForRealtime(SETTLE_MS, function()
        if mine ~= generation then return end -- the slider moved again
        local ok, err = pcall(function()
            local setting, party = Party.MaxSize(), Party.PartyFloor()
            if setting >= party then return end
            -- Who counts: during a long-rest night, also the members waiting in camp to come back.
            local waitingInCamp = party - Party.ActiveCount()
            local who = string.format("the number in your party (%d)", party)
            local how = "send members to camp on the Party tab first, then lower the limit."
            if waitingInCamp > 0 then
                who = string.format("your party (%d, including the %d waiting in camp after the long rest)",
                    party, waitingInCamp)
                how = "bring them back first (Restore on the Party tab, or wait until morning), then send "
                    .. "members to camp and lower the limit."
            end
            if party > PP.MAX_PARTY_SIZE then
                Party.ApplyMaxSize()
                message(string.format("The party limit can't be lower than %s. The slider only goes up to %d, "
                    .. "so Party Picker uses %d in this game without changing the setting. To lower it, %s",
                    who, PP.MAX_PARTY_SIZE, party, how))
                return
            end
            local okSet, written = pcall(MCM.Set, SETTING, party)
            Party.ApplyMaxSize()
            if okSet and written == true then
                message(string.format("The party limit can't be lower than %s. It has been set to %d. "
                    .. "To lower it, %s", who, party, how))
            else
                message(string.format("The party limit can't be lower than %s. Party Picker uses %d, but could "
                    .. "not change the setting itself. To lower it, %s", who, party, how))
            end
        end)
        if not ok then PP.Log("party limit check failed: " .. tostring(err)) end
    end)
end

-- A save has loaded or the MCM profile changed: tell the host if this game's party is bigger than the
-- setting. The setting is left alone (it is shared by every save).
function LimitGuard.CheckLoadedParty()
    Ext.Timer.WaitForRealtime(LOAD_CHECK_MS, function()
        local ok, err = pcall(function()
            Party.ApplyMaxSize()
            local setting, party = Party.MaxSize(), Party.PartyFloor()
            if setting >= party then return end
            local key = setting .. "/" .. party
            if key == lastLoadNotice then return end
            lastLoadNotice = key
            message(string.format("This game's party has %d members, more than your Maximum party size (%d). "
                .. "Party Picker uses %d in this game; your setting stays %d.", party, setting, party, setting))
        end)
        if not ok then PP.Log("party limit check failed: " .. tostring(err)) end
    end)
end

-- Another mod that sets the same limit (compatibility only; the author: other party mods, use at your own risk).
-- Configurable Party Limit (Nexus 11172, meta.lsx UUID 16b5fbb6-...) sets the party limit too (its
-- Server/_Init.lua, read 2026-10-24 for compatibility only).
function LimitGuard.WarnOtherMods()
    local ok, loaded = pcall(Ext.Mod.IsModLoaded, "16b5fbb6-72fe-4a08-814a-87a9fc0b14bc")
    if ok and loaded then
        PP.Log("WARNING: Configurable Party Limit is also active. It sets the same party-size limit as Party "
            .. "Picker; the two will overwrite each other. Use at your own risk.")
    end
end

return LimitGuard
