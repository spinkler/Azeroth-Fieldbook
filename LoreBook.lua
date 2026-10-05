local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local L,U=ns.Lore,ns.AtlasUI
local ROW_HEIGHT,LIST_HEIGHT=50,430
local VISIBLE_ROWS=math.ceil(LIST_HEIGHT/ROW_HEIGHT)+1
local icons={writing="Interface\\Icons\\INV_Misc_Book_09",landmark="Interface\\Icons\\INV_Misc_Map_01",person="Interface\\Icons\\INV_Misc_GroupLooking",mystery="Interface\\Icons\\INV_Misc_QuestionMark"}
local statusNames={partial="Partial archive",complete="Complete archive",interrupted="Capture interrupted",failed="Partial archive",unsupported="Automatic full-book capture unavailable"}
local mysteryNames={open="Open",investigating="Investigating",resolved="Resolved by me"}
local natureNames={source="Preserved source text",translation="Player translation",observation="Direct observation",account="Reported account",interpretation="Personal interpretation",annotation="Annotation",paraphrase="Paraphrase",rumour="Rumour",theory="Working theory"}
local function dateText(at) return at and U.Date(at) or "Time unknown" end
local function nonempty(value,fallback) return type(value)=="string" and value~="" and value or fallback end
local function latestReceipt(report)
    local r=report.latestReceipt;if not r then return nil end
    return "Latest delivery — received: "..dateText(r.received).."\n"..
        (r.receivedFrom and "Received from (your record): "..r.receivedFrom or "Actual sender not recorded.")..
        "\nSender claim: "..nonempty(r.sender,"unknown").." (not authenticated)\nExported: "..dateText(r.created)
