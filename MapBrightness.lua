local _,ns=...
-- One terrain preference for every Fieldbook map, independent of journal scope.
local B={listeners={}};ns.MapBrightness=B
local function valid(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="number"
        and value>=0.2 and value<=1
end
function B:Initialize(saved,atlas,gathering)
    if ns.InitializationBlocked then return end
    self.saved=saved
    if not valid(saved.mapBrightness) then
        -- Prefer the Atlas control being replaced, then the older Locations controls.
        local settings=type(atlas)=="table" and type(atlas.settings)=="table" and atlas.settings
        local value=settings and settings.mapBrightness
        if not valid(value) then value=saved.locationMapBrightness end
        if not valid(value) then value=type(gathering)=="table" and gathering.mapBrightness end
        saved.mapBrightness=valid(value) and value or 0.8
    end
    self:Refresh()
end
function B:Get() return self.saved and self.saved.mapBrightness or 0.8 end
function B:Refresh()
    for _,refresh in pairs(self.listeners) do refresh() end
end
function B:Set(value)
    if ns.InitializationBlocked or not self.saved or not valid(value) then return end
    if self.saved.mapBrightness==value then return end
    self.saved.mapBrightness=value
    self:Refresh()
end
function B:Attach(map,getValue,setValue,apply)
    local panel=CreateFrame("Frame",nil,map)
    panel:SetPoint("BOTTOMLEFT",map,"BOTTOMLEFT",8,8);panel:SetSize(218,20)
    panel:SetFrameLevel(map:GetFrameLevel()+8)
    local function label(text,x,width)
        local font=ns.TextSize and ns.TextSize:Font("GameFontHighlightSmall") or "GameFontHighlightSmall"
        local t=panel:CreateFontString(nil,"OVERLAY",font)
        t:SetPoint("TOPLEFT",x,-4);t:SetWidth(width);t:SetJustifyH("LEFT")
        t:SetWordWrap(false);t:SetTextColor(0.55,0.57,0.57);t:SetText(text)
        return t
    end
    label("Brightness",0,72)
    local slider=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",80,-2);slider:SetSize(90,16)
    for _,key in ipairs({"Low","High","Text"}) do
        local region=slider[key]
        if type(region)=="table" or type(region)=="userdata" then region:Hide() end
    end
    slider.track=slider:CreateTexture(nil,"BACKGROUND")
    slider.track:SetPoint("TOPLEFT",2,-4);slider.track:SetPoint("BOTTOMRIGHT",-2,4)
    slider.track:SetColorTexture(0.045,0.032,0.018,1)
    slider:SetMinMaxValues(0.2,1);slider:SetValueStep(0.05);slider:SetObeyStepOnDrag(true)
    slider.valueLabel=label("",180,36);slider.panel=panel
    function slider:Display(value)
        self.syncing=true;self:SetValue(value);self.syncing=false
        self.valueLabel:SetText(math.floor(value*100+0.5).."%")
    end
    local function get() return B.saved and B:Get() or getValue() end
    slider:SetScript("OnValueChanged",function(self,value)
        if self.syncing or not valid(value) then return end
        value=math.floor(value*20+0.5)/20
        if B.saved then B:Set(value) else setValue(value) end
        self:Display(get());apply()
    end)
    slider:SetScript("OnEnter",function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Map brightness")
            GameTooltip:AddLine("Shared by every Fieldbook map (20–100%). Labels, shading, markers and player arrows keep their contrast.",1,1,1,true)
            GameTooltip:Show()
        end
    end)
    slider:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    local function refresh() slider:Display(get());apply() end
    self.listeners[map]=refresh
    panel:SetScript("OnShow",refresh)
    slider:Display(get())
    return slider
end
