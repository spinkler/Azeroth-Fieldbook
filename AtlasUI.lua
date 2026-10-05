local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local U={};ns.AtlasUI=U
local ui=ns.FieldbookUI
U.Button=ui.Button;U.Edit=ui.Edit;U.Search=ui.Search
U.ShareButton=ui.ShareButton
U.MenuButton=ui.MenuButton
U.DetailGold={0.46,0.36,0.13}
function U.DetailDivider(parent,y,width)
    return ui.EntryDivider(parent,y,width)
end
function U.DetailPaint(text,colour)
    return "|cff"..colour..ns.Atlas.Safe(text).."|r"
end
function U.ZoneMenu(parent,x,y,width,getMaps,onSelect,onCurrentZone)
    local button
    button=U.MenuButton(parent,"Choose zone",x,y,width,function()
        if not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
        MenuUtil.CreateContextMenu(button,function(_,root)
            root:SetScrollMode(420)
            if onCurrentZone then root:CreateButton("Current Zone",onCurrentZone);root:CreateDivider() end
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
function U.SavedIcon(saved)
    local texture=saved and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Up"
    return "|T"..texture..":14:14:0:0|t "
end
function U.TypeCheck(texture,kind)
    local inferred=kind=="inferred"
    texture:SetDesaturated(inferred)
    texture:SetVertexColor(inferred and 0.6 or 1,inferred and 0.6 or 1,inferred and 0.6 or 1)
    texture:SetShown(kind=="inferred" or kind=="player")
end
function U.SavedButton(parent,text,x,y,width,action)
    local button=U.Button(parent,text,x,y,width,action)
    local box=button:CreateTexture(nil,"ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up");box:SetSize(14,14);box:SetPoint("LEFT",14,0)
    local check=button:CreateTexture(nil,"OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");check:SetAllPoints(box);check:Hide()
    local label=button:GetFontString()
    label:ClearAllPoints();label:SetPoint("LEFT",32,0);label:SetPoint("RIGHT",-8,0);label:SetJustifyH("LEFT")
    button.savedBox=box;button.savedCheck=check
    function button:SetSaved(saved,enabled)
        check:SetShown(saved==true)
        box:SetAlpha(enabled==false and 0.45 or 1);check:SetAlpha(enabled==false and 0.45 or 1)
    end
    return button
end
function U.StyleSelection(control)
        -- Crop the native bevel only; the red face is never tinted or brightened.
        local borders={}
        local function border(source,l,r,t,b,x1,y1,x2,y2)
            for layer=0,1 do
                local piece=control:CreateTexture(nil,"BORDER",nil,layer)
                piece:SetPoint("TOPLEFT",source,"TOPLEFT",x1,y1)
                piece:SetPoint("BOTTOMRIGHT",source,"BOTTOMRIGHT",x2,y2)
                piece:SetTexCoord(l,r,t,b)
                piece:SetVertexColor(1,1,0)
                piece:SetBlendMode(layer==0 and "BLEND" or "ADD")
                borders[#borders+1]={texture=piece,source=source}
            end
        end
        local function refreshBorder()
            for _,part in ipairs(borders) do
                part.texture:SetTexture(part.source:GetTexture())
                part.texture:SetShown(control.afbSelected and control:IsEnabled())
            end
        end
        -- UIPanelButtonTemplate uses a 128x32 texture with an 80x22 button,
        -- split into 12px end caps and a stretching middle. Its outer 4px
        -- contain the bevel; copying those pixels preserves the native shape.
        local function createBorder()
            local height=control:GetHeight()
            local edge=height*4/22
            for _,slice in ipairs({{"Left",0,12},{"Middle",12,68},{"Right",68,80}}) do
                local source=control[slice[1]]
                if source and type(source)~="function" then
                    border(source,slice[2]/128,slice[3]/128,0,4/32,0,0,0,height-edge)
                    border(source,slice[2]/128,slice[3]/128,18/32,22/32,0,-height+edge,0,0)
                    if slice[1]=="Left" then
                        border(source,0,4/128,4/32,18/32,0,-edge,-8,edge)
                    elseif slice[1]=="Right" then
                        border(source,76/128,80/128,4/32,18/32,8,-edge,0,edge)
                    end
                end
            end
        end
        control.SetSelected=function(self,selected)
            self.afbSelected=selected
            if selected and #borders==0 then createBorder() end
            refreshBorder()
        end
        for _,event in ipairs({"OnMouseDown","OnMouseUp","OnEnable","OnDisable","OnShow"}) do
            control:HookScript(event,refreshBorder)
        end
        control:SetSelected(false)
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
    return slider,caption
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
    e:SetMultiLine(true);e:SetAutoFocus(false);e:SetFontObject(textFont("GameFontHighlight"))
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
-- Match the collapsed journal detail panel without moving its contents.
function U.FooterBackground(parent,shell)
    local paper=parent:CreateTexture(nil,"BACKGROUND")
    paper:SetPoint("TOPLEFT",332,-584);paper:SetSize(600,123)
    paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga");paper:SetDesaturated(true)
    shell:AddBackgroundLayer(paper,0.17,0.17,0.17,true)
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local border=parent:CreateTexture(nil,"BORDER")
        border:SetColorTexture(unpack(U.DetailGold))
        border:SetPoint(edge[1],paper,edge[1]);border:SetPoint(edge[2],paper,edge[2])
        if edge[3] then border:SetHeight(1) else border:SetWidth(1) end
    end
    return paper
end
-- Match the Options edge fade against the footer's dark parchment.
function U.AlignFooterScrollBar(scroll,paper,expand)
    local bar=scroll.ScrollBar
    if not bar or type(bar)=="function" then return end
    local up,down=bar.ScrollUpButton,bar.ScrollDownButton
    local upHeight=up and type(up)~="function" and up:GetHeight() or 16
    local downHeight=down and type(down)~="function" and down:GetHeight() or 16
    bar:ClearAllPoints()
    if expand then bar:SetPoint("TOP",expand,"BOTTOM",0,-4-upHeight)
    else bar:SetPoint("TOP",paper,"TOPRIGHT",-15,-6-upHeight) end
    bar:SetPoint("BOTTOM",paper,"BOTTOMRIGHT",-15,4+downHeight)
    if up and type(up)~="function" then up:ClearAllPoints();up:SetPoint("BOTTOM",bar,"TOP",0,0) end
    if down and type(down)~="function" then down:ClearAllPoints();down:SetPoint("TOP",bar,"BOTTOM",0,0) end
end

function U.FooterFades(scroll,shell,topInset)
    local steps,fadeHeight=24,12
    local function makeEdge(top)
        local edge=CreateFrame("Frame",nil,scroll)
        edge:SetFrameLevel(scroll:GetFrameLevel()+10);edge:EnableMouse(false)
        edge:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",scroll,top and "TOPLEFT" or "BOTTOMLEFT",0,top and 1 or -2)
        edge.strips={}
        for i=1,steps do
            local strip=edge:CreateTexture(nil,"ARTWORK")
            strip:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",0,(top and -1 or 1)*(i-1)*fadeHeight/steps)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga");strip:SetDesaturated(true)
            strip:SetAlpha(1-(i-1)/(steps-1));shell:AddBackgroundLayer(strip,0.17,0.17,0.17,true)
            edge.strips[i]=strip
        end
        return edge
    end
    scroll.topFade,scroll.bottomFade=makeEdge(true),makeEdge(false)
    local function update()
        local width,height=scroll:GetWidth(),scroll:GetHeight()
        local paperHeight=topInset+height+6
        local range=math.max(0,scroll:GetVerticalScrollRange() or 0)
        local offset=scroll:GetVerticalScroll() or 0
        for _,edge in ipairs({scroll.topFade,scroll.bottomFade}) do
            edge:SetSize(width,fadeHeight)
            for i,strip in ipairs(edge.strips) do
                local y=edge==scroll.topFade and topInset-1+(i-1)*fadeHeight/steps or topInset+height+2-i*fadeHeight/steps
                strip:SetSize(width,fadeHeight/steps)
                strip:SetTexCoord(10/600,(10+width)/600,y/paperHeight,(y+fadeHeight/steps)/paperHeight)
            end
        end
        scroll.topFade:SetShown(range>0 and offset>0)
        scroll.bottomFade:SetShown(range>0 and offset<range)
    end
    for _,event in ipairs({"OnVerticalScroll","OnScrollRangeChanged","OnShow","OnSizeChanged"}) do scroll:HookScript(event,update) end
    update()
end
function U.ContactListFades(scroll,shell,parent,x,y)
    local steps,fadeHeight=24,12
    local function edge(top)
        local frame=CreateFrame("Frame",nil,parent)
        frame:SetFrameLevel(scroll:GetFrameLevel()+10);frame:EnableMouse(false)
        frame:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",scroll,top and "TOPLEFT" or "BOTTOMLEFT",0,top and 2 or -2)
        frame.strips={}
        for i=1,steps do
            local strip=frame:CreateTexture(nil,"ARTWORK")
            strip:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",0,(top and -1 or 1)*(i-1)*fadeHeight/steps)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
            strip:SetAlpha(1-(i-1)/(steps-1))
            shell:AddBackgroundLayer(strip,0.504,0.504,0.48888)
            frame.strips[i]=strip
        end
        return frame
    end
    scroll.topFade,scroll.bottomFade=edge(true),edge(false)
    local bar=scroll.ScrollBar
    if bar then bar:SetFrameLevel(scroll.topFade:GetFrameLevel()+1) end
    local function update()
        local width,height=scroll:GetWidth(),scroll:GetHeight()
        local paperWidth,paperHeight=parent:GetWidth()-8,parent:GetHeight()-15
        local originY=type(y)=="function" and y() or y
        for _,frame in ipairs({scroll.topFade,scroll.bottomFade}) do
            frame:SetSize(width,fadeHeight)
            for i,strip in ipairs(frame.strips) do
                local py=frame==scroll.topFade and -originY-2+(i-1)*fadeHeight/steps or -originY+height+2-i*fadeHeight/steps
                strip:SetSize(width,fadeHeight/steps)
                strip:SetTexCoord((x-6)/paperWidth,(x+width-6)/paperWidth,(py-9)/paperHeight,(py+fadeHeight/steps-9)/paperHeight)
            end
        end
        local range=math.max(0,scroll:GetVerticalScrollRange() or 0)
        local offset=scroll:GetVerticalScroll() or 0
        scroll.topFade:SetShown(scroll:IsShown() and range>0 and offset>0)
        scroll.bottomFade:SetShown(scroll:IsShown() and range>0 and offset<range)
    end
    for _,event in ipairs({"OnVerticalScroll","OnScrollRangeChanged","OnShow","OnSizeChanged","OnHide"}) do scroll:HookScript(event,update) end
    update()
end
function U.ReadArea(parent,x,y,width,height)
    local s,body=U.Scroll(parent,x,y,width,height)
    local t=ui.Label(body,"",0,0,width,"GameFontHighlightSmall");t:SetWordWrap(true);t:SetSpacing(3)
    function s:SetText(text,reset)
        t:SetText(ns.Atlas.Safe(text));body:SetHeight(math.max(height,t:GetStringHeight()+12))
        if reset then self:SetVerticalScroll(0) end
        self:UpdateScrollChildRect();self:RefreshScrollBar()
    end
    s.text=t;return s,body
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