end
local function provenance(p,report)
    local lines={natureNames[p.nature] or "Preserved passage"}
    if report then
        lines[#lines+1]="Origin: Received report"
        lines[#lines+1]=report.receivedFrom and "Received from (your record): "..report.receivedFrom or "Actual sender not recorded."
        lines[#lines+1]="Sender claim: "..nonempty(report.sender,"unknown").." (not authenticated)"
        lines[#lines+1]="Claimed original observer: "..nonempty(report.originalSource,"unknown")
        lines[#lines+1]="Reported source: "..nonempty(p.source,nonempty(p.sourceTitle,nonempty(report.sourceTitle,report.title or "Unknown")))
        lines[#lines+1]="Not personally encountered. Original capture claims are unverified."
        lines[#lines+1]=latestReceipt(report)
    elseif p.origin=="captured" then
        lines[#lines+1]="Origin: Captured during your encounter"
        lines[#lines+1]=p.personallyViewed and "Presented in the original reader; no claim that you read it." or "Automatically retrieved; not personally opened in the original reader."
    elseif p.origin=="reported" then
        lines[#lines+1]="Origin: Received from "..nonempty(p.sender,"unknown sender").." • not personally encountered"
    else lines[#lines+1]="Origin: Manually recorded by you" end
    if p.source and p.source~="" and not report then lines[#lines+1]="Source: "..p.source end
    if p.sourceTitle and p.sourceTitle~="" then lines[#lines+1]="Source title: "..p.sourceTitle end
    if p.private then lines[#lines+1]=report and "Private passage explicitly included by the sender." or "Private passage; excluded from export unless selected explicitly." end
    if p.speaker and p.speaker~="" then lines[#lines+1]="Speaker: "..p.speaker end
    if p.translation then
        lines[#lines+1]=L.TranslationLabel(p.translation)
        lines[#lines+1]='Player contribution; language and translator attribution are claims. Original text remains separately available.'
    end
    lines[#lines+1]="Method: "..(p.method=="manual" and "manual transcription / record" or p.method or "unknown").." • "..dateText(p.at)
    return table.concat(lines,"\n")
end
local function sourceReader(parent)
    local width,height=543,438
    local reader,body=U.Scroll(parent,342,-215,width,height)
    local header=U.Label(body,"",0,0,width,"GameFontHighlight")
    header:SetWordWrap(true);header:SetSpacing(3);header:SetTextColor(0.65,0.65,0.65)
    local text=U.Label(body,"",0,0,width,"GameFontHighlight")
    text:SetWordWrap(true);text:SetSpacing(4)
    local path,size,flags=text:GetFont()
    reader.overviewRows={}
    function reader:SetText(content,metadata,lore,blocks)
        local hasSource=metadata~=nil
        header:SetText(L.Safe(metadata or ""));header:SetShown(hasSource)
        local top=hasSource and header:GetStringHeight()+20 or 0
        text:ClearAllPoints();text:SetPoint("TOPLEFT",0,-top)
        if path and type(size)=="number" then text:SetFont(path,size+(hasSource and 4 or 0),flags) end
        if hasSource then text:SetTextColor(1,1,1) else text:SetTextColor(0.75,0.8,0.8) end
        text:SetText(L.Safe(hasSource and lore or content))
        text:SetShown(not blocks)
        for _,row in ipairs(self.overviewRows) do row:Hide() end
        local contentHeight=top+text:GetStringHeight()+12
        if blocks then
            local y=0
            for i,block in ipairs(blocks) do
                local row=self.overviewRows[i]
                if not row then row=U.Label(body,"",0,0,width,"GameFontHighlight");self.overviewRows[i]=row end
                local style=block.style
                local font=style=="title" and "GameFontNormalLarge" or style=="heading" and "GameFontNormal" or "GameFontHighlight"
                row:SetFontObject(textFont(font));row:SetWordWrap(true);row:SetSpacing(4)
                if style=="title" then row:SetTextColor(1,0.82,0.14)
                elseif style=="heading" then row:SetTextColor(0.33,0.87,0.93)
                elseif style=="metadata" then row:SetTextColor(0.6,0.63,0.63)
                else row:SetTextColor(0.85,0.85,0.8) end
                row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row:SetText(L.Safe(block.text));row:Show()
                y=y+row:GetStringHeight()+(style=="heading" and 6 or 14)
            end
            contentHeight=y
        end
        body:SetHeight(math.max(height,contentHeight))
        self:UpdateScrollChildRect();self:RefreshScrollBar()
    end
    reader.text=text;reader.header=header
    return reader
end
function ns.CreateLoreBook(journal,tracking,shell,references)
    local state=journal.state
    state.query=type(state.query)=="string" and state.query or ""
    state.offset=L.Integer(state.offset,0,L.MAX_ENTRIES) and state.offset or 0
    state.indexScroll=L.Integer(state.indexScroll,0,1000000) and state.indexScroll or state.offset*ROW_HEIGHT
    state.view="entry"
    state.reading=type(state.reading)=="table" and state.reading or {}
    state.location=L.Integer(state.location,1,L.MAX_LOCATIONS) and state.location or 1
    local c={journal=journal,tracking=tracking,shell=shell,state=state,panels={},references=references or ns.CreateLoreReferences(journal,shell)}
    function c:Message(message) if self.main then self.main.message:SetText(L.Safe(message or "")) end end
    function c:Menu(button,build)
        if MenuUtil and type(MenuUtil.CreateContextMenu)=="function" then MenuUtil.CreateContextMenu(button,build)
        else self:Message("This client does not expose the supported menu control.") end
    end
    function c:Remember()
        if not self.main or not state.selected or not self.main.readerKey then return end
        local r=state.reading[state.selected]
        if r then r.scroll=self.main.reader:GetVerticalScroll() end
    end
    function c:Filter() state.offset=0;state.indexScroll=0;self:Refresh() end
    function c:ResetFilters()
        state.kind=nil;state.zone=nil;state.origin=nil;state.revisit=nil;state.status=nil;state.completeness=nil;state.sort=nil
        state.query="";self.main.search:SetText("");self:Filter()
    end
    function c:Select(id)
        local e=journal:Get(id);if not e then return end
        self:Remember()
        if state.selected~=id then
            state.selected=id;state.location=1;local locations=L.VisibleLocations(e);state.mapID=locations[1] and locations[1].mapID
            self.main.readerKey=nil
        end
        self:Refresh()
    end
    function c:SetView(view)
        self:Remember();state.view=view;self:Refresh()
    end
    function c:Sources(e)
        local rows={{id="overview",label="Entry & personal notes",overview=true}}
        local keys={};for key in pairs(e.pages or {}) do keys[#keys+1]=key end
        table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)=="number" end)
        local seen={}
        if e.firstPage and e.lastPage then for n=e.firstPage,e.lastPage do
            seen[n]=true;rows[#rows+1]={id="page:"..n,label="Page "..n..(not e.pages[n] and " — missing" or ""),page=e.pages[n],missing=not e.pages[n],number=n}
        end end
        for _,key in ipairs(keys) do if not seen[key] then
            rows[#rows+1]={id="page:"..key,label=type(key)=="number" and "Page "..key or "Page order unknown",page=e.pages[key],number=type(key)=="number" and key}
        end end
        local function passage(p,id,label,report)
            rows[#rows+1]={id=id,label=p.translation and L.TranslationLabel(p.translation) or label,page=p,report=report}
            if p.translation then rows[#rows+1]={id=id..':original',label='Original for '..L.TranslationLabel(p.translation),translationOriginal=p.translation,report=report} end
        end
        for i,p in ipairs(e.passages or {}) do passage(p,"passage:"..(p.id or i),"Passage "..i.." • "..(natureNames[p.nature] or "Source")) end
        for index,report in ipairs(e.reports or {}) do
            rows[#rows+1]={id="report:"..index,label="Received report "..index.." • source & selected annotations",report=report}
            for i,p in ipairs(report.pages or {}) do rows[#rows+1]={id="report:"..index..":page:"..i,label="Report "..index.." • "..(p.number and "page "..p.number or "page order unknown"),page=p,report=report} end
            for i,p in ipairs(report.passages or {}) do passage(p,"report:"..index..":passage:"..i,"Report "..index.." • passage "..i,report) end
        end
        return rows
    end
    function c:Overview(e)
        local lines={L.kinds[e.kind]..(e.subtype~="" and " • "..e.subtype or ""),"Created "..dateText(e.created).." • Updated "..dateText(e.updated)}
        if e.firstEncounter then lines[#lines+1]="First encounter "..dateText(e.firstEncounter).." • Last encounter "..dateText(e.lastEncounter) end
        if e.sourceTitle and e.sourceTitle~="" then lines[#lines+1]="Observed source title: "..e.sourceTitle end
        if e.kind=="writing" then
            local s=journal:WritingSummary(e)
            lines[#lines+1]=(statusNames[s.status] or "Partial archive").." • Pages captured: "..s.captured..(s.last and s.first==1 and " / "..s.last or " • total unknown")
            if #s.missing>0 then lines[#lines+1]="Missing pages: "..table.concat(s.missing,", ") end
            if s.reason and s.reason~="" then lines[#lines+1]="Capture detail: "..s.reason end
            if e.variantOf then lines[#lines+1]="Content variant of "..e.variantOf..". Conflicting text is preserved separately." end
            lines[#lines+1]="Capturing a source preserves its claims; it does not establish their truth. Choose a captured page or passage above."
        elseif e.kind=="mystery" then lines[#lines+1]="Status: "..(mysteryNames[e.status] or "Open").." • your investigation" end
        if e.description and e.description~="" then lines[#lines+1]="Your description / observations (private)\n"..e.description end
        if e.theory and e.theory~="" then lines[#lines+1]="Your working theory (private)\n"..e.theory end
        if e.nextStep and e.nextStep~="" then lines[#lines+1]="Next step (private)\n"..e.nextStep end
        if e.notes and e.notes~="" then lines[#lines+1]="Your personal notes (private)\n"..e.notes end
        if #e.tags>0 then lines[#lines+1]="Tags: "..table.concat(e.tags,", ") end
        if e.revisit then lines[#lines+1]="Revisit / follow up flagged" end
        if #e.passages>0 then lines[#lines+1]=#e.passages.." source passages / observations available in the reader selector." end
        if #(e.reports or {})>0 then lines[#lines+1]=#e.reports.." received reports. Select a report in the reader to inspect its source claims and chosen annotations." end
        if #e.locations>0 then
            local locations={"Locations"};for _,p in ipairs(e.locations) do locations[#locations+1]=L.LocationLabel(p) end
            lines[#lines+1]=table.concat(locations,"\n")
        end
        if #e.links>0 then
            local links={"Related entries — open / manage with Related"}
            for _,ref in ipairs(e.links) do
                local current,title=c.references:Resolve(ref)
                links[#links+1]=title..": "..(ref.label or ref.name or "Reference")..(current.missing and " [unavailable]" or "")..
                    (ref.explanation and ref.explanation~="" and " — "..ref.explanation or "")
            end
            lines[#lines+1]=table.concat(links,"\n")
        end
        local blocks={}
        local headings={
            ["Your description / observations (private)"]=true,["Your working theory (private)"]=true,
            ["Next step (private)"]=true,["Your personal notes (private)"]=true,
            ["Locations"]=true,["Related entries — open / manage with Related"]=true,
        }
        for i,value in ipairs(lines) do
            local heading,body=value:match("^([^\n]+)\n(.*)$")
            if heading and headings[heading] then
                blocks[#blocks+1]={text=heading,style="heading"}
                blocks[#blocks+1]={text=body,style="body"}
            else blocks[#blocks+1]={text=value,style=i==1 and "title" or "metadata"} end
        end
        return table.concat(lines,"\n\n"),nil,nil,blocks
    end
    function c:SourceText(e,row)
        if row.overview then return self:Overview(e) end
        if row.missing then return "This page has not been preserved. Missing text is never filled from an external source." end
        if row.translationOriginal then
            local t=row.translationOriginal
            local metadata='Original supplied with translation\n'..t.sourceTitle..'\n'..L.TranslationLabel(t)..
                (row.report and '\nReceived with a player report; not personally encountered or independently verified.' or '\nExact source text selected when this translation was recorded.')
            local text=L.Plain(t.sourceRaw);return metadata..'\n\n'..text,metadata,text
        end
        if row.page then
            local p=row.page
            local metadata=provenance(p,row.report)
            local lore=p.raw=="" and "[This source page was empty.]" or L.Plain(p.raw or "")
            return metadata.."\n\n"..lore,metadata,lore
        end
        local r=row.report;local lines={row.label,r.receivedFrom and "Received from (your record): "..r.receivedFrom or "Actual sender not recorded.",
            "Sender claim: "..nonempty(r.sender,"unknown").." (not authenticated)","Claimed original observer: "..nonempty(r.originalSource,"unknown"),"Received: "..dateText(r.received),
            "Reported source: "..nonempty(r.sourceTitle,nonempty(r.title,"Unknown")),"Not personally encountered. Sender and original observer claims are not independently verified."}
        lines[#lines+1]=latestReceipt(r)
        for _,key in ipairs({"description","notes","theory","nextStep"}) do
            local value=r.annotations and r.annotations[key]
            if value and value~="" then lines[#lines+1]="Reported "..key.." (sender explicitly included)\n"..value end
        end
        for _,p in ipairs(r.locations or {}) do lines[#lines+1]="Reported: "..L.LocationLabel(p) end
        for _,ref in ipairs(r.references or {}) do lines[#lines+1]="Reference only: "..(ref.label or ref.name or "Unknown") end
        return table.concat(lines,"\n\n")
    end
    function c:Page(delta,id)
        local e=journal:Get(state.selected);if not e then return end
        self:Remember();local r=state.reading[e.id];local rows=self:Sources(e);local index=1
        for i,row in ipairs(rows) do if row.id==r.source then index=i;break end end
        index=math.max(1,math.min(#rows,index+(delta or 0)));r.source=id or rows[index].id;r.scroll=0;self.main.readerKey=nil;self:Refresh()
    end
    function c:Refresh()
        if not self.main then return end
        local m=self.main;self:Remember()
        local rows=journal:List(state);self.rows=rows
        local scroll=math.max(0,math.min(state.indexScroll,math.max(0,#rows*ROW_HEIGHT-LIST_HEIGHT)))
        state.indexScroll=scroll
        m.updatingList=true;m.listBody:SetHeight(math.max(LIST_HEIGHT,#rows*ROW_HEIGHT))
        m.list:SetVerticalScroll(scroll);m.list:UpdateScrollChildRect();m.list:RefreshScrollBar();m.updatingList=nil
        local first=math.floor(scroll/ROW_HEIGHT)
        for i,row in ipairs(m.rows) do
            local e=rows[first+i];row.id=e and e.id;row:SetShown(e~=nil)
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+i-1)*ROW_HEIGHT)
            if e then
                row.name:SetText(L.AutomaticLabel(journal:Title(e),L.IsAutomatic(e)));row.icon:SetTexture(icons[e.kind]);row:SetSelected(e.id==state.selected)
                local text=L.kinds[e.kind]
                if e.kind=="writing" then text=text.." • "..(journal:WritingSummary(e).complete and "complete" or "partial") end
                if e.kind=="mystery" then text=text.." • "..(mysteryNames[e.status] or "Open") end
                if e.revisit then text=text.." • revisit" end
                if #(e.reports or {})>0 then text=text.." • reports" end
                row.context:SetText(L.Safe(text))
            end
        end
        m.empty:SetShown(#rows==0);m.empty:SetText(next(journal.entries) and "No matching entries.\nTry clearing the filters." or
            "Your archive begins empty.\n\nOpen supported readable lore to preserve it, or record a writing, landmark, person or mystery.")
        local usage=journal:StorageStatus();m.capacity:SetText(usage)
        m.count:SetCounts(#journal:List(),#rows)
        local filters=0;for _,key in ipairs({"kind","zone","origin","revisit","status","completeness"}) do if state[key] then filters=filters+1 end end
        m.filters:SetSelected(filters>0)
        local e=journal:Get(state.selected);m.name:SetText(e and L.AutomaticLabel(journal:Title(e),L.IsAutomatic(e)) or "Your personal archive")
        m.deleteButton:SetEnabled(e~=nil and not journal.readOnly)
        for _,control in ipairs({m.edit,m.revisit,m.related,m.more,m.sourceMenu,m.locationMenu,m.addLocation,m.place}) do control:SetEnabled(e~=nil and not journal.readOnly) end
        -- Reading and reference navigation remain available for a future-schema archive.
        m.sourceMenu:SetEnabled(e~=nil);m.related:SetEnabled(e~=nil);m.locationMenu:SetEnabled(e~=nil)
        m.revisit:SetText(e and e.revisit and "Revisit: Yes" or "Revisit: No")
        m.locationView:SetSelected(state.view=="location")
        for _,control in ipairs({m.reader,m.sourceMenu,m.pagePrevious,m.pageNext}) do control:SetShown(state.view=="entry") end
        for _,control in ipairs({m.map,m.locationMenu,m.addLocation,m.place,m.locationDescription,m.mapZone}) do control:SetShown(state.view=="location") end
        if state.view=="entry" then
            local content,key,scroll,metadata,lore,blocks
            if e then
                local sources=self:Sources(e);self.sources=sources
                local r=state.reading[e.id]
                if type(r)~="table" then r={};state.reading[e.id]=r end
                local selected,index
                for i,v in ipairs(sources) do if v.id==r.source then selected=v;index=i;break end end
                if not selected then index=e.kind=="writing" and #sources>1 and 2 or 1;selected=sources[index];r.source=selected.id;r.scroll=0 end
                content,metadata,lore,blocks=self:SourceText(e,selected);key=e.id..":"..selected.id;scroll=type(r.scroll)=="number" and r.scroll or 0
                m.sourceMenu:SetText(L.Safe(selected.label));m.pagePrevious:SetEnabled(index>1);m.pageNext:SetEnabled(index<#sources)
            else
                content="The Atlas remembers where something is. Lorekeeper's Chronicle remembers what you found out about it—and what you still don't understand.\n\nEncounter a source, preserve its words, add your thoughts, connect your evidence and leave yourself a reason to return.\n\nAutomatic book capture works in the background. It never opens this window or changes your selected entry."
                m.sourceMenu:SetText("Preserved sources & personal notes");m.pagePrevious:SetEnabled(false);m.pageNext:SetEnabled(false);scroll=0
            end
            if m.readerContent~=content or m.readerKey~=key then m.reader:SetText(content,metadata,lore,blocks);m.readerContent=content;m.readerKey=key;m.reader:SetVerticalScroll(scroll) end
        else
            local locations=L.VisibleLocations(e);local p=locations[state.location]
            if not p and #locations>0 then state.location=1;p=locations[1] end
            m.locationMenu:SetText(p and L.Safe(L.LocationLabel(p)) or "No local location recorded")
            m.locationDescription:SetText(L.Safe(p and (L.LocationLabel(p)..(p.note and p.note~="" and "\n"..p.note or "")) or "Add an observation or deliberately place a landmark. A mentioned place does not create a discovered location."))
            m.mapZone:SetText(state.mapID and "Map "..state.mapID or "Choose map")
            m.map:Render();m.place:SetText(m.map.placing and "Cancel placement" or "Place landmark on map")
        end
        if journal.readOnly then self:Message("Unsupported Lore save: read-only view. Original saved data is untouched.")
        elseif journal.invalid>0 then self:Message(journal.invalid.." malformed saved entries are preserved but excluded from this view.") end
    end
    L.InstallEditors(c)
    local function build(content)
        c.frame=content;local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m
        local spine=ns.FieldbookUI.PageDivider(m)
        m.pageTitle=ns.FieldbookUI.SectionTitle(m,"Lorekeeper's Chronicle")
        m.search=U.Search(m,70,-110,168,200);m.search:SetText(state.query)
        m.search:HookScript("OnTextChanged",function() state.query=m.search:GetText();c:Filter() end)
        m.filters=ns.FieldbookUI.FilterButton(m,244,-110,function(button)
            m.search:ClearFocus()
            c:Menu(button,function(_,root)
                -- Each submenu owns one state key; other groups retain their selection.
                local function checkbox(parent,label,key,value)
                    local item=parent:CreateCheckbox(label,function() return state[key]==value end,function()
                        state[key]=value;c:Filter()
                    end)
                    item:SetResponse(MenuResponse.Refresh)
                    return item
                end
                local kinds=root:CreateButton("Entry Kinds")
                checkbox(kinds,"All entry kinds","kind",nil)
                for _,kind in ipairs({"writing","landmark","person","mystery"}) do checkbox(kinds,L.kinds[kind],"kind",kind) end
                root:CreateDivider();root:CreateTitle("Filters")
                local zones=root:CreateButton("Zone / location");zones:SetScrollMode(420)
                checkbox(zones,"All recorded zones","zone",nil)
                local all={};for _,e in pairs(journal.entries) do
                    for _,p in ipairs(e.locations) do if p.zone~="" then all[p.zone]=true end end
                    for _,r in ipairs(e.reports or {}) do for _,p in ipairs(r.locations or {}) do if p.zone and p.zone~="" then all[p.zone]=true end end end
                end
                local names={};for name in pairs(all) do names[#names+1]=name end;table.sort(names)
                for _,name in ipairs(names) do checkbox(zones,L.Safe(name),"zone",name) end
                local origin=root:CreateButton("Origin")
                for _,row in ipairs({{"","Any origin"},{"captured","Captured in your interaction"},{"manual","Manually recorded"},{"reported","Received reports"}}) do
                    checkbox(origin,row[2],"origin",row[1]~="" and row[1] or nil)
                end
                local revisit=root:CreateCheckbox("Only revisit / follow up",function() return state.revisit==true end,function() state.revisit=not state.revisit or nil;c:Filter() end)
                revisit:SetResponse(MenuResponse.Refresh)
                local complete=root:CreateButton("Writing completeness")
                checkbox(complete,"Any","completeness",nil)
                for _,key in ipairs({"complete","partial","interrupted","unsupported"}) do checkbox(complete,statusNames[key],"completeness",key) end
                local status=root:CreateButton("Mystery status")
                checkbox(status,"Any","status",nil)
                for _,key in ipairs({"open","investigating","resolved"}) do checkbox(status,mysteryNames[key],"status",key) end
                root:CreateDivider()
                local clear=root:CreateButton("Clear",function() c:ResetFilters() end)
                clear:SetResponse(MenuResponse.Refresh)
            end)
        end)
        m.filters.ResetFilters=function() c:ResetFilters() end
        U.StyleSelection(m.filters)
        m.sort=U.Button(m,"",270,-110,22,function(button)
            m.search:ClearFocus()
            c:Menu(button,function(_,root)
                root:CreateTitle("Sort by")
                for _,choice in ipairs({{"","Title"},{"newest","Recently added"},{"updated","Recently updated"}}) do
                    root:CreateButton((state.sort or "")==choice[1] and choice[2].." (selected)" or choice[2],function() state.sort=choice[1]~="" and choice[1] or nil;c:Filter() end)
                end
            end)
        end)
        m.sort:SetSize(22,22)
        for row=0,4 do
            local stroke=m.sort:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-row*2,1);stroke:SetPoint("CENTER",0,2-row);stroke:SetColorTexture(1,0.82,0.14,1)
        end
        for _,item in ipairs({{m.filters,"Filter entries\nRight-click to reset filters."},{m.sort,"Sort"}}) do
            item[1]:SetScript("OnEnter",function(self)
                if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(item[2]);GameTooltip:Show() end
            end)
            item[1]:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        end
        m.rows={}
        m.list,m.listBody=U.Scroll(m,42,-173,228,LIST_HEIGHT)
        m.list:HookScript("OnVerticalScroll",function(self,value)
            if not m.updatingList then state.indexScroll=value or self:GetVerticalScroll();c:Refresh() end
        end)
        local function scrollList(_,delta)
            m.list:SetVerticalScroll(math.max(0,math.min(m.listBody:GetHeight()-LIST_HEIGHT,m.list:GetVerticalScroll()-delta*ROW_HEIGHT)))
        end
        m.list:EnableMouseWheel(true);m.list:SetScript("OnMouseWheel",scrollList)
        for i=1,VISIBLE_ROWS do
            local row=CreateFrame("Button",nil,m.listBody,"BackdropTemplate");row:SetPoint("TOPLEFT",0,-(i-1)*ROW_HEIGHT);row:SetSize(228,49)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",scrollList)
            ns.FieldbookUI.StyleMenuRow(row)
            row.divider=ns.FieldbookUI.EntryDivider(row,1,228)
            for _,line in ipairs(row.divider) do line:SetShown(i>1) end
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",7,-9);row.icon:SetSize(20,20)
            row.name=U.Label(row,"",33,-7,188,"GameFontHighlightSmall");row.name:SetWordWrap(false)
            row.context=U.Label(row,"",33,-28,188,"GameFontDisableSmall");row.context:SetWordWrap(false)
            row:SetScript("OnClick",function(self) if self.id then c:Select(self.id) end end);m.rows[i]=row
        end
        m.empty=U.Label(m,"",46,-184,242,"GameFontHighlight");m.empty:SetWordWrap(true)
        m.capacity=U.Label(m,"",42,-701,250,"GameFontDisableSmall")
        m.capacity:SetWordWrap(false)
        m.capacityHover=CreateFrame('Frame',nil,m);m.capacityHover:SetPoint('TOPLEFT',42,-699);m.capacityHover:SetSize(250,20)
        m.capacityHover:EnableMouse(true)
        m.capacityHover:SetScript('OnEnter',function(self)
            if GameTooltip then
                local title,detail=journal:StorageStatus()
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(title);GameTooltip:AddLine(detail,1,1,1,true);GameTooltip:Show()
            end
        end)
        m.capacityHover:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        m.count=ns.FieldbookUI.EntryCount(m)
        m.new=U.MenuButton(m,"Record…",42,-638,120,function(button)
            c:Menu(button,function(_,root)
                for _,row in ipairs({{"writing","Transcribe writing"},{"landmark","Record Landmark"},{"person","Manual person"},{"mystery","Create Mystery"}}) do root:CreateButton(row[2],function() c:Edit(row[1]) end) end
                root:CreateDivider();root:CreateButton("Record current Person",function()
                    local e,err=tracking:RecordPerson();if e then c:Select(e.id) else c:Message(err or "No supported NPC. Use Manual person.") end
                end)
                root:CreateButton("Capture / retry current text",function()
                    local ok,err=tracking:CaptureCurrent();c:Message(err or (ok and "Capture requested. Keep the source interaction open." or "No supported readable interaction is active."));c:Refresh()
                end)
            end)
        end)
        m.savePassage=U.Button(m,"Save Passage",173,-638,119,function()
            local e,err=tracking:SavePassage();if e then c:Select(e.id) else c:Message(err or "No supported displayed dialogue. Use manual transcription.") end
        end)
        m.shareButton=U.ShareButton(m,function()
            c:Menu(m.shareButton,function(_,root)
                root:CreateButton("Export report",function() if c.reportUI then c.reportUI:OpenExport() end end)
                root:CreateButton("Import report",function() if c.reportUI then c.reportUI:OpenImport() end end)
            end)
        end)
        m.name=U.Label(m,"",342,-60,566,"GameFontNormalLarge");m.name:SetWordWrap(false)
        m.name:SetShadowColor(0,0,0,0.85);m.name:SetShadowOffset(1,-1)
        local titlePath,titleSize,titleFlags=m.name:GetFont()
        if titlePath and titleSize then m.name:SetFont(titlePath,titleSize+2,titleFlags) end
        m.locationView=U.Button(m,"Location",832,-60,104,function()
            c:SetView(state.view=="location" and "entry" or "location")
        end);U.StyleSelection(m.locationView)
        m.locationView:ClearAllPoints();m.locationView:SetPoint("TOPRIGHT",m,"TOPRIGHT",-24,-60)
        m.name:SetWidth(0);m.name:SetPoint("TOPRIGHT",m.locationView,"TOPLEFT",-8,0)
        m.edit=U.Button(m,"Edit",566,-99,76,function() c:Edit(nil,state.selected) end)
        m.revisit=U.Button(m,"Revisit: No",652,-99,128,function() local e=journal:Get(state.selected);if e then journal:Update(e.id,{revisit=not e.revisit});c:Refresh() end end)
        m.related=U.Button(m,"Related",790,-99,120,function() c:Relationships() end)
        m.more=U.MenuButton(m,"Sources / manage",342,-137,190,function(button)
            c:Menu(button,function(_,root)
                root:CreateButton("Add passage / transcription",function() c:Passage() end)
                root:CreateButton("Add translation of selected text",function() c:Translation() end)
                root:CreateButton("Remove manual annotation",function() c:RemovePassage() end)
                root:CreateButton("Add location",function() c:Location() end)
            end)
        end)
        m.deleteButton=U.Button(m,"Delete",174,-672,118,function()
            local e=journal:Get(state.selected);if not m:IsVisible() or not e or journal.readOnly then return end
            local id=e.id
            m.deleteForm=m.deleteForm or ns.FieldbookUI.DeletePanel(m,shell,"Delete archive entry")
            m.deleteForm:Open("Delete “"..journal:Title(e).."” and its preserved text, personal notes and reports?\n\nOther entries and linked evidence remain. This cannot be undone. You can archive this source again later.",function()
                if state.selected~=id or journal:Get(id)~=e then return nil,"Selection changed; nothing deleted." end
                local ok,err=journal:Delete(id)
                if ok then c:Refresh() end
                return ok,err
            end)
        end)
        m.sourceMenu=U.MenuButton(m,"Preserved sources & notes",342,-175,392,function(button)
            local e=journal:Get(state.selected);if not e then return end
            c:Menu(button,function(_,root) root:SetScrollMode(420);for _,row in ipairs(c:Sources(e)) do root:CreateButton(L.Safe(row.label),function() c:Page(0,row.id) end) end end)
        end)
        m.pagePrevious=U.Button(m,"<",747,-175,73,function() c:Page(-1) end)
        m.pageNext=U.Button(m,">",832,-175,78,function() c:Page(1) end)
        m.reader=sourceReader(m)
        m.reader:HookScript("OnVerticalScroll",function() c:Remember() end)
        m.locationMenu=U.MenuButton(m,"Recorded location",342,-175,569,function(button)
            local e=journal:Get(state.selected);if not e then return end
            c:Menu(button,function(_,root) root:SetScrollMode(420);for i,p in ipairs(L.VisibleLocations(e)) do root:CreateButton(L.Safe(L.LocationLabel(p)),function() state.location=i;state.mapID=p.mapID;c:Refresh() end) end end)
        end)
        m.map=ns.CreateLoreMap(m,journal,function() return state.selected,state.location,state.mapID end,function(index)
            state.location=index;local locations=L.VisibleLocations(journal:Get(state.selected));state.mapID=locations[index] and locations[index].mapID;c:Refresh()
        end,function(x,y)
            m.map.placing=false
            local loc={meaning="landmark",zone="",mapID=state.mapID,x=x,y=y,precision="manual",origin="manual"}
            local info=L.Read(C_Map and C_Map.GetMapInfo,state.mapID);loc.zone=type(info)=="table" and info.name or ""
            c:Location(nil,loc)
        end)
        -- Exact Traveller's Atlas anchor. The shared map factory owns dimensions.
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.locationDescription=U.Label(m,"",342,-590,566,"GameFontHighlightSmall");m.locationDescription:SetWordWrap(true)
        m.mapZone=U.ZoneMenu(m,342,-638,180,function()
            local ids={};for _,e in pairs(journal.entries) do for _,p in ipairs(L.VisibleLocations(e)) do if p.mapID then ids[#ids+1]=p.mapID end end end;return ids
        end,function(id) state.mapID=id;c:Refresh() end)
        m.addLocation=U.MenuButton(m,"Locations…",534,-638,150,function(button)
            c:Menu(button,function(_,root)
                root:CreateButton("Add observation / location",function() c:Location() end)
                root:CreateButton("Inspect / remove selected",function() c:Location(state.location) end)
            end)
        end)
        m.place=U.Button(m,"Place landmark on map",697,-638,214,function()
            if not state.mapID or not m.map.available then c:Message("Choose an available map first.");return end
            m.map.placing=not m.map.placing;c:Refresh();c:Message(m.map.placing and "Click a deliberate landmark position on the map; review it before saving." or "Placement cancelled.")
        end)
        m.message=U.Label(m,"",342,-677,568,"GameFontHighlightSmall");m.message:SetWordWrap(true)
        if ns.CreateLoreReportUI then c.reportUI=ns.CreateLoreReportUI(content,journal,function() return state.selected end,function(id)
            if id then c:Select(type(id)=="table" and id.id or id) else c:Refresh() end
        end,shell) end
        content:SetScript("OnHide",function()
            c:Remember();m.search:ClearFocus();m.map.placing=false
            for _,p in pairs(c.panels) do for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
            if GameTooltip then GameTooltip:Hide() end
        end)
        c:Refresh()
    end
    shell:RegisterSection("lore",{title="Lorekeeper's Chronicle",icon=icons.writing,frameName="AzerothFieldbookLoreSection",build=build,sharedEventLog=true,
        help=L.HELP or "Lorekeeper's Chronicle preserves writings, significant places, people and personal investigations. Use search and Filters to find known entries by kind, location or source.\n\nOpen a supported readable source to archive its text. Automatically archive readable lore and Only archive pages I open both start on in Options. Turn off the second option to request the whole accessible book where supported; keep the reader open while pages are retrieved. An interrupted capture can leave a partial archive. Automatically retrieved pages are labelled separately from pages presented to you; neither proves you read or understood them.\n\nUse Record… > Capture / retry current text for an open supported source, or Record… > Transcribe writing for a manual entry. After saving, Sources / manage > Add passage / transcription lets you enter source text. Edit keeps your description and private notes separate from that text.\n\nFor People, use Record… > Record current Person with a supported NPC selected or in conversation. Save Passage preserves the currently displayed supported gossip or quest text. Manual person and Add passage / transcription let you record other sources yourself.\n\nIn Entry, use the reader selector to choose captured pages, manual passages, received reports or Entry & personal notes. Archived text remains available away from its source and after reload. A partial archive contains only the pages actually preserved.\n\nUse Record… > Record Landmark to create a place entry. Location shows its recorded positions; Place landmark on map lets you place one deliberately. Read here records where text was encountered, not where a carried letter originated. Approximate observation positions are distinct from landmark positions.\n\nCreate Mystery records a question, working theory, next step and status. Related links it to known evidence. Resolved by me is your conclusion and can be reopened. Removing a link does not delete its evidence.\n\nFor a copyable report, select Share > Export report, choose the pages, passages and locations, then Prepare exact preview. Private notes and interpretations start excluded. To receive one, use Share > Import report, paste the text, Preview pasted report, then Accept reported material. Received material retains source attribution and stays separate from your own encounters; accepting it does not verify its claims.\n\nFor a player translation, share the original page with another player. They select it in their reader and use Sources / manage > Add translation of selected text. They can enter readable text or choose their own readable capture, then export Local sources with Passages / translations included. Select your original entry when importing the reply and check Attach to selected entry. Both the translation and its original snapshot remain in the reader, with language labels and translator credit. Translations are player contributions, not automatic decoding.\n\nAccount-wide tracking in Options applies to Lore too. It starts on; turn it off to use this character's separate archive after /reload. Existing character entries import once; later changes in the two scopes stay separate.",
        onOpen=function(context)
            if context and context.entryID then c:Select(context.entryID) end
            c:Refresh()
        end})
    local previous=journal.onChange
    journal.onChange=function(...)
        if previous then previous(...) end
        if c.main and shell.active=="lore" and shell:GetFrame():IsShown() and not c.refreshQueued then
            c.refreshQueued=true
            local function refresh() c.refreshQueued=false;if shell.active=="lore" and shell:GetFrame():IsShown() then c:Refresh() end end
            if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.1,refresh) else refresh() end
        end
    end
    return c
end
