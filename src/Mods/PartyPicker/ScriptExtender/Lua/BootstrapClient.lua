-- Party Picker (client).
Ext.Require("Shared/Common.lua")
local PartyTab = Ext.Require("Client/PartyTab.lua")
local PickFour = Ext.Require("Client/PickFour.lua")
local MessageWindow = Ext.Require("Client/MessageWindow.lua")

PP.Net.PickFour:SetHandler(function(data)
    data = data or {}
    PickFour.Show(data.reason, data.size)
end)

-- A message window for the host (MessageWindow.Show itself skips other players).
PP.Net.Message:SetHandler(function(data)
    local ok, err = pcall(MessageWindow.Show, data and data.text or "")
    if not ok then PP.Log("could not show the message: " .. tostring(err)) end
    -- The limit guard sends these after writing the party size back (MCM.Set sends no event).
    pcall(PartyTab.SettingChanged)
end)

-- A setting the Party tab shows was changed: redraw it. MCM saves the value on the server first and
-- then passes the event on to the clients (BG3-MCM Server/MCMServer.lua, SetSettingValue).
local tabSettings = {
    inspiration_point_controls = true,
    inspiration_limit = true,
    inspiration_match_party = true,
    max_party_size = true,
}
pcall(function()
    Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
        if payload and payload.modUUID == ModuleUUID and tabSettings[payload.settingId] then
            pcall(PartyTab.SettingChanged)
        end
    end)
end)

-- The Inspiration limit for a client that is not the host (multiplayer; untested). The host's own
-- client shares the server's static data, so it needs nothing.
PP.Net.Inspiration:SetHandler(function(data)
    pcall(function()
        if Ext.Net.IsHost() then return end
        local limit = data and tonumber(data.limit)
        if not limit then return end
        local d = Ext.StaticData.Get(PP.INSPIRATION_UUID, "ActionResource")
        if d then d.MaxValue = limit end
    end)
end)

PP.Net.Notice:SetHandler(function(data)
    local text = data and data.text or ""
    PP.Log(text)
    PickFour.Notice(text)
    PartyTab.SetStatus(text)
end)

-- The Party tab inside MCM. MCM 1.38+ accepts a table of named arguments
-- (BG3-MCM MCMAPIImplementations.lua, InsertModMenuTab).
local inserted = false
if MCM and MCM.InsertModMenuTab then
    local ok, err = pcall(MCM.InsertModMenuTab, {
        tabName = "Party",
        tabCallback = function(tab) PartyTab.Attach(tab) end,
    })
    inserted = ok
    if not ok then PP.Log("could not add the MCM Party tab: " .. tostring(err)) end

    -- Re-read the party whenever our MCM page is opened.
    pcall(function()
        Ext.ModEvents.BG3MCM["MCM_Mod_Tab_Activated"]:Subscribe(function(payload)
            if payload and payload.modUUID == ModuleUUID then PartyTab.Activated() end
        end)
    end)
end

-- Fallback without MCM (and handy for testing): client console  !pp
local standalone = nil
Ext.RegisterConsoleCommand("pp", function()
    if standalone == nil then
        standalone = Ext.IMGUI.NewWindow("Party Picker - Party")
        standalone.Closeable = true
        standalone.AlwaysAutoResize = true
        PartyTab.Attach(standalone)
    else
        PartyTab.Attach(standalone)
    end
    standalone.Open = true
end)

PP.Log("client loaded (v" .. PP.VERSION .. ")" .. (inserted and " (Party tab added to MCM)" or "") .. ". Client console: !pp")
