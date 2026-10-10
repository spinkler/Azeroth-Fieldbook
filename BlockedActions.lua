local addonName = ...
-- Register before the other modules so startup failures are observable.
-- Session-only diagnostics; do not alter Blizzard's protection or popup.
local rows = {}
local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, owner, action)
    if issecretvalue and (issecretvalue(owner) or issecretvalue(action)) then return end
    if owner ~= addonName then return end
    if type(action) ~= "string" then action = "unknown function" end
    action = action:gsub("|", ""):gsub("[%c]", " "):sub(1, 240)
    rows[#rows + 1] = event .. ": " .. action
    if #rows > 20 then table.remove(rows, 1) end
end)
SLASH_AZEROTHFIELDBOOKBLOCKED1 = "/afbblocked"
SlashCmdList.AZEROTHFIELDBOOKBLOCKED = function()
    print("Azeroth Fieldbook blocked actions (this session): " .. #rows)
    for _, row in ipairs(rows) do print(row) end
end
