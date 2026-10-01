local _,ns=...

-- Extend the native Filters dropdown; retain Blizzard's entries and callbacks.
local layers,registered={},false
local order={"Points","Labels","Zones","Merchants","Nodes"}
local loader=CreateFrame("Frame")
local updates={}
local worker=CreateFrame("Frame");worker:Hide()
worker:SetScript("OnUpdate",function(self)
    self:Hide()
    local pending=updates;updates={}
    for name,layer in pairs(pending) do
        -- Rebinding a journal must not redraw a previous journal's frames.
        if layers[name]==layer and layer.refresh then layer.refresh() end
    end
end)
local function attach()
    if registered or not Menu or type(Menu.ModifyMenu)~="function" then return end
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING",function(_,root)
        local heading=false
        for _,name in ipairs(order) do
            local layer=layers[name]
            if layer then
                if not heading then root:CreateDivider();root:CreateTitle("Azeroth Fieldbook");heading=true end
                local check=root:CreateCheckbox(name,layer.selected,function()
                    if layers[name]~=layer or (layer.enabled and not layer.enabled()) then return end
                    layer.set(not layer.selected())
                    if layer.refresh then updates[name]=layer;worker:Show() end
                    -- Native checkboxes already default to Refresh. Return no
                    -- addon-supplied response into the forbidden menu delegate.
                end)
                -- These are addon display preferences, not selections belonging
                -- to Blizzard's filter button or its selection-text traversal.
                if check and check.SetSelectionIgnored then check:SetSelectionIgnored() end
                if check and check.SetEnabled then check:SetEnabled(not layer.enabled or layer.enabled()) end
            end
        end
    end)
    registered=true;loader:UnregisterEvent("ADDON_LOADED")
end
function ns.RegisterWorldMapLayer(name,selected,set,enabled,refresh)
    layers[name]={selected=selected,set=set,enabled=enabled,refresh=refresh}
    attach()
end
loader:RegisterEvent("ADDON_LOADED");loader:SetScript("OnEvent",attach)
attach()
