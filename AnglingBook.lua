local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A,U,R=ns.Angling,ns.AtlasUI,ns.AnglingReports
local ROW_HEIGHT,LIST_HEIGHT=38,440
local VISIBLE_ROWS=math.ceil(LIST_HEIGHT/ROW_HEIGHT)+1
local function dateLabel(stamp) return U.Date(stamp) end
local function itemIcon(e)
    local icon=e.itemID and A.Read(C_Item and C_Item.GetItemIconByID or GetItemIcon,e.itemID)
    if A.Integer(icon,1,2147483647) then return icon end
    if A.Integer(e.icon,1,2147483647) then return e.icon end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function showEntryTooltip(owner,e)
    if not e or not GameTooltip then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    local native=false
    if e.kind=="item" and A.Integer(e.itemID,1,2147483647) then
        local cached=A.Read(C_Item and C_Item.IsItemDataCachedByID,e.itemID)
        if cached~=false then
            if type(GameTooltip.SetItemByID)=="function" then native=pcall(GameTooltip.SetItemByID,GameTooltip,e.itemID)
            elseif type(GameTooltip.SetHyperlink)=="function" then native=pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..e.itemID) end
        end
        if not native then A.Read(C_Item and C_Item.RequestLoadItemDataByID,e.itemID) end
    end
    if not native then
        GameTooltip:SetText(A.Safe(e.name))
        GameTooltip:AddLine(e.kind=="item" and "Item details unavailable; select to read recorded catches." or "Select to read fishing observations.",1,1,1,true)
    end
    if e.note and e.note~="" then GameTooltip:AddLine(A.Safe(e.note),1,1,1,true) end
    GameTooltip:Show()
end

