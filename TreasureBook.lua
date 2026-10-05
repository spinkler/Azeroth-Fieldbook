local _, ns = ...
local T,U=ns.Treasure,ns.AtlasUI
local ROW_HEIGHT,LIST_HEIGHT=60,440
local VISIBLE_ROWS=math.ceil(LIST_HEIGHT/ROW_HEIGHT)+1
local HISTORY_PAGE=8
local categories={world="World finds",portable="Portable",salvage="Salvage"}
local knowledge={personal="Personal",reported="Reported only",missing="No contents",contents="Has contents"}
local function icon(item)
    local value=item and item.itemID and T.Read(C_Item and C_Item.GetItemIconByID or GetItemIcon,item.itemID)
    return T.Integer(value,1,2147483647) and value or T.ICON
end
local function itemTooltip(owner,item,journal)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
    local native=false
    if item.itemID and type(GameTooltip.SetHyperlink)=="function" then native=pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..item.itemID) end
    if not native then GameTooltip:SetText(T.Safe(journal:ItemName(item))) end
    GameTooltip:Show()
end
function ns.CreateTreasureBook(journal,tracking,shell)
    local state=journal.state
    state.query=T.Text(state.query,200,true) and state.query or ""
    state.offset=T.Integer(state.offset,0,T.MAX_KINDS) and state.offset or 0
    state.indexScroll=T.Number(state.indexScroll,0,1000000) and state.indexScroll or state.offset*ROW_HEIGHT
    state.showContents=state.showContents==true or state.detail=="contents"
    state.detail=({summary=true,history=true,notes=true})[state.detail] and state.detail or "summary"
    state.detailScroll=T.Number(state.detailScroll,0,1000000) and state.detailScroll or 0
    state.historyOffset=T.Integer(state.historyOffset,0,T.MAX_ENCOUNTERS) and state.historyOffset or 0
    state.bookmarks=state.bookmarks==true;state.allZone=state.allZone==true
    state.mapID=T.Integer(state.mapID,1,2147483647) and state.mapID or nil
    if not categories[state.category] then state.category=nil end
    if not knowledge[state.knowledge] then state.knowledge=nil end
    if not T.Text(state.zone,160) then state.zone=nil end
    local c={journal=journal,tracking=tracking,shell=shell,state=state,panels={}}
    function c:Message(message) if self.main then self.main.message:SetText(T.Safe(message or "")) end end
    function c:Menu(button,build)
        if MenuUtil and type(MenuUtil.CreateContextMenu)=="function" then MenuUtil.CreateContextMenu(button,build) end
    end
    function c:Filter() state.offset=0;state.indexScroll=0;self:Refresh() end
    function c:ResetFilters()
        state.category=nil;state.zone=nil;state.knowledge=nil;state.bookmarks=false;state.query="";state.sort=nil
        self.main.search:SetText("");self:Filter()
    end
    function c:Select(id)
        local e=journal:Get(id);if not e then return end
        if state.selected~=id then
            state.selected=id;state.encounter=nil;state.detailScroll=0;state.historyOffset=0;self.main.details:SetVerticalScroll(0);self.main.contents:SetVerticalScroll(0)
            local history=journal:History(id);local chosen=history[1]
            for _,v in ipairs(history) do if (v.context=="world" or v.context=="acquired") and v.location.mapID then chosen=v;break end end
            state.encounter=chosen and chosen.id;state.mapID=chosen and chosen.location.mapID
        end
        self:Refresh()
    end
    function c:Encounter(id)
        local v=journal.encounters[id];if not v then return end
        -- All-zone pins may focus another kind's encounter without changing the catalogue selection.
        state.encounter=id;state.detail="history";state.detailScroll=0;state.historyOffset=0
        if v.location.mapID then state.mapID=v.location.mapID end
        self.main.details:SetVerticalScroll(0);self:Refresh()
    end
    function c:DetailRows(detail)
        detail=detail or state.detail
        local e=journal:Get(state.selected);local rows={}
        local function add(text,item,encounter,style,title) rows[#rows+1]={text=text,item=item,encounter=encounter,style=style,title=title} end
        if not e then
            add("Your journal begins with finds you record or openable items observed in your bags. Use Record a find for world containers and salvage. No undiscovered finds are included.")
            return rows
        end
        local all=journal:History(e.id);local history={};local summary=journal:Summary(e)
        state.historyOffset=math.min(state.historyOffset,math.max(0,math.floor((#all-1)/HISTORY_PAGE)*HISTORY_PAGE))
        for i=state.historyOffset+1,math.min(#all,state.historyOffset+HISTORY_PAGE) do history[#history+1]=all[i] end
        if #all>HISTORY_PAGE then add("Showing encounters "..(state.historyOffset+1).."–"..math.min(#all,state.historyOffset+HISTORY_PAGE).." of "..#all..". Use Newer / Older above the map.",nil,nil,"guidance") end
        if detail=="summary" then
            add((e.form=="world" and "World find" or "Portable container").." • "..e.category.."\n"..
                (e.itemID and "Item identity: "..e.itemID or "Provisional kind: "..e.id..". Matching names do not prove matching kinds."))
            add(summary.knowledge.." • "..summary.personal.." personal recorded encounters • "..summary.reported.." reported encounters\n"..
                summary.inspections.." personal inspections • "..summary.recoveries.." items explicitly recorded as recovered",nil,nil,"body","Recorded encounters")
            add(summary.contents==0 and "Contents not recorded. This does not mean the container was empty." or "Contents observations retain their own encounter, location and source. Missing items in partial captures are not confirmed absences.",nil,nil,"guidance","Contents evidence")
            for _,v in ipairs(history) do if v.access~="" then
                add("Access ("..(v.reported and "reported / " or "")..v.accessMethod.."): "..v.access.."\n"..T.Date(v.origin.at).." • "..T.LocationText(v.location),nil,v.id)
            end end
            add("Automatic capture records readable openable bag items and strictly matched portable inspections. It never confirms receipt. World identity, acquisition context, access requirements and recovery claims can be recorded manually.",nil,nil,"guidance","Recording finds")
        elseif detail=="notes" then
            add("General notes (private):\n"..(e.note~="" and e.note or "No notes yet. Use Edit."),nil,nil,"notes")
            add("Look for again: "..(e.bookmark and "Bookmarked" or "Not bookmarked").."\n"..(e.bookmarkNote~="" and e.bookmarkNote or "No reason recorded."),nil,nil,"notes")
            add("Bookmarks describe your intention to look again. They make no claim that a particular container remains available.",nil,nil,"guidance")
            for _,v in ipairs(history) do if v.reportNote and v.reportNote~="" then add("Reported kind note — "..v.origin.source..": "..v.reportNote,nil,v.id) end end
        elseif detail=="contents" then
            local any=false
            for _,v in ipairs(history) do if v.facts.inspected or #v.items>0 then
                add(T.Date(v.origin.at).." • "..(v.reported and "Reported by " or "Personal / "..v.origin.method..": ")..v.origin.source..
                    "\n"..T.LocationText(v.location).."\n"..T.captures[v.capture],nil,v.id)
                rows[#rows].divider=any;any=true
                for _,item in ipairs(v.items) do
                    local receipt=item.recovered and (v.reported and "Source reports recovering " or "Personally recovered (manual): ")..item.recovered or "Receipt unconfirmed"
                    add(journal:ItemName(item).." × "..item.quantity.." observed\n"..receipt,item,v.id)
                end
                if #v.items==0 then add(v.capture=="full" and "No items listed in this full manual capture." or "No item rows captured; contents are unknown.",nil,v.id) end
            end end
            if not any then add("Contents not recorded. Record an inspection and its observed items; a sighting alone says nothing about contents.") end
        else
            local focus=journal.encounters[state.encounter]
            local list={};if focus and state.historyOffset==0 then list[#list+1]=focus end
            for _,v in ipairs(history) do if v~=focus or state.historyOffset>0 then list[#list+1]=v end end
            if #list==0 then add("No encounters remain for this kind. Its personal notes and bookmark are retained.") end
            for _,v in ipairs(list) do
                local text=(v.id==state.encounter and "Selected • " or "")..journal:Title(journal:Get(v.kindID)).." • "..T.Date(v.origin.at)..
                    "\n"..(v.reported and "Reported by " or "Personal / "..v.origin.method..": ")..v.origin.source.." • "..T.Outcome(v)..
                    "\n"..T.LocationText(v.location).."\n"..T.captures[v.capture]
                if v.reported then text=text.." • received "..T.Date(v.received) end
                if v.access~="" then text=text.."\nAccess ("..v.accessMethod.."): "..v.access end
                if v.note~="" then text=text.."\nEncounter note: "..v.note end
                add(text,nil,v.id,"encounter")
            end
        end
        return rows
    end
    function c:RenderDetails(scroll,body,pool,width,detail)
        local y=0;local rows=self:DetailRows(detail)
        for i,data in ipairs(rows) do
            local row=pool[i]
            if not row then
                row=CreateFrame("Button",nil,body);row:SetWidth(width);row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                row.text=U.Label(row,"",0,0,width,"GameFontHighlightSmall");row.text:SetWordWrap(true);row.text:SetSpacing(3)
                row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",0,-1);row.icon:SetSize(24,24)
                row:SetScript("OnEnter",function(self) if self.data and self.data.item then itemTooltip(self,self.data.item,journal) end end)
                row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                row:SetScript("OnClick",function(self)
                    if not self.data then return end
                    local item=self.data.item
                    if item and item.itemID and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                        local name=journal:ItemName(item);ChatEdit_InsertLink("|Hitem:"..item.itemID.."|h["..T.Safe(name).."]|h")
                    elseif self.data.encounter then c:Encounter(self.data.encounter) end
                end)
                pool[i]=row
            end
            local divider=detail=="contents" and data.divider or (detail~="contents" and i>1)
            if divider and not row.divider then
                row.divider=detail=="contents" and ns.FieldbookUI.EntryDivider(row,8) or U.DetailDivider(row,8,width)
            end
            if row.divider then for _,line in ipairs(row.divider) do line:SetShown(divider==true) end end
            if divider then y=y+14 end
            row.data=data;row.text:ClearAllPoints();row.text:SetPoint("TOPLEFT",data.item and 31 or 0,0)
            row.text:SetWidth(width-(data.item and 31 or 0));row.text:SetText(T.Safe(data.text));row.text:SetTextColor(0.75,0.8,0.8)
            if detail~="contents" then
                local formatted={}
                for line in (data.text.."\n"):gmatch("(.-)\n") do
                    local label,value=line:match("^([^:]+:)(.*)$")
                    if data.style=="guidance" then formatted[#formatted+1]=U.DetailPaint(line,"9ba7ad")
                    elseif data.title or (data.style=="notes" and #formatted>0) then formatted[#formatted+1]=U.DetailPaint(line,"c5cdcf")
                    elseif #formatted==0 then
                        local name,stamp
                        if data.style=="encounter" then name,stamp=line:match("^(.*) • ([^•]+)$") end
                        formatted[#formatted+1]=name and (U.DetailPaint(name,"ffd100").."\n"..U.DetailPaint(stamp,"9ba7ad")) or U.DetailPaint(line,"ffd100")
                    elseif label then formatted[#formatted+1]=U.DetailPaint(label,"74c7d5")..U.DetailPaint(value,"c5cdcf")
                    elseif line==T.captures.partial or line==T.captures.failed then formatted[#formatted+1]=U.DetailPaint(line,"cfad64")
                    else formatted[#formatted+1]=U.DetailPaint(line,"9ba7ad") end
                end
                row.text:SetText((data.title and U.DetailPaint(data.title,"ffd100").."\n\n" or "")..table.concat(formatted,"\n"))
            end
            if data.item and data.item.itemID then
                local quality=T.Read(C_Item and C_Item.GetItemQualityByID,data.item.itemID)
                local color=T.Integer(quality,0,8) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if type(color)=="table" and T.Number(color.r,0,1) and T.Number(color.g,0,1) and T.Number(color.b,0,1) then row.text:SetTextColor(color.r,color.g,color.b) end
            end
            local height=math.ceil(math.max(data.item and 28 or 18,row.text:GetStringHeight()+8))
            row:SetHeight(height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-y);row.icon:SetShown(data.item~=nil)
            if data.item then row.icon:SetTexture(icon(data.item)) end
            row:Show();y=y+height+6
        end
        for i=#rows+1,#pool do pool[i]:Hide();pool[i].data=nil end
        body:SetHeight(math.max(scroll:GetHeight(),y));scroll:UpdateScrollChildRect();scroll:RefreshScrollBar()
    end
    function c:LayoutDetails(progress)
        local m=self.main
        m.notesProgress=progress
        m.notesOverlay:ClearAllPoints();m.notesOverlay:SetPoint("TOPLEFT",342,-588+414*progress)
        m.notesOverlay:SetHeight(113+414*progress)
        m.details:SetHeight(80+414*progress)
        m.notesPaper:Show()
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
                c:RenderDetails(m.details,m.detailBody,m.detailRows,550)
                m.details:SetVerticalScroll(math.min(m.details:GetVerticalScroll(),math.max(0,m.detailBody:GetHeight()-m.details:GetHeight())))
            end
        end)
    end
    function c:Refresh(preserveTop)
        if not self.main then return end
        local m=self.main;local top=preserveTop and self.rows and self.rows[math.floor(state.indexScroll/ROW_HEIGHT)+1]
        local rows,total=journal:List(state);self.rows=rows
        if top then for i,row in ipairs(rows) do if row.entry.id==top.entry.id then state.indexScroll=(i-1)*ROW_HEIGHT+state.indexScroll%ROW_HEIGHT;break end end end
        local scroll=math.max(0,math.min(state.indexScroll,math.max(0,#rows*ROW_HEIGHT-LIST_HEIGHT)))
        state.indexScroll=scroll
        m.updatingList=true;m.listBody:SetHeight(math.max(LIST_HEIGHT,#rows*ROW_HEIGHT))
        m.list:SetVerticalScroll(scroll);m.list:UpdateScrollChildRect();m.list:RefreshScrollBar();m.updatingList=nil
        local first=math.floor(scroll/ROW_HEIGHT)
        m.count:SetCounts(total,#rows)
        m.empty:SetShown(#rows==0);m.empty:SetText(total==0 and "Your Treasure Journal begins empty.\n\nRecord a find, or carry an openable container. All locations describe past encounters." or "No entries match these filters.\nUse Filters > Clear to browse all known finds.")
        for i,row in ipairs(m.rows) do
            local found=rows[first+i];row:SetShown(found~=nil);row.id=found and found.entry.id
            row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-(first+i-1)*ROW_HEIGHT)
            if found then
                local e,s=found.entry,found.summary;row.name:SetText((e.bookmark and U.SavedIcon(true) or "")..T.Safe(found.title));row.icon:SetTexture(icon(e))
                row.kind:SetText(T.Safe((e.form=="world" and "World" or "Portable").." / "..e.category.." • "..found.zone))
                row.knowledge:SetText((s.personal==0 and s.reported>0 and "[R] " or "")..(s.contents>0 and "Contents recorded" or "Contents not recorded"))
                row:SetSelected(e.id==state.selected)
            end
        end
        m.filters:SetSelected(state.category~=nil or state.zone~=nil or state.knowledge~=nil or state.bookmarks==true)
        m.showContents:SetSelected(state.showContents)
        m.list:SetShown(not state.showContents);m.empty:SetShown(not state.showContents and #rows==0)
        m.contents:SetShown(state.showContents)
        m.contentsHeader:SetShown(state.showContents)
        local selected=journal:Get(state.selected)
        m.contentsHeader.name:SetText(selected and T.Safe(journal:Title(selected)) or "No container selected")
        m.contentsHeader.icon:SetTexture(icon(selected))
        m.contentsHeader:SetSelected(selected~=nil)
        local headerHeight=math.ceil(math.max(36,m.contentsHeader.name:GetStringHeight()+12))
        m.contentsHeader:SetHeight(headerHeight);m.contents:SetHeight(LIST_HEIGHT-headerHeight-8)
        if state.showContents then self:RenderDetails(m.contents,m.contentsBody,m.contentsRows,224,"contents") end
        for key,button in pairs(m.detailButtons) do button:SetSelected(state.detail==key) end
        local e=journal:Get(state.selected);local s=e and journal:Summary(e)
        m.name:SetText(e and T.Safe(journal:Title(e)) or "Treasure Journal")
        m.summary:SetText(e and ((e.form=="world" and "World find" or "Portable container").." • "..e.category.." • "..s.knowledge) or "A personal guide to temporary discoveries")
        m.counts:SetText(e and (s.personal.." personal encounters • "..s.reported.." reported • latest observation: "..(s.last>0 and T.Date(s.last) or "Unknown")) or "Choose a known kind or record a new find.")
        local v=journal.encounters[state.encounter]
        m.focus:SetText(v and T.Safe(T.Outcome(v).." • "..T.Date(v.origin.at)) or "No encounter selected")
        local historyCount=e and #journal:History(e.id) or 0
        m.newer:SetEnabled(state.historyOffset>0);m.older:SetEnabled(state.historyOffset+HISTORY_PAGE<historyCount)
        m.bookmark:SetEnabled(e~=nil);m.bookmark:SetSaved(e and e.bookmark,e~=nil);m.bookmark:SetText("Look for again")
        m.edit:SetEnabled(v~=nil and not v.reported);m.remove:SetEnabled(v~=nil and e~=nil and v.kindID==e.id and not journal.readOnly);m.notes:SetEnabled(e~=nil)
        local zoneName;for _,p in ipairs(journal:Zones()) do if p.mapID==state.mapID then zoneName=p.zone;break end end
        m.mapZone:SetText(zoneName or "Known maps");m.scope:SetText(state.allZone and "All finds in zone" or "Selected kind")
        m.map:Render();self:RenderDetails(m.details,m.detailBody,m.detailRows,550)
        if journal.readOnly then self:Message("Saved schema is read-only; original data is preserved.")
        elseif journal.invalid>0 then self:Message(journal.invalid.." malformed saved records preserved but omitted from this view.") end
    end
    T.InstallEditors(c)
    local function build(content)
        c.frame=content;local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m
        local spine=m:CreateTexture(nil,"ARTWORK");spine:SetColorTexture(0.25,0.13,0.055,0.35);spine:SetPoint("TOPLEFT",306,-53);spine:SetSize(3,661)
        m.pageTitle=ns.FieldbookUI.SectionTitle(m,"Treasure Journal")
        m.directory=CreateFrame("Frame",nil,m);m.directory:SetAllPoints();local d=m.directory
        m.search=U.Search(d,70,-110,168,200);m.search:SetText(state.query)
        m.search:HookScript("OnTextChanged",function() state.query=m.search:GetText();c:Filter() end)
        m.filters=ns.FieldbookUI.FilterButton(d,244,-110,function(button)
            m.search:ClearFocus()
            c:Menu(button,function(_,root)
                local function checkbox(parent,label,key,value)
                    local item=parent:CreateCheckbox(label,function() return state[key]==value end,function()
                        state[key]=value;c:Filter()
                    end)
                    item:SetResponse(MenuResponse.Refresh)
                end
                local category=root:CreateButton("Categories")
                checkbox(category,"All categories","category",nil)
                for _,id in ipairs({"world","portable","salvage"}) do checkbox(category,categories[id],"category",id) end
                root:CreateDivider();root:CreateTitle("Filters")
                local zones=root:CreateButton("Zone / location");zones:SetScrollMode(400)
                checkbox(zones,"All locations","zone",nil)
                checkbox(zones,"Current zone","zone","@current")
                local seen={};for _,p in ipairs(journal:Zones()) do local name=p.zone
                    if name~="" and not seen[name] then seen[name]=true;checkbox(zones,T.Safe(name),"zone",name) end
                end
                local sources=root:CreateButton("Source / knowledge")
                checkbox(sources,"All sources / knowledge","knowledge",nil)
                for _,id in ipairs({"personal","reported","missing","contents"}) do checkbox(sources,knowledge[id],"knowledge",id) end
                local bookmarks=root:CreateCheckbox("Look for again",function() return state.bookmarks==true end,function()
                    state.bookmarks=not state.bookmarks;c:Filter()
                end)
                bookmarks:SetResponse(MenuResponse.Refresh)
                root:CreateDivider()
                local clear=root:CreateButton("Clear",function() c:ResetFilters() end)
                clear:SetResponse(MenuResponse.Refresh)
            end)
        end)
        m.filters.ResetFilters=function() c:ResetFilters() end
        U.StyleSelection(m.filters)
        m.sort=U.Button(d,"",270,-110,22,function(button)
            m.search:ClearFocus()
            c:Menu(button,function(_,root)
                root:CreateTitle("Sort by")
                for _,choice in ipairs({{"name","Name"},{"location","Location"},{"recent","Most recent"}}) do
                    root:CreateButton((state.sort or "name")==choice[1] and choice[2].." (selected)" or choice[2],function() state.sort=choice[1]~="" and choice[1] or nil;c:Filter() end)
                end
            end)
        end)
        m.sort:SetSize(22,22)
        for row=0,4 do
            local stroke=m.sort:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-row*2,1);stroke:SetPoint("CENTER",0,2-row);stroke:SetColorTexture(1,0.82,0.14,1)
        end
        for _,item in ipairs({{m.filters,"Filter finds\nRight-click to reset filters."},{m.sort,"Sort"}}) do
            item[1]:SetScript("OnEnter",function(self)
                if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(item[2]);GameTooltip:Show() end
            end)
            item[1]:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        end
        m.showContents=U.Button(d,"Observed contents",42,-142,250,function()
            state.showContents=not state.showContents;c:Refresh()
        end)
        U.StyleSelection(m.showContents)
        m.count=ns.FieldbookUI.EntryCount(d);m.rows={}
        m.contentsHeader=CreateFrame("Button",nil,d,"BackdropTemplate");m.contentsHeader:SetPoint("TOPLEFT",42,-177);m.contentsHeader:SetSize(250,36)
        ns.FieldbookUI.StyleMenuRow(m.contentsHeader);m.contentsHeader:EnableMouse(false)
        m.contentsHeader.icon=m.contentsHeader:CreateTexture(nil,"ARTWORK")
        m.contentsHeader.icon:SetPoint("TOPLEFT",6,-6);m.contentsHeader.icon:SetSize(24,24)
        m.contentsHeader.name=U.Label(m.contentsHeader,"",37,-6,207,"GameFontNormal")
        local headerNamePath,headerNameSize,headerNameFlags=m.contentsHeader.name:GetFont()
        if headerNamePath and type(headerNameSize)=="number" then m.contentsHeader.name:SetFont(headerNamePath,headerNameSize+2,headerNameFlags) end
        m.contentsHeader.name:SetWordWrap(true)
        m.contents,m.contentsBody=U.Scroll(d,42,-211,228,LIST_HEIGHT-34);m.contentsRows={}
        m.contents:ClearAllPoints();m.contents:SetPoint("TOPLEFT",m.contentsHeader,"BOTTOMLEFT",0,-8)
        m.list,m.listBody=U.Scroll(d,42,-177,228,LIST_HEIGHT)
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
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",6,-6);row.icon:SetSize(19,19)
            row.name=U.Label(row,"",29,-6,192,"GameFontHighlightSmall")
            local namePath,nameSize,nameFlags=row.name:GetFont()
            if namePath and type(nameSize)=="number" then row.name:SetFont(namePath,nameSize+4,nameFlags) end
            row.kind=U.Label(row,"",7,-27,214,"GameFontDisableSmall");row.knowledge=U.Label(row,"",7,-41,214,"GameFontHighlightSmall")
            row.name:SetWordWrap(false);row.kind:SetWordWrap(false);row.knowledge:SetWordWrap(false)
            row:SetScript("OnClick",function(self) c:Select(self.id) end)
            row:SetScript("OnEnter",function(self)
                local e=journal:Get(self.id);if not e or not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(T.Safe(journal:Title(e)))
                GameTooltip:AddLine(journal:Summary(e).knowledge,1,1,1,true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end);m.rows[i]=row
        end
        m.empty=U.Label(d,"",49,-203,235,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(5)
        m.manual=U.Button(d,"Record a find",42,-638,250,function() c:Manual() end)
        m.name=U.Label(m,"",342,-60,426,"GameFontNormalLarge");m.name:SetWordWrap(false)
        m.name:SetShadowColor(0,0,0,0.85);m.name:SetShadowOffset(1,-1)
        m.bookmark=U.SavedButton(m,"Look for again",782,-60,140,function() journal:Bookmark(state.selected) end)
        m.summary=U.Label(m,"",342,-89,580,"GameFontHighlightSmall");m.summary:SetWordWrap(false)
        m.counts=U.Label(m,"",342,-112,580,"GameFontDisableSmall");m.counts:SetWordWrap(false)
        m.focus=U.Label(m,"",342,-135,420,"GameFontHighlightSmall");m.focus:SetWordWrap(false)
        m.newer=U.Button(m,"Newer",770,-129,73,function() state.historyOffset=math.max(0,state.historyOffset-HISTORY_PAGE);m.details:SetVerticalScroll(0);c:Refresh() end)
        m.older=U.Button(m,"Older",850,-129,72,function() state.historyOffset=state.historyOffset+HISTORY_PAGE;m.details:SetVerticalScroll(0);c:Refresh() end)
        U.Label(m,"Past finds — current availability unknown.",342,-158,580,"GameFontNormalSmall")
        m.mapZone=U.MenuButton(m,"Known maps",342,-174,256,function(self)
            c:Menu(self,function(_,root)
                root:SetScrollMode(420)
                local selected;if not state.allZone then selected=state.selected end
                for _,p in ipairs(journal:Zones(selected)) do if p.mapID then
                    local id=p.mapID;root:CreateButton(T.Safe(p.zone).." • map "..id,function() state.mapID=id;c:Refresh() end)
                end end
            end)
        end)
        m.scope=U.Button(m,"Selected kind",604,-174,146,function() state.allZone=not state.allZone;c:Refresh() end)
        m.edit=U.Button(m,"Correct",756,-174,78,function() c:Manual(state.encounter) end)
        m.notes=U.Button(d,"Edit",42,-672,120,function() c:Notes() end)
        m.remove=U.Button(d,"Delete",174,-672,118,function() c:RemoveEncounter() end)
        m.map=ns.CreateTreasureMap(m,journal,state,function(id) c:Encounter(id) end)
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.notesOverlay=CreateFrame("Frame",nil,m)
        m.notesOverlay:SetSize(580,113);m.notesOverlay:SetFrameLevel(m:GetFrameLevel()+30)
        m.notesPaper=m.notesOverlay:CreateTexture(nil,"BACKGROUND")
        m.notesPaper:SetPoint("TOPLEFT",m.notesOverlay,"TOPLEFT",-10,4)
        m.notesPaper:SetPoint("BOTTOMRIGHT",m.notesOverlay,"BOTTOMRIGHT",10,-6)
        m.notesPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga");m.notesPaper:SetDesaturated(true)
        shell:AddBackgroundLayer(m.notesPaper,0.17,0.17,0.17,true)
        for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
            local border=m.notesOverlay:CreateTexture(nil,"OVERLAY")
            border:SetColorTexture(unpack(U.DetailGold))
            border:SetPoint(edge[1],m.notesPaper,edge[1]);border:SetPoint(edge[2],m.notesPaper,edge[2])
            if edge[3] then border:SetHeight(1) else border:SetWidth(1) end
        end
        m.detailButtons={}
        for i,v in ipairs({{"summary","Summary / access"},{"history","Encounter history"},{"notes","Personal notes"}}) do
            local key=v[1];m.detailButtons[key]=U.Button(m.notesOverlay,v[2],(i-1)*146,0,140,function()
                state.detail=key;state.detailScroll=0;m.details:SetVerticalScroll(0);c:Refresh()
            end)
            U.StyleSelection(m.detailButtons[key])
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
        m.details,m.detailBody=U.Scroll(m.notesOverlay,0,-33,555,80);m.detailRows={}
        U.AlignFooterScrollBar(m.details,m.notesPaper,m.expand)
        U.FooterFades(m.details,shell,37)
        c:LayoutDetails(0)
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall");m.message:SetWordWrap(false)
        content:SetScript("OnHide",function()
            m.notesOverlay:SetScript("OnUpdate",nil);c:LayoutDetails(m.notesExpanded and 1 or 0)
            state.detailScroll=m.details:GetVerticalScroll();m.map:SuspendPlayer();m.search:ClearFocus()
            for _,p in pairs(c.panels) do for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
            if GameTooltip then GameTooltip:Hide() end
        end)
        c:Message(tracking.status);c:Refresh();m.details:SetVerticalScroll(state.detailScroll)
    end
    shell:RegisterSection("treasure",{title="Treasure Journal",icon=T.ICON,frameName="AzerothFieldbookTreasureSection",build=build,
        help=T.VISION.."\n\n|cffffd100Historical knowledge|r\nEach entry groups a kind of treasure or container; History lists its past sightings, access attempts and inspections. A recorded past find is not evidence that a container is currently present. Matching names do not automatically combine different kinds.\n\n"..
            "|cffffd100Record and correct|r\nUse Record a find to choose an existing kind or create one, then record what happened. Leave the location unknown if unsure. Use player position supplies approximate coordinates for review. Enter contents only if inspected, and distinguish what you saw from what you personally recovered.\n\nSelect an encounter in History or on the map, then use Correct or Remove. Automatic encounters allow corrections to location, access details and notes while retaining their original contents evidence. Edit changes the kind's label, category and notes; Look for again bookmarks it.\n\n"..
            "|cffffd100Maps and browsing|r\nSearch names, locations, items and notes. Known maps chooses a recorded map; Selected kind switches to All finds in zone. Click a marker to review a past encounter, or click again to cycle overlapping finds. The arrow beside the detail tabs slides the notes over the map; use the down arrow to collapse them.\n\nMap pins come from positioned world finds and recorded acquisitions. Seeing or opening a container in your bags does not establish where you acquired it.\n\n"..
            "|cffffd100Automatic capture|r\nRecognizable openable bag items and world containers can be recorded automatically. World capture matches a recent object tooltip to the actual loot source; recognized English names include chests, crates, coffers, strongboxes, footlockers, lockboxes, caches, barrels and sacks. When the tooltip has no object ID, a recent world click or completed opening cast can establish the name; the loot window must still identify one world-object source. Locations are approximate player positions. When opened, contents are captured only if the addon can reliably identify the source. Captures are partial and do not confirm that you recovered the items. Uncertain sources are skipped; the page status explains why a recognized container could not be captured.\n\nUse Record a find for unrecognized world finds, acquisition details, access methods and recovered quantities. Seeing an item in the journal does not establish that you still own it.\n\n"..
            "|cffffd100Reports|r\nTreasure currently has no player-facing report sending, import or export. Bestiary Share does not send Treasure records.\n\n"..
            "|cffffd100Your journal|r\nTreasure follows Account-wide tracking in Options. It starts on; turn it off to use this character's separate journal after /reload. Existing character history imports once; later changes in the two scopes stay separate.",
        onOpen=function() if c.main then c:Message(tracking.status);c:Refresh();c.main.details:SetVerticalScroll(state.detailScroll) end end})
    journal.onChange=function()
        if not c.main or shell.active~="treasure" or not shell:GetFrame():IsShown() or c.refreshQueued then return end
        c.refreshQueued=true
        local function refresh() c.refreshQueued=false;if shell.active=="treasure" and shell:GetFrame():IsShown() then c:Refresh(true) end end
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.1,refresh) else refresh() end
    end
    tracking.onStatus=function(message)
        if c.main and shell.active=="treasure" and shell:GetFrame():IsShown() then c:Message(message) end
    end
    return c
end
function ns.InitializeTreasure(shell,eventJournal)
    if ns.InitializationBlocked then return end
    if AzerothFieldbookTreasureDB==nil then AzerothFieldbookTreasureDB={} end
    local store=AzerothFieldbookTreasureDB
    if ns.SelectSectionStorage then store=ns.SelectSectionStorage("treasure",store) end
    local journal=ns.CreateTreasureJournal(store)
    local tracking=ns.CreateTreasureTracking(journal)
    tracking.onContentsRecorded=function(entry)
        if eventJournal and eventJournal:GetCreatureAnnouncement() and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r |cffffd100[Contents recorded]|r |cff80d0ffTreasure Journal:|r |cffffffff"..T.Safe(entry.name).."|r")
        end
    end
    return ns.CreateTreasureBook(journal,tracking,shell)
end
