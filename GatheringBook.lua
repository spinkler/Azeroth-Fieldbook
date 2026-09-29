local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end

-- Keep gathering camera settings independent of the Bestiary. A camera distance
-- of 1.25 / 0.40 gives approximately 40% of the original apparent model size.
local function applyModelZoom(model)
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(3.125)
end

-- Selection borders and clipped hover names mirror the Bestiary. Kept local to
-- this section so its implementation cannot change any other page's controls.
local function addNameScroller(row,heading)
    local viewport=CreateFrame("ScrollFrame",nil,row)
    viewport:SetPoint("TOPLEFT",17,0);viewport:SetSize(140,28);viewport:EnableMouse(false)
    local body=CreateFrame("Frame",nil,viewport)
    body:SetSize(140,28);body:EnableMouse(false);viewport:SetScrollChild(body)
    local text=body:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlight"))
    text:SetPoint("TOPLEFT",0,-8);text:SetJustifyH("LEFT");text:SetWordWrap(false)
    text:SetShadowColor(0.05,0.05,0.05)
    if heading then
        viewport:ClearAllPoints();viewport:SetAllPoints(row)
        text:ClearAllPoints();text:SetPoint("TOPLEFT",0,0)
        text:SetFontObject(textFont("GameFontNormalLarge"))
        local path,size,flags=row.text:GetFont()
        if path then text:SetFont(path,size,flags) end
    end
    row.nameViewport,row.scrollingName=viewport,text
    function row:StopNameScroll()
        self:SetScript("OnUpdate",nil)
        viewport:SetHorizontalScroll(0);viewport:Hide();self.text:Show()
    end
    row:SetScript("OnEnter",function(self)
        local width=self.text:GetUnboundedStringWidth()
        if type(width)~="number" then width=self.text:GetStringWidth() end
        local visible=self.text:GetWidth()
        if not self.id or type(width)~="number" or width<=visible then return end
        width=math.ceil(width)+1
        viewport:SetWidth(visible);body:SetWidth(width);text:SetWidth(width)
        if heading then body:SetHeight(self:GetHeight()) end
        text:SetText(self.text:GetText());text:SetTextColor(self.text:GetTextColor())
        text:SetAlphaGradient(visible-20,20)
        self.text:Hide();viewport:Show();viewport:SetHorizontalScroll(0)
        local elapsed,distance=0,width-visible
        local travel=distance/24 -- Gentle movement in UI pixels per second.
        self:SetScript("OnUpdate",function(_,dt)
            if heading and self.text:GetWidth()~=visible then self:StopNameScroll();return end
            elapsed=(elapsed+dt)%(travel*2+2)
            local position
            if elapsed<0.8 then position=0
            elseif elapsed<0.8+travel then position=(elapsed-0.8)*24
            elseif elapsed<2+travel then position=distance
            else position=distance-(elapsed-2-travel)*24 end
            viewport:SetHorizontalScroll(position)
            -- Fade into the stationary right edge while travelling, then show
            -- the complete ending during the pause. The viewport clips the left.
            if position<distance then text:SetAlphaGradient(position+visible-20,20)
            else text:ClearAlphaGradient() end
        end)
    end)
    row:SetScript("OnLeave",function(self) self:StopNameScroll() end)
    row:SetScript("OnHide",function(self) self:StopNameScroll() end)
    row:StopNameScroll()
end

    local filterFonts={}
    local function filterFont(base)
        if not filterFonts[base] then
            local name="AzerothFieldbookGatheringFilter"..base
            local font=CreateFont(name)
            font:CopyFontObject(_G[base])
            local path,size,flags=font:GetFont()
            if path and size then font:SetFont(path,math.max(1,size-1),flags) end
            filterFonts[base]=name
        end
        return filterFonts[base]
    end
    local function styleSelection(control,keepGoldText,borderOnly)
        if not borderOnly then
            control:SetHighlightTexture("")
            control:SetDisabledFontObject(textFont(filterFont("GameFontDisable")))
        end
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
            if not borderOnly then
                local font=filterFont((selected or keepGoldText) and "GameFontNormal" or "GameFontDisable")
                self:SetNormalFontObject(textFont(font))
                self:SetHighlightFontObject(textFont(font))
            end
            self.afbSelected=selected
            if selected and #borders==0 then createBorder() end
            refreshBorder()
        end
        for _,event in ipairs({"OnMouseDown","OnMouseUp","OnEnable","OnDisable","OnShow"}) do
            control:HookScript(event,refreshBorder)
        end
        control:SetSelected(false)
    end