function ns.CreateAnglingBook(journal,tracking,shell)
    local c={journal=journal,tracking=tracking,shell=shell,panels={}}
    local state=journal.state
    state.view=(state.view=="pools" or state.view=="catches") and state.view or "waters"
    function c:LayoutDetails(progress)
        local m=self.main
        m.notesProgress=progress
        m.notesOverlay:ClearAllPoints();m.notesOverlay:SetPoint("TOPLEFT",342,-588+414*progress)
        m.notesOverlay:SetHeight(113+414*progress)
        m.details:SetHeight(61+414*progress)
        m.detailBody:SetHeight(math.max(m.details:GetHeight(),m.detailHeight or 0))
        m.details:UpdateScrollChildRect();m.details:RefreshScrollBar()
        m.notesOverlay:EnableMouse(progress>0)
    end
    function c:Expand()
        local m=self.main
        m.notesExpanded=not m.notesExpanded
        m.expand:SetSelected(m.notesExpanded)
        local from=m.notesProgress or 0
        local target=m.notesExpanded and 1 or 0
        for row,stroke in ipairs(m.notesArrow) do
            stroke:ClearAllPoints();stroke:SetPoint("CENTER",0,m.notesExpanded and 3-row or row-3)
        end
        local elapsed=0
        m.notesOverlay:SetScript("OnUpdate",function(frame,delta)
            elapsed=math.min(0.18,elapsed+delta)
            local t=elapsed/0.18;local eased=1-(1-t)^3
            c:LayoutDetails(from+(target-from)*eased)
            if t>=1 then
                frame:SetScript("OnUpdate",nil)
                m.details:SetVerticalScroll(math.min(m.details:GetVerticalScroll(),math.max(0,m.detailBody:GetHeight()-m.details:GetHeight())))
            end
        end)
    end
    function c:State() return journal:View(state.view) end
    function c:SelectedEntry()
        local e=journal:Get(self:State().selected)
        if not e then return end
        local view=e.kind=="pool" and "pools" or e.kind=="item" and "catches" or "waters"
        if view==state.view then return e end
    end
    function c:Filters()
        local s=self:State();local f=A.Copy(s)
        f.mapID=nil -- map browsing and the index's zone filter are independent
        if s.currentZone then f.mapID=A.Location(A.CurrentLocation()).mapID or -1 end
        return f
    end
    function c:Message(message) self.message=message;if self.main then self.main.message:SetText(A.Safe(message or "")) end end
    function c:ClosePanel()
        for _,p in pairs(self.panels) do p:Hide() end
        self.activePanel=nil
    end
    function c:OpenPanel(panel)
        self:ClosePanel();self.activePanel=panel;panel:Show()
    end
    function c:Panel(title)
        local p=CreateFrame("Frame",nil,self.frame,"BackdropTemplate")
        p:SetPoint("TOPLEFT",38,-90);p:SetSize(262,584);p:SetFrameLevel(self.main:GetFrameLevel()+15);p:EnableMouse(true)
        p:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        local paper=p:CreateTexture(nil,"BACKGROUND");paper:SetPoint("TOPLEFT",5,-5);paper:SetPoint("BOTTOMRIGHT",-5,5)
        paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png");paper:SetDesaturated(true)
        shell:AddBackgroundLayer(paper,0.17,0.17,0.17,true)
        p.title=U.Label(p,title,15,-18,184,"GameFontNormal");p.title:SetWordWrap(false)
        p.back=U.Button(p,"Back",204,-12,47,function() c:ClosePanel() end)
        p.inputs={}
        p:SetScript("OnHide",function(self) for _,e in ipairs(self.inputs) do e:ClearFocus() end;if GameTooltip then GameTooltip:Hide() end end)
        return p
    end
    function c:SetView(view)
        local previous=self:State();previous.detailScroll=self.main.details:GetVerticalScroll()
        state.view=view;self:ClosePanel()
        local s=self:State();if not s.mapID then local p=A.Location(A.CurrentLocation());s.mapID,s.mapZone=p.mapID,p.zone end
        self.rendering=true;self.main.search:SetText(self:State().query);self.rendering=false
        self:Refresh();self.main.details:SetVerticalScroll(self:State().detailScroll or 0)
    end
    function c:Select(id,focus)
        local e=journal:Get(id);if not e then return end
        local view=e.kind=="pool" and "pools" or e.kind=="item" and "catches" or "waters"
        if state.view~=view then self:SetView(view) end
        local s=self:State()
        if e.removed then s.status="removed" end
        if focus then s.focusFact,s.focusItem=focus.factID,focus.itemID
        elseif s.selected~=id then s.focusFact,s.focusItem=nil,nil end
        s.selected=id
        local place=e
        if e.kind=="pool" or e.kind=="item" then place=journal:Links(e,"locations",self:Filters())[1] or e end
        if place.mapID then s.mapID,s.mapZone=place.mapID,place.zone end
        local rows=journal:List(view,self:Filters());local found
        for i,r in ipairs(rows) do if r.id==id then found=i end end
        if not found then
            s.query="";s.currentZone=false;s.source="all";s.status=e.removed and "removed" or "all";s.knowledge="all"
            self.rendering=true;self.main.search:SetText("");self.rendering=false
            rows=journal:List(view,self:Filters());for i,r in ipairs(rows) do if r.id==id then found=i end end
            self:Message("Index filters cleared to show the selected fishing record.")
        end
        if found then
            local top=(found-1)*ROW_HEIGHT;local scroll=s.indexScroll or 0
            if top<scroll then s.indexScroll=top
            elseif top+ROW_HEIGHT>scroll+LIST_HEIGHT then s.indexScroll=top+ROW_HEIGHT-LIST_HEIGHT end
        end
        s.detailScroll=0;self.main.details:SetVerticalScroll(0);self:ClosePanel();self:Refresh()
    end
    function c:Details(e)
        if not e then return {"Your fishing journal starts with what you observe or deliberately record.",
            "Remember a spot, record a pool sighting, or fish. Uncertain sources remain unclassified.",A.VISION} end
        local f=self:Filters();local summary=journal:Summary(e,f)
        local lines={}
        if e.kind=="spot" then
            lines[#lines+1]=e.zone..(e.subzone~="" and " / "..e.subzone or "").." • "..A.PositionLabel(e)
            lines[#lines+1]="Last seen "..dateLabel(e.personalLast or e.last).."; current availability unknown."
            if e.hover then lines[#lines+1]="Pool type seen on a world-object tooltip in this zone. Exact position and contents are unknown." end
        elseif e.kind=="water" then
            lines[#lines+1]="Fishing waters; catches do not create permanent coordinate pins."
            local focus=journal.db.aggregates[self:State().focusFact] or journal.db.reported[self:State().focusFact]
            local item=journal:Get(self:State().focusItem)
            if focus and focus.waterID==e.id then
                lines[#lines+1]="Selected source: "..A.SourceLabels[focus.source]..(focus.poolID and " / "..journal:Get(focus.poolID).name or "")..
                    (item and " — "..item.name or "")..(journal.db.reported[focus.id] and " (Reported)" or "")
            end
        end
        if e.note~="" then lines[#lines+1]="Your notes: "..e.note end
        for _,id in ipairs(e.mergedFrom or {}) do local old=journal.db.merged[id];if old then
            lines[#lines+1]="Merged spot: "..old.name.." • "..A.PositionLabel(old)..(old.note~="" and "\nPreserved note: "..old.note or "")
        end end
        if summary.events==0 then
            lines[#lines+1]=e.kind=="pool" and "No catches recorded from this pool type." or "No personal catches recorded here."
        else
            lines[#lines+1]="Catch events: "..summary.events..(e.kind=="item" and " obtained across this item's recorded sources" or " personal").." ("..summary.recordedEvents.." player-recorded)."
            if e.kind~="item" then lines[#lines+1]="Recorded items: "..A.Count(summary.items).." different items." end
            local items={};for id,value in pairs(summary.items) do items[#items+1]={entry=journal:Get(id),value=value} end
            table.sort(items,function(a,b) return a.entry.name<b.entry.name end)
            for _,item in ipairs(items) do
                local v=item.value
                lines[#lines+1]=(e.kind=="item" and "" or item.entry.name.." — ")..v.quantity.." items; recorded in "..v.occurrences.." of "..summary.events..
                    string.format(" catch events (%.1f%% observed frequency).",100*v.occurrences/summary.events)
            end
            lines[#lines+1]="Denominator: obtained catch events in the displayed source contexts, not casts. Multi-item events can contain several different items."
        end
        lines[#lines+1]="Requirements unknown. Success is evidence of success at that skill, not a minimum requirement."
        for _,row in ipairs(journal:Facts(e,nil,f)) do
            local fact=row.fact;local w=journal:Get(fact.waterID)
            local provenance=row.reported and ("Reported by "..fact.origin.source.." (not authenticated)")
                or (fact.originUnknown and "Historical catches; original observer not recorded")
                or ((fact.method=="recorded" and "Player-recorded catches by " or "Catches observed by ")..fact.origin.source)
            lines[#lines+1]="\n"..w.name.." • "..A.SourceLabels[fact.source]..(fact.poolID and ": "..journal:Get(fact.poolID).name or "")
            lines[#lines+1]=provenance
            lines[#lines+1]="Source association: "..fact.association.." • "..fact.events.." catch events."
            if fact.lastPosition then lines[#lines+1]="Latest "..A.PositionLabel(fact.lastPosition) end
            local localItems={};for id,value in pairs(fact.items) do localItems[#localItems+1]=journal:Get(id).name.." ×"..value.quantity.." ("..value.occurrences.." events)" end
            table.sort(localItems)
            for _,item in ipairs(localItems) do lines[#lines+1]=item end
            if fact.lowestSkill then
                lines[#lines+1]=(row.reported and "Lowest successful skill reported: " or "Lowest successful effective skill personally observed: ")..fact.lowestSkill.effective
            end
            if fact.lastSkill and next(fact.lastSkill) then
                local s=fact.lastSkill
                lines[#lines+1]="Latest cast skill snapshot — base: "..(s.base or "unknown")..", modifier: "..(s.modifier or "unknown")..", temporary points: "..(s.temporary or "unknown").."; equipment/lure split unknown."
            end
            lines[#lines+1]="First "..dateLabel(fact.first).." • Latest "..dateLabel(fact.last)
        end
        for _,key in ipairs(e.claims or {}) do
            local claim=journal.db.claims[key]
            if claim then lines[#lines+1]="Reported identity: "..claim.origin.source.." / "..claim.origin.method.." (not authenticated)"..
                (claim.notes and "\nReported note: "..claim.notes or "") end
        end
        local history=0
        for i=#journal.db.history,1,-1 do
            local h=journal.db.history[i];local fact=journal.db.aggregates[h.aggregateID]
            if fact and journal:Matches(fact,e) and (e.kind~="item" or h.items[e.id]~=nil) then
                local parts={};for id,qty in pairs(h.items) do parts[#parts+1]=journal:Get(id).name.." ×"..qty end;table.sort(parts)
                if history==0 then lines[#lines+1]="\nRecent personal history (up to 200 events retained; totals persist):" end
                lines[#lines+1]=dateLabel(h.at).." — "..table.concat(parts,", ");history=history+1;if history>=10 then break end
            end
        end
        return lines
    end
    function c:RenderDetails(e)
        local m=self.main;local lines=self:Details(e)
        -- Retain the plain text for readers of the complete detail content.
        m.details.text:SetText(A.Safe(table.concat(lines,"\n")));m.details.text:Hide()
        local blocks={{title=e and "Fishing summary" or "Your fishing field notes",lines={}}}
        for _,line in ipairs(lines) do
            if line:sub(1,1)=="\n" then
                blocks[#blocks+1]={title=line:sub(2),lines={}}
            else
                local block=blocks[#blocks]
                local text
                if block.title:match("^Recent personal history") then
                    local stamp,catch=line:match("^(.-) — (.*)$")
                    text=stamp and U.DetailPaint(stamp.." — ","9ba7ad")..U.DetailPaint(catch,"c5cdcf") or U.DetailPaint(line,"c5cdcf")
                elseif line:match("^Denominator:") or line:match("^Requirements unknown") or line:match("^Last seen ") or line:match("^First ") then
                    text=U.DetailPaint(line,"9ba7ad")
                elseif line:match("^Latest cast skill snapshot") then
                    text=U.DetailPaint("Latest cast skill", "74c7d5")..U.DetailPaint(line:sub(#"Latest cast skill snapshot"+1),"c5cdcf")
                else
                    local label,value=line:match("^([^:]+:)(.*)$")
                    local item,counts=line:match("^(.-)( — %d+ items;.*)$")
                    if label then text=U.DetailPaint(label,"74c7d5")..U.DetailPaint(value,"c5cdcf")
                    elseif item then text=U.DetailPaint(item,"74c7d5")..U.DetailPaint(counts,"c5cdcf")
                    else text=U.DetailPaint(line,"c5cdcf") end
                end
                block.lines[#block.lines+1]=text
            end
        end
        m.detailRows=m.detailRows or {};local y=0
        for i,block in ipairs(blocks) do
            local row=m.detailRows[i]
            if not row then
                row=CreateFrame("Frame",nil,m.detailBody);row:SetWidth(550)
                row.text=U.Label(row,"",0,0,550,"GameFontHighlightSmall");row.text:SetWordWrap(true);row.text:SetSpacing(3)
                row.divider=U.DetailDivider(row,9,550);m.detailRows[i]=row
            end
            for _,line in ipairs(row.divider) do line:SetShown(i>1) end
            if i>1 then y=y+20 end
            row.text:SetText(U.DetailPaint(block.title,"ffd100")..(#block.lines>0 and "\n\n"..table.concat(block.lines,"\n") or ""))
            local height=math.ceil(row.text:GetStringHeight()+8)
            row:SetHeight(height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:Show();y=y+height+8
        end
        for i=#blocks+1,#m.detailRows do m.detailRows[i]:Hide() end
        m.detailHeight=y
    end
    function c:Refresh()
        if not self.main or self.refreshing then return end;self.refreshing=true
        local m,s=self.main,self:State();local rows=journal:List(state.view,self:Filters())
        local scroll=math.max(0,math.min(s.indexScroll or 0,math.max(0,#rows*ROW_HEIGHT-LIST_HEIGHT)))
        s.indexScroll=scroll
        m.updatingList=true;m.listBody:SetHeight(math.max(LIST_HEIGHT,#rows*ROW_HEIGHT))
        m.list:SetVerticalScroll(scroll);m.list:UpdateScrollChildRect();m.list:RefreshScrollBar();m.updatingList=nil
        local first=math.floor(scroll/ROW_HEIGHT)
        for i,row in ipairs(m.rows) do
            local e=rows[first+i];row.id=e and e.id;row:SetShown(e~=nil)
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+i-1)*ROW_HEIGHT)
            if e then
                row.name:SetText((e.favourite and U.SavedIcon(true) or "")..A.Safe(e.name));row:SetSelected(e.id==s.selected)
                row.zone:SetText((e.personal and "Personal" or "Reported").." • "..(e.kind=="spot" and (e.hover and "Pool zone sighting" or e.poolID and "Pool sighting" or "Remembered spot") or e.kind))
                row.icon:SetTexture(e.kind=="item" and itemIcon(e) or "Interface\\Icons\\Trade_Fishing")
            end
        end
        m.count:SetCounts(#journal:List(state.view,{status=s.status=="removed" and "removed" or "all"}),#rows)
        m.empty:SetShown(#rows==0);m.empty:SetText("No matching fishing knowledge.\n\nRemember a spot, record a sighting, or catch something to begin.")
        m.filters:SetSelected(s.currentZone==true or s.knowledge~="all" or s.source~="all" or s.status~="all")
        for key,b in pairs(m.views) do b:SetEnabled(key~=state.view) end
        local e=self:SelectedEntry()
        if not tracking.observingHover then m.map:Render(s.mapID,s.selected) end
        m.zone:SetText(A.Safe(s.mapZone or "Choose zone"));m.session:SetText(A.Safe(tracking:SessionText()))
        m.heading:SetText(e and A.Safe(e.name) or "Your fishing field notes")
        self:RenderDetails(e)
        self:LayoutDetails(m.notesProgress or 0)
        for _,b in ipairs(m.entryButtons) do b:SetEnabled(e~=nil) end
        m.deleteButton:SetEnabled(e~=nil and not e.removed and not journal.readOnly)
        m.merge:SetShown(state.view=="waters")
        m.merge:SetEnabled(e~=nil and not e.removed and e.kind=="spot" and not journal.readOnly)
        m.restore:SetShown(e~=nil and e.removed==true)
        m.restore:SetEnabled(e~=nil and e.removed==true and not journal.readOnly)
        m.favourite:SetText(e and e.favourite and "Unfavourite" or "Favourite")
        m.assign:SetEnabled(e~=nil and not e.removed and (e.kind=="pool" or e.kind=="spot") and not journal.readOnly)
        m.assign:SetText(e and e.kind=="spot" and not e.poolID and "Use selected spot" or "Assign selected pool")
        m.message:SetText(A.Safe(journal.readOnly and "Newer Almanac schema: read-only; saved data is untouched." or self.message or tracking.status))
        local links=self.panels.links;if links and links:IsShown() then links:Render() end
        self.refreshing=false
    end
    function c:OpenForm(kind,id)
        local p=self.panels.form
        if not p then
            p=self:Panel("");self.panels.form=p
            p.a=U.Field(p,"",14,-55,228,300);p.b=U.Field(p,"",14,-111,228,160);p.c=U.Field(p,"",14,-167,228,12)
            p.notesLabel=U.Label(p,"Personal notes",14,-230,226,"GameFontNormalSmall")
            p.notes=U.TextArea(p,18,-253,207,155,4000);p.hint=U.ReadArea(p,14,-425,214,84)
            p.save=U.Button(p,"Save",14,-539,228,function()
                local e,err
                if p.kind=="edit" then e,err=journal:Edit(p.id,p.a:GetText(),p.notes:GetText(),journal:Get(p.id).favourite)
                elseif p.kind=="catch" then
                    local input=p.a:GetText();local itemID=tonumber(input) or tonumber(input:match("item:(%d+)"))
                    local items={{itemID=itemID,name=A.Name(p.b:GetText()),quantity=tonumber(p.c:GetText())}}
                    for line in p.notes:GetText():gmatch("[^\r\n]+") do
                        local id,quantity=line:match("^%s*(%d+)%s*,%s*(%d+)%s*$")
                        if not id then p.hint:SetText("Additional items use one item ID, quantity pair per line (for example: 1234, 2).",true);return end
                        items[#items+1]={itemID=tonumber(id),quantity=tonumber(quantity)}
                    end
                    e,err=tracking:ManualCatch(items)
                else
                    if p.kind=="sighting" and not A.Name(p.b:GetText()) then p.hint:SetText("Enter the pool type you saw; its contents will remain unknown.",true);return end
                    e,err=journal:Remember({name=p.a:GetText(),pool=p.kind=="sighting" and {name=p.b:GetText()} or nil,note=p.notes:GetText(),location=p.location})
                end
                if e then c:ClosePanel();if type(e)=="table" and e.kind then c:Select(e.id) else c:Refresh() end;c:Message("Fishing journal saved.")
                else p.hint:SetText(err or "Check the fields and try again.",true) end
            end)
            p.inputs={p.a,p.b,p.c,p.notes}
        end
        p.kind,p.id=kind,id;p.location=A.CurrentLocation()
        local e=journal:Get(id)
        p.title:SetText(kind=="edit" and "Edit field notes" or kind=="catch" and "Record catch" or kind=="sighting" and "Record pool sighting" or "Remember a spot")
        p.a.fieldLabel:SetText(kind=="catch" and "Item ID or item link" or "Name")
        p.b.fieldLabel:SetText(kind=="catch" and "Item name (or ID above)" or "Pool type name")
        p.c.fieldLabel:SetText("Quantity in ONE catch event")
        p.a:SetText(e and e.name or "");p.b:SetText("");p.c:SetText("1");p.notes:SetText(e and e.note or "")
        p.b:SetShown(kind=="catch" or kind=="sighting");p.b.fieldLabel:SetShown(kind=="catch" or kind=="sighting")
        p.c:SetShown(kind=="catch");p.c.fieldLabel:SetShown(kind=="catch")
        p.notesLabel:SetText(kind=="catch" and "Other items: ID, quantity per line" or "Personal notes")
        p.hint:SetText(kind=="catch" and "Player-recorded fallback. Add only a catch missing from automatic history. Extra items above belong to the same event. Current skill is not attached. Source uses the visible session assignment."
            or kind=="edit" and "Your notes stay private unless deliberately included in a report. Only remembered-spot names can be changed."
            or "Player-recorded observation at your current position. This is approximate, not an exact pool position. Pool contents stay unknown until recorded.",true)
        p.save:SetEnabled(not journal.readOnly);self:OpenPanel(p)
    end
    function c:OpenLinks(kind)
        local selected=journal:Get(self:State().selected);if not selected then return end
        local p=self.panels.links
        if not p then
            p=self:Panel("");self.panels.links=p;p.rows={}
            for i=1,10 do
                local row=U.Button(p,"",14,-61-(i-1)*44,228,function(self)
                    if not self.data then return end
                    if p.kind=="merge" then
                        local e,err=journal:MergeSpots(p.selected,self.data.id);if e then c:Select(e.id) else c:Message(err) end
                    else c:Select(self.data.id,self.data.focus) end
                end)
                row:SetHeight(40);row:SetNormalFontObject(textFont("GameFontHighlightSmall"))
                row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(24,24);row.icon:SetPoint("LEFT",8,0)
                row.itemName=U.Label(row,"",39,-7,180,"GameFontHighlightSmall");row.itemName:SetWordWrap(true)
                row:SetScript("OnEnter",function(self) if p.kind=="items" then showEntryTooltip(self,self.data) end end)
                row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                row:SetScript("OnHide",function(self) if GameTooltip and A.Read(GameTooltip.IsOwned,GameTooltip,self) then GameTooltip:Hide() end end)
                p.rows[i]=row
            end
            p.previous=U.Button(p,"Previous",14,-539,109,function() p.offset=math.max(0,p.offset-10);p:Render() end)
            p.next=U.Button(p,"Next",132,-539,110,function() p.offset=p.offset+10;p:Render() end)
            p.count=U.Label(p,"",14,-512,228,"GameFontHighlightSmall")
            function p:Render()
                self.offset=math.min(self.offset,math.floor(math.max(0,#self.data-1)/10)*10)
                for i,row in ipairs(self.rows) do
                    local e=self.data[self.offset+i];row.data=e;row:SetShown(e~=nil)
                    local item=e and self.kind=="items"
                    row.icon:SetShown(item==true);row.itemName:SetShown(item==true)
                    if e then
                        row:SetText(item and "" or A.Safe(e.name))
                        if item then row.icon:SetTexture(itemIcon(e));row.itemName:SetText(A.Safe(e.name)) end
                    end
                end
                self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+10<#self.data)
                self.count:SetText(#self.data==0 and "No recorded links yet." or #self.data.." recorded links")
            end
        end
        p.kind,p.selected,p.offset=kind,selected.id,0;p.data={}
        p.title:SetText(kind=="items" and "Recorded catches" or kind=="merge" and "Merge into this spot" or "Known fishing sources")
        if kind=="merge" then
            for _,e in pairs(journal.db.spots) do if not e.removed and e.id~=selected.id and e.waterID==selected.waterID and e.poolID==selected.poolID then p.data[#p.data+1]=e end end
            table.sort(p.data,function(a,b) return a.name<b.name end)
        elseif kind=="items" then p.data=journal:Links(selected,kind,self:Filters())
        else
            local seen={}
            for _,row in ipairs(journal:Facts(selected,self:State().knowledge,self:Filters())) do
                local f=row.fact;local e=journal:Get(f.spotID or f.waterID)
                if e.removed then e=journal:Get(f.waterID) end
                local key=A.Key(e.id,f.source,f.poolID,row.reported,f.method)
                local itemID=selected.kind=="item" and selected.id or nil
                local last=itemID and f.items[itemID].last or f.last
                if not seen[key] or seen[key].last<last then
                    local entry=seen[key] or {};if not seen[key] then p.data[#p.data+1]=entry;seen[key]=entry end
                    entry.id,entry.last=e.id,last;entry.focus={factID=f.id,itemID=itemID}
                    entry.name=e.name.."\n"..(f.poolID and journal:Get(f.poolID).name or A.SourceLabels[f.source])..
                        (row.reported and " • Reported" or f.method=="recorded" and " • Player-recorded" or "")
                end
            end
            if #p.data==0 then p.data=journal:Links(selected,"locations",self:Filters()) end
        end
        p:Render();self:OpenPanel(p)
    end
    function c:OpenReports()
        local p=self.panels.reports
        if not p then
            p=self:Panel("Fishing reports");self.panels.reports=p
            p.build=U.Button(p,"Prepare selected knowledge",14,-54,228,function()
                local report,err=R.Build(journal,c:State().selected,c:State().knowledge,p.notes:GetChecked()==true)
                if not report then p.preview:SetText(err,true);return end
                p.data:SetText(R.Encode(report));p.preview:SetText(R.Preview(report),true)
            end)
            p.notes=U.Check(p,"Include selected record's note",12,-86,202,function() end)
            U.Label(p,"Report data (copy or paste)",14,-122,228,"GameFontNormalSmall")
            p.data=U.TextArea(p,18,-144,207,122,R.MAX_BYTES)
            p.preview=U.ReadArea(p,14,-314,214,237)
            p.check=U.Button(p,"Preview",14,-280,109,function()
                R.Cancel(p.ticket);local ticket,err=R.Prepare(p.data:GetText());p.ticket=ticket
                local summary,canAccept
                if ticket then summary,canAccept=R.Preflight(journal,ticket) end
                p.preview:SetText(ticket and summary.."\n\n"..ticket.preview or err,true);p.accept:SetEnabled(canAccept==true)
            end)
            p.accept=U.Button(p,"Accept report",132,-280,110,function()
                local ok,added,updated=R.Accept(journal,p.ticket)
                if ok then p.ticket=nil;p.accept:SetEnabled(false);p.preview:SetText("Accepted as Reported. "..added.." new and "..updated.." updated result summaries; personal totals unchanged.",true)
                else p.preview:SetText(added,true) end
            end)
            p.accept:SetEnabled(false);p.inputs={p.data}
            p.data:HookScript("OnTextChanged",function() R.Cancel(p.ticket);p.ticket=nil;p.accept:SetEnabled(false) end)
            p.preview:SetText("Prepare one selected record and its supporting knowledge, or paste a fishing report, Preview it, then Accept. Notes are excluded by default. No addon-message sending or fishing prices are configured.",true)
        end
        local selectionKey=A.Key(self:State().selected,self:State().knowledge=="reported" and "reported" or "personal")
        if p.selectionKey~=selectionKey then p.notes:SetChecked(false);p.selectionKey=selectionKey end
        self:OpenPanel(p)
    end
    local function build(content)
        c.frame=content;local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m
        local fish=content:CreateTexture(nil,"BACKGROUND",nil,0)
        fish:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\AnglingFishSketch.png")
        fish:SetSize(296,296)
        fish:SetTexCoord(24/320,1,0,296/320)
        fish:SetPoint("BOTTOMLEFT",content,"BOTTOMLEFT",6,16)
        fish:SetAlpha(0.23)
        shell:AddBackgroundLayer(fish,1,1,1,true)
        c.fishIllustration=fish
        local fades={}
        local function fadeStrip(x,y,width,height,alpha)
            local strip=content:CreateTexture(nil,"BACKGROUND",nil,4)
            strip:SetPoint("BOTTOMLEFT",content,"BOTTOMLEFT",x,y)
            strip:SetSize(width,height)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(alpha)
            shell:AddBackgroundLayer(strip,0.504,0.504,0.48888)
            fades[#fades+1]={texture=strip,x=x,y=y,width=width,height=height}
        end
        for i=1,28 do
            local alpha=1-(i-1)/27
            fadeStrip(5+i,16,1,296,alpha)
            fadeStrip(6,15+i,296,1,alpha)
        end
        local function updateMillFade()
            local width,height=content:GetWidth()-8,content:GetHeight()-15
            if width<=0 or height<=0 then return end
            for _,fade in ipairs(fades) do
                local x,y=fade.x-6,fade.y-6
                fade.texture:SetTexCoord(x/width,(x+fade.width)/width,
                    1-(y+fade.height)/height,1-y/height)
            end
        end
        content:HookScript("OnSizeChanged",updateMillFade)
        updateMillFade()
        c.fishCornerFade=ns.FieldbookUI.IllustrationCornerFade(content,shell,16)
        local spine=ns.FieldbookUI.PageDivider(m)
        m.pageTitle=ns.FieldbookUI.SectionTitle(m,"Angler’s Almanac")
        m.views={}
        local viewHelp={
            waters="Browse recorded waters and remembered fishing spots. Select a place to see its map location and observations.",
            pools="Browse observed pool types. Select a type to see its recorded catches and fishing spots.",
            catches="Browse recorded catch items. Select an item to see where and how it was caught.",
        }
        for i,view in ipairs({"waters","pools","catches"}) do
            local key=view;m.views[key]=U.Button(m,({waters="Waters",pools="Pool Types",catches="Catches"})[key],42+(i-1)*84,-140,82,function() c:SetView(key) end)
            m.views[key]:SetScript("OnEnter",function(self)
                if GameTooltip then
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self:GetText())
                    GameTooltip:AddLine(viewHelp[key],1,1,1,true);GameTooltip:Show()
                end
            end)
            m.views[key]:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        end
        m.search=U.Search(m,70,-110,168,200);m.search:SetText(c:State().query)
        m.search:HookScript("OnTextChanged",function() if not c.rendering then local s=c:State();s.query=m.search:GetText();s.offset=0;s.indexScroll=0;c:Refresh() end end)
        m.filters=ns.FieldbookUI.FilterButton(m,244,-110,function(button)
            m.search:ClearFocus()
            if not MenuUtil or type(MenuUtil.CreateContextMenu)~="function" then return end
            MenuUtil.CreateContextMenu(button,function(_,root)
                local s=c:State()
                local function choices(label,key,values)
                    local group=root:CreateButton(label)
                    for _,choice in ipairs(values) do
                        local value=choice[1]
                        local item=group:CreateCheckbox(choice[2],function() return s[key]==value or (value==false and not s[key]) end,function()
                            s[key]=value;s.offset=0;s.indexScroll=0;c:Refresh()
                        end)
                        item:SetResponse(MenuResponse.Refresh)
                    end
                end
                root:CreateTitle("Filters")
                choices("Zone / location","currentZone",{{false,"All recorded zones"},{true,"Current zone"}})
                choices("Knowledge","knowledge",{{"all","All knowledge"},{"personal","Personal"},{"reported","Reported"}})
                choices("Source","source",{{"all","All sources"},{"pool",A.SourceLabels.pool},{"open",A.SourceLabels.open},{"unclassified",A.SourceLabels.unclassified}})
                choices("Show","status",{{"all","All"},{"fished","With recorded catches"},{"unfished","No catches recorded"},{"favourites","Favourites"},{"removed","Removed"}})
                root:CreateDivider()
                local clear=root:CreateButton("Clear",function()
                    s.currentZone=false;s.knowledge="all";s.source="all";s.status="all";s.query="";s.offset=0;s.indexScroll=0
                    m.search:SetText("");c:Refresh()
                end)
                clear:SetResponse(MenuResponse.Refresh)
            end)
        end)
        m.filters.ResetFilters=function()
            local s=c:State()
            s.currentZone=false;s.knowledge="all";s.source="all";s.status="all";s.query="";s.offset=0;s.indexScroll=0
            m.search:SetText("");c:Refresh()
        end
        U.StyleSelection(m.filters)
        m.filters:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Filter fishing records\nRight-click to reset filters.");GameTooltip:Show() end
        end)
        m.filters:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        m.count=ns.FieldbookUI.EntryCount(m);m.rows={}
        m.list,m.listBody=U.Scroll(m,42,-180,228,LIST_HEIGHT)
        U.ContactListFades(m.list,shell,m,42,-180)
        m.list:HookScript("OnVerticalScroll",function(self,value)
            if not m.updatingList then c:State().indexScroll=value or self:GetVerticalScroll();c:Refresh() end
        end)
        local function scrollList(_,delta)
            m.list:SetVerticalScroll(math.max(0,math.min(m.listBody:GetHeight()-LIST_HEIGHT,m.list:GetVerticalScroll()-delta*ROW_HEIGHT)))
        end
        m.list:EnableMouseWheel(true);m.list:SetScript("OnMouseWheel",scrollList)
        for i=1,VISIBLE_ROWS do
            local row=CreateFrame("Button",nil,m.listBody,"BackdropTemplate");row:SetPoint("TOPLEFT",0,-(i-1)*ROW_HEIGHT);row:SetSize(228,37)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",scrollList)
            ns.FieldbookUI.StyleMenuRow(row)
            row.divider=ns.FieldbookUI.EntryDivider(row,1,228)
            for _,line in ipairs(row.divider) do line:SetShown(i>1) end
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",7,-10);row.icon:SetSize(20,20)
            row.name=U.Label(row,"",32,-6,189,"GameFontHighlightSmall");row.name:SetWordWrap(false)
            local rowTitlePath,rowTitleSize,rowTitleFlags=row.name:GetFont()
            if rowTitlePath and rowTitleSize then row.name:SetFont(rowTitlePath,rowTitleSize+2,rowTitleFlags) end
            row.zone=U.Label(row,"",32,-21,189,"GameFontDisableSmall");row.zone:SetWordWrap(false)
            row:SetScript("OnClick",function(self) c:Select(self.id) end)
            row:SetScript("OnEnter",function(self)
                showEntryTooltip(self,journal:Get(self.id))
            end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);m.rows[i]=row
        end
        m.empty=U.Label(m,"",50,-195,233,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(4)
        m.remember=U.Button(m,"Remember spot",342,-60,145,function() c:OpenForm("spot") end)
        m.sighting=U.Button(m,"Pool sighting",493,-60,136,function() c:OpenForm("sighting") end)
        m.manual=U.Button(m,"Record catch",794,-174,128,function() c:OpenForm("catch") end)
        m.reports=U.ShareButton(m,function() c:OpenReports() end)
        m.deleteButton=U.Button(m,"Delete",174,-672,118,function()
            local e=c:SelectedEntry()
            if not m:IsVisible() or c.activePanel or not e or e.removed or journal.readOnly then return end
            local view=state.view
            m.deleteForm=m.deleteForm or ns.FieldbookUI.DeletePanel(m,shell,"Delete fishing entry")
            m.deleteForm:Open("Delete "..A.Safe(e.name).." from this page?\n\nCatch history is preserved. Restore this entry through Filters > Show > Removed.\n\nNew observations can record it again.",function()
                if journal.readOnly or state.view~=view or c:SelectedEntry()~=e or e.removed then
                    return nil,"Selection changed or journal unavailable; nothing deleted."
                end
                local ok,err=journal:SetEntryRemoved(e.id,true)
                if ok then
                    c:State().selected=nil
                    if e.kind~="item" then tracking:ClearSource("Fishing record deleted; session source cleared.") end
                end
                c:Message(ok and "Entry deleted from this page. Restore with Filters > Show > Removed; catch history is preserved." or err)
                c:Refresh();return ok,err
            end)
        end)
        m.zone=U.ZoneMenu(m,342,-174,256,function()
            local ids={c:State().mapID};for _,water in pairs(journal.db.waters) do if water.mapID then ids[#ids+1]=water.mapID end end;return ids
        end,function(id,name)
            local s=c:State();s.mapID,s.mapZone=id,name;m.map:Invalidate();c:Refresh()
        end,function()
            local p=A.Location(A.CurrentLocation());local s=c:State();s.mapID,s.mapZone=p.mapID,p.zone;m.map:Invalidate();c:Refresh()
        end)
        m.session=U.ReadArea(m,342,-125,580,41)
        m.session.text:SetJustifyH("LEFT")
        m.assign=U.Button(m,"Assign selected pool",342,-91,172,function()
            local e=journal:Get(c:State().selected);local source=e and e.kind=="spot" and not e.poolID and "unclassified" or "pool"
            local ok,err=tracking:Assign(source,c:State().selected);c:Message(ok and tracking.status or err);c:Refresh()
        end)
        m.open=U.Button(m,"Assign open water",520,-91,162,function() local ok,err=tracking:Assign("open",c:State().selected);c:Message(ok and tracking.status or err);c:Refresh() end)
        m.clear=U.Button(m,"Clear session source",688,-91,234,function() tracking:ClearSource();c:Message(tracking.status);c:Refresh() end)
        m.map=ns.CreateAnglingMap(m,journal,function(id) c:Select(id) end,function() return c:Filters() end,function(id,name)
            local s=c:State();s.mapID,s.mapZone=id,name;m.map:Invalidate();c:Refresh()
        end)
        -- Exactly AtlasBook's parent-relative anchor and footer geometry. The
        -- renderer uses 578*.99 by 302*1.25*.99, aspect fits and crops edge tiles.
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.notesOverlay=CreateFrame("Frame",nil,m)
        m.notesOverlay:SetSize(580,113);m.notesOverlay:SetFrameLevel(m:GetFrameLevel()+30)
        m.notesPaper=m.notesOverlay:CreateTexture(nil,"BACKGROUND")
        m.notesPaper:SetPoint("TOPLEFT",m.notesOverlay,"TOPLEFT",-10,4)
        m.notesPaper:SetPoint("BOTTOMRIGHT",m.notesOverlay,"BOTTOMRIGHT",10,-6)
        m.notesPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png");m.notesPaper:SetDesaturated(true)
        shell:AddBackgroundLayer(m.notesPaper,0.17,0.17,0.17,true)
        for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
            local border=m.notesOverlay:CreateTexture(nil,"OVERLAY")
            border:SetColorTexture(unpack(U.DetailGold))
            border:SetPoint(edge[1],m.notesPaper,edge[1]);border:SetPoint(edge[2],m.notesPaper,edge[2])
            if edge[3] then border:SetHeight(1) else border:SetWidth(1) end
        end
        m.heading=U.Label(m.notesOverlay,"",0,-33,580,"GameFontNormalSmall");m.heading:SetWordWrap(false)
        m.heading:SetShadowColor(0,0,0,0.85);m.heading:SetShadowOffset(1,-1)
        m.details,m.detailBody=U.ReadArea(m.notesOverlay,0,-52,555,61)
        m.details:HookScript("OnVerticalScroll",function(self,value) c:State().detailScroll=value or self:GetVerticalScroll() end)
        m.locations=U.Button(m.notesOverlay,"Sources / spots",0,0,126,function() c:OpenLinks("locations") end)
        m.catches=U.Button(m.notesOverlay,"Catches",132,0,88,function() c:OpenLinks("items") end)
        m.notes=U.Button(m.notesOverlay,"Notes / edit",226,0,106,function() c:OpenForm("edit",c:State().selected) end)
        m.favourite=U.Button(m.notesOverlay,"Favourite",338,0,106,function()
            local e=journal:Get(c:State().selected);if e then journal:Edit(e.id,e.name,e.note,not e.favourite);c:Refresh() end
        end)
        m.expand=U.Button(m.notesOverlay,"",450,0,22,function() c:Expand() end);m.expand:SetSize(22,22)
        m.expand:ClearAllPoints();m.expand:SetPoint("TOPRIGHT",m.notesPaper,"TOPRIGHT",-4,-4)
        U.StyleSelection(m.expand)
        m.notesArrow={}
        for row=0,4 do
            local stroke=m.expand:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-row*2,1);stroke:SetPoint("CENTER",0,row-2);stroke:SetColorTexture(1,0.82,0.14,1)
            m.notesArrow[#m.notesArrow+1]=stroke
        end
        m.expand:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(m.notesExpanded and "Collapse notes" or "Expand notes");GameTooltip:Show() end
        end)
        m.expand:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        U.AlignFooterScrollBar(m.details,m.notesPaper,m.expand)
        U.FooterFades(m.details,shell,56)
        c:LayoutDetails(0)
        m.merge=U.Button(m,"Merge spot",42,-638,120,function()
            local e=c:SelectedEntry()
            if state.view=="waters" and e and e.kind=="spot" and not e.removed and not journal.readOnly then c:OpenLinks("merge") end
        end)
        m.restore=U.Button(m,"Restore",174,-638,118,function()
            local e=c:SelectedEntry();if not e or journal.readOnly then return end
            if e.removed then
                local ok,err=journal:SetEntryRemoved(e.id,false)
                if ok then c:State().selected=nil end
                c:Message(ok and "Fishing record restored." or err);c:Refresh()
            end
        end)
        m.entryButtons={m.locations,m.catches,m.notes,m.favourite}
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall");m.message:SetWordWrap(false)
        c.eventLog=ns.CreateAnglingEventLog(journal,shell)
        shell:SetSectionPages("angling",{eventLog=c.eventLog})
        content:SetScript("OnHide",function()
            m.notesOverlay:SetScript("OnUpdate",nil);c:LayoutDetails(m.notesExpanded and 1 or 0)
            c:State().detailScroll=m.details:GetVerticalScroll();m.map:SuspendPlayer();m.search:ClearFocus()
            for _,p in pairs(c.panels) do for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
            if GameTooltip then GameTooltip:Hide() end
        end)
        local p=A.Location(A.CurrentLocation());local s=c:State();if not s.mapID then s.mapID,s.mapZone=p.mapID,p.zone end
        c:Refresh();m.details:SetVerticalScroll(s.detailScroll or 0)
        if journal.readOnly then c:Message("Newer Almanac schema: read-only; saved data is untouched.") end
    end
    shell:RegisterSection("angling",{title="Angler’s Almanac",icon="Interface\\Icons\\Trade_Fishing",frameName="AzerothFieldbookAnglingSection",build=build,
        help=A.VISION.."\n\n|cffffd100Waters, Pool Types, Catches|r\nBrowse fishing places under Waters, known pools under Pool Types, or items under Catches. Search names, zones and notes, and use the funnel beside search to narrow the list. Sources / spots shows where a selected catch was recorded; map pins select remembered places.\n\n"..
            "|cffffd100Fishing observations|r\nCollected, readable fishing loot records automatically, even with the Almanac closed. Catches with no assigned source stay unclassified. Assign selected pool and Assign open water label future catches with your chosen session source; that choice is your assertion, not automatic identification. Movement, zone changes, other casts or a long pause clear the assignment.\n\n"..
            "|cffffd100Discovery and deletion|r\nHover a recognizable pool tooltip to record a zone sighting. This adds no coordinates and does not assign catches to that pool. Use Pool sighting if the tooltip is not recognized. Delete beside Share hides the selected entry on the current page. A new observation can rediscover it immediately; deletion never blacklists a record. Choose Filters > Show > Removed, select the entry and use Restore to bring it back manually. Catch history is retained for all deleted entries.\n\n"..
            "|cffffd100Remembering and correcting|r\nRemember spot and Pool sighting save your approximate player position, not the exact pool location. Notes / edit saves notes and can rename remembered spots. Merge spot below the Waters list combines duplicate spots in the same waters and pool type, preserving their notes and history.\n\n"..
            "|cffffd100Fallback and skill|r\nUse Record catch only for a catch missing from automatic history. It adds a player-recorded catch event; do not enter the same catch twice. Item quantities and catch-event counts are different. Recorded skill successes show what worked on that occasion, not a minimum skill requirement.\n\n"..
            "|cffffd100Event log|r\nEvent log in the title bar shows catches, fishing failures, discoveries and corrections. Clear log, then Confirm clear, removes the log without deleting fishing knowledge.\n\n"..
            "|cffffd100Share|r\nSelect a record, open Share and use Prepare selected knowledge to create text for copying. Notes start excluded. To import, paste the data, click Preview, then Accept report. Imported claims stay Reported and do not increase personal catch totals. Choose Filters > Knowledge > Reported to forward received claims; source names are not verified. Reports are exchanged by copy and paste.\n\n"..
            "|cffffd100Your journal|r\nAlmanac records, the Event log and browsing settings follow Account-wide tracking in Options. It starts on; turn it off to use this character's separate journal after /reload.",
        onOpen=function() if c.main then c.main.map:Invalidate();c:Refresh();c.main.details:SetVerticalScroll(c:State().detailScroll or 0) end end})
    local function refresh() if c.main and shell.active=="angling" and shell:GetFrame():IsShown() then c:Refresh() end end
    journal.onChange=refresh;tracking.onChange=function() c.message=nil;refresh() end
    return c
end
function ns.InitializeAngling(shell)
    if type(AzerothFieldbookAnglingDB)~="table" then AzerothFieldbookAnglingDB={} end
    local storage=ns.SelectSectionStorage and ns.SelectSectionStorage("angling",AzerothFieldbookAnglingDB) or AzerothFieldbookAnglingDB
    local journal=ns.CreateAnglingJournal(storage)
    local tracking=ns.CreateAnglingTracking(journal)
    return ns.CreateAnglingBook(journal,tracking,shell)
end
