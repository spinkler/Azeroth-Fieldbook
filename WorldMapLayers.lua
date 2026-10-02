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

-- Wait for the map's first visible frame, including a lazily loaded WorldMap.
-- The account flag is written only after the native gold HelpTip is displayed.
local tutorial=CreateFrame("Frame");tutorial:Hide()
local tutorialMap
local tutorialText="Click the drop down list for Azeroth Fieldbook filters"
local function hideTutorial()
    if HelpTip and tutorialMap then HelpTip:Hide(tutorialMap,tutorialText) end
end
local function queueTutorial() tutorial:Show() end
local function attachTutorial()
    local map=WorldMapFrame
    if not map or tutorialMap==map then return end
    tutorialMap=map
    map:HookScript("OnShow",queueTutorial)
    map:HookScript("OnHide",function() tutorial:Hide();hideTutorial() end)
    if map:IsShown() then queueTutorial() end
end
tutorial:SetScript("OnUpdate",function(self)
    self:Hide()
    local account=AzerothFieldbookAccountDB
    if not registered or not next(layers) or type(account)~="table" or account.worldMapFiltersTutorialSeen
        or not tutorialMap or not tutorialMap:IsShown() or not HelpTip then return end
    -- Blizzard stores the unnamed tracking dropdown among its overlay frames.
    local anchor
    for _,frame in ipairs(tutorialMap.overlayFrames or {}) do
        if type(frame.worldMapFilters)=="table" and type(frame.GetWorldMapFilters)=="function" then
            anchor=frame;break
        end
    end
    if not anchor or not anchor:IsShown() then return end
    local shown=HelpTip:Show(tutorialMap,{
        text=tutorialText,textColor=NORMAL_FONT_COLOR,
        buttonStyle=HelpTip.ButtonStyle.Close,targetPoint=HelpTip.Point.LeftEdgeCenter,
        autoEdgeFlipping=true,autoHideWhenTargetHides=true,
    },anchor)
    if shown then
        account.worldMapFiltersTutorialSeen=true
        anchor:HookScript("OnMouseDown",hideTutorial)
        self:UnregisterEvent("ADDON_LOADED");self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
tutorial:RegisterEvent("ADDON_LOADED");tutorial:RegisterEvent("PLAYER_LOGIN")
tutorial:SetScript("OnEvent",attachTutorial)
attachTutorial()
