-- Party Picker (client): a small message window with an OK button, for messages the host must see
-- (plan docs/PLAN_inspiration_and_30.md, Parts D and E). Its own window, separate from the pick-four
-- window, so a message never replaces the picker.

local MessageWindow = {}

local window = nil

-- Word wrap at about `width` characters.
function MessageWindow.Wrap(text, width)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        if line ~= "" and #line + 1 + #word > width then
            lines[#lines + 1] = line
            line = word
        else
            line = (line == "" and word) or (line .. " " .. word)
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

local function clear(w)
    local kids = {}
    for _, child in ipairs(w.Children or {}) do kids[#kids + 1] = child end
    for _, child in ipairs(kids) do pcall(function() child:Destroy() end) end
end

function MessageWindow.Show(text)
    if not Ext.Net.IsHost() then return end
    if window == nil then
        window = Ext.IMGUI.NewWindow("Party Picker - Message")
        window.Closeable = true
        window.AlwaysAutoResize = true
    else
        clear(window)
    end
    -- One line per sentence-sized piece, so the auto-sized window stays narrow.
    for _, line in ipairs(MessageWindow.Wrap(tostring(text or ""), 70)) do window:AddText(line) end
    local ok = window:AddButton("OK")
    ok.IDContext = "PartyPicker_MessageOK"
    ok.OnClick = function() window.Open = false end
    window.Open = true
end

return MessageWindow
