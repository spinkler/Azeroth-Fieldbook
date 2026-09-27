local _, ns = ...
local U={};ns.AtlasUI=U
local ui=ns.FieldbookUI
U.Button=ui.Button;U.Edit=ui.Edit
function U.MenuButton(parent,text,x,y,width,action)
    local button=U.Button(parent,text,x,y,width,action)
    button.arrowShadow=button:CreateTexture(nil,"OVERLAY",nil,-1)
    button.arrowShadow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    button.arrowShadow:SetPoint("RIGHT",-11,-1);button.arrowShadow:SetSize(10,12)
    button.arrowShadow:SetVertexColor(0,0,0,0.85)
    button.arrow=button:CreateTexture(nil,"OVERLAY")
    button.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    button.arrow:SetPoint("RIGHT",-12,0);button.arrow:SetSize(10,12)
    local label=button:GetFontString()
    if label then
        label:ClearAllPoints();label:SetPoint("LEFT",10,0);label:SetPoint("RIGHT",-28,0)
        label:SetJustifyH("CENTER");label:SetWordWrap(false)
    end
    return button
end
function U.ZoneMenu(parent,x,y,width,getMaps,onSelect)
    local button
    button=U.MenuButton(parent,"Choose zone",x,y,width,function()
        if not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
        MenuUtil.CreateContextMenu(button,function(_,root)
            root:SetScrollMode(420)
            local groups=ns.Atlas.MapMenuGroups(getMaps())
            for _,group in ipairs(groups) do
                local submenu=root:CreateButton(ns.Atlas.Safe(group.name))
                submenu:SetScrollMode(420)
                if group.base then
                    local base=group.base
                    submenu:CreateButton("View "..ns.Atlas.Safe(base.zone),function() onSelect(base.mapID,base.zone) end)
                    submenu:CreateDivider()
                end
                for _,row in ipairs(group.rows) do
                    if not group.base or row.mapID~=group.base.mapID then
                        submenu:CreateButton(ns.Atlas.Safe(row.zone),function() onSelect(row.mapID,row.zone) end)
                    end
                end
            end
            if #groups==0 then root:CreateTitle("No maps available") end
        end)
    end)
    return button
end
function U.Label(parent,text,x,y,width,font)
    local label=ui.Label(parent,text,x,y,width,font)
    if font and font:find("GameFontNormal",1,true) then label:SetTextColor(1,0.82,0.14)
    elseif font and font:find("Disable",1,true) then label:SetTextColor(0.55,0.57,0.57) end
    return label
end
function U.Tip(control,text)
    control:SetScript("OnEnter",function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            GameTooltip:SetText("Map layer")
            GameTooltip:AddLine(text,1,1,1,true)
            GameTooltip:Show()
        end
    end)
    control:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
end
function U.Check(parent,text,x,y,width,action)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",x,y);b:SetSize(24,24)
    b.label=ui.Label(b,text,26,-5,width or 120,"GameFontHighlightSmall")
    b:SetScript("OnClick",function(self) action(self:GetChecked()==true) end)
    return b
end
function U.SmallSlider(parent,text,x,y,labelWidth,low,high,step,format,action)
    local caption=U.Label(parent,text,x,y-1,labelWidth,"GameFontHighlightSmall")
    caption:SetWordWrap(false)
    local slider=CreateFrame("Slider",nil,parent,"OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT",x+labelWidth+4,y);slider:SetSize(60,16)
    for _,key in ipairs({"Low","High","Text"}) do
        local region=slider[key]
        if type(region)=="table" or type(region)=="userdata" then region:Hide() end
    end
    slider.track=slider:CreateTexture(nil,"BACKGROUND")
    slider.track:SetPoint("TOPLEFT",2,-4);slider.track:SetPoint("BOTTOMRIGHT",-2,4)
    slider.track:SetColorTexture(0.045,0.032,0.018,1)
    slider:SetMinMaxValues(low,high);slider:SetValueStep(step);slider:SetObeyStepOnDrag(true)
    slider.valueLabel=U.Label(parent,"",x+labelWidth+69,y-1,32,"GameFontHighlightSmall")
    function slider:Display(value)
        self.syncing=true;self:SetValue(value);self.syncing=false
        self.valueLabel:SetText(format(value))
    end
    slider:SetScript("OnValueChanged",function(self,value)
        if self.syncing or not ns.Atlas.Number(value,low,high) then return end
        value=low+math.floor((value-low)/step+0.5)*step
        self.valueLabel:SetText(format(value));action(value)
    end)
    return slider
