local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A,U=ns.Atlas,ns.AtlasUI
function ns.InstallAtlasEditors(c)
    local j=c.journal
    local entries=c.entries or j
    local function main() c:Show();c:Refresh() end
    local function locationFields(p,x,y,width)
        p.mapID=U.Field(p,"Map ID (optional)",x,y,140,10)
        p.zone=U.Field(p,"Observed zone label",x+160,y,width-160,160)
        p.subzone=U.Field(p,"Subzone (optional)",x,y-59,width-260,160)
        p.x=U.Field(p,"X: 0–100",x+width-240,y-59,105,16)
        p.y=U.Field(p,"Y: 0–100",x+width-115,y-59,105,16)
    end
    local function fillLocation(p,d)
        for _,k in ipairs({"mapID","zone","subzone"}) do p[k]:SetText(d[k] or "") end
        p.x:SetText(d.x and string.format("%.2f",d.x/100) or "");p.y:SetText(d.y and string.format("%.2f",d.y/100) or "")
    end
    local function readLocation(p,d)
        local x,y,err=A.Coordinates(p.x:GetText(),p.y:GetText());if err then return nil,err end
        local raw=p.mapID:GetText();local id=raw~="" and tonumber(raw) or nil
        if raw~="" and not A.Integer(id,1,2147483647) then return nil,"Map ID must be a positive integer." end
        d.mapID,d.zone,d.subzone,d.x,d.y=id,p.zone:GetText(),p.subzone:GetText(),x,y
        local valid,e=A.Location(d);if not valid then return nil,e end;return d
    end
    function c:ClearFocus()
        for _,panel in pairs(self.pages) do
            for _,control in ipairs(panel.inputs or {}) do control:ClearFocus() end
            if panel.search then panel.search:ClearFocus() end
        end
    end
    function c:PlaceOnMap(callback,returnView)
        if self.main.map.microMapID then
            returnView.message:SetText("Return to the zone map before choosing an exterior position.");return
        end
        if not self.main.map.available or not j.state.mapID then
            returnView.message:SetText("Map artwork unavailable. Enter a map ID and coordinates, or save without a position.");return
        end
        self.placeReturn=returnView;self.placeCallback=callback;self.main.map.placing=true
        if self.main.microMap then self.main.microMap:SetEnabled(false) end
        self:UpdatePositionButton();self:Show()
        self:Message("Click the displayed map to choose a position. This is not your current position.")
    end
    function c:ChoosePosition()
        local p=self.editor;local d,err=p:Capture()
        if not d then p.message:SetText(err);return end
        self:PlaceOnMap(function(x,y,mapID,zone)
            d.x,d.y,d.mapID,d.zone,d.subzone=x,y,mapID,zone,""
            p.draft=d;p:Fill();p.message:SetText("Position selected on the displayed map. Save to keep it.")
            c:UpdatePositionButton();c:Show(p)
        end,p)
    end
    function c:OpenEditor(id,expedition,initial)
        local p=self.editor
        if not p then
            p=U.Panel(self.frame,self.shell,"Discovery",main);self.editor=p;self.pages.editor=p
            p.scroll,p.body=U.Scroll(p,24,-57,810,498);p.body:SetHeight(1010)
            local b=p.body
            p.name=U.Field(b,"Name / title",0,-4,520,160)
            p.category=U.MenuButton(b,"",540,-25,255,function()
                p.categoryMenu:SetShown(not p.categoryMenu:IsShown())
            end)
            p.categoryMenu=CreateFrame("Frame",nil,p,"BackdropTemplate")
            local menu=p.categoryMenu
            menu:SetPoint("TOPLEFT",p.category,"BOTTOMLEFT",0,-2);menu:SetSize(255,250)
            menu:SetFrameLevel(p:GetFrameLevel()+40);menu:EnableMouse(true)
            menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
            menu:SetBackdropColor(0.055,0.04,0.022,1)
            menu.rows={}
            local choices={};for _,v in ipairs(A.categories) do choices[#choices+1]=v end
            choices[#choices+1]=ns.AtlasEntrances.generic
            for i,v in ipairs(choices) do
                local choice=v
                local row=U.Button(menu,v.label,8,-8-(i-1)*26,239,function()
                    local d,err=p:Capture();if not d then p.message:SetText(err);return end
                    d.category=choice.id
                    if d.entrance then d.confirmCategory=choice.id;d.classification={kind="player",category=choice.id} end
                    p.draft=d;p:Fill();menu:Hide()
                end)
                row.categoryID=v.id;menu.rows[i]=row
            end
            menu:SetScript("OnShow",function()
                local d=p.draft
                for _,row in ipairs(menu.rows) do
                    row:SetShown(row.categoryID~="entrance" or d.entrance~=nil)
                end
                menu:SetHeight(16+(#A.categories+(d.entrance and 1 or 0))*26)
            end)
            p:HookScript("OnHide",function() menu:Hide() end)
            menu:Hide()
            p.date=U.Label(b,"",540,-7,260,"GameFontHighlightSmall")
            p.explored=U.Check(b,"Explored — explicitly marked by me",0,-65,360,function() end)
            p.locationHint=U.Label(b,"",0,-100,800,"GameFontHighlightSmall");p.locationHint:SetWordWrap(true)
            p.location=CreateFrame("Frame",nil,b);p.location:SetPoint("TOPLEFT",0,-140);p.location:SetSize(800,115)
            locationFields(p.location,0,0,800)
            p.current=U.Button(b,"Use my current position",4,-262,232,function()
                local d,err=p:Capture();if not d then p.message:SetText(err);return end
                local loc=A.CurrentLocation()
                if d.entrance then
                    local sample=ns.AtlasEnvironment.Capture()
                    if not sample or sample.inside or sample.position.mapID~=d.mapID then
                        p.message:SetText("Use a valid outdoor position on this entrance's exterior zone map.");return
                    end
                    loc={mapID=sample.position.mapID,x=sample.position.x,y=sample.position.y,zone=d.zone,subzone=d.subzone}
                end
                for _,key in ipairs({"mapID","zone","subzone","x","y"}) do d[key]=loc[key] end
                p.draft=d;p:Fill();p.message:SetText(A.Position(loc) and "Captured your current position. Check that this is the entrance before saving." or "Position unavailable. No coordinates were substituted; save an unpositioned entry.")
            end)
            p.mapPick=U.Button(b,"Choose on displayed map",247,-262,236,function() c:ChoosePosition() end)
            p.zones=U.Button(b,"Expedition zones",498,-262,294,function()
                local d,err=p:Capture();if not d then p.message:SetText(err);return end
                c:PickZone(function(z)
                    local found
                    for i,v in ipairs(d.zones) do if v.mapID==z.mapID then table.remove(d.zones,i);found=true;break end end
                    if not found then d.zones[#d.zones+1]={mapID=z.mapID,zone=z.zone} end
                    p.draft=d;p:Fill();c:Show(p)
                end,function() c:Show(p) end)
            end)
            p.zoneList=U.ReadArea(b,0,-301,772,66)
            p.notesLabel=U.Label(b,"Personal notes / expedition journal (private)",0,-378,800,"GameFontNormal")
            p.notes,p.noteScroll=U.TextArea(b,4,-403,772,166,8000)
            p.accessLabel=U.Label(b,"Approach / access notes (private)",0,-589,790,"GameFontNormal")
            p.access,p.accessScroll=U.TextArea(b,4,-614,772,125,8000)
            p.interior=U.Field(b,"Cave interior / subzone label (optional)",0,-764,510,160)
            p.interiorMapID=U.Field(b,"Interior map ID (optional)",535,-764,250,10)
            p.caveHint=U.Label(b,"Caves use the entrance as their navigational location. Interior labels do not imply an entrance or a connection.",0,-827,790,"GameFontHighlightSmall")
            p.caveHint:SetWordWrap(true)
            p.source=U.Label(b,"",0,-884,790,"GameFontHighlightSmall");p.source:SetWordWrap(true)
            p.save=U.Button(p,"Save",24,-574,110,function()
                local saved,err=p:Save();if not saved then p.message:SetText(err);return end
                if p.expedition then c:Expeditions() else main();c:Select(saved) end
            end)
            p.links=U.Button(p,"Save & connections",144,-574,188,function()
                local saved,err=p:Save();if not saved then p.message:SetText(err);return end
                c:Connections(saved,p.expedition)
            end)
            p.stops=U.Button(p,"Save & route stops",342,-574,186,function()
                local saved,err=p:Save();if not saved then p.message:SetText(err);return end;c:Stops(saved)
            end)
            p.delete=U.Button(p,"Delete",742,-574,108,function()
                local id,expedition=p.id,p.expedition
                local store=expedition and j.expeditions or j.records
                local entry=store[id];if not entry then return end
                p.deleteForm=p.deleteForm or ns.FieldbookUI.DeletePanel(p,c.shell,"Delete Atlas entry")
                p.deleteForm:Open("Delete "..A.Safe(p.draft.name).."?\n\nThis cannot be undone. Related entries and source-section records are preserved.\n\nLinks in routes, expeditions and report drafts remain unresolved.",function()
                    if p.id~=id or p.expedition~=expedition or store[id]~=entry then return nil,"Selection changed; nothing deleted." end
                    local ok=j:Delete(id,expedition);if ok then main() end
                    return ok,"Could not delete this entry."
                end)
            end)
            p.inputs={p.name,p.notes,p.access,p.interior,p.interiorMapID}
            for _,key in ipairs({"mapID","zone","subzone","x","y"}) do p.inputs[#p.inputs+1]=p.location[key] end
            function p:Capture()
                local d=A.Copy(self.draft);d.name=self.name:GetText();d.notes=self.notes:GetText()
                if not self.expedition then
                    local ok,err=readLocation(self.location,d);if not ok then return nil,err end
                    d.explored=self.explored:GetChecked()==true;d.access=self.access:GetText();d.interior=self.interior:GetText()
                    local raw=self.interiorMapID:GetText();d.interiorMapID=raw~="" and tonumber(raw) or nil
                    if raw~="" and not A.Integer(d.interiorMapID,1,2147483647) then return nil,"Invalid interior map ID." end
                end
                return d
            end
            function p:Save()
                local d,err=self:Capture();if not d then return nil,err end
                local id,e=entries:Save(d,self.id,self.expedition)
                if id then self.id=id;self.draft=entries:Get(id,self.expedition);self:Fill();c:Refresh() end
                return id,e
            end
            function p:Fill()
                local d=self.draft
                self.title:SetText(self.expedition and "Expedition note" or "Discovery / entrance")
                self.name:SetText(d.name or "");self.notes:SetText(d.notes or "");self.access:SetText(d.access or "")
                self.interior:SetText(d.interior or "");self.interiorMapID:SetText(d.interiorMapID or "")
                fillLocation(self.location,d);self.explored:SetChecked(d.explored==true)
                local category=A.category[d.category or "other"] or ns.AtlasEntrances.Category(d.category)
                self.category:SetText(category.label)
                self.category:SetShown(not self.expedition);self.explored:SetShown(not self.expedition)
                self.location:SetShown(not self.expedition);self.current:SetShown(not self.expedition);self.mapPick:SetShown(not self.expedition)
                self.zones:SetShown(self.expedition==true);self.date:SetText(self.id and U.Date(d.created) or "Date set when saved")
                self.locationHint:SetText(self.expedition and "An expedition can connect several zones, places and discoveries. Choose a zone again to remove it."
                    or "Location is map-relative. Leave X and Y blank to save without a position. For caves, record the entrance deliberately.")
                local zones={};for _,z in ipairs(d.zones or {}) do zones[#zones+1]=z.zone.." ("..tostring(z.mapID or "no map")..")" end
                self.zoneList:SetText(self.expedition and ("Zones: "..(#zones>0 and table.concat(zones,", ") or "none selected")) or "Choose on displayed map uses the map you are browsing. Use my current position samples your character.")
                for _,control in ipairs({self.accessLabel,self.accessScroll,self.interior,self.interiorMapID,self.caveHint}) do control:SetShown(not self.expedition) end
                self.interior.fieldLabel:SetShown(not self.expedition);self.interiorMapID.fieldLabel:SetShown(not self.expedition)
                self.source:SetText(self.expedition and "Use Save & connections to link places, routes, creatures and gathering discoveries."
                    or "Knowledge source: "..((d.provenance and d.provenance.kind) or "recorded")..". Saving a location never marks it explored.")
                if d.entrance then
                    local e=d.evidence
                    self.locationHint:SetText("Exterior position only. Map and observed area labels belong to the evidence. Grey ticks are suggestions; choose a category and Save to confirm it in gold.")
                    self.caveHint:SetText("Interior identity and the original exterior anchor are retained as observation evidence. Position edits move only the displayed zone marker.")
                    self.source:SetText(A.AutomaticLabel("Observed entrance",true)..": "..e.entries.." entries / "..e.exits.." exits • "..e.evidence..
                        ". Type: "..d.classification.kind..". Notes never confirm a suggested type. Entrance evidence stays out of legacy field reports.")
                    self.interior:Hide();self.interiorMapID:Hide();self.interior.fieldLabel:Hide();self.interiorMapID.fieldLabel:Hide()
                else self.caveHint:SetText("Caves use the entrance as their navigational location. Interior labels do not imply an entrance or a connection.") end
                -- Give expedition prose room without blank place-only fields.
                self.locationHint:ClearAllPoints();self.locationHint:SetPoint("TOPLEFT",0,self.expedition and -65 or -100)
                self.zones:ClearAllPoints();self.zones:SetPoint("TOPLEFT",self.expedition and 4 or 498,self.expedition and -106 or -262)
                self.zoneList:ClearAllPoints();self.zoneList:SetPoint("TOPLEFT",0,self.expedition and -141 or -301)
                self.notesLabel:ClearAllPoints();self.notesLabel:SetPoint("TOPLEFT",0,self.expedition and -239 or -378)
                self.noteScroll:ClearAllPoints();self.noteScroll:SetPoint("TOPLEFT",4,self.expedition and -264 or -403)
                self.noteScroll:SetHeight(self.expedition and 286 or 166)
                self.source:ClearAllPoints();self.source:SetPoint("TOPLEFT",0,self.expedition and -582 or -884)
                self.body:SetHeight(self.expedition and 646 or 1010)
                self.links:SetEnabled(not d.entrance)
                self.stops:SetShown(not self.expedition and d.category=="route" and not d.entrance);self.delete:SetShown(self.expedition);self.delete:SetEnabled(self.id~=nil)
                self.scroll:UpdateScrollChildRect();self.scroll:RefreshScrollBar()
            end
        end
        local d=id and entries:Get(id,expedition) or initial or {}
        if not d then self:Message("Entry unavailable.");return end
        d=A.Copy(d);d.related=d.related or {};d.references=d.references or {};d.stops=d.stops or {};d.zones=d.zones or {};d.category=d.category or "other"
        p.id,p.expedition,p.draft=id,expedition==true,d;p:Fill();p.message:SetText("")
        p.scroll:SetVerticalScroll(0);p.noteScroll:SetVerticalScroll(0);p.accessScroll:SetVerticalScroll(0);self:Show(p)
    end
    function c:Connections(id,expedition,external)
        local e=j:Get(id,expedition);if not e then main();return end
        self:Picker({title=(external and "Fieldbook references — " or "Atlas connections — ")..e.name,back=main,
            extraLabel=external and "Atlas places / routes" or "Other Fieldbook sections",
            extra=function() c:Connections(id,expedition,not external) end,
            hint="Click to attach or remove a link. Open follows a discovery or shows a safe summary. Missing links are retained until you remove them.",
            rows=function(query)
                local current=j:Get(id,expedition);if not current then return {} end
                local rows={}
                if external then
                    local seen={}
                    for _,r in ipairs(c.adapters:List(query)) do
                        local key=r.section..":"..r.key;seen[key]=true;local linked=false
                        for _,v in ipairs(current.references) do if v.section==r.section and v.key==r.key then linked=true end end
                        rows[#rows+1]={name=r.name,detail=r.title,ref=r,checked=linked}
                    end
                    for _,r in ipairs(current.references) do
                        if not seen[r.section..":"..r.key] and r.name:lower():find(query:lower(),1,true) then
                            local target,title=c.adapters:Resolve(r)
                            rows[#rows+1]={name=r.name,detail=title..(target.missing and " — unavailable" or ""),ref=r,checked=true}
                        end
                    end
                else
                    for _,r in ipairs(j:List(query,nil,true)) do
                        if expedition or r.id~=id then rows[#rows+1]={name=r.name,detail=r.zone,id=r.id,checked=U.Contains(current.related,r.id)} end
                    end
                    for _,key in ipairs(current.related) do if not j:Get(key) then rows[#rows+1]={name=key.." (missing)",id=key,checked=true} end end
                end
                return rows
            end,pick=function(row)
                local d=j:Get(id,expedition);if not d then return end
                if external then
                    local found
                    for i,r in ipairs(d.references) do if r.section==row.ref.section and r.key==row.ref.key then table.remove(d.references,i);found=true;break end end
                    if not found then d.references[#d.references+1]={section=row.ref.section,key=row.ref.key,name=row.ref.name} end
                else U.Toggle(d.related,row.id) end
                local _,err=j:Save(d,id,expedition);if err then c.pages.picker.message:SetText(err) end;c:Refresh()
            end,secondary=function(row)
                if external then
                    local opened,summary=c.adapters:Open(row.ref)
                    if not opened then c.pages.picker.message:SetText(A.Safe(summary)) end
                elseif j:Get(row.id) then main();c:Select(row.id)
                else c.pages.picker.message:SetText("This Atlas entry was deleted. You may remove its reference.") end
            end})
    end
    function c:Expeditions(linkID)
        self:Picker({title=linkID and "Expedition notes — link this discovery" or "Expedition notes",back=main,
            extraLabel=linkID and "New linked note" or "New expedition",extra=function()
                local d={related=linkID and {linkID} or {},zones={}}
                if j.state.mapID then d.zones={{mapID=j.state.mapID,zone=j.state.zone or ""}} end
                c:OpenEditor(nil,true,d)
            end,rows=function(query)
                local rows={};for _,n in ipairs(j:List(query,nil,true,true)) do
                    rows[#rows+1]={id=n.id,name=n.name,detail=U.Date(n.created),checked=linkID and U.Contains(n.related,linkID)}
                end;return rows
            end,pick=function(row) c:OpenEditor(row.id,true) end,
            secondaryLabel="Link / unlink",secondary=linkID and function(row)
                local n=j:Get(row.id,true);if n then U.Toggle(n.related,linkID);j:Save(n,row.id,true);c.pages.picker:Render();c:Refresh() end
            end or nil,empty="No expedition notes yet. Start a new expedition above.",
            hint=linkID and "Linked notes are marked. Open a title to read it; Link / unlink changes only the association." or "Journal text stays private unless explicitly included in a field report."})
    end
    function c:Stops(id)
        local e=j:Get(id);if not e or e.category~="route" then main();return end
        local p=self.pages.stops
        if not p then
            p=U.Panel(self.frame,self.shell,"Route itinerary",main);self.pages.stops=p;p.rows={};p.offset=0
            U.Label(p,"Stops keep their order across zones. Connections are observations, not terrain-aware or guaranteed safe paths.",24,-58,823,"GameFontHighlightSmall")
            for i=1,9 do
                local y=-100-(i-1)*46;local row=U.Button(p,"",24,y,535,function(self)
                    local route=j:Get(p.id);local stop=route and route.stops[self.index]
                    if stop then
                        if stop.recordID and j:Get(stop.recordID) then main();c:Select(stop.recordID)
                        elseif not stop.recordID then c:Waypoint(p.id,self.index)
                        else p.message:SetText("This stop references a deleted place. Remove it or keep its unresolved history.") end
                    end
                end)
                row:SetHeight(38);row:SetNormalFontObject(textFont("GameFontHighlightSmall"))
                row.up=U.Button(p,"Up",573,y,64,function() local d=j:Get(p.id);if j:MoveStop(d,row.index,row.index-1) then j:Save(d,p.id);p:Render();c:Refresh() end end)
                row.down=U.Button(p,"Down",644,y,74,function() local d=j:Get(p.id);if j:MoveStop(d,row.index,row.index+1) then j:Save(d,p.id);p:Render();c:Refresh() end end)
                row.remove=U.Button(p,"Remove",726,y,124,function() local d=j:Get(p.id);table.remove(d.stops,row.index);j:Save(d,p.id);p:Render();c:Refresh() end)
                p.rows[i]=row
            end
            p.previous=U.Button(p,"Previous",24,-532,100,function() p.offset=math.max(0,p.offset-9);p:Render() end)
            p.next=U.Button(p,"Next",134,-532,100,function() p.offset=p.offset+9;p:Render() end)
            U.Button(p,"Add existing place",252,-570,195,function()
                c:Picker({title="Add route stop",back=function() c:Stops(p.id) end,rows=function(query)
                    local rows={};for _,r in ipairs(j:List(query,nil,true)) do if r.category~="route" then rows[#rows+1]={id=r.id,name=r.name,detail=r.zone} end end;return rows
                end,pick=function(row)
                    local d=j:Get(p.id);d.stops[#d.stops+1]={recordID=row.id,name=row.name};local _,err=j:Save(d,p.id)
                    c:Stops(p.id);if err then p.message:SetText(err) end
                end})
            end)
            U.Button(p,"Add waypoint",460,-570,165,function() c:Waypoint(p.id) end)
            U.Button(p,"Edit route notes",638,-570,210,function() c:OpenEditor(p.id) end)
            function p:Render()
                local d=j:Get(self.id);if not d then main();return end
                self.title:SetText("Route: "..d.name);self.offset=math.max(0,math.min(self.offset,math.floor(math.max(0,#d.stops-1)/9)*9))
                local previousMap
                for i,row in ipairs(self.rows) do
                    local n=self.offset+i;local stop=d.stops[n];row.index=n
                    row:SetShown(stop~=nil);row.up:SetShown(stop~=nil);row.down:SetShown(stop~=nil);row.remove:SetShown(stop~=nil)
                    if stop then
                        local v=j:ResolveStop(stop);local prior=n>1 and j:ResolveStop(d.stops[n-1])
                        previousMap=prior and prior.mapID
                        row:SetText(A.Safe(n..". "..v.name.."\n"..(v.zone or "Unresolved")..(previousMap and previousMap~=v.mapID and " — zone transition" or "")))
                        row.up:SetEnabled(n>1);row.down:SetEnabled(n<#d.stops)
                    end
                end
                self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+9<#d.stops)
                self.message:SetText(#d.stops==0 and "Add places or named waypoints to build an itinerary." or #d.stops.." ordered stops. Click a place to open it; click a waypoint to edit it.")
            end
        end
        p.id=id;p:Render();self:Show(p)
    end
    function c:Waypoint(routeID,index)
        local p=self.pages.waypoint
        if not p then
            p=U.Panel(self.frame,self.shell,"Route waypoint",function() c:Stops(p.routeID) end);self.pages.waypoint=p
            p.name=U.Field(p,"Waypoint name",25,-66,816,160);locationFields(p,25,-139,816)
            U.Button(p,"Use my current position",29,-274,253,function() fillLocation(p,A.CurrentLocation()) end)
            U.Button(p,"Choose on displayed map",294,-274,261,function()
                c:PlaceOnMap(function(x,y,mapID,zone) fillLocation(p,{mapID=mapID,zone=zone,x=x,y=y});c:UpdatePositionButton();c:Show(p) end,p)
            end)
            U.Label(p,"A waypoint belongs to this route. It may be unpositioned. It does not create a second place record.",29,-331,807,"GameFontHighlight")
            U.Button(p,"Save waypoint",25,-572,195,function()
                local d,err=readLocation(p,{name=p.name:GetText()})
                if not d then p.message:SetText(err);return end
                local stop,e=A.Stop(d);if not stop then p.message:SetText(e);return end
                local route=j:Get(p.routeID);if not route then main();return end
                route.stops[p.index or (#route.stops+1)]=stop;local _,errorText=j:Save(route,p.routeID)
                if errorText then p.message:SetText(errorText);return end;c:Stops(p.routeID);c:Refresh()
            end)
            p.inputs={p.name,p.mapID,p.zone,p.subzone,p.x,p.y}
        end
        local route=j:Get(routeID);if not route then return end
        local d=index and route.stops[index] or A.CurrentLocation()
        p.routeID,p.index=routeID,index;p.name:SetText(d.name or "");fillLocation(p,d);p.message:SetText("");self:Show(p)
    end
end
