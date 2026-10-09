local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A,U=ns.Atlas,ns.AtlasUI
local ROW_HEIGHT,LIST_HEIGHT=38,462
local VISIBLE_ROWS=math.ceil(LIST_HEIGHT/ROW_HEIGHT)+1
local function categoryInfo(id) return A.category[id] or ns.AtlasEntrances.Category(id) end
function ns.CreateAtlasBook(journal,shell,adapters)
    local c={journal=journal,shell=shell,adapters=adapters,pages={}}
    local entries=ns.AtlasEntrances and ns.AtlasEntrances.View(journal) or journal
    entries.borderlessPins=true -- The icon artwork retains its own bevel.
    c.entries=entries
    ns.AtlasOptions={
        GetLegacy=function() return journal.state.subzoneFillMethod=='convex' end,
        Writable=function() return not journal.readOnly end,
        SetLegacy=function(on)
            if journal.readOnly then return end
            journal.state.subzoneFillMethod=on and 'convex' or 'traced'
            if c.main then c:Refresh() end
            c.worldSubzones:Refresh()
        end,
    }
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
    function c:ListRows()
        local rows={}
        for _,entry in ipairs(entries:List(state.query,state.mapID,state.all)) do
            if (not state.listCategory or entry.category==state.listCategory)
                and (not state.listOrigin or (state.listOrigin=="automatic" and entry.entrance)
                    or (state.listOrigin=="deliberate" and not entry.entrance)) then rows[#rows+1]=entry end
        end
        local sort=state.listSort or "name"
        table.sort(rows,function(a,b)
            if sort=="newest" or sort=="oldest" then
                local av,bv=a.created or 0,b.created or 0
                if av~=bv then if sort=="newest" then return av>bv else return av<bv end end
            elseif sort=="zone" and a.zone~=b.zone then return a.zone:lower()<b.zone:lower() end
            if a.name:lower()~=b.name:lower() then return a.name:lower()<b.name:lower() end
            return a.id<b.id
        end)
        return rows
    end
    function c:SetListFilter(category,origin)
        state.listCategory=category;state.listOrigin=origin;state.indexScroll=0;self:Refresh()
    end
    function c:SetListSort(sort)
        state.listSort=sort;state.indexScroll=0;self:Refresh()
    end
    state.query=type(state.query)=="string" and state.query or ""
    state.offset=A.Integer(state.offset,0,5000) and state.offset or 0
    state.indexScroll=A.Number(state.indexScroll,0,1000000) and state.indexScroll or state.offset*ROW_HEIGHT
    state.all=state.all~=false
    function c:Show(page)
        for _,v in pairs(self.pages) do v:Hide() end
        self.activePage=page or self.main;self.activePage:Show()
        if ns.WindowFocus then ns.WindowFocus:Register(shell:GetFrame()) end
        if GameTooltip then GameTooltip:Hide() end
    end
    function c:Message(text) self.main.message:SetText(A.Safe(text or "")) end
    function c:SetZone(mapID,zone)
        state.mapID,state.zone=mapID,zone or "Unknown zone";state.offset=0;state.indexScroll=0
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
        local rows=self:ListRows();local found
        for i,r in ipairs(rows) do if r.id==id then found=i;break end end
        if not found then
            if state.query~="" then self:Message("Index search cleared to show the selected discovery.") end
            state.query="";self.main.search:SetText("")
            rows=entries:List("",state.mapID,state.all)
            for i,r in ipairs(rows) do if r.id==id then found=i;break end end
        end
        if found then
            local top=(found-1)*ROW_HEIGHT;local scroll=state.indexScroll
            if top<scroll then state.indexScroll=top
            elseif top+ROW_HEIGHT>scroll+LIST_HEIGHT then state.indexScroll=top+ROW_HEIGHT-LIST_HEIGHT end
        end
        self.main.details:SetVerticalScroll(0);self:Refresh()
        self.main.map:CenterOnEntry(id)
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
        local rows=self:ListRows()
        local scroll=math.max(0,math.min(state.indexScroll,math.max(0,#rows*ROW_HEIGHT-LIST_HEIGHT)))
        state.indexScroll=scroll
        m.updatingList=true;m.listBody:SetHeight(math.max(LIST_HEIGHT,#rows*ROW_HEIGHT))
        m.list:SetVerticalScroll(scroll);m.list:UpdateScrollChildRect();m.list:RefreshScrollBar();m.updatingList=nil
        local first=math.floor(scroll/ROW_HEIGHT)
        if m.automaticMapping then m.automaticMapping:SetChecked(state.automaticMapping~=false) end
        if m.autoEntrances then
            m.autoEntrances:SetChecked(state.autoEntrances==true)
        end
        m.scope:SetSelected(not state.all)
        if m.listFilter then m.listFilter:SetSelected(state.listCategory~=nil or state.listOrigin~=nil) end
        m.zone:SetText(state.zone and state.zone~="" and state.zone or "Choose zone")
        for i,row in ipairs(m.rows) do
            local data=rows[first+i];row.id=data and data.id;row:SetShown(data~=nil)
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+i-1)*ROW_HEIGHT)
            if data then
                row.name:SetText(A.AutomaticLabel(data.name,data.entrance));row.zone:SetText(A.Safe(data.zone~="" and data.zone or "Unpositioned / unknown zone"))
                row.icon:SetTexture(categoryInfo(data.category).icon)
                local selected=data.id==state.selected;row:SetSelected(selected)
                row.name:SetTextColor(selected and 1 or 0.75,selected and 0.82 or 0.8,selected and 0.14 or 0.8)
            end
        end
        m.empty:SetShown(#rows==0)
        m.empty:SetText((next(journal.records) or (journal.entrances and next(journal.entrances.records))) and "No matching discoveries.\nTry all zones or clear your search." or "Your atlas starts empty.\n\nChoose Add Discovery to record a place at your current position, or enable entrance discovery as you explore.")
        m.count:SetCounts(#entries:List("",nil,true),#rows)
        self:UpdatePositionButton()
        m.subzones:SetChecked(state.showSubzones==true)
        m.subzoneLabels:SetChecked(state.showSubzoneLabels==true)
        m.subzonePoints:SetChecked(state.showSubzonePoints==true)
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
        local formatted={}
        for i,line in ipairs(detail) do
            local label,value=line:match("^([^:]+: )(.*)$")
            if e and i==1 then formatted[#formatted+1]=U.DetailPaint(line,"ffd100")
            elseif e and (i==2 or i==4) then formatted[#formatted+1]=U.DetailPaint(line,"9ba7ad")
            elseif label then formatted[#formatted+1]=U.DetailPaint(label,"74c7d5")..U.DetailPaint(value,"c5cdcf")
            else formatted[#formatted+1]=U.DetailPaint(line,"c5cdcf") end
        end
        if mapCaption~="" then table.insert(formatted,1,U.DetailPaint(mapCaption,"cfad64")) end
        m.details.text:SetText(table.concat(formatted,"\n"))
        self:SizeDetails()
        m.reveal:SetShown(e~=nil and not entries:Layer(e.category))
        for _,b in ipairs(m.entryButtons) do b:SetEnabled(e~=nil) end
        for _,b in ipairs(m.deliberateButtons) do b:SetEnabled(e~=nil and not e.entrance) end
        m.deleteButton:SetEnabled(e~=nil and not journal.readOnly and not (e.entrance and journal.entrances.readOnly))
        m.route:SetEnabled(e~=nil and e.category=="route" and not e.entrance)
        self:UpdatePositionButton()
    end
    function c:UpdatePositionButton()
        local button=self.main.position
        local placing=self.main.map.placing==true
        button:SetText(placing and "Cancel" or "Map position")
        button:SetSelected(placing)
        button:SetEnabled(placing or entries:Get(state.selected)~=nil)
    end
    function c:CancelPlacement()
        self.main.map.placing=false;self.placeCallback=nil;self.placeReturn=nil
        self:Message("");self:UpdatePositionButton()
        self:Show();self:Refresh()
    end
    function c:SizeDetails()
        local m=self.main
        m.detailBody:SetHeight(math.max(m.details:GetHeight(),m.details.text:GetStringHeight()+12))
        m.details:UpdateScrollChildRect();m.details:RefreshScrollBar()
        m.details:SetVerticalScroll(math.min(m.details:GetVerticalScroll(),math.max(0,m.detailBody:GetHeight()-m.details:GetHeight())))
    end
    function c:LayoutDetails(progress)
        local m=self.main
        m.notesProgress=progress
        -- Expanded paper starts at -201, just above the map at -205 and
        -- below the zone selector and sub-zone controls ending at -198.
        m.notesOverlay:ClearAllPoints();m.notesOverlay:SetPoint("TOPLEFT",342,-588+383*progress)
        m.notesOverlay:SetHeight(113+383*progress)
        m.details:SetHeight(80+383*progress)
        m.notesPaper:Show()
        self:SizeDetails()
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
                c:SizeDetails()
                m.details:SetVerticalScroll(math.min(m.details:GetVerticalScroll(),math.max(0,m.detailBody:GetHeight()-m.details:GetHeight())))
            end
        end)
    end
    local function build(content)
        c.frame=content
        local compass=content:CreateTexture(nil,"BACKGROUND",nil,0)
        compass:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\AtlasCompassSketch.png")
        compass:SetSize(296,296)
        compass:SetTexCoord(24/320,1,0,296/320)
        compass:SetPoint("BOTTOMLEFT",content,"BOTTOMLEFT",6,21)
        compass:SetAlpha(0.23)
        shell:AddBackgroundLayer(compass,1,1,1,true)
        c.compassIllustration=compass
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
            fadeStrip(5+i,21,1,296,alpha)
            fadeStrip(6,20+i,296,1,alpha)
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
        c.compassCornerFade=ns.FieldbookUI.IllustrationCornerFade(content,shell,21)
        local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m;c.pages.main=m
        local spine=ns.FieldbookUI.PageDivider(m)
        m.pageTitle=ns.FieldbookUI.SectionTitle(m,"Traveller’s Atlas")
        m.search=U.Search(m,70,-110,168,200);m.search:SetText(state.query)
        m.search:HookScript("OnTextChanged",function() state.query=m.search:GetText();state.offset=0;state.indexScroll=0;c:Refresh() end)
        m.listFilter=ns.FieldbookUI.FilterButton(m,244,-110,function(owner)
            if not MenuUtil then return end
            m.search:ClearFocus()
            MenuUtil.CreateContextMenu(owner,function(_,root)
                local categories=root:CreateButton("Category")
                categories:CreateRadio("All categories",function() return not state.listCategory end,function() c:SetListFilter(nil,state.listOrigin) end)
                local choices={};for _,category in ipairs(A.categories) do choices[#choices+1]=category end
                if journal.entrances then choices[#choices+1]=categoryInfo("entrance") end
                for _,category in ipairs(choices) do
                    local id=category.id
                    categories:CreateRadio(category.label,function() return state.listCategory==id end,function() c:SetListFilter(id,state.listOrigin) end)
                end
                local origin=root:CreateButton("Record source")
                for _,choice in ipairs({{"All records",false},{"Automatic entrances","automatic"},{"Deliberate records","deliberate"}}) do
                    local value=choice[2] or nil
                    origin:CreateRadio(choice[1],function() return state.listOrigin==value end,function() c:SetListFilter(state.listCategory,value) end)
                end
                root:CreateButton("Clear list filters",function() c:SetListFilter(nil,nil) end)
            end)
        end)
        m.listFilter.ResetFilters=function() c:SetListFilter(nil,nil) end
        U.StyleSelection(m.listFilter);U.Tip(m.listFilter,"Filter discoveries by category or record source. Right-click to clear list filters.")
        m.listSort=U.Button(m,"",270,-110,22,function(owner)
            if not MenuUtil then return end
            m.search:ClearFocus()
            MenuUtil.CreateContextMenu(owner,function(_,root)
                for _,choice in ipairs({{"Name","name"},{"Zone","zone"},{"Newest first","newest"},{"Oldest first","oldest"}}) do
                    local value=choice[2]
                    root:CreateRadio(choice[1],function() return (state.listSort or "name")==value end,function() c:SetListSort(value) end)
                end
            end)
        end)
        m.listSort:SetSize(22,22)
        for row=0,4 do
            local stroke=m.listSort:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-row*2,1);stroke:SetPoint("CENTER",0,2-row);stroke:SetColorTexture(1,0.82,0.14,1)
        end
        U.Tip(m.listSort,"Sort discoveries by name, zone or first recorded time.")
        m.scope=U.Button(m,"Current map",42,-140,250,function() state.all=not state.all;state.offset=0;state.indexScroll=0;c:Refresh() end)
        U.StyleSelection(m.scope)
        m.count=ns.FieldbookUI.EntryCount(m)
        m.rows={}
        m.list,m.listBody=U.Scroll(m,42,-170,228,LIST_HEIGHT)
        U.ContactListFades(m.list,shell,m,42,-170)
        m.list:HookScript("OnVerticalScroll",function(self,value)
            if not m.updatingList then state.indexScroll=value or self:GetVerticalScroll();c:Refresh() end
        end)
        local function scrollList(_,delta)
            m.list:SetVerticalScroll(math.max(0,math.min(m.listBody:GetHeight()-LIST_HEIGHT,m.list:GetVerticalScroll()-delta*ROW_HEIGHT)))
        end
        m.list:EnableMouseWheel(true);m.list:SetScript("OnMouseWheel",scrollList)
        for i=1,VISIBLE_ROWS do
            local row=CreateFrame("Button",nil,m.listBody,"BackdropTemplate");row:SetPoint("TOPLEFT",0,-(i-1)*ROW_HEIGHT);row:SetSize(228,ROW_HEIGHT-1)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",scrollList)
            ns.FieldbookUI.StyleMenuRow(row)
            row.divider=ns.FieldbookUI.EntryDivider(row,1,228)
            for _,line in ipairs(row.divider) do line:SetShown(i>1) end
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",3,-6);row.icon:SetSize(20,20)
            row.name=U.Label(row,"",32,-6,189,"GameFontHighlightSmall");row.name:SetWordWrap(false)
            local rowTitlePath,rowTitleSize,rowTitleFlags=row.name:GetFont()
            if rowTitlePath and rowTitleSize then row.name:SetFont(rowTitlePath,rowTitleSize+2,rowTitleFlags) end
            row.zone=U.Label(row,"",32,-21,189,"GameFontDisableSmall");row.zone:SetWordWrap(false)
            row:SetScript("OnClick",function(self) if self.id then c:Select(self.id) end end)
            row:SetScript("OnEnter",function(self)
                local e=entries:Get(self.id)
                if e and GameTooltip then
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(A.AutomaticLabel(e.name,e.entrance))
                    GameTooltip:AddLine(A.Safe(e.zone).." • "..categoryInfo(e.category).label,1,1,1)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            m.rows[i]=row
        end
        m.empty=U.Label(m,"",50,-194,233,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(4)
        -- Center the 580-pixel control rows between the divider and inner right edge.
        U.Button(m,"Add Discovery",342,-60,140,function() c:OpenEditor(nil,false,A.CurrentLocation()) end)
        m.expeditions=U.Button(m,"Expeditions",618,-60,116,function() c:Expeditions() end)
        m.expeditions:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Expeditions")
            GameTooltip:AddLine("Keep longer journals for your journeys, exploration plans and field notes. Link an expedition to Atlas discoveries to bring related places and notes together.",1,1,1,true)
            GameTooltip:Show()
        end)
        local function hideExpeditionTooltip() if GameTooltip then GameTooltip:Hide() end end
        m.expeditions:SetScript("OnLeave",hideExpeditionTooltip)
        m.expeditions:HookScript("OnHide",hideExpeditionTooltip)
        m.shareButton=U.ShareButton(m,function() c:Report() end)
        m.capacity=U.Label(m,"Archive: calculating…",42,-701,250,"GameFontDisableSmall")
        m.capacity:SetWordWrap(false)
        local storageJob,storageDetail
        local storageElapsed=30
        local function storageTooltip()
            if GameTooltip then
                GameTooltip:SetOwner(m.capacityHover,'ANCHOR_RIGHT');GameTooltip:SetText(m.capacity:GetText())
                GameTooltip:AddLine(storageDetail or 'Calculating estimated saved-data size…',1,1,1,true);GameTooltip:Show()
            end
        end
        local function refreshStorage()
            if storageJob and storageJob.thread then return end
            storageJob=ns.AtlasSubzones.Queue(function(checkpoint)
                local title,detail=journal:StorageStatus(checkpoint)
                return {title=title,detail=detail}
            end,function(ok,result)
                storageJob=nil
                if ok then m.capacity:SetText(result.title);storageDetail=result.detail
                else m.capacity:SetText('Archive: usage unavailable');storageDetail='Could not estimate saved data.' end
                if GameTooltip and GameTooltip:IsOwned(m.capacityHover) then storageTooltip() end
            end,m)
        end
        m.capacityHover=CreateFrame('Frame',nil,m);m.capacityHover:SetPoint('TOPLEFT',42,-699);m.capacityHover:SetSize(250,20)
        m.capacityHover:EnableMouse(true)
        m.capacityHover:SetScript('OnEnter',function() storageTooltip();refreshStorage() end)
        m.capacityHover:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        m:HookScript('OnShow',function() storageElapsed=30 end)
        m:HookScript('OnHide',function() ns.AtlasSubzones.Cancel(storageJob);storageJob=nil end)
        m:HookScript('OnUpdate',function(_,dt)
            storageElapsed=(storageElapsed or 0)+dt
            if storageElapsed>=30 then storageElapsed=0;refreshStorage() end
        end)
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
        m.zone=U.ZoneMenu(m,342,-174,306,function()
            local ids={state.mapID};for _,row in ipairs(A.MapCatalog(entries)) do ids[#ids+1]=row.mapID end;return ids
        end,function(id,name) c:SetZone(id,name) end,function()
            local location=A.CurrentLocation();c:SetZone(location.mapID,location.zone);c:Message(location.mapID and "Showing your current zone." or "Current map unavailable; you can still record notes.")
        end)
        m.layerMenu=ns.FieldbookUI.FilterButton(m,0,0,function()
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
            local check=U.Check(layers,label,10,y,174,function(on) entries:SetLayer(id,on);c:Refresh() end)
            check.icon=check:CreateTexture(nil,"ARTWORK")
            check.icon:SetPoint("LEFT",check,"RIGHT",2,0);check.icon:SetSize(20,20)
            local info=categoryInfo(id)
            check.icon:SetTexture(info.icon)
            check.label:ClearAllPoints();check.label:SetPoint("TOPLEFT",check, "TOPLEFT",50,-5)
            check.layerID=id;layers.checks[#layers.checks+1]=check;y=y-26
        end
        for _,category in ipairs(A.categories) do addLayer(category.id,category.label) end
        if journal.entrances then addLayer("entrance",categoryInfo("entrance").label) end
        local function all(visible)
            for _,check in ipairs(layers.checks) do entries:SetLayer(check.layerID,visible);check:SetChecked(visible) end
            c:Refresh()
        end
        m.layerMenu.ResetFilters=function() all(true);layers:Hide() end
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
            for _,check in ipairs(layers.checks) do
                check:SetChecked(entries:Layer(check.layerID))
                -- Resolve the shared definition again so icon revisions carry through.
                local info=categoryInfo(check.layerID)
                check.icon:SetTexture(info.icon)
            end
            m.iconSize:Display(A.Number(state.iconSize,6,40) and state.iconSize or 20)
        end)
        m:HookScript("OnHide",function() layers:Hide() end)
        layers:Hide()
        U.Tip(m.layerMenu,"Right-click to reset filters. Choose which discovery markers appear on the map. Check several layers or use Show all / Hide all. The discovery index and sub-zone controls are unchanged.")
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
        U.Tip(m.automaticMapping,"Automatically record sub-zone crossings and interior survey points. Pauses in The Great Sea, on flight paths, while flying, and while dead or a ghost. City mapping is enabled. Loading screens, map changes and large coordinate jumps wait for stable readings; new area labels settle before interior sampling. Manual survey-point keybindings remain available when this is off.")
        m.cleanPoints=U.Button(m,"Clean Redundant Points",754,-60,168,function()
            local allMaps=A.Read(IsControlKeyDown)==true
            local results={}
            local function done(count,message)
                m.cleanPoints:SetEnabled(not journal.readOnly)
                m.cleanPoints.lastCleanup=message or ''
                if allMaps and #results>0 then m.cleanPoints.lastCleanup=m.cleanPoints.lastCleanup..'\n\n'..table.concat(results,'\n\n') end
                storageElapsed=30
                c:Refresh()
                local completion=count and ((count==0 and "|cff00ff00" or "|cffffd100").."[DONE]|r ") or ""
                if message and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r |cff80d0ff"..shell.sections.atlas.definition.title..":|r "..completion..message) end
                c:Message(message or ("Removed "..count.." redundant interior sample"..(count==1 and "." or "s.")))
            end
            local function progress(message)
                if message and message:find('Removed %d+ of %d+ interior points') then results[#results+1]=message end
                c:Message(message)
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r |cff80d0ff"..shell.sections.atlas.definition.title..":|r "..message) end
            end
            local started
            if allMaps then started=ns.AtlasSubzones.CleanAllInterior(journal,done,progress)
            else started=ns.AtlasSubzones.CleanInterior(journal,state.mapID,done,progress) end
            if started then m.cleanPoints:SetEnabled(false);c:Message(allMaps and "Checking interior samples on all saved maps..." or "Checking interior samples on this map...") end
        end)
        m.cleanPoints:SetEnabled(not journal.readOnly)
        U.Tip(m.cleanPoints,"Simplify automatic survey points, including edge points, within a 5-yard outline tolerance on this map; Ctrl+Click for all maps. Protects narrow passages, shared borders, crossings and manual points. Compact coverage remembers removed positions, including edges, without blocking new observations beyond the simplified boundary or in another area. Recording stays at 25 yards. The last cleanup breakdown appears below after a run.")
        m.cleanPoints:HookScript('OnEnter',function(self)
            if GameTooltip and self.lastCleanup then
                GameTooltip:AddLine('Last cleanup',1,0.82,0.14)
                GameTooltip:AddLine(self.lastCleanup,1,1,1,true);GameTooltip:Show()
            end
        end)
        -- Keep the survey controls together within the existing header height.
        local group=CreateFrame("Frame",nil,m,"BackdropTemplate");m.subzoneControls=group
        group:SetPoint("TOPLEFT",660,-91);group:SetSize(262,107);group:EnableMouse(false)
        group:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        group:SetBackdropColor(0.055,0.04,0.022,0.6);group:SetBackdropBorderColor(0.45,0.30,0.13,0.75)
        U.Label(group,"Sub-zones",12,-7,80,"GameFontNormalSmall")
        m.labelSize=U.SmallSlider(group,"",96,-68,0,2,24,1,function(v) return tostring(v) end,function(value)
            if not journal.readOnly then state.subzoneLabelSize=value end
            c:Refresh()
        end)
        m.labelSize:SetWidth(120)
        m.labelSize.valueLabel:ClearAllPoints();m.labelSize.valueLabel:SetPoint("LEFT",m.labelSize,"RIGHT",5,0)
        U.Tip(m.labelSize,"Sub-zone label text size (2–24, default 4). Applies immediately; map zoom also scales labels.")
        m.subzones=U.Check(group,"Shading",10,-23,65,function(on)
            if not journal.readOnly then state.showSubzones=on end;c:Refresh()
        end)
        U.Tip(m.subzones,"Shade self-discovered sub-zones after three non-collinear observations. Crossings and interior samples with more than 25 yards of clearance collect while playing, even with these layers hidden. Points and Labels are independent display options. Hover for evidence details. Separated groups shade independently; isolated dots cannot stretch a distant region. Traced fill bends inward through supporting samples; sparse evidence can still span unknown space. Legacy fill restores the original outline.")
        m.subzonePoints=U.Check(group,"Points",10,-43,88,function(on)
            if not journal.readOnly then state.showSubzonePoints=on end;c:Refresh()
        end)
        U.Tip(m.subzonePoints,"Checked: show every recorded crossing and interior sample, including points incorporated into shading. Ctrl+Alt+Right Click an observation to delete it. Alt-right-click an observation in the Atlas to exclude or restore it; excluded points appear grey with Points on. Unchecked: retain automatic isolated dots with shading and hide incorporated or excluded samples. All dots stay small when zooming.")
        m.subzoneLabels=U.Check(group,"Labels",10,-63,65,function(on)
            if not journal.readOnly then state.showSubzoneLabels=on end;c:Refresh()
        end)
        U.Tip(m.subzoneLabels,"Show discovered sub-zone names independently of boundary shading. Names try two lines before hiding for lack of space. Adjust their text size with the slider to the right.")
        m.hideZoneAreas=U.Check(group,"Hide zone-name areas",10,-83,218,function(on)
            if not journal.readOnly then state.hideZoneNameSubzones=on end;c:Refresh()
        end)
        U.Tip(m.hideZoneAreas,"Hide shading and labels for areas whose name matches the displayed zone (for example Loch Modan in Loch Modan). Sample points, recording and other sub-zones are unchanged.")
        for _,check in ipairs({m.subzones,m.subzonePoints,m.subzoneLabels,m.hideZoneAreas}) do
            check:SetSize(20,20)
        end
        m.map=ns.CreateAtlasMap(m,entries,function(id) c:Select(id) end,function(x,y)
            if c.placeCallback then
                local callback=c.placeCallback;c.placeCallback=nil;m.map.placing=false;c:UpdatePositionButton();c:Message("")
                callback(x,y,state.mapID,state.zone)
            end
        end,function(id,name) c:SetZone(id,name) end)
        m.map.preserveZoomOnMapChange=true
        m.brightness=m.map.brightness
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.layerMenu:SetParent(m.map);m.layerMenu:ClearAllPoints()
        m.layerMenu:SetPoint("TOPLEFT",m.map,"TOPLEFT",8,-8)
        m.layerMenu:SetFrameLevel(m.map:GetFrameLevel()+25)
        m.map.observedLevelRange=function(mapID) return adapters:ObservedLevelRange(mapID) end
        m.map.weatherText=U.Label(m.layerMenu,"",0,0,190,"GameFontHighlightSmall")
        m.map.weatherText:ClearAllPoints()
        m.map.weatherText:SetPoint("LEFT",m.layerMenu,"RIGHT",8,0)
        m.map.weatherText:SetWordWrap(false)
        m.map.weatherText:SetShadowColor(0,0,0,0.85);m.map.weatherText:SetShadowOffset(1,-1)
        local weatherFont,weatherSize,weatherFlags=m.map.weatherText:GetFont()
        if weatherFont and weatherSize then m.map.weatherText:SetFont(weatherFont,weatherSize+2,weatherFlags) end
        m.map.levelText=U.Label(m.layerMenu,"",0,0,270,"GameFontHighlightSmall")
        m.map.levelText:ClearAllPoints()
        m.map.levelText:SetPoint("LEFT",m.map.weatherText,"RIGHT",0,0)
        m.map.levelText:SetWordWrap(false)
        m.map.levelText:SetShadowColor(0,0,0,0.85);m.map.levelText:SetShadowOffset(1,-1)
        if weatherFont and weatherSize then m.map.levelText:SetFont(weatherFont,weatherSize+2,weatherFlags) end

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
        m.expand=U.Button(m.notesOverlay,"",438,0,22,function() c:Expand() end);m.expand:SetSize(22,22)
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
        m.footerBackground=m.notesPaper
        m.details,m.detailBody=U.ReadArea(m.notesOverlay,0,-33,555,80)
        m.details.text:SetShadowColor(0,0,0,0.85);m.details.text:SetShadowOffset(1,-1)
        U.AlignFooterScrollBar(m.details,m.notesPaper,m.expand)
        U.FooterFades(m.details,shell,37)
        c:LayoutDetails(0)
        m.reveal=U.Button(m,"Reveal layer",788,-513,114,function()
            local e=entries:Get(state.selected);if e then entries:SetLayer(e.category,true);c:Refresh() end
        end)
        -- Leave a separate line for the hidden-layer affordance, never cover text.
        m.reveal:ClearAllPoints();m.reveal:SetPoint("TOPLEFT",174,-638)
        local edit=U.Button(m,"Edit",42,-638,120,function() c:OpenEditor(state.selected) end)
        local links=U.Button(m.notesOverlay,"Connections",0,0,128,function() c:Connections(state.selected,false) end)
        m.route=U.Button(m.notesOverlay,"Route stops",134,0,112,function() c:Stops(state.selected) end)
        local notes=U.Button(m.notesOverlay,"Linked notes",252,0,112,function() c:Expeditions(state.selected) end)
        local position=U.Button(m,"Map position",488,-60,124,function()
            if m.map.placing then c:CancelPlacement()
            else c:OpenEditor(state.selected);c:ChoosePosition() end
        end)
        m.position=position;U.StyleSelection(position)
        position:SetMotionScriptsWhileDisabled(true)
        position:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText(m.map.placing and "Cancel placement" or "Map position")
            local explanation=m.map.placing and "Cancel choosing a position and return to the Atlas map. The saved position stays unchanged."
                or (not entries:Get(state.selected) and "Select a discovery first to choose its position on the displayed map."
                or "Choose a position for the selected discovery by clicking the displayed map. Review the chosen coordinates in the editor, then Save to keep them.")
            GameTooltip:AddLine(explanation,1,1,1,true);GameTooltip:Show()
        end)
        local function hidePositionTooltip() if GameTooltip then GameTooltip:Hide() end end
        position:SetScript("OnLeave",hidePositionTooltip);position:HookScript("OnHide",hidePositionTooltip)
        m.entryButtons={edit,links,notes,position}
        m.deliberateButtons={links,notes}
        for _,action in ipairs({{links,"Connections"},{m.route,"Route stops"},{notes,"Linked notes"}}) do
            local button,title=action[1],action[2]
            button:SetMotionScriptsWhileDisabled(true)
            button:SetScript("OnEnter",function(self)
                if self:IsEnabled() or not GameTooltip then return end
                local e=entries:Get(state.selected)
                local reason
                if not e then reason="Select a discovery first."
                elseif e.entrance then reason="Automatically discovered entrances do not support this action. Record a deliberate Atlas discovery to use it."
                else reason="Route stops are available only for Route / Passage discoveries." end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title)
                GameTooltip:AddLine(reason,1,1,1,true);GameTooltip:Show()
            end)
            button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            button:HookScript("OnHide",function() if GameTooltip then GameTooltip:Hide() end end)
        end
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall")
        ns.InstallAtlasEditors(c);ns.InstallAtlasReportUI(c)
        content:SetScript("OnHide",function()
            m.notesOverlay:SetScript("OnUpdate",nil);c:LayoutDetails(m.notesExpanded and 1 or 0)
            m.map:SuspendPlayer()
            if GameTooltip then GameTooltip:Hide() end
            m.search:ClearFocus()
            if c.ClearFocus then c:ClearFocus() end
        end)
        local initial=A.CurrentLocation()
        if initial.mapID then
            state.mapID,state.zone,state.continent=initial.mapID,initial.zone,nil;state.offset=0;state.indexScroll=0
        end
        c:Show();c:Refresh()
        if journal.readOnly then c:Message("Newer Atlas schema: this journal is read-only; saved data is untouched.") end
    end
    shell:RegisterSection("atlas",{title="Traveller’s Atlas",icon="Interface\\Icons\\INV_Misc_Map03",
        help="|cffffd1001. Record a discovery|r\nKeep a journal of places you want to find again. Click Add Discovery, enter a name and category, then Save. Use my current position captures your location; Choose on displayed map lets you place a point yourself. Coordinates may be left blank. For a cave, record its entrance.\n\n"..
            "|cffffd1002. Browse maps|r\nChoose a map or select Current Zone at the top of the zone menu. Search the current map or all recorded zones, then select an index entry or map pin. Your zoom level is retained when changing maps. Selected map icons glow gold. Repeated clicks cycle overlapping pins. Map Layers shows or hides discovery categories; Reveal layer shows a selected entry's hidden category.\n\n"..
            "|cffffd1003. Edit and explore|r\nEdit changes names, notes, access details and explored status. Map position lets you place the selected discovery. Explored is your own assertion: saving a location does not mark it explored. Recorded and Reported identify the source of the information.\n\n"..
            "|cffffd1004. Routes and passages|r\nChoose the Route / Passage category, then Save & route stops. Add recorded places or named waypoints; use Up, Down and Remove to arrange them. Stops can span zones. Map lines connect recorded stops, not guaranteed safe paths.\n\n"..
            "|cffffd1005. Expeditions and connections|r\nUse Expeditions for longer journals and Linked notes to attach them to a discovery. Connections links known Atlas discoveries or records in other supported Fieldbook sections. Removing a link leaves the source record intact.\n\n"..
            "|cffffd1006. Field reports|r\nShare saves a field-report draft for a zone or selected discoveries. Choose what to include, add private notes or expedition excerpts only if wanted, then use Preview report. This page provides drafts and previews only; it cannot send or import reports.\n\n"..
            "|cffffd1007. Self-discovered sub-zones|r\nAutomatic mapping starts on and records area crossings and survey points as you travel, even with the Atlas closed. Toggle Automatic Mapping pauses it. Automatic recording pauses in The Great Sea, on flight paths, while flying, and while dead or a ghost. Loading screens, map changes and large coordinate jumps wait for stable readings; interior samples also wait for new area labels to settle.\n\nBind Record Atlas survey point in the game's keybinding settings to add a point where you stand, including with automatic mapping off. You must be alive, with a readable position and enough distance from existing samples. Clean Redundant Points simplifies automatic survey points, including edge points, within a 5-yard outline tolerance while recording stays at 25 yards. It protects narrow passages, shared borders, crossings and manual points. Compact coverage prevents repeat sampling at cleaned locations; new observations beyond the simplified boundary or in another area remain eligible. Repeated cleanup uses the original remembered positions so its tolerance does not accumulate. Cleanup skips maps with separated observation groups to preserve their separation. Legacy Fill in Options defaults off; it uses less CPU at the expense of outline detail. Survey points no longer store timestamps.\n\nShading, Points and Labels control the Atlas display. Use the world map Filters dropdown to enable Points, Labels and Zones independently on the main map, alongside Merchants and Nodes. Shading estimates an area from your samples; it is not an exact border survey. Separated observation groups shade independently, keeping distant portal dots from stretching an area across the map. Hover the map to inspect the evidence. Ctrl+Alt+Right Click an observation in the Atlas to delete it. Automatic mapping can record new observations there later. Alt-right-click an observation in the Atlas to exclude it from mapping without deleting it. Enable Points to see excluded observations in grey, and use the same gesture to restore them. Sub-zone samples do not add discovery entries or enter field reports.\n\n"..
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
        local message="|cffffd100[Recorded]|r |cff80d0ff"..shell.sections.atlas.definition.title..":|r |cffffffff"..A.AutomaticLabel(name,true).."|r |cff999999("..zone..
            string.format(" • %.1f, %.1f)|r",entry.exterior.x/100,entry.exterior.y/100)
        if bestiary and bestiary.RecordEvent then
            bestiary:RecordEvent(message,{kind="atlas-recorded",entranceID=entry.id,mapID=entry.exterior.mapID,automatic=true})
        end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r "..message) end
    end end
    function AzerothFieldbookRecordAtlasPoint()
        local added,message=journal.subzones:RecordPoint()
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r |cff80d0ff"..shell.sections.atlas.definition.title..":|r "..message) end
        return added
    end
    local adapters=ns.CreateAtlasReferences(bestiary,function() return ns.ActiveSectionStores and ns.ActiveSectionStores.gathering or AzerothFieldbookGatheringDB end,shell)
    return ns.CreateAtlasBook(journal,shell,adapters)
end