end
function U.Scroll(parent,x,y,width,height)
    local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    s:SetPoint("TOPLEFT",x,y);s:SetSize(width,height)
    local body=CreateFrame("Frame",nil,s);body:SetSize(width,height);s:SetScrollChild(body)
    if s.ScrollBar then ns.StyleScrollBarTrack(s.ScrollBar,0.4) end
    ns.AutoHideScrollBar(s,function() return body:GetHeight() end)
    return s,body
end
function U.TextArea(parent,x,y,width,height,limit)
    local s=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    s:SetPoint("TOPLEFT",x,y);s:SetSize(width,height)
    local border=CreateFrame("Frame",nil,s,"BackdropTemplate")
    border:SetPoint("TOPLEFT",-4,4);border:SetPoint("BOTTOMRIGHT",22,-4)
    border:SetFrameLevel(s:GetFrameLevel())
    border:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    border:SetBackdropColor(0.05,0.04,0.025,0.6);border:SetBackdropBorderColor(0.45,0.30,0.13,1)
    border:EnableMouse(false)
    local e=CreateFrame("EditBox",nil,s)
    e:SetMultiLine(true);e:SetAutoFocus(false);e:SetFontObject("GameFontHighlight")
    e:SetWidth(width);e:SetHeight(height);e:SetMaxLetters(limit or 8000)
    e:SetTextInsets(5,5,5,5);e:SetScript("OnEscapePressed",e.ClearFocus)
    s:SetScrollChild(e);ns.AutoHideScrollBar(s)
    if s.ScrollBar then ns.StyleScrollBarTrack(s.ScrollBar,0.4) end
    -- Native cursor scrolling keeps long journal edits inside the viewport.
    e:SetScript("OnCursorChanged",function(_,_,cy,_,ch)
        local yOffset=-cy;local top=s:GetVerticalScroll()
        if yOffset<top then s:SetVerticalScroll(math.max(0,yOffset))
        elseif yOffset+ch>top+s:GetHeight() then s:SetVerticalScroll(math.max(0,yOffset+ch-s:GetHeight())) end
    end)
    e:SetScript("OnTextChanged",function() s:UpdateScrollChildRect();s:RefreshScrollBar() end)
    s:SetScript("OnMouseDown",function() e:SetFocus() end)
    return e,s
end
function U.ReadArea(parent,x,y,width,height)
    local s,body=U.Scroll(parent,x,y,width,height)
    local t=ui.Label(body,"",0,0,width,"GameFontHighlightSmall");t:SetWordWrap(true);t:SetSpacing(3)
    function s:SetText(text,reset)
        t:SetText(ns.Atlas.Safe(text));body:SetHeight(math.max(height,t:GetStringHeight()+12))
        if reset then self:SetVerticalScroll(0) end
        self:UpdateScrollChildRect();self:RefreshScrollBar()
    end
    s.text=t;return s
end
function U.Panel(parent,shell,title,back)
    local p=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    p:SetPoint("TOPLEFT",38,-53);p:SetSize(884,652);p:EnableMouse(true)
    p:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
    local paper=p:CreateTexture(nil,"BACKGROUND");paper:SetPoint("TOPLEFT",5,-5);paper:SetPoint("BOTTOMRIGHT",-5,5)
    paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga");paper:SetDesaturated(true)
    shell:AddBackgroundLayer(paper,0.17,0.17,0.17,true)
    p.title=U.Label(p,title,20,-18,720,"GameFontNormalLarge");p.title:SetWordWrap(false)
    p.back=ui.Button(p,"Back",770,-12,90,back)
    p.message=ui.Label(p,"",20,-615,835,"GameFontHighlightSmall");p.message:SetWordWrap(true)
    p:SetScript("OnHide",function(self)
        for _,control in ipairs(self.inputs or {}) do control:ClearFocus() end
        if self.search then self.search:ClearFocus() end
        if GameTooltip then GameTooltip:Hide() end
    end)
    return p
end
function U.Field(parent,title,x,y,width,limit)
    local label=U.Label(parent,title,x,y,width,"GameFontNormalSmall")
    local edit=ui.Edit(parent,x+5,y-21,width-10,limit or 160)
    edit.fieldLabel=label;return edit
end
function U.Date(stamp)
    return type(date)=="function" and date("%d %b %Y, %H:%M",stamp or 0) or tostring(stamp or 0)
end
function U.Toggle(values,id)
    for i,v in ipairs(values) do if v==id then table.remove(values,i);return false end end
    values[#values+1]=id;return true
end
function U.Contains(values,id) for _,v in ipairs(values) do if v==id then return true end end;return false end
