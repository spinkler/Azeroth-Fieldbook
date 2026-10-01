local _,ns=...

-- Extend the native Filters dropdown; retain Blizzard's entries and callbacks.
local layers,registered={},false
local order={"Points","Labels","Zones","Merchants","Nodes"}
local loader=CreateFrame("Frame")
local function attach()
    if registered or not Menu or type(Menu.ModifyMenu)~="function" then return end
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING",function(_,root)
        local heading=false
        for _,name in ipairs(order) do
            local layer=layers[name]
            if layer then
                if not heading then root:CreateDivider();root:CreateTitle("Azeroth Fieldbook");heading=true end
                local check=root:CreateCheckbox(name,layer.selected,function()
                    if not layer.enabled or layer.enabled() then layer.set(not layer.selected()) end
                    return MenuResponse and MenuResponse.Refresh
                end)
                if check and check.SetEnabled then check:SetEnabled(not layer.enabled or layer.enabled()) end
            end
        end
    end)
    registered=true;loader:UnregisterEvent("ADDON_LOADED")
end
function ns.RegisterWorldMapLayer(name,selected,set,enabled)
    layers[name]={selected=selected,set=set,enabled=enabled}
    attach()
end
loader:RegisterEvent("ADDON_LOADED");loader:SetScript("OnEvent",attach)
attach()
