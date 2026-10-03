local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A,U=ns.Atlas,ns.AtlasUI
local function categoryInfo(id) return A.category[id] or ns.AtlasEntrances.Category(id) end
function ns.CreateAtlasBook(journal,shell,adapters)
    local c={journal=journal,shell=shell,adapters=adapters,pages={}}
    local entries=ns.AtlasEntrances and ns.AtlasEntrances.View(journal) or journal
    entries.borderlessPins=true -- The icon artwork retains its own bevel.
    c.entries=entries
    c.worldSubzones=ns.AtlasSubzones.CreateWorldOverlay(journal)
    c.subzoneObserver=ns.AtlasSubzones.Track(journal,function()
        if c.main and c.main.map:IsVisible() then c.main.map:RenderSubzones() end
        c.worldSubzones:Refresh()
    end)
    -- Weather is a per-zone collection of encountered types, independent of
    -- which map is open. Keep only first observations, not a running history.
    c.weatherObserver=CreateFrame("Frame")
    c.weatherObserver:SetScript("OnEvent",function()
        journal:ObserveWeather()
        if c.main then c.main.map:UpdateWeather() end
    end)
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","WEATHER_CHANGED"}) do
        pcall(c.weatherObserver.RegisterEvent,c.weatherObserver,event)
    end
    journal:ObserveWeather()
    local state=journal.state
    state.query=type(state.query)=="string" and state.query or ""
    state.offset=A.Integer(state.offset,0,5000) and state.offset or 0
    state.all=state.all==true
    function c:Show(page)
        for _,v in pairs(self.pages) do v:Hide() end
        self.activePage=page or self.main;self.activePage:Show()
        if ns.WindowFocus then ns.WindowFocus:Register(shell:GetFrame()) end
        if GameTooltip then GameTooltip:Hide() end
    end
    function c:Message(text) self.main.message:SetText(A.Safe(text or "")) end
    function c:SetZone(mapID,zone)
        state.mapID,state.zone=mapID,zone or "Unknown zone";state.offset=0
        if self.main then self.main.map:Invalidate() end
        self:Refresh()
    end
    function c:Select(id)
        local e=entries:Get(id);if not e then return end
        state.selected=id
        local target=e
        if e.category=="route" then
            for _,s in ipairs(e.stops) do local p=journal:ResolveStop(s);if p.mapID then target=p;break end end
            if journal:InZone(e,state.mapID) then target={mapID=state.mapID,zone=state.zone} end
        end
        if target.mapID and target.mapID~=state.mapID then
            state.mapID,state.zone,state.continent=target.mapID,target.zone,nil
        end
        if not target.mapID and not journal:InZone(e,state.mapID) then
            state.all=true;self:Message("Showing all recorded zones for this unpositioned discovery.")
        end
        -- Pins may select entries outside the current search. Make that clear
        -- and clear only the index query so selection can be seen in both views.
        local rows=entries:List(state.query,state.mapID,state.all);local found
        for i,r in ipairs(rows) do if r.id==id then found=i;break end end
        if not found then
            if state.query~="" then self:Message("Index search cleared to show the selected discovery.") end
            state.query="";self.main.search:SetText("")
            rows=entries:List("",state.mapID,state.all)
            for i,r in ipairs(rows) do if r.id==id then found=i;break end end
        end
        if found then state.offset=math.floor((found-1)/12)*12 end
        self.main.details:SetVerticalScroll(0);self:Refresh()
    end
    function c:Picker(config)
        local p=self.pages.picker
        if not p then
            p=U.Panel(self.frame,shell,"",function() p.config.back() end);self.pages.picker=p
            p.search=U.Search(p,27,-75,620,200);p.rows={}
            p.extra=U.Button(p,"",674,-74,183,function() if p.config.extra then p.config.extra() end end)
            for i=1,10 do
                local row=U.Button(p,"",24,-115-(i-1)*43,705,function(self)
                    if self.data then p.config.pick(self.data);p:Render() end
                end)
                row:SetHeight(38);row:SetNormalFontObject(textFont("GameFontHighlightSmall"))
                row.typeCheck=row:CreateTexture(nil,"OVERLAY")
                row.typeCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                row.typeCheck:SetSize(18,18);row.typeCheck:SetPoint("LEFT",12,0);row.typeCheck:Hide()
                row.secondary=U.Button(p,"Open",738,-121-(i-1)*43,112,function()
                    if row.data and p.config.secondary then p.config.secondary(row.data) end
                end)
                p.rows[i]=row
            end
            p.previous=U.Button(p,"Previous",24,-556,110,function() p.offset=math.max(0,p.offset-10);p:Render() end)
            p.next=U.Button(p,"Next",144,-556,110,function() p.offset=p.offset+10;p:Render() end)
            p.count=U.Label(p,"",275,-562,570,"GameFontHighlightSmall")
            function p:Render()
                local rows=self.config.rows(self.search:GetText());self.data=rows
                self.offset=math.max(0,math.min(self.offset,math.floor(math.max(0,#rows-1)/10)*10))
                for i,row in ipairs(self.rows) do
                    local data=rows[self.offset+i];row.data=data;row:SetShown(data~=nil)
                    row.typeCheck:SetShown(data~=nil and data.typeSelected==true)
                    row.secondary:SetShown(data~=nil and self.config.secondary~=nil)
                    if data then
                        row:SetText(A.Safe((data.checked and "[Linked] " or "")..data.name..(data.detail and "\n"..data.detail or "")))
                        row:SetWidth(self.config.secondary and 705 or 826)
                        row.secondary:SetText(self.config.secondaryLabel or "Open")
                        if data.typeSelected then U.TypeCheck(row.typeCheck,data.typeKind) end
                    end
                end
                self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+10<#rows)
                self.count:SetText(#rows==0 and (self.config.empty or "No matching entries.") or (self.offset+1).."–"..math.min(self.offset+10,#rows).." of "..#rows)
            end
            p.search:HookScript("OnTextChanged",function() if p.config then p.offset=0;p:Render() end end)
        end
        p.config=config;p.offset=0;p.title:SetText(config.title);p.search:SetText("")
        p.extra:SetText(config.extraLabel or "");p.extra:SetShown(config.extra~=nil)
        p.message:SetText(config.hint or "");p:Render();self:Show(p)
        return p
    end
    function c:PickZone(callback,back,continent)
        local maps=A.MapCatalog(entries)
        self:Picker({title="Choose a zone",back=back,rows=function(query)
            local rows={}
            for _,z in ipairs(maps) do
                if (not continent or z.continent==continent) and (z.zone.." "..z.continent):lower():find(query:lower(),1,true) then
                    rows[#rows+1]={name=z.zone,detail=z.continent.." • Map "..z.mapID,zone=z}
                end
            end
            return rows
        end,pick=function(r) callback(r.zone) end,empty="No maps available. Use Current Zone or enter a map ID in a record."})
    end
    function c:Refresh()
        if not self.main then return end
        local m=self.main
        local rows=entries:List(state.query,state.mapID,state.all)
        state.offset=math.max(0,math.min(state.offset,math.floor(math.max(0,#rows-1)/12)*12))
        if m.automaticMapping then m.automaticMapping:SetChecked(state.automaticMapping~=false) end
        if m.autoEntrances then
            m.autoEntrances:SetChecked(state.autoEntrances==true)
        end
        m.scope:SetText(state.all and "Scope: All recorded zones" or "Scope: Current map")
        m.zone:SetText(state.zone and state.zone~="" and state.zone or "Choose zone")
        for i,row in ipairs(m.rows) do
            local data=rows[state.offset+i];row.id=data and data.id;row:SetShown(data~=nil)
            if data then
                row.name:SetText((data.id==state.selected and "> " or "")..A.AutomaticLabel(data.name,data.entrance));row.zone:SetText(A.Safe(data.zone~="" and data.zone or "Unpositioned / unknown zone"))
                row.icon:SetTexture(categoryInfo(data.category).icon)
                local selected=data.id==state.selected;row:SetSelected(selected)
                row.name:SetTextColor(selected and 1 or 0.75,selected and 0.82 or 0.8,selected and 0.14 or 0.8)
            end
        end
        m.empty:SetShown(#rows==0)
        m.empty:SetText((next(journal.records) or (journal.entrances and next(journal.entrances.records))) and "No matching discoveries.\nTry all zones or clear your search." or "Your atlas starts empty.\n\nChoose Add Discovery to record a place at your current position, or enable entrance discovery as you explore.")
        m.count:SetText(#rows.." discoveries • "..(state.all and "all zones" or "displayed map"))
        m.cancelPlace:SetShown(m.map.placing==true)
        m.previous:SetEnabled(state.offset>0);m.next:SetEnabled(state.offset+12<#rows)
        m.subzones:SetChecked(state.showSubzones==true)
        m.subzoneLabels:SetChecked(state.showSubzoneLabels==true)
        m.subzonePoints:SetChecked(state.showSubzonePoints==true)
        m.legacySubzones:SetChecked(state.subzoneFillMethod=="convex")
        c.worldSubzones:Refresh()
        m.hideZoneAreas:SetChecked(state.hideZoneNameSubzones==true)
        m.labelSize:Display(A.Integer(state.subzoneLabelSize,2,24) and state.subzoneLabelSize or ns.AtlasSubzones.DEFAULT_LABEL_SIZE)
        local e=entries:Get(state.selected)
        local mapCaption=m.map:Render(state.mapID,state.selected)
        local detail={}
        if e then
            detail={e.name.." — "..categoryInfo(e.category).label,
                (e.zone~="" and e.zone or "Unknown zone")..(e.subzone~="" and " / "..e.subzone or "")..(A.Position(e) and string.format(" • %.1f, %.1f",e.x/100,e.y/100) or " • Unpositioned"),
                "Knowledge: "..e.provenance.kind.." ("..e.provenance.source..") • "..(e.explored and "Explored — your assertion" or "Not marked explored"),
                "Created "..U.Date(e.created).." • Updated "..U.Date(e.updated)}
            if e.notes~="" then detail[#detail+1]="Notes: "..e.notes end
            if e.access~="" then detail[#detail+1]="Access: "..e.access end
            if e.interior~="" then detail[#detail+1]="Interior label: "..e.interior end
            if e.interiorMapID then detail[#detail+1]="Interior map: "..e.interiorMapID end
            if e.entrance then
                local evidence=e.evidence
                detail[#detail+1]=evidence.entries.." entries / "..evidence.exits.." exits • "..evidence.evidence.." • Type: "..e.classification.kind
                detail[#detail+1]="Exterior map "..evidence.exterior.mapID.." • Interior best map "..evidence.interior.bestMapID..
                    (evidence.interior.microMapID and " • Micro map "..evidence.interior.microMapID or "")
                if e.classification.kind=="inferred" then detail[#detail+1]="Suggested by "..(e.classification.field or "name").." keyword: "..(e.classification.keyword or "") end
            end
            if e.category=="route" and not e.entrance then
                if #e.stops>0 then detail[#detail+1]="From "..journal:ResolveStop(e.stops[1]).name.." to "..journal:ResolveStop(e.stops[#e.stops]).name end
                for i,s in ipairs(e.stops) do
                    local p=journal:ResolveStop(s);detail[#detail+1]=i..". "..p.name.." — "..(p.zone or "Unknown zone")..(p.mapID~=state.mapID and " (another map / unresolved)" or "")
                end
            end
            for _,id in ipairs(e.related) do local r=journal:Get(id);detail[#detail+1]="Related: "..(r and r.name or id.." (missing)") end
            for _,r in ipairs(e.references) do local target,title=adapters:Resolve(r);detail[#detail+1]=title..": "..target.name..(target.missing and " (unavailable)" or "") end
            for _,n in ipairs(journal:Associated(e.id)) do detail[#detail+1]="Expedition: "..n.name end
        else detail={"Select a discovery to read your field notes.","Record entrances deliberately; an interior position is not an outdoor entrance."} end
        if mapCaption~="" then table.insert(detail,1,mapCaption) end
        m.details:SetText(table.concat(detail,"\n"))
        m.reveal:SetShown(e~=nil and not entries:Layer(e.category))
        for _,b in ipairs(m.entryButtons) do b:SetEnabled(e~=nil) end
        for _,b in ipairs(m.deliberateButtons) do b:SetEnabled(e~=nil and not e.entrance) end
        m.deleteButton:SetEnabled(e~=nil and not journal.readOnly and not (e.entrance and journal.entrances.readOnly))
        m.route:SetEnabled(e~=nil and e.category=="route" and not e.entrance)
    end
    local function build(content)
        c.frame=content
        local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m;c.pages.main=m
        local spine=m:CreateTexture(nil,"ARTWORK")
        spine:SetColorTexture(0.25,0.13,0.055,0.35)
        spine:SetPoint("TOPLEFT",306,-53);spine:SetSize(3,661)
        m.pageTitle=ns.FieldbookUI.SectionTitle(m,"Traveller’s Atlas")
        m.search=U.Search(m,48,-113,240,200);m.search:SetText(state.query)
        m.search:HookScript("OnTextChanged",function() state.query=m.search:GetText();state.offset=0;c:Refresh() end)
        m.scope=U.Button(m,"",42,-146,250,function() state.all=not state.all;state.offset=0;c:Refresh() end)
        m.count=U.Label(m,"",42,-179,250,"GameFontHighlightSmall")
        m.rows={}
        for i=1,12 do
            local row=CreateFrame("Button",nil,m,"BackdropTemplate");row:SetPoint("TOPLEFT",42,-204-(i-1)*30);row:SetSize(250,29)
            ns.FieldbookUI.StyleMenuRow(row)
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",3,-6);row.icon:SetSize(20,20)
            row.name=U.Label(row,"",28,-2,217,"GameFontHighlightSmall");row.name:SetWordWrap(false)
            row.zone=U.Label(row,"",28,-17,217,"GameFontDisableSmall");row.zone:SetWordWrap(false)
            row:SetScript("OnClick",function(self) if self.id then c:Select(self.id) end end)
            row:SetScript("OnEnter",function(self)
                local e=entries:Get(self.id)
                if e and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(A.AutomaticLabel(e.name,e.entrance));GameTooltip:AddLine(A.Safe(e.zone).." • "..categoryInfo(e.category).label,1,1,1);GameTooltip:Show() end
            end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            m.rows[i]=row
        end
        m.empty=U.Label(m,"",50,-228,233,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(4)
        m.previous=U.Button(m,"Previous",42,-574,118,function() state.offset=math.max(0,state.offset-12);c:Refresh() end)
        m.next=U.Button(m,"Next",174,-574,118,function() state.offset=state.offset+12;c:Refresh() end)
        -- Center the 580-pixel control rows between the divider and inner right edge.
        U.Button(m,"Add Discovery",342,-60,140,function() c:OpenEditor(nil,false,A.CurrentLocation()) end)
        U.Button(m,"Expeditions",488,-60,116,function() c:Expeditions() end)
        m.shareButton=U.ShareButton(m,function() c:Report() end)
        m.deleteButton=U.Button(m,"Delete",174,-672,118,function()
            local id=state.selected;local e=entries:Get(id)
            if c.activePage~=m or not e or journal.readOnly then return end
            local records=e.entrance and journal.entrances.records or journal.records
            local recordID=e.entrance or id;local record=records[recordID]
            m.deleteForm=m.deleteForm or ns.FieldbookUI.DeletePanel(m,shell,"Delete Atlas entry")
            m.deleteForm:Open("Delete "..A.Safe(e.name).."?\n\nThis cannot be undone. Related entries and source-section records are preserved.\n\nLinks in routes, expeditions and report drafts remain unresolved.",function()
                if state.selected~=id or records[recordID]~=record then return nil,"Selection changed; nothing deleted." end
                local ok=entries:Delete(id)
                if ok then state.selected=nil;c:Refresh() end
                return ok,"Could not delete this entry."
            end)
        end)
        U.Button(m,"Current Zone",794,-60,128,function()
            local location=A.CurrentLocation();c:SetZone(location.mapID,location.zone);c:Message(location.mapID and "Showing your current zone." or "Current map unavailable; you can still record notes.")
        end)
        m.zone=U.ZoneMenu(m,342,-174,306,function()
            local ids={state.mapID};for _,row in ipairs(A.MapCatalog(entries)) do ids[#ids+1]=row.mapID end;return ids
        end,function(id,name) c:SetZone(id,name) end)
        m.layerMenu=U.MenuButton(m,"Map Layers",342,-146,130,function()
            m.layerPanel:SetShown(not m.layerPanel:IsShown())
        end)
        m.layerPanel=CreateFrame("Frame",nil,m,"BackdropTemplate")
        local layers=m.layerPanel
        layers:SetPoint("TOPLEFT",m.layerMenu,"BOTTOMLEFT",0,-2)
        layers:SetFrameLevel(m:GetFrameLevel()+40);layers:EnableMouse(true)
        layers:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        layers:SetBackdropColor(0.055,0.04,0.022,1)
        layers.checks={}
        local y=-10
        local function addLayer(id,label)
            local check=U.Check(layers,label,10,y,210,function(on) entries:SetLayer(id,on);c:Refresh() end)
            check.layerID=id;layers.checks[#layers.checks+1]=check;y=y-26
        end
        for _,category in ipairs(A.categories) do addLayer(category.id,category.label) end
        if journal.entrances then addLayer("entrance","Generic Entrances") end
        local function all(visible)
            for _,check in ipairs(layers.checks) do entries:SetLayer(check.layerID,visible);check:SetChecked(visible) end
            c:Refresh()
        end
        U.Button(layers,"Show all",12,y,106,function() all(true) end)
        U.Button(layers,"Hide all",124,y,106,function() all(false) end)
        y=y-34
        m.iconSize=U.SmallSlider(layers,"Icon size",12,y,76,6,40,1,function(v) return tostring(v) end,function(value)
            if not journal.readOnly then state.iconSize=value end
            c:Refresh()
        end)
        m.iconSize:SetEnabled(not journal.readOnly)
        layers:SetSize(244,-y+30)
        ns.FieldbookUI.DismissOnOutsideClick(layers,m.layerMenu)
        layers:SetScript("OnShow",function()
            for _,check in ipairs(layers.checks) do check:SetChecked(entries:Layer(check.layerID)) end
            m.iconSize:Display(A.Number(state.iconSize,6,40) and state.iconSize or 20)
        end)
        m:HookScript("OnHide",function() layers:Hide() end)
        layers:Hide()
        U.Tip(m.layerMenu,"Choose which discovery markers appear on the map. Check several layers or use Show all / Hide all. The discovery index and sub-zone controls are unchanged.")
        if journal.entrances then
            m.autoEntrances=U.Check(m,"Auto-discover entrances",342,-91,148,function(on) c.entranceObserver:SetEnabled(on) end)
            m.autoEntrances:SetEnabled(not journal.entrances.readOnly)
            U.Tip(m.autoEntrances,"Learn exterior entrances from indoor / outdoor crossings. Starts off. This controls recording only; Map Layers controls visibility. Sub-zone mapping is independent.")
        end
        m.automaticMapping=U.Check(m,"Toggle Automatic Mapping",342,-119,280,function(on)
            if not journal.readOnly then state.automaticMapping=on;journal.subzones:Reset() end
        end)
        m.automaticMapping:SetChecked(state.automaticMapping~=false)
        m.automaticMapping:SetEnabled(not journal.readOnly)
        U.Tip(m.automaticMapping,"Automatically record sub-zone crossings and interior survey points. Pauses in The Great Sea, on flight paths and while flying. City mapping is enabled. Manual survey-point keybindings remain available when this is off.")
        m.cleanPoints=U.Button(m,"Clean Redundant Points",480,-146,168,function()
            local allMaps=A.Read(IsControlKeyDown)==true
            local function done(count,message)
                m.cleanPoints:SetEnabled(not journal.readOnly)
                c:Refresh()
                if message and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r "..message) end
                c:Message(message or ("Removed "..count.." redundant interior sample"..(count==1 and "." or "s.")))
            end
            local function progress(message)
                c:Message(message)
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r "..message) end
            end
            local started
            if allMaps then started=ns.AtlasSubzones.CleanAllInterior(journal,done,progress)
            else started=ns.AtlasSubzones.CleanInterior(journal,state.mapID,done,progress) end
            if started then m.cleanPoints:SetEnabled(false);c:Message(allMaps and "Checking interior samples on all saved maps..." or "Checking interior samples on this map...") end
        end)
        m.cleanPoints:SetEnabled(not journal.readOnly)
        U.Tip(m.cleanPoints,"Cleanup is paused while traced fill is enabled. With Legacy fill: click to remove redundant interior samples on this map, or Ctrl+Click for ALL saved Atlas maps. Preserves cross-over points and convex perimeter/overlap evidence. Removing interior points can affect a later return to traced fill. Recorded discoveries are unchanged.")
        -- Keep the survey controls together within the existing header height.
        local group=CreateFrame("Frame",nil,m,"BackdropTemplate");m.subzoneControls=group
        group:SetPoint("TOPLEFT",660,-91);group:SetSize(262,107);group:EnableMouse(false)
        group:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        group:SetBackdropColor(0.055,0.04,0.022,0.6);group:SetBackdropBorderColor(0.45,0.30,0.13,0.75)
        U.Label(group,"Sub-zones",12,-7,80,"GameFontNormalSmall")
        m.labelSize=U.SmallSlider(group,"Label size",100,-68,56,2,24,1,function(v) return tostring(v) end,function(value)
            if not journal.readOnly then state.subzoneLabelSize=value end
            c:Refresh()
        end)
        U.Tip(m.labelSize,"Sub-zone label text size (2–24, default 4). Applies immediately; map zoom also scales labels.")
        m.legacySubzones=U.Check(group,"Legacy Fill",98,-3,100,function(on)
            if not journal.readOnly then state.subzoneFillMethod=on and "convex" or "traced" end
            c:Refresh()
        end)
        m.legacySubzones:SetSize(20,20)
        m.legacySubzones.label:ClearAllPoints()
        m.legacySubzones.label:SetPoint("TOPLEFT",22,-5)
        m.legacySubzones:SetEnabled(not journal.readOnly)
        U.Tip(m.legacySubzones,"Restore the original convex fill on both maps. Unchecked: trace inward through supporting samples. Saved observations are unchanged when switching. Cleanup is paused in traced mode to protect its supporting points; legacy cleanup permanently removes points and can affect a later return to traced mode.")
        m.subzones=U.Check(group,"Shading",10,-23,65,function(on)
            if not journal.readOnly then state.showSubzones=on end;c:Refresh()
        end)
        U.Tip(m.subzones,"Shade self-discovered sub-zones after three non-collinear observations. Crossings and interior samples with more than 50 yards of clearance collect while playing, even with these layers hidden. Points and Labels are independent display options. Hover for evidence details. Traced fill bends inward through supporting samples; sparse evidence can still span unknown space. Legacy fill restores the original outline.")
        m.subzonePoints=U.Check(group,"Points",10,-43,88,function(on)
            if not journal.readOnly then state.showSubzonePoints=on end;c:Refresh()
        end)
        U.Tip(m.subzonePoints,"Checked: show every recorded crossing and interior sample, including points incorporated into shading. Unchecked: retain automatic isolated dots with shading and hide incorporated samples. All dots stay small when zooming. Recording and saved observations are unchanged.")
        m.subzoneLabels=U.Check(group,"Labels",10,-63,65,function(on)
            if not journal.readOnly then state.showSubzoneLabels=on end;c:Refresh()
        end)
        U.Tip(m.subzoneLabels,"Show discovered sub-zone names independently of boundary shading. Names try two lines before hiding for lack of space. Adjust their text with Label size.")
        m.hideZoneAreas=U.Check(group,"Hide zone-name areas",10,-83,218,function(on)
            if not journal.readOnly then state.hideZoneNameSubzones=on end;c:Refresh()
        end)
        U.Tip(m.hideZoneAreas,"Hide shading and labels for areas whose name matches the displayed zone (for example Loch Modan in Loch Modan). Sample points, recording and other sub-zones are unchanged.")
        for _,check in ipairs({m.subzones,m.subzonePoints,m.subzoneLabels,m.hideZoneAreas}) do
            check:SetSize(20,20)
        end
        m.map=ns.CreateAtlasMap(m,entries,function(id) c:Select(id) end,function(x,y)
            if c.placeCallback then
                local callback=c.placeCallback;c.placeCallback=nil;m.map.placing=false;c:Message("")
                callback(x,y,state.mapID,state.zone)
            end
        end,function(id,name) c:SetZone(id,name) end)
        m.brightness=m.map.brightness
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.map.weatherText=U.Label(m,"",342,-587,580,"GameFontHighlightSmall")
        m.map.weatherText:SetWordWrap(false)
        m.details=U.ReadArea(m,342,-606,555,64)
        m.reveal=U.Button(m,"Reveal layer",788,-513,114,function()
            local e=entries:Get(state.selected);if e then entries:SetLayer(e.category,true);c:Refresh() end
        end)
        -- Leave a separate line for the hidden-layer affordance, never cover text.
        m.reveal:ClearAllPoints();m.reveal:SetPoint("TOPLEFT",174,-638)
        local edit=U.Button(m,"Edit",42,-638,120,function() c:OpenEditor(state.selected) end)
        local links=U.Button(m,"Connections",428,-680,128,function() c:Connections(state.selected,false) end)
        m.route=U.Button(m,"Route stops",562,-680,112,function() c:Stops(state.selected) end)
        local notes=U.Button(m,"Linked notes",680,-680,112,function() c:Expeditions(state.selected) end)
        local position=U.Button(m,"Map position",798,-680,124,function() c:OpenEditor(state.selected);c:ChoosePosition() end)
        m.entryButtons={edit,links,notes,position}
        m.deliberateButtons={links,notes}
        m.cancelPlace=U.Button(m,"Cancel placement",42,-638,128,function()
            m.map.placing=false;c.placeCallback=nil;m.cancelPlace:Hide();c:Message("")
            if c.placeReturn then c:Show(c.placeReturn) end
        end);m.cancelPlace:Hide()
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall")
        ns.InstallAtlasEditors(c);ns.InstallAtlasReportUI(c)
        content:SetScript("OnHide",function()
            m.map:SuspendPlayer()
            if GameTooltip then GameTooltip:Hide() end
            m.search:ClearFocus()
            if c.ClearFocus then c:ClearFocus() end
        end)
        local initial=A.CurrentLocation()
        if initial.mapID then
            state.mapID,state.zone,state.continent=initial.mapID,initial.zone,nil;state.offset=0
        end
        c:Show();c:Refresh()
        if journal.readOnly then c:Message("Newer Atlas schema: this journal is read-only; saved data is untouched.") end
    end
    shell:RegisterSection("atlas",{title="Traveller’s Atlas",icon="Interface\\Icons\\INV_Misc_Map03",
        help="|cffffd1001. Record a discovery|r\nKeep a journal of places you want to find again. Click Add Discovery, enter a name and category, then Save. Use my current position captures your location; Choose on displayed map lets you place a point yourself. Coordinates may be left blank. For a cave, record its entrance.\n\n"..
            "|cffffd1002. Browse maps|r\nChoose a map or click Current Zone. Search the current map or all recorded zones, then select an index entry or map pin. Repeated clicks cycle overlapping pins. Map Layers shows or hides discovery categories; Reveal layer shows a selected entry's hidden category.\n\n"..
            "|cffffd1003. Edit and explore|r\nEdit changes names, notes, access details and explored status. Map position lets you place the selected discovery. Explored is your own assertion: saving a location does not mark it explored. Recorded and Reported identify the source of the information.\n\n"..
            "|cffffd1004. Routes and passages|r\nChoose the Route / Passage category, then Save & route stops. Add recorded places or named waypoints; use Up, Down and Remove to arrange them. Stops can span zones. Map lines connect recorded stops, not guaranteed safe paths.\n\n"..
            "|cffffd1005. Expeditions and connections|r\nUse Expeditions for longer journals and Linked notes to attach them to a discovery. Connections links known Atlas discoveries or records in other supported Fieldbook sections. Removing a link leaves the source record intact.\n\n"..
            "|cffffd1006. Field reports|r\nShare saves a field-report draft for a zone or selected discoveries. Choose what to include, add private notes or expedition excerpts only if wanted, then use Preview report. This page provides drafts and previews only; it cannot send or import reports.\n\n"..
            "|cffffd1007. Self-discovered sub-zones|r\nAutomatic mapping starts on and records area crossings and survey points as you travel, even with the Atlas closed. Toggle Automatic Mapping pauses it. Automatic recording pauses in The Great Sea, on flight paths and while flying.\n\nBind Record Atlas survey point in the game's keybinding settings to add a point where you stand, including with automatic mapping off. You need a readable position and enough distance from existing samples. Cleanup is paused while traced fill is enabled to preserve its supporting points. Legacy fill restores the original convex outline; its cleanup can permanently remove interior samples.\n\nShading, Points and Labels control the Atlas display. Use the world map Filters dropdown to enable Points, Labels and Zones independently on the main map, alongside Merchants and Nodes. Shading estimates an area from your samples; it is not an exact border survey. Hover the map to inspect the evidence. Sub-zone samples do not add discovery entries or enter field reports.\n\n"..
            "|cffffd1008. Entrance discovery|r\nAuto-discover entrances starts off and learns from physical indoor / outdoor crossings. Generic Entrances starts hidden in Map Layers; recording and visibility are independent. Grey category ticks are suggestions; explicitly choose a category and Save for a gold player-confirmed tick. Entrance evidence stays separate from deliberate records and field reports.\n\n"..
            "|cffffd1009. Your journal|r\nAtlas records and browsing settings follow Account-wide tracking in Options. It starts on; turn it off to use this character's separate journal after /reload. Bestiary resets, backups and sharing do not include Atlas records.",
        frameName="AzerothFieldbookAtlasSection",build=build,onOpen=function()
            if c.main then c.main.map:Invalidate() end;c:Refresh()
        end})
    if ns.AtlasEntranceTracking then
        c.entranceObserver=ns.AtlasEntranceTracking.Track(journal,function(id)
            if c.main and id and c.main:IsVisible() then c:Refresh() end
        end)
    end
    return c
end
function ns.InitializeAtlas(shell,bestiary)
    if type(AzerothFieldbookAtlasDB)~="table" then AzerothFieldbookAtlasDB={} end
    local storage=ns.SelectSectionStorage and ns.SelectSectionStorage("atlas",AzerothFieldbookAtlasDB) or AzerothFieldbookAtlasDB
    local journal=ns.CreateAtlasJournal(storage)
    if journal.entrances then journal.entrances.onRecorded=function(entry)
        local name=entry.name:gsub("[\r\n]+"," ")
        local zone=A.Text(entry.interior.zone,160) and entry.interior.zone or ("Map "..entry.exterior.mapID)
        zone=A.Safe(zone):gsub("[\r\n]+"," ")
        local message=shell.sections.atlas.definition.title.." recorded: "..A.AutomaticLabel(name,true).." ("..zone..
            string.format(" • %.1f, %.1f).",entry.exterior.x/100,entry.exterior.y/100)
        if bestiary and bestiary.RecordEvent then
            bestiary:RecordEvent(message,{kind="atlas-recorded",entranceID=entry.id,mapID=entry.exterior.mapID,automatic=true})
        end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r "..message) end
    end end
    function AzerothFieldbookRecordAtlasPoint()
        local added,message=journal.subzones:RecordPoint()
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("AFB: "..message) end
        return added
    end
    local adapters=ns.CreateAtlasReferences(bestiary,function() return ns.ActiveSectionStores and ns.ActiveSectionStores.gathering or AzerothFieldbookGatheringDB end,shell)
    return ns.CreateAtlasBook(journal,shell,adapters)
end
