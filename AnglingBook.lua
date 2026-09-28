local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A,U,R=ns.Angling,ns.AtlasUI,ns.AnglingReports
local PAGE_SIZE=9
local function cycle(value,values)
    for i,v in ipairs(values) do if value==v then return values[i%#values+1] end end;return values[1]
end
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
    function c:State() return journal:View(state.view) end
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
        paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga");paper:SetDesaturated(true)
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
        if found then s.offset=math.floor((found-1)/PAGE_SIZE)*PAGE_SIZE end
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
                    (item and " — "..item.name or "")..(focus.origin and " (Reported)" or "")
            end
        end
        if e.note~="" then lines[#lines+1]="Your notes: "..e.note end
        for _,id in ipairs(e.mergedFrom or {}) do local old=journal.db.merged[id];if old then
            lines[#lines+1]="Merged spot: "..old.name.." • "..A.PositionLabel(old)..(old.note~="" and "\nPreserved note: "..old.note or "")
        end end
        if summary.events==0 then
            lines[#lines+1]=e.kind=="pool" and "No catches recorded from this pool type." or "No personal catches recorded here."
        else
            lines[#lines+1]=e.kind=="item" and (summary.events.." obtained events across this item's recorded sources ("..summary.recordedEvents.." player-recorded).")
                or (summary.events.." personal catch events ("..summary.recordedEvents.." player-recorded); "..A.Count(summary.items).." different items recorded.")
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
            local provenance=row.reported and ("Reported by "..fact.origin.source.." (not authenticated)") or (fact.method=="recorded" and "Player-recorded catches" or "Personally observed catches")
            lines[#lines+1]="\n"..w.name.." • "..A.SourceLabels[fact.source]..(fact.poolID and ": "..journal:Get(fact.poolID).name or "")
            lines[#lines+1]=provenance.."; source association: "..fact.association..". "..fact.events.." catch events."
            if fact.lastPosition then lines[#lines+1]="Latest "..A.PositionLabel(fact.lastPosition) end
            local localItems={};for id,value in pairs(fact.items) do localItems[#localItems+1]=journal:Get(id).name.." ×"..value.quantity.." ("..value.occurrences.." events)" end
            table.sort(localItems);lines[#lines+1]=table.concat(localItems,", ")
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
    function c:Refresh()
        if not self.main or self.refreshing then return end;self.refreshing=true
        local m,s=self.main,self:State();local rows=journal:List(state.view,self:Filters())
        s.offset=math.min(s.offset,math.floor(math.max(0,#rows-1)/PAGE_SIZE)*PAGE_SIZE)
        for i,row in ipairs(m.rows) do
            local e=rows[s.offset+i];row.id=e and e.id;row:SetShown(e~=nil)
            if e then
                row.name:SetText((e.favourite and U.SavedIcon(true) or "")..A.Safe(e.name));row.selected:SetShown(e.id==s.selected)
                row.zone:SetText((e.personal and "Personal" or "Reported").." • "..(e.kind=="spot" and (e.hover and "Pool zone sighting" or e.poolID and "Pool sighting" or "Remembered spot") or e.kind))
                row.icon:SetTexture(e.kind=="item" and itemIcon(e) or "Interface\\Icons\\Trade_Fishing")
            end
        end
        m.count:SetText(#rows.." recorded "..(state.view=="catches" and "items" or state.view=="pools" and "pool types" or "waters & spots"))
        m.empty:SetShown(#rows==0);m.empty:SetText("No matching fishing knowledge.\n\nRemember a spot, record a sighting, or catch something to begin.")
        m.previous:SetEnabled(s.offset>0);m.next:SetEnabled(s.offset+PAGE_SIZE<#rows)
        m.scope:SetText(s.currentZone and "Current zone" or "All recorded zones")
        m.knowledge:SetText("Knowledge: "..s.knowledge);m.source:SetText("Source: "..(A.SourceLabels[s.source] or "all"))
        m.status:SetText(s.status=="fished" and "With recorded catches" or s.status=="unfished" and "No catches recorded" or "Show: "..s.status)
        for key,b in pairs(m.views) do b:SetEnabled(key~=state.view) end
        local e=journal:Get(s.selected)
        if not tracking.observingHover then m.map:Render(s.mapID,s.selected) end
        m.zone:SetText(A.Safe(s.mapZone or "Choose zone"));m.session:SetText(A.Safe(tracking:SessionText()))
        m.heading:SetText(e and A.Safe(e.name) or "Your fishing field notes")
        m.details:SetText(table.concat(self:Details(e),"\n"))
        for _,b in ipairs(m.entryButtons) do b:SetEnabled(e~=nil) end
        m.merge:SetEnabled(e~=nil and ((e.kind=="spot" and not e.removed) or e.kind=="pool") and not journal.readOnly)
        m.merge:SetText(e and e.kind=="pool" and (e.removed and "Restore pool" or "Remove pool") or "Merge spot")
        m.removeSighting:SetShown(e~=nil and e.kind=="spot")
        m.removeSighting:SetEnabled(not journal.readOnly)
        m.removeSighting:SetText(e and e.removed and (e.poolID and "Restore sighting" or "Restore spot") or (e and e.poolID and "Remove sighting" or "Remove spot"))
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
                p.preview:SetText(ticket and ticket.preview or err,true);p.accept:SetEnabled(ticket~=nil and not journal.readOnly)
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
        local spine=m:CreateTexture(nil,"ARTWORK");spine:SetColorTexture(0.25,0.13,0.055,0.35);spine:SetPoint("TOPLEFT",306,-53);spine:SetSize(3,661)
        U.Label(m,"Angler’s Almanac",42,-60,260,"GameFontNormalLarge")
        m.views={}
        for i,view in ipairs({"waters","pools","catches"}) do
            local key=view;m.views[key]=U.Button(m,({waters="Waters",pools="Pool Types",catches="Catches"})[key],42+(i-1)*84,-94,82,function() c:SetView(key) end)
        end
        m.search=U.Edit(m,48,-126,240,200);m.search:SetText(c:State().query)
        m.search:SetScript("OnTextChanged",function() if not c.rendering then local s=c:State();s.query=m.search:GetText();s.offset=0;c:Refresh() end end)
        local function filter(key,values)
            return function() local s=c:State();s[key]=cycle(s[key],values);s.offset=0;c:Refresh() end
        end
        m.scope=U.Button(m,"",42,-157,250,function() local s=c:State();s.currentZone=not s.currentZone;s.offset=0;c:Refresh() end)
        m.knowledge=U.Button(m,"",42,-186,250,filter("knowledge",{"all","personal","reported"}))
        m.source=U.Button(m,"",42,-215,250,filter("source",{"all","pool","open","unclassified"}))
        m.status=U.Button(m,"",42,-244,250,function()
            filter("status",state.view~="catches" and {"all","fished","unfished","favourites","removed"}
                or {"all","fished","unfished","favourites"})()
        end)
        m.count=U.Label(m,"",42,-277,250,"GameFontHighlightSmall");m.rows={}
        for i=1,PAGE_SIZE do
            local row=CreateFrame("Button",nil,m,"BackdropTemplate");row:SetPoint("TOPLEFT",42,-300-(i-1)*30);row:SetSize(250,29)
            row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            row.selected=row:CreateTexture(nil,"BACKGROUND");row.selected:SetAllPoints();row.selected:SetColorTexture(0.95,0.7,0.15,0.18)
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",3,-6);row.icon:SetSize(20,20)
            row.name=U.Label(row,"",28,-2,217,"GameFontHighlightSmall");row.name:SetWordWrap(false)
            row.zone=U.Label(row,"",28,-17,217,"GameFontDisableSmall");row.zone:SetWordWrap(false)
            row:SetScript("OnClick",function(self) c:Select(self.id) end)
            row:SetScript("OnEnter",function(self)
                showEntryTooltip(self,journal:Get(self.id))
            end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);m.rows[i]=row
        end
        m.empty=U.Label(m,"",50,-315,233,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(4)
        m.previous=U.Button(m,"Previous",42,-574,118,function() local s=c:State();s.offset=math.max(0,s.offset-PAGE_SIZE);c:Refresh() end)
        m.next=U.Button(m,"Next",174,-574,118,function() local s=c:State();s.offset=s.offset+PAGE_SIZE;c:Refresh() end)
        U.Label(m,"Waters & Spots remembers places.\nPool Types and Catches follow the same observations.",42,-615,250,"GameFontHighlightSmall")
        m.remember=U.Button(m,"Remember spot",342,-58,145,function() c:OpenForm("spot") end)
        m.sighting=U.Button(m,"Pool sighting",493,-58,136,function() c:OpenForm("sighting") end)
        m.manual=U.Button(m,"Record catch",794,-91,128,function() c:OpenForm("catch") end)
        m.reports=U.Button(m,"Reports",635,-58,153,function() c:OpenReports() end)
        m.zone=U.ZoneMenu(m,342,-91,306,function()
            local ids={c:State().mapID};for _,water in pairs(journal.db.waters) do if water.mapID then ids[#ids+1]=water.mapID end end;return ids
        end,function(id,name)
            local s=c:State();s.mapID,s.mapZone=id,name;m.map:Invalidate();c:Refresh()
        end)
        m.current=U.Button(m,"Current Zone",794,-58,128,function()
            local p=A.Location(A.CurrentLocation());local s=c:State();s.mapID,s.mapZone=p.mapID,p.zone;m.map:Invalidate();c:Refresh()
        end)
        m.session=U.ReadArea(m,342,-125,555,41)
        m.assign=U.Button(m,"Assign selected pool",342,-174,172,function()
            local e=journal:Get(c:State().selected);local source=e and e.kind=="spot" and not e.poolID and "unclassified" or "pool"
            local ok,err=tracking:Assign(source,c:State().selected);c:Message(ok and tracking.status or err);c:Refresh()
        end)
        m.open=U.Button(m,"Assign open water",520,-174,162,function() local ok,err=tracking:Assign("open",c:State().selected);c:Message(ok and tracking.status or err);c:Refresh() end)
        m.clear=U.Button(m,"Clear session source",688,-174,234,function() tracking:ClearSource();c:Message(tracking.status);c:Refresh() end)
        m.map=ns.CreateAnglingMap(m,journal,function(id) c:Select(id) end,function() return c:Filters() end,function(id,name)
            local s=c:State();s.mapID,s.mapZone=id,name;m.map:Invalidate();c:Refresh()
        end)
        -- Exactly AtlasBook's parent-relative anchor and footer geometry. The
        -- renderer uses 578*.99 by 302*1.25*.99, aspect fits and crops edge tiles.
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.heading=U.Label(m,"",342,-587,580,"GameFontNormalSmall");m.heading:SetWordWrap(false)
        m.details=U.ReadArea(m,342,-606,555,64)
        m.details:HookScript("OnVerticalScroll",function(self,value) c:State().detailScroll=value or self:GetVerticalScroll() end)
        m.locations=U.Button(m,"Sources / spots",342,-680,126,function() c:OpenLinks("locations") end)
        m.catches=U.Button(m,"Catches",474,-680,88,function() c:OpenLinks("items") end)
        m.notes=U.Button(m,"Notes / edit",568,-680,106,function() c:OpenForm("edit",c:State().selected) end)
        m.favourite=U.Button(m,"Favourite",680,-680,106,function()
            local e=journal:Get(c:State().selected);if e then journal:Edit(e.id,e.name,e.note,not e.favourite);c:Refresh() end
        end)
        m.merge=U.Button(m,"Merge spot",792,-680,130,function()
            local e=journal:Get(c:State().selected)
            if e and e.kind=="pool" then
                local removed=not e.removed;c:State().selected=nil
                if removed then tracking:ClearSource("Pool removed; session source cleared.") end
                local ok,err=journal:SetPoolRemoved(e.id,removed)
                c:Message(ok and (removed and "Pool removed from the list; automatic re-addition suppressed. Restore with Show: removed. Catch history is preserved."
                    or "Pool restored.") or err);c:Refresh()
            else c:OpenLinks("merge") end
        end)
        m.removeSighting=U.Button(m,"Remove sighting",42,-680,250,function()
            local e=journal:Get(c:State().selected)
            if not e or e.kind~="spot" then return end
            local removed=not e.removed;c:State().selected=nil
            if removed then tracking:ClearSource("Sighting removed; session source cleared.") end
            local ok,err=journal:SetSightingRemoved(e.id,removed)
            c:Message(ok and (removed and "Sighting removed. Restore it with Show: removed; catch history is preserved." or "Sighting restored.") or err)
            c:Refresh()
        end)
        m.entryButtons={m.locations,m.catches,m.notes,m.favourite}
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall");m.message:SetWordWrap(false)
        c.eventLog=ns.CreateAnglingEventLog(journal,shell)
        shell:SetSectionPages("angling",{eventLog=c.eventLog})
        content:SetScript("OnHide",function()
            c:State().detailScroll=m.details:GetVerticalScroll();m.map:SuspendPlayer();m.search:ClearFocus()
            for _,p in pairs(c.panels) do for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
            if GameTooltip then GameTooltip:Hide() end
        end)
        local p=A.Location(A.CurrentLocation());local s=c:State();if not s.mapID then s.mapID,s.mapZone=p.mapID,p.zone end
        c:Refresh();m.details:SetVerticalScroll(s.detailScroll or 0)
        if journal.readOnly then c:Message("Newer Almanac schema: read-only; saved data is untouched.") end
    end
    shell:RegisterSection("angling",{title="Angler’s Almanac",icon="Interface\\Icons\\Trade_Fishing",frameName="AzerothFieldbookAnglingSection",build=build,
        help=A.VISION.."\n\n|cffffd100Waters & Spots, Pool Types, Catches|r\nThese browse the same personal observations. Search names, zones, subzones and notes. Click the compact filter buttons to cycle options. Sources / spots supports reverse lookup; click a remembered pin to select its record.\n\n"..
            "|cffffd100Fishing observations|r\nReadable fishing loot records obtained item slots, even when this page is closed or the client cast ID is unavailable. Uncertain sources stay unclassified. Assign selected pool or Assign open water is your assertion for the current session. Movement, zone changes, other casts, five minutes idle and reload clear that assignment. No confirmation is needed per fish.\n\n"..
            "|cffffd100Pool discovery and removal|r\nRecognizable world-object pool tooltips add a zone sighting without coordinates or catch attribution. Select a pool type and Remove pool to hide it and suppress automatic re-addition. Show: removed and Restore pool undo this; notes and catch history are preserved. Unrecognized tooltips can still be recorded with Pool sighting.\n\n"..
            "|cffffd100Remembering and correcting|r\nRemember spot and Pool sighting capture your player position, labelled approximate. They never reveal unknown pool contents. Notes / edit saves your notes. Merge spot explicitly combines duplicate spots in the same waters/pool, preserving their notes, original positions and history.\n\n"..
            "|cffffd100Fallback and skill|r\nRecord catch adds one explicitly player-recorded event when automatic capture was unavailable. Do not re-enter catches already recorded. Quantities and event counts differ. Skill successes are measured evidence, never a minimum requirement; equipment and lure contributions stay unknown when unreadable.\n\n"..
            "|cffffd100Event log|r\nThe title-bar Event log button opens the active journal’s ongoing Almanac history: catches, failed fishing attempts, discoveries, corrections and source changes. Events remain until you clear the log. Catch quantities update one row as slots are collected. Clear log requires a second click and does not delete fishing knowledge.\n\n"..
            "|cffffd100Reports|r\nReports prepares selected knowledge, with notes excluded unless selected. Choose Reported knowledge to forward original claims. Paste data, Preview, then Accept to store visibly reported claims. Source names are not authenticated. Personal counts, notes and skill records are unchanged. No addon-message transport, report price or reward is implemented.\n\n"..
            "Almanac data and browsing state follow the global Account-wide tracking option, outside other sections’ resets and sharing. Detailed history is bounded to 200 events and 32 sessions; totals persist.",
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