function ns.CreateGatheringBook(journal,shell)
    local controller={journal=journal}
    local ui=ns.FieldbookUI
    local label,button,edit=ui.Label,ui.Button,ui.Edit
    local book,selected,category,initial
    local offset,indexOpen=0,false
    local PAGE_SIZE=16
    local locationFilters,drafts={},{}
    local locations=ns.CreateGatheringLocationsWindow(journal,function() return shell:GetFrame() end)
    controller.locations=locations
    local refresh,refreshLocationFilter
    local function choose(id)
        selected=id
        locations:SetResource(id)
        if book then book.message:SetText("");refresh() end
    end
    local function currentRows(letter)
        return journal:List(category,book.search:GetText(),letter,locationFilters)
    end
    local function cycle(direction)
        local rows=currentRows(initial)
        if #rows==0 then return end
        local index=direction>0 and 0 or 1
        for i,e in ipairs(rows) do if e.id==selected then index=i;break end end
        index=(index-1+direction)%#rows+1
        if index<=offset then offset=index-1 elseif index>offset+PAGE_SIZE then offset=index-PAGE_SIZE end
        choose(rows[index].id)
    end
    local function dateText(stamp)
        return stamp and stamp>0 and type(date)=="function" and date("%d %b %Y, %H:%M",stamp) or "Unknown"
    end
    refresh=function(reloadModel)
        if not book then return end
        book.revision=journal.revision
        local unlettered=currentRows()
        local letters={}
        for _,entry in ipairs(unlettered) do letters[string.upper(entry.name:sub(1,1))]=true end
        for _,control in ipairs(book.letterButtons) do
            control:SetShown(indexOpen);control:SetEnabled(letters[control.letter]==true)
            control:SetSelected(control.letter==initial)
        end
        book.indexButton:SetSelected(indexOpen)
        for kind,control in pairs(book.typeButtons) do control:SetSelected(kind==(category or "all")) end
        book.locationsButton:SetSelected(next(locationFilters)~=nil or book.locationFrame:IsShown())
        local rows=initial and currentRows(initial) or unlettered
        if not selected or not journal.entries[selected] then selected=rows[1] and rows[1].id end
        offset=math.max(0,math.min(offset,math.max(0,#rows-PAGE_SIZE)))
        book.updatingScroll=true
        book.resourceScrollBar:SetMinMaxValues(0,math.max(0,#rows-PAGE_SIZE))
        book.resourceScrollBar:SetValue(offset);book.resourceScrollBar:SetShown(#rows>PAGE_SIZE)
        book.updatingScroll=false
        for i,row in ipairs(book.rows) do
            local data=rows[offset+i]
            if row.id~=(data and data.id) then row:StopNameScroll() end
            row.id=data and data.id;row:SetShown(data~=nil);row:EnableMouseWheel(#rows>PAGE_SIZE)
            if data then
                row.text:SetText(data.name)
                local active=data.id==selected
                row.text:SetTextColor(active and 1 or 0.75,active and 0.82 or 0.8,active and 0.14 or 0.8)
                row:SetSelected(active)
            end
        end
        book.entryCount:SetText(#journal:List().." entries")
        book.indexCount:SetText(#rows==0 and "No matching entries." or (#rows.." shown"))
        book.previous:SetEnabled(#rows>0);book.next:SetEnabled(#rows>0)
        book.noMatches:SetShown(#rows==0)
        book.noMatches:SetText(journal.readOnly and "Saved by a newer addon version.\nUpdate Azeroth Fieldbook to view this journal.\nYour data has been left untouched."
            or next(journal.entries) and "No matching entries.\nTry clearing your filters."
            or "No herbs or minerals recorded yet.")
        local entry=selected and journal.entries[selected]
        book.title:SetText(entry and (entry.name.." • "..ns.GatheringKinds[entry.kind].title) or "Gatherer's Compendium")
        book.locations:SetEnabled(entry~=nil);book.details:SetShown(entry~=nil);book.empty:SetShown(entry==nil)
        if not entry then
            book.modelFileID=nil;book.model:ClearModel();book.model:Hide()
            return
        end
        local modelFileID=entry.modelFileID or ns.GatheringModel(entry.kind,entry.name)
        -- Load only after the section and its book are visible. Native model
        -- render state can be discarded while a section is hidden, even when
        -- the selected entry/file ID has not changed.
        if book:IsShown() and shell:GetFrame():IsShown()
            and (reloadModel or book.modelEntry~=selected or book.modelFileID~=modelFileID) then
            book.modelEntry=selected;book.modelFileID=modelFileID
            book.model:ClearModel();book.model:Hide();book.modelRotation=0
            book.modelCaption:SetText("Model unavailable")
            if modelFileID then
                book.modelCaption:SetText("Loading model…")
                local ok=pcall(book.model.SetModel,book.model,modelFileID)
                if ok then
                    book.model:Show()
                    applyModelZoom(book.model)
                else book.modelCaption:SetText("Model unavailable") end
                book.model:SetRotation(0)
            end
        end
        book.stats:SetText("Interactions: "..entry.interactions.."\nCompleted gathers: "..entry.completed)
        book.history:SetText("First encountered: "..dateText(entry.firstSeen).."\nLast interaction: "..
            (entry.interactions>0 and dateText(entry.lastSeen) or "Not yet interacted"))
        local loot={}
        for itemID,item in pairs(entry.loot or {}) do
            local name,quality,icon
            local info=C_Item and C_Item.GetItemInfo or GetItemInfo
            if type(info)=="function" then
                local ok,n,_,q,_,_,_,_,_,_,texture=pcall(info,itemID)
                if ok then
                    name=ns.GatheringName(n)
                    if not (issecretvalue and issecretvalue(q)) and type(q)=="number" then quality=q end
                    if not (issecretvalue and issecretvalue(texture)) and (type(texture)=="number" or type(texture)=="string") then icon=texture end
                end
            end
            loot[#loot+1]={id=itemID,name=name or item.name or ("Item "..itemID),quality=quality,icon=icon,data=item}
            if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,itemID) end
        end
        table.sort(loot,function(a,b) if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
        for i,item in ipairs(loot) do
            local row=book.lootRows[i]
            if not row then
                row=CreateFrame("Button",nil,book.lootChild);row:SetSize(230,62);row:SetPoint("TOPLEFT",0,-(i-1)*62)
                row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",0,-3);row.icon:SetSize(28,28)
                row.name=label(row,"",34,-2,190,"GameFontNormal");row.name:SetHeight(32);row.name:SetWordWrap(true)
                row.quantity=label(row,"",34,-38,190,"GameFontHighlightSmall")
                row:SetScript("OnEnter",function(self)
                    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..self.itemID);GameTooltip:Show() end
                end)
                row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                row:SetScript("OnHide",function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
                book.lootRows[i]=row
            end
            row.itemID=item.id;row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(item.name)
            local colour=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            row.name:SetTextColor(colour and colour.r or 1,colour and colour.g or 1,colour and colour.b or 1)
            local data=item.data
            row.quantity:SetText("Observed stack: "..data.minQuantity..(data.maxQuantity~=data.minQuantity and ("–"..data.maxQuantity) or ""))
            row:Show()
        end
        for i=#loot+1,#book.lootRows do book.lootRows[i]:Hide() end
        book.noLoot:SetShown(#loot==0)
        book.lootChild:SetHeight(math.max(169,#loot*62))
        if book.lootID~=selected then book.lootID=selected;book.lootScroll:SetVerticalScroll(0) end
        book.lootScroll:UpdateScrollChildRect();book.lootScroll:RefreshScrollBar()
        local zones=journal:GetLocationZones(selected)
        for i,zone in ipairs(zones) do
            local row=book.zoneRows[i]
            if not row then
                row=button(book.zoneChild,"",0,-(i-1)*28,304,function(self)
                    locations:Open(selected,self.zone.mapID)
                end)
                row:SetNormalFontObject(textFont("GameFontHighlightSmall"))
                row:SetHighlightFontObject(textFont("GameFontHighlightSmall"))
                book.zoneRows[i]=row
            end
            local count=0;for _ in pairs(zone.data and zone.data.points or {}) do count=count+1 end
            row.zone=zone;row:SetText(zone.name.."  •  "..count.." mapped positions");row:Show()
        end
        for i=#zones+1,#book.zoneRows do book.zoneRows[i]:Hide() end
        book.noZones:SetShown(#zones==0)
        book.zoneChild:SetHeight(math.max(140,#zones*28))
        if book.noteID~=selected then
            book.note:ClearFocus()
            book.noteID=selected;book.loadingNote=true
            book.note:SetText(drafts[selected] or entry.note or "")
            book.noteScroll:SetVerticalScroll(0);book.loadingNote=false
            book.zoneScroll:SetVerticalScroll(0)
        end
        book.zoneScroll:UpdateScrollChildRect();book.zoneScroll:RefreshScrollBar()
        book.saveNote:SetEnabled((drafts[selected] or entry.note or "")~=(entry.note or ""))
        locations:SetResource(selected);locations:Refresh()
    end
    local function build(content)
        book=content;controller.frame=book
        local spine=book:CreateTexture(nil,"ARTWORK")
        spine:SetColorTexture(0.25,0.13,0.055,0.35)
        spine:SetPoint("TOPLEFT",324,-53);spine:SetSize(3,661)
        book.entryCount=label(book,"",135,-55,180,"GameFontHighlightSmall")
        book.typeButtons={}
        for i,spec in ipairs({{"all","All"},{"herb","Herbs"},{"mineral","Minerals"}}) do
            local kind=spec[1]
            local control=button(book,spec[2],42,-110-(i-1)*28,88,function()
                if kind=="all" or category==kind then category=nil else category=kind end
                offset=0;refresh()
            end)
            styleSelection(control);book.typeButtons[kind]=control
        end
        book.locationsButton=button(book,"Locations",42,-479,88,function()
            refreshLocationFilter();book.locationFrame:SetShown(not book.locationFrame:IsShown());refresh()
        end)
        styleSelection(book.locationsButton,true)
        book.clearFilters=button(book,"Clear filters",42,-511,88,function()
            category,initial=nil,nil;offset=0
            for zone in pairs(locationFilters) do locationFilters[zone]=nil end
            book.search:SetText("");refreshLocationFilter();refresh()
        end)
        book.search=edit(book,145,-78,146,100);book.search:SetTextInsets(0,22,0,0)
        book.searchClear=CreateFrame("Button",nil,book.search)
        book.searchClear:SetSize(18,18);book.searchClear:SetPoint("RIGHT",book.search,"RIGHT",-2,0)
        local glyph=book.searchClear:CreateFontString(nil,"OVERLAY",textFont("GameFontNormalLarge"))
        glyph:SetPoint("CENTER");glyph:SetText("×");glyph:SetTextColor(0.95,0.15,0.12)
        book.searchClear:SetScript("OnEnter",function() glyph:SetTextColor(1,0.4,0.3) end)
        book.searchClear:SetScript("OnLeave",function() glyph:SetTextColor(0.95,0.15,0.12) end)
        book.searchClear:SetScript("OnClick",function() book.search:SetText("");book.search:SetFocus() end)
        book.searchPlaceholder=label(book.search,"Search",0,-5,124,"GameFontHighlightSmall")
        book.searchPlaceholder:SetTextColor(0.55,0.55,0.55)
        book.search:SetScript("OnTextChanged",function(self)
            book.searchPlaceholder:SetShown(self:GetText()=="");offset=0;refresh()
        end)
        local dismiss=CreateFrame("Button","AzerothFieldbookGatheringSortMenu",UIParent)
        dismiss:SetAllPoints(UIParent);dismiss:SetFrameStrata("FULLSCREEN_DIALOG");dismiss:SetToplevel(true)
        dismiss:SetScript("OnShow",function(self) self:SetScale(shell:GetFrame():GetScale());self:Raise() end)
        dismiss:EnableMouse(true);dismiss:SetScript("OnClick",function(self) self:Hide() end)
        local menu=CreateFrame("Frame",nil,dismiss,"BackdropTemplate")
        menu:SetSize(184,290);menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetClampedToScreen(true);menu:EnableMouse(true)
        menu:SetFrameLevel(dismiss:GetFrameLevel()+1)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        menu:SetBackdropColor(0.08,0.055,0.025,1);menu:SetBackdropBorderColor(0.45,0.30,0.13,1)
        label(menu,"Sorting by",12,-12,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        book.sortChoices={}
        local function refreshSort()
            local field,descending=journal:GetListSort()
            for _,choice in ipairs(book.sortChoices) do
                choice.control:SetSelected(choice.field and choice.field==field or (not choice.field and choice.descending==descending))
            end
        end
        for i,spec in ipairs({{"name","Name"},{"kind","Type"},{"interactions","Interactions"},
            {"completed","Completed Gathers"},{"firstSeen","First Encountered"},{"lastSeen","Last Interaction"}}) do
            local field=spec[1]
            local control=button(menu,spec[2],12,-32-(i-1)*27,160,function()
                local _,descending=journal:GetListSort();journal:SetListSort(field,descending)
                offset=0;refresh();refreshSort()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG");styleSelection(control)
            book.sortChoices[#book.sortChoices+1]={control=control,field=field}
        end
        label(menu,"Order",12,-199,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        for i,title in ipairs({"Ascending","Descending"}) do
            local descending=i==2
            local control=button(menu,title,12,-219-(i-1)*27,160,function()
                journal:SetListSort(journal:GetListSort(),descending);offset=0;refresh();refreshSort()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG");styleSelection(control)
            book.sortChoices[#book.sortChoices+1]={control=control,descending=descending}
        end
        book.sortButton=button(book,"",297,-78,22,function()
            book.search:ClearFocus();refreshSort();dismiss:SetShown(not dismiss:IsShown())
        end)
        book.sortButton:SetSize(22,22)
        for i=0,4 do
            local stroke=book.sortButton:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-i*2,1);stroke:SetPoint("CENTER",0,2-i);stroke:SetColorTexture(1,0.82,0.14,1)
        end
        book.sortButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Sort");GameTooltip:Show() end
        end)
        book.sortButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        menu:SetPoint("TOPRIGHT",book.sortButton,"BOTTOMRIGHT",0,-4);dismiss:Hide();book.sortMenu=dismiss
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookGatheringSortMenu" end
        book.rows={}
        book.resourceScrollBar=CreateFrame("Slider",nil,book,"UIPanelScrollBarTemplate")
        book.resourceScrollBar:SetPoint("TOPLEFT",301,-126);book.resourceScrollBar:SetSize(14,446)
        ns.StyleScrollBarTrack(book.resourceScrollBar,0.3)
        book.resourceScrollBar:SetMinMaxValues(0,0);book.resourceScrollBar:SetValueStep(1)
        book.resourceScrollBar:SetObeyStepOnDrag(true)
        book.resourceScrollBar:SetScript("OnValueChanged",function(_,value)
            if book.updatingScroll then return end
            offset=math.floor(value+0.5);refresh()
        end)
        local function wheel(_,delta) offset=offset-delta*3;refresh() end
        book.resourceScrollBar:EnableMouseWheel(true);book.resourceScrollBar:SetScript("OnMouseWheel",wheel)
        for i=1,PAGE_SIZE do
            local row=CreateFrame("Button",nil,book,"BackdropTemplate")
            row:SetPoint("TOPLEFT",135,-110-(i-1)*30);row:SetSize(162,28)
            ns.FieldbookUI.StyleMenuRow(row)
            row.text=label(row,"",17,-8,140);row.text:SetWordWrap(false);addNameScroller(row)
            row:SetScript("OnClick",function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",wheel);book.rows[i]=row
        end
        book.noMatches=label(book,"",145,-122,146,"GameFontHighlightSmall");book.noMatches:SetSpacing(4)
        book.previous=button(book,"Previous",135,-596,84,function() cycle(-1) end)
        book.next=button(book,"Next",229,-596,86,function() cycle(1) end)
        book.indexCount=label(book,"",135,-660,180,"GameFontHighlightSmall");book.indexCount:SetTextColor(0.55,0.58,0.58)
        label(book,"Click Index to show or hide A-Z filters.",38,-704,256,"GameFontHighlightSmall")
        book.indexButton=button(book,"Index",3,-78,57,function() indexOpen=not indexOpen;initial=nil;offset=0;refresh() end)
        styleSelection(book.indexButton);book.indexButton:SetFrameLevel(shell:GetFrame().titleIcon:GetFrameLevel()-1)
        book.letterButtons={}
        for i=1,26 do
            local letter=string.char(64+i)
            local tab=button(book,letter,3,-107-(i-1)*23,29,function()
                if initial==letter then initial=nil else initial=letter end;offset=0;refresh()
            end)
            tab:SetHeight(21)
            local text=tab:GetFontString()
            if text then text:ClearAllPoints();text:SetPoint("CENTER",tab,"CENTER",0.5,0) end
            tab:SetFrameLevel(shell:GetFrame().titleIcon:GetFrameLevel()-1);tab.letter=letter
            styleSelection(tab);tab:Hide();book.letterButtons[i]=tab
        end
        book.title=label(book,"Gatherer's Compendium",362,-55,474,"GameFontNormalLarge")
        book.title:SetTextColor(1,0.82,0.14);book.title:SetWordWrap(false)
        local path,size,flags=book.title:GetFont()
        if path and size then book.title:SetFont(path,size+2,flags) end
        book.locations=button(book,"Locations",854,-52,82,function() locations:Toggle(selected) end)
        styleSelection(book.locations,true)
        locations:SetVisibilityCallback(function(shown) book.locations:SetSelected(shown) end)
        book.empty=label(book,"Mouse over a herb or mineral to discover it and its zone, even without the profession.\n\nInteract with it to record coordinates. Each entry keeps your interactions, completed gathers and field notes.",362,-115,538)
        book.empty:SetSpacing(6)
        book.details=CreateFrame("Frame",nil,book);book.details:SetAllPoints(book)
        local detail=book.details
        label(detail,"Basic info",362,-86,562,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",364,-109);book.modelBorder:SetSize(207,168)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model=CreateFrame("PlayerModel",nil,detail)
        book.model:SetFrameLevel(book.modelBorder:GetFrameLevel()+1)
        book.model:SetPoint("TOPLEFT",366,-111);book.model:SetSize(203,164)
        applyModelZoom(book.model);book.model:EnableMouse(true)
        book.modelCaption=label(book.modelBorder,"",8,-76,191,"GameFontHighlightSmall")
        book.modelCaption:SetJustifyH("CENTER")
        book.model:SetScript("OnModelLoaded",function(self)
            -- Ignore late callbacks belonging to the previously selected entry.
            if book.modelFileID and self:GetModelFileID()==book.modelFileID then
                applyModelZoom(self)
                book.modelCaption:SetText("")
            end
        end)
        local rotating,lastCursorX=false,nil
        local function cursorX()
            local x=GetCursorPosition and GetCursorPosition()
            if type(x)=="number" and not (issecretvalue and issecretvalue(x)) then
                return x/(UIParent:GetEffectiveScale() or 1)
            end
        end
        book.model:SetScript("OnMouseDown",function() rotating=true;lastCursorX=cursorX() end)
        book.model:SetScript("OnMouseUp",function() rotating=false;lastCursorX=nil end)
        book.model:SetScript("OnUpdate",function(self)
            if not rotating then return end
            local x=cursorX()
            if x and lastCursorX then
                book.modelRotation=(book.modelRotation or 0)+(x-lastCursorX)*0.015
                self:SetRotation(book.modelRotation)
            end
            lastCursorX=x
        end)
        book.model:SetScript("OnHide",function() rotating=false;lastCursorX=nil end)
        book.stats=label(detail,"",362,-302,216);book.stats:SetSpacing(6)
        book.history=label(detail,"",590,-302,334,"GameFontHighlightSmall");book.history:SetSpacing(6)
        label(detail,"Locations",590,-109,334,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        book.zoneScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        book.zoneScroll:SetPoint("TOPLEFT",590,-134);book.zoneScroll:SetSize(312,140)
        book.zoneChild=CreateFrame("Frame",nil,book.zoneScroll);book.zoneChild:SetSize(304,140)
        book.zoneScroll:SetScrollChild(book.zoneChild);ns.AutoHideScrollBar(book.zoneScroll)
        book.zoneRows={};book.noZones=label(book.zoneChild,"Mouse over this herb or mineral to record its zone.",0,-6,296,"GameFontHighlightSmall")
        local divider=detail:CreateTexture(nil,"ARTWORK")
        divider:SetColorTexture(0.35,0.20,0.08,0.42)
        divider:SetPoint("TOPLEFT",362,-367);divider:SetSize(554,3)
        label(detail,"Field notes",362,-391,270,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        local noteBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        noteBorder:SetPoint("TOPLEFT",362,-421);noteBorder:SetSize(270,185)
        noteBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        noteBorder:SetBackdropColor(0.05,0.04,0.025,0.6);noteBorder:SetBackdropBorderColor(0.45,0.30,0.13,1)
        book.noteScroll=CreateFrame("ScrollFrame",nil,noteBorder,"UIPanelScrollFrameTemplate")
        book.noteScroll:SetPoint("TOPLEFT",8,-8);book.noteScroll:SetSize(230,169)
        book.note=CreateFrame("EditBox",nil,book.noteScroll)
        book.note:SetMultiLine(true);book.note:SetAutoFocus(false);book.note:SetMaxLetters(1000)
        book.note:EnableMouse(true);book.note:EnableKeyboard(true)
        book.note:SetFontObject(textFont("GameFontHighlight"));book.note:SetSize(222,169)
        book.noteScroll:SetScrollChild(book.note);ns.AutoHideScrollBar(book.noteScroll)
        local function focusNotes(_,mouseButton)
            if mouseButton=="LeftButton" and selected and book.noteID==selected then book.note:SetFocus() end
        end
        book.noteScroll:EnableMouse(true);book.noteScroll:SetScript("OnMouseDown",focusNotes)
        noteBorder:EnableMouse(true);noteBorder:SetScript("OnMouseDown",focusNotes)
        book.note:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        book.note:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local scroll=book.noteScroll:GetVerticalScroll();local top=-y
            if top<scroll then book.noteScroll:SetVerticalScroll(top)
            elseif top+height>scroll+169 then book.noteScroll:SetVerticalScroll(top+height-169) end
        end)
        book.note:SetScript("OnTextChanged",function(self)
            if book.loadingNote or not selected then return end
            drafts[selected]=self:GetText();book.message:SetText("")
            book.saveNote:SetEnabled(drafts[selected]~=(journal.entries[selected].note or ""))
            book.noteScroll:UpdateScrollChildRect();book.noteScroll:RefreshScrollBar()
        end)
        book.saveNote=button(detail,"Save notes",362,-618,108,function()
            local id=book.noteID
            if id and id==selected and journal:SetNote(id,book.note:GetText()) then
                drafts[id]=nil;book.message:SetText("Notes saved.");book.note:ClearFocus();refresh()
            end
        end)
        book.message=label(detail,"",482,-624,150,"GameFontHighlightSmall")
        label(detail,"Observed loot",646,-391,270,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        local lootBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        lootBorder:SetPoint("TOPLEFT",646,-421);lootBorder:SetSize(270,185)
        lootBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        lootBorder:SetBackdropColor(0.05,0.04,0.025,0.6);lootBorder:SetBackdropBorderColor(0.45,0.30,0.13,1)
        book.lootScroll=CreateFrame("ScrollFrame",nil,lootBorder,"UIPanelScrollFrameTemplate")
        book.lootScroll:SetPoint("TOPLEFT",8,-8);book.lootScroll:SetSize(230,169)
        book.lootChild=CreateFrame("Frame",nil,book.lootScroll);book.lootChild:SetSize(230,169)
        book.lootScroll:SetScrollChild(book.lootChild);ns.AutoHideScrollBar(book.lootScroll)
        book.lootRows={}
        book.noLoot=label(book.lootChild,"No loot recorded yet.\nGather this node to record its drops.",4,-6,218,"GameFontHighlightSmall")
        book.mapOptions={}
        for i,spec in ipairs({{"worldMap","Show nodes on world map"},{"minimap","Show nodes on minimap"}}) do
            local key=spec[1]
            local control=CreateFrame("CheckButton",nil,book,"UICheckButtonTemplate")
            control:SetSize(24,24);control:SetPoint("TOPLEFT",362+(i-1)*280,-649)
            label(control,spec[2],26,-6,250,"GameFontHighlightSmall")
            control:SetChecked(journal:ShowNodesOn(key))
            control:SetScript("OnClick",function(self)
                journal:SetShowNodesOn(key,self:GetChecked()==true)
                if controller.mapPins then controller.mapPins:Refresh() end
            end)
            book.mapOptions[key]=control
        end
        label(book,"Hover to record zones. Interact to record approximate coordinates.",362,-681,554,"GameFontHighlightSmall")
        local filter=CreateFrame("Frame","AzerothFieldbookGatheringLocationFilter",UIParent,"BackdropTemplate")
        filter:SetSize(320,378);filter:SetPoint("TOPRIGHT",book,"TOPLEFT",-6,0)
        filter:SetFrameStrata("FULLSCREEN_DIALOG");filter:SetClampedToScreen(true);filter.afbAnchorRule="filters"
        filter:SetMovable(true);filter:EnableMouse(true);filter:RegisterForDrag("LeftButton")
        filter:SetScript("OnDragStart",filter.StartMoving);filter:SetScript("OnDragStop",filter.StopMovingOrSizing)
        filter:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local paper=filter:CreateTexture(nil,"BACKGROUND")
        paper:SetPoint("TOPLEFT",6,-6);paper:SetPoint("BOTTOMRIGHT",-6,6)
        paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        shell:AddBackgroundLayer(paper,0.504,0.504,0.48888)
        label(filter,"Filter: Locations",28,-28,264,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        label(filter,"Show entries in any checked location.",28,-58,264,"GameFontHighlightSmall")
        ui.Close(filter);filter.closeButton:SetSize(24,24)
        book.locationFrame=filter
        filter.scroll=CreateFrame("ScrollFrame",nil,filter,"UIPanelScrollFrameTemplate")
        filter.scroll:SetPoint("TOPLEFT",28,-88);filter.scroll:SetSize(250,212)
        filter.body=CreateFrame("Frame",nil,filter.scroll);filter.body:SetSize(240,212)
        filter.scroll:SetScrollChild(filter.body);ns.AutoHideScrollBar(filter.scroll)
        ns.StyleWindowScrollBar(filter.scroll,filter)
        filter.rows={}
        filter.empty=label(filter.body,"No locations recorded yet.",0,0,238,"GameFontHighlightSmall")
        refreshLocationFilter=function()
            local seen,names={},{}
            for _,entry in pairs(journal.entries) do
                for _,zone in ipairs(journal:GetLocationZones(entry.id)) do
                    if not seen[zone.name] then seen[zone.name]=true;names[#names+1]=zone.name end
                end
            end
            table.sort(names)
            for i,name in ipairs(names) do
                local row=filter.rows[i]
                if not row then
                    row=CreateFrame("CheckButton",nil,filter.body,"UICheckButtonTemplate")
                    row:SetSize(24,24);row:SetPoint("TOPLEFT",0,-(i-1)*28)
                    row.text=label(row,"",28,-5,202,"GameFontHighlightSmall");row.text:SetWordWrap(false)
                    row:SetScript("OnClick",function(self)
                        locationFilters[self.zone]=self:GetChecked() and true or nil;offset=0;refresh()
                    end)
                    filter.rows[i]=row
                end
                row.zone=name;row.text:SetText(name);row:SetChecked(locationFilters[name]==true);row:Show()
            end
            for i=#names+1,#filter.rows do filter.rows[i]:Hide() end
            filter.empty:SetShown(#names==0);filter.body:SetHeight(math.max(212,#names*28))
            filter.scroll:UpdateScrollChildRect();filter.scroll:RefreshScrollBar()
        end
        button(filter,"Clear all",28,-328,170,function()
            for zone in pairs(locationFilters) do locationFilters[zone]=nil end
            offset=0;refreshLocationFilter();refresh()
        end)
        filter:SetScript("OnShow",function() refreshLocationFilter();refresh() end)
        filter:HookScript("OnHide",function() filter:StopMovingOrSizing();if book.locationFrame then refresh() end end)
        filter:Hide()
        if ns.UIScale then ns.UIScale:Register(filter) end
        if ns.WindowPositions then ns.WindowPositions:Register(filter,filter:GetName()) end
        if ns.WindowFocus then ns.WindowFocus:Register(filter) end
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=filter:GetName() end
        book:SetScript("OnHide",function()
            dismiss:Hide();filter:Hide();locations:Hide();book.search:ClearFocus();book.note:ClearFocus()
            for _,row in ipairs(book.rows) do row:StopNameScroll() end
        end)
        local elapsed=0
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.25 then
                elapsed=0
                if book.revision~=journal.revision then refresh();if filter:IsShown() then refreshLocationFilter() end end
            end
        end)
    end
    shell:RegisterSection("gathering",{title="Gatherer's Compendium",icon="Interface\\Icons\\INV_Misc_Flower_02",
        help="|cffffd1001. Discover|r\nMouse over a herb or mineral in the world to record its name, type and zone from the readable tooltip. You do not need Herbalism or Mining to discover it. Hovering records a zone, not a coordinate or completed gather.\n\n"..
            "|cffffd1002. Record positions|r\nStarting a Herbalism or Mining cast records an interaction and approximate position, even if interrupted. A successful cast also counts as a completed gather, not a quantity of loot. Without the required profession or rank, right-clicking the node can still record its position when the matching skill-requirement error is received. Unrelated loot, targeting and minimap tracking do not record nodes.\n\n"..
            "|cffffd1003. Browse|r\nUse Herbs, Minerals, search, the sort menu and Locations filters to narrow the index. Index opens the A-Z filters; Previous and Next browse the matching entries. Drag the node preview to rotate it.\n\n"..
            "|cffffd1004. Review locations|r\nClick a zone under Locations to open its recorded positions. Green dots are herbs; gold dots are minerals. Hover a dot for coordinates. These are your approximate positions while interacting, not proof that a node is currently available. Zone-only discoveries have no dots.\n\n"..
            "|cffffd1005. Map display|r\nThe checkboxes at the bottom independently show recorded nodes on the world map and minimap. Both start off and are saved with the active journal. World-map dots show up to 512 recent positions in the displayed zone; minimap dots show up to 128 nearest positions and follow movement, zoom and rotation. All recorded positions remain in each resource's Locations view. Dots hide when the client cannot provide the required location information.\n\n"..
            "|cffffd1006. Field notes|r\nSelect an entry, write your notes and click Save notes. The adjacent Observed loot list records readable items from completed gathers, with item icons, quality colours and hover tooltips. Stack ranges describe observed loot, not guaranteed yields. Older gathers cannot be reconstructed. Gathering records follow the global Account-wide tracking option and remain separate from Bestiary resets, backups and sharing. Use the Options cog for shared Fieldbook settings.",
        frameName="AzerothFieldbookGatheringSection",build=build,onOpen=function() refresh(true) end})
    function controller:OpenAtMouseover()
        local id=self.tracking and self.tracking:DiscoverAtMouseover()
        if not id or not journal.entries[id] then return false end
        selected=id;category=nil;initial=nil;offset=0
        for zone in pairs(locationFilters) do locationFilters[zone]=nil end
        shell:ShowSection("gathering")
        book.search:SetText("");book.search:ClearFocus();book.note:ClearFocus()
        book.locationFrame:Hide()
        for i,entry in ipairs(currentRows()) do
            if entry.id==id then offset=math.max(0,i-PAGE_SIZE);break end
        end
        choose(id)
        return true
    end
    function controller:Refresh() refresh() end
    return controller
end

function ns.InitializeGathering(shell,getBrightness)
    if type(AzerothFieldbookGatheringDB)~="table" then AzerothFieldbookGatheringDB={} end
    local storage=ns.SelectSectionStorage and ns.SelectSectionStorage("gathering",AzerothFieldbookGatheringDB) or AzerothFieldbookGatheringDB
    local journal=ns.CreateGatheringJournal(storage,getBrightness)
    local controller=ns.CreateGatheringBook(journal,shell)
    controller.tracking=ns.CreateGatheringTracking(journal)
    controller.mapPins=ns.CreateGatheringMapPins(journal)
    return controller
end
