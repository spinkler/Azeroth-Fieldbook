local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local L,U,R=ns.Ledger,ns.AtlasUI,ns.LedgerReports
local date=L.Date
local function money(n) return n~=nil and string.format("%dg %ds %dc",math.floor(n/10000),math.floor(n/100)%100,n%100) or "Unknown" end
local function goodsMoney(n)
    if n==nil then return "Unknown" end
    if n==0 then return "Free" end
    local parts={}
    local gold,silver,copper=math.floor(n/10000),math.floor(n/100)%100,n%100
    if gold>0 then parts[#parts+1]=gold.."g" end
    if silver>0 then parts[#parts+1]=silver.."s" end
    if copper>0 then parts[#parts+1]=copper.."c" end
    return table.concat(parts," ")
end
local function sortedKeys(t) local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys);return keys end
function ns.CreateLedgerBook(journal,tracking,shell)
    local state=journal.state
    state.query=L.Text(state.query,200,true) and state.query or "";state.roles=type(state.roles)=="table" and state.roles or {}
    state.offset=L.Integer(state.offset,0,L.MAX_CONTACTS) and state.offset or 0
    state.detail=({goods=true,training=true,services=true})[state.detail] and state.detail or "services"
    local c={journal=journal,tracking=tracking,shell=shell,state=state,panels={}}
    function c:Message(text) self.main.message:SetText(L.Safe(text or "")) end
    function c:Menu(button,build)
        if MenuUtil and type(MenuUtil.CreateContextMenu)=="function" then MenuUtil.CreateContextMenu(button,build) end
    end
    function c:Filter() state.offset=0;state.contactScroll=0;self:Refresh() end
    function c:Reset()
        for _,k in ipairs({"zone","subzone","knowledge","favourites","recipes","sort"}) do state[k]=nil end
        state.roles={};state.query="";state.offset=0;state.contactScroll=0;self.main.search:SetText("");self:Refresh()
    end
    function c:DefaultDetail(e)
        local roles=journal:Roles(e)
        if roles.merchant or next(e.goods) then return "goods" end
        if roles.trainer or next(e.lessons) then return "training" end
        return "services"
    end
    function c:Select(id,match)
        local e=journal:Get(id);if not e then return end
        if state.selected~=id then state.sighting=1;state.sightingKey=nil end
        state.selected=id;state.focus=match and match.key;state.focusReported=match and match.reported
        state.detail=match and match.kind or self:DefaultDetail(e)
        state.detailScroll=0;self.main.details:SetVerticalScroll(0);self:Refresh()
    end
    function c:OpenAtUnit(unit)
        local observed=L.Unit(unit);if not observed then return false end
        local e=journal:Get(journal.db.aliases[observed.guid])
        if not e then
            -- Browsing a unique remembered template does not bind this new GUID
            -- or merge stock from a different individual.
            for _,candidate in pairs(journal.db.contacts) do
                if candidate.npcID==observed.npcID and candidate.name==observed.name then
                    if e then return false end
                    e=candidate
                end
            end
        end
        if not e then return false end
        shell:ShowSection("merchants");self:ClosePanel();self:Reset();self:Select(e.id)
        local top=0
        for _,found in ipairs(self.rows) do
            if found.contact.id==e.id then break end
            top=top+(journal:Sublabel(found.contact)=="" and 53 or 65)
        end
        state.contactScroll=top;self:Refresh();return true
    end
    function c:Sighting(index)
        local e=journal:Get(state.selected);local p=e and journal:Locations(e)[index]
        if not p then return end
        state.sightingKey=L.Key(p.reported==true,p.origin.source,p.origin.key);state.sighting=index;self:Refresh()
    end
    function c:Details(e,rich,detail)
        if not e then return "Select a contact to view its notes." end
        detail=detail or state.detail
        if detail=="services" then
            local lines={}
            if e.note~="" then lines[#lines+1]=e.note end
            local retained=journal:ImportedNotes(e);if retained~="" then lines[#lines+1]=retained end
            if e.migrationIssue then lines[#lines+1]=e.migrationIssue end
            local roles=journal:RoleText(e);if roles~="" then lines[#lines+1]=roles end
            for speciality,o in pairs(e.specialities) do lines[#lines+1]="Speciality: "..speciality.." ("..o.method..")" end
            if e.ambiguous then lines[#lines+1]="Identity unresolved: another contact shares this NPC template. Use Link identity after reviewing both records." end
            for _,report in ipairs(e.reports) do
                lines[#lines+1]="Report from "..report.identity.origin.source..", observed "..date(report.identity.origin.at)..", received "..date(report.received)
                if report.notes then lines[#lines+1]="Reported note: "..report.notes end
            end
            return table.concat(lines,'\n')
        end
        local training=detail=="training";local kind=training and "lessons" or "goods"
        local inspection=e[training and "trainerInspection" or "merchantInspection"]
        local lines={training and "Observed Training" or "Known goods — historical observations"}
        if inspection then lines[#lines+1]="Latest inspection: "..date(inspection.at).." • "..(inspection.complete and "Readable, unfiltered" or inspection.reason) end
        local rows={};local headings={};local muted={};local prices={}
        for key,v in pairs(e[kind]) do rows[#rows+1]={value=v,key=key} end
        for _,report in ipairs(e.reports) do for _,v in ipairs(report[kind]) do
            local receipt=report.factReceipts and report.factReceipts[L.Key(v.origin.source,v.origin.key)]
            rows[#rows+1]={value=v,key=v.key,reported=true,received=receipt and receipt.received or report.received}
        end end
        table.sort(rows,function(a,b)
            local af=a.key==state.focus and not a.reported==not state.focusReported
            local bf=b.key==state.focus and not b.reported==not state.focusReported
            if af~=bf then return af end
            if not a.reported~=not b.reported then return not a.reported end
            return (a.value.name or ""):lower()<(b.value.name or ""):lower()
        end)
        for _,row in ipairs(rows) do
            local v=row.value;lines[#lines+1]="\n"..(row.reported and "REPORTED: " or "")..(v.name or ("Item #"..tostring(v.itemID).." — metadata pending"))..
                (training and v.rank~="" and " ("..v.rank..")" or "")..(v.recipe and " • Recipe"..(v.profession and " / "..v.profession or "") or "")
            if rich and not training and L.Integer(v.itemID,1,2147483647) then
                local icon=v.icon or L.Read(C_Item and C_Item.GetItemIconByID,v.itemID)
                local art=L.Integer(icon,1,2147483647) and ("|T"..icon..":18:18:0:0|t ") or ""
                local quality
                if C_Item and type(C_Item.GetItemInfo)=="function" then
                    local ok,_,_,q=pcall(C_Item.GetItemInfo,v.itemID)
                    if ok and L.Integer(q,0,8) then quality=q end
                end
                local color=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                local hex=color and color.hex
                if L.Public(hex) and type(hex)=="string" then hex=hex:gsub("^|c","") end
                local tint=L.Public(hex) and type(hex)=="string" and hex:match("^ff%x%x%x%x%x%x$") and hex or "ffffffff"
                headings[#lines]="\n"..(row.reported and "REPORTED: " or "").."|Hitem:"..v.itemID.."|h"..art.."|c"..tint..
                    L.Safe(v.name or ("Item #"..v.itemID.." — metadata pending")).."|r|h"..
                    (v.recipe and " • Recipe"..(v.profession and " / "..L.Safe(v.profession) or "") or "")
            end
            if training then
                local labels={available="Available when inspected",unavailable="Unavailable when inspected",used="Already known when inspected",unknown="Availability unknown"}
                lines[#lines+1]=labels[v.availability] or "Availability unknown"
                local cost=v.costUnit=="copper" and money(v.price) or tostring(v.price or "Unknown")..(v.costUnit=="training points" and " training points" or " (unit unknown)")
                lines[#lines+1]="Last quoted cost: "..cost.." • "..date(v.priceAt)
            else
                if not v.stock or v.stock.state~="unlimited" then
                    lines[#lines+1]="Last observed stock: "..L.StockLabel(v.stock).." • "..date(v.stockAt)..(v.notSeen and " • Not seen on the latest inspection" or "")
                elseif v.notSeen then lines[#lines+1]="Not seen on the latest inspection" end
                local price=goodsMoney(v.price)..(v.bundle and " / "..v.bundle or " • Bundle size unknown")
                if v.price and v.price>0 and v.bundle and v.bundle>1 and v.price%v.bundle==0 then
                    price=price.." ("..goodsMoney(v.price/v.bundle).." each)"
                end
                lines[#lines+1]="Price: "..price.." • "..date(v.priceAt);prices[#lines]=true
                for _,cost in ipairs(v.costs or {}) do lines[#lines+1]="Last additional quoted cost: "..cost.quantity.." × "..(cost.name or cost.kind.." #"..cost.id).." • "..date(v.costsAt) end
                if not v.costsKnown then lines[#lines+1]="Additional costs on latest inspection: unknown or partially readable" end
                -- An unusable (for example, higher-level) item can still be bought.
                -- Keep the native requirements below without inventing a purchase restriction.
                if v.purchasable==false and v.usable==true then lines[#lines+1]="Not purchasable when inspected; reason unknown unless displayed below" end
            end
            for _,requirement in ipairs(v.requirements or {}) do lines[#lines+1]=requirement end
            lines[#lines+1]="First: "..date(v.first).." • Last: "..date(v.last).." • "..v.origin.source.." / "..v.origin.method
            muted[#lines]=true
            if row.reported then lines[#lines+1]="Report received: "..date(row.received) end
        end
        if #rows==0 then lines[#lines+1]=training and "No training recorded. Open a trainer to remember readable lessons." or "No goods recorded. Open this merchant to remember visible offerings." end
        local blocks={};local pending={}
        local function flush()
            if #pending>0 then blocks[#blocks+1]={text=table.concat(pending,"\n")};pending={} end
        end
        if rich then for i,line in ipairs(lines) do
            local safe=L.Safe(line)
            if prices[i] then
                local colors={g="ffffd100",s="ffc7c7cf",c="ffb87333"}
                safe=safe:gsub("(%d+)([gsc])",function(amount,unit) return amount.."|c"..colors[unit]..unit.."|r" end)
            end
            lines[i]=headings[i] or (muted[i] and "|cff888888"..safe.."|r" or safe)
            if headings[i] then flush();blocks[#blocks+1]={text=headings[i]:gsub("^\n",""),heading=true}
            else pending[#pending+1]=lines[i] end
        end;flush() end
        return table.concat(lines,'\n'),blocks
    end
    function c:GoodsReadArea(parent,x,y,width,height)
        local area,body=U.Scroll(parent,x,y,width,height)
        local text=U.Label(body,"",0,0,width,"GameFontHighlightSmall");text:SetWordWrap(true);text:SetSpacing(3)
        body:SetHyperlinksEnabled(true)
        body:SetScript("OnHyperlinkEnter",function(self,link)
            local id=type(link)=="string" and tonumber(link:match("^item:(%d+)$"))
            if not L.Integer(id,1,2147483647) or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_CURSOR");GameTooltip:SetHyperlink("item:"..id);GameTooltip:Show()
        end)
        local function hide() if GameTooltip then GameTooltip:Hide() end end
        body:SetScript("OnHyperlinkLeave",hide);body:SetScript("OnHide",hide)
        area.blocks={text};area.headingViews={}
        function area:HeadingView(index,label)
            local view=self.headingViews[index]
            if view then return view end
            view=CreateFrame("ScrollFrame",nil,body);view:EnableMouse(true)
            local canvas=CreateFrame("Frame",nil,view);view:SetScrollChild(canvas)
            canvas:EnableMouse(false)
            canvas:SetHyperlinksEnabled(false)
            local hover=CreateFrame("Frame",nil,view)
            hover:SetAllPoints(view);hover:EnableMouse(true)
            view.hover=hover
            view.icon=hover:CreateTexture(nil,"ARTWORK")
            view.icon:SetSize(18,18)
            view.icon:SetPoint("LEFT",hover,"LEFT",0,0)
            view.canvas=canvas;self.headingViews[index]=view
            local function stop(self)
                self:SetScript("OnUpdate",nil);self:SetHorizontalScroll(0);hide()
                label:SetWidth(self:GetWidth())
            end
            view:SetScript("OnLeave",stop);view:SetScript("OnHide",stop)
            view:SetScript("OnEnter",function(self)
                local distance=math.max(0,(self.contentWidth or self:GetWidth())-self:GetWidth())
                if distance==0 then return end
                label:SetWidth(self.contentWidth)
                local elapsed=0;local travel=distance/24
                self:SetScript("OnUpdate",function(_,dt)
                    elapsed=(elapsed+dt)%(2*travel+2)
                    local position
                    if elapsed<0.8 then position=0
                    elseif elapsed<0.8+travel then position=(elapsed-0.8)*24
                    elseif elapsed<2+travel then position=distance
                    else position=distance-(elapsed-2-travel)*24 end
                    self:SetHorizontalScroll(position)
                end)
            end)
            -- A stationary hit area owns hover; moving hyperlink text must not
            -- steal mouse focus or restart the scroll's initial pause.
            hover:SetScript("OnEnter",function(self)
                view:GetScript("OnEnter")(view)
                local link=label:GetText():match("|H(item:%d+)")
                if link then body:GetScript("OnHyperlinkEnter")(self,link) end
            end)
            hover:SetScript("OnLeave",function() stop(view) end)
            hover:SetScript("OnHide",function() stop(view) end)
            view:EnableMouseWheel(true)
            view:SetScript("OnMouseWheel",function(_,delta)
                area:SetVerticalScroll(math.max(0,math.min(math.max(0,body:GetHeight()-height),area:GetVerticalScroll()-delta*32)))
            end)
            hover:EnableMouseWheel(true)
            hover:SetScript("OnMouseWheel",function(_,delta) view:GetScript("OnMouseWheel")(view,delta) end)
            return view
        end
        function area:SetContact(e,reset,detail)
            detail=detail or state.detail
            local rich=detail=="goods" and e~=nil
            local content,blocks=c:Details(e,rich,detail)
            if not rich or not blocks or #blocks==0 then blocks={{text=L.Safe(content)}} end
            local y=0
            for i,block in ipairs(blocks) do
                local label=self.blocks[i]
                if not label then label=U.Label(body,"",0,0,width,"GameFontHighlightSmall");self.blocks[i]=label end
                local fontName=block.heading and "GameFontNormal" or "GameFontHighlightSmall"
                label:SetFontObject(textFont(fontName))
                -- SetFont overrides survive SetFontObject. Always size from the
                -- shared base font, never from this reused label's current size.
                local base=textFont(_G[fontName])
                if base and type(base.GetFont)=="function" then
                    local path,size,flags=base:GetFont()
                    if type(path)=="string" and type(size)=="number" then
                        label:SetFont(path,size+(block.heading and 2 or 0)+(rich and 1 or 0),flags)
                    end
                end
                label:SetTextColor(1,1,1);label:SetWordWrap(not block.heading);label:SetSpacing(3)
                label:SetText(block.text);label:Show()
                if block.heading then
                    y=y+8
                    local view=self:HeadingView(i,label)
                    view:SetScript("OnUpdate",nil);view:SetHorizontalScroll(0)
                    local icon=block.text:match("|T(%d+):18:18:0:0|t ")
                    local inset=icon and 24 or 0
                    local visibleWidth=width-inset
                    view.icon:SetTexture(icon and tonumber(icon) or nil)
                    view.icon:SetShown(icon~=nil)
                    label:SetText((block.text:gsub("|T%d+:18:18:0:0|t ","",1)))
                    label:SetParent(view.canvas);label:ClearAllPoints();label:SetPoint("TOPLEFT",0,0)
                    label:SetWidth(0)
                    local measured=label:GetUnboundedStringWidth()
                    if type(measured)~="number" then measured=label:GetStringWidth() end
                    local fullWidth=math.max(visibleWidth,type(measured)=="number" and math.ceil(measured)+1 or visibleWidth)
                    label:SetWidth(visibleWidth)
                    -- Keep the resting label constrained so WoW adds an ellipsis.
                    -- Expand to its full text width only during mouseover scrolling.
                    view.contentWidth=fullWidth
                    local lineHeight=math.max(20,label:GetStringHeight())
                    view:ClearAllPoints();view:SetPoint("TOPLEFT",inset,-y);view:SetSize(visibleWidth,lineHeight)
                    view.hover:ClearAllPoints()
                    view.hover:SetPoint("TOPLEFT",view,"TOPLEFT",-inset,0)
                    view.hover:SetPoint("BOTTOMRIGHT",view,"BOTTOMRIGHT",0,0)
                    view.canvas:SetSize(fullWidth,lineHeight);view:Show();view:UpdateScrollChildRect()
                    y=y+lineHeight+5
                else
                    if self.headingViews[i] then self.headingViews[i]:Hide() end
                    label:SetParent(body);label:ClearAllPoints();label:SetPoint("TOPLEFT",0,-y);label:SetWidth(width)
                    y=y+label:GetStringHeight()+5
                end
            end
            for i=#blocks+1,#self.blocks do self.blocks[i]:Hide();if self.headingViews[i] then self.headingViews[i]:Hide() end end
            body:SetHeight(math.max(height,y+12))
            if reset then self:SetVerticalScroll(0) end
            self:UpdateScrollChildRect();self:RefreshScrollBar()
        end
        area.text=text;return area
    end
    function c:ClosePanel()
        for _,p in pairs(self.panels) do p:Hide();for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
        self.main.directory:Show();self.panel=nil;self:UpdateDetailToggles()
    end
    function c:Panel(key,title)
        self:ClosePanel();local p=self.panels[key]
        if not p then
            p=CreateFrame("Frame",nil,self.main);p:SetPoint("TOPLEFT",38,-90);p:SetSize(260,615)
            p.title=U.Label(p,title,4,-4,245,"GameFontNormalSmall")
            p.back=U.Button(p,"Back to contacts",4,-584,250,function() c:ClosePanel() end)
            self.panels[key]=p
        end
        self.main.directory:Hide();self.panel=p;p:Show();self:UpdateDetailToggles();return p
    end
    function c:RemoveContact()
        local e=journal:Get(state.selected);if not e then return end
        local p=self:Panel("remove","Remove contact")
        if not p.description then
            p.description=U.ReadArea(p,7,-35,221,330)
            p.confirm=U.Button(p,"Remove contact",4,-410,250,function()
                if journal.readOnly then c:Message("Newer Ledger schema is read-only.");return end
                tracking:Forget(p.contact)
                local ok,err=journal:Remove(p.contact)
                if ok then c:ClosePanel();c:Refresh();c:Message("Contact removed. A future interaction can record it again.")
                else c:Message(err) end
            end)
        end
        p.contact=e.id
        p.description:SetText("Remove "..e.name.." from the Ledger?\n\nThis deletes this contact’s saved goods, training, locations, notes and imported reports from the active journal.\n\nFuture interactions can record this contact again. This does not blacklist the NPC.",true)
    end
    function c:Notes()
        if self.panel and self.panel==self.panels.notes then self:ClosePanel();return end
        local e=journal:Get(state.selected);if not e then return end
        local p=self:Panel("notes","Personal / access notes")
        if not p.edit then
            p.edit,p.scroll=U.TextArea(p,9,-32,217,322,4000);p.inputs={p.edit}
            U.Label(p,"Manual service / speciality",4,-375,240,"GameFontNormalSmall")
            p.role=U.Button(p,"Choose role",4,-398,250,function(self)
                c:Menu(self,function(_,root) for _,role in ipairs(L.roleOrder) do local k=role;root:CreateButton(L.roles[k],function() p.roleID=k;p.role:SetText(L.roles[k].." (manual)") end) end end)
            end)
            p.speciality=U.Edit(p,10,-438,230,160);p.inputs[#p.inputs+1]=p.speciality
            U.Label(p,"Optional speciality; explicitly your annotation.",4,-466,245,"GameFontDisableSmall")
            U.Button(p,"Save notes / annotation",4,-514,250,function()
                local ok,err=journal:Annotate(p.contact,p.edit:GetText(),p.roleID,p.speciality:GetText())
                c:Message(ok and "Personal notes saved." or err);if ok then c:ClosePanel() end
            end)
        end
        if p.contact~=e.id then p.contact=e.id;p.edit:SetText(e.note);p.speciality:SetText("");p.roleID=nil;p.role:SetText("Choose role") end
    end
    function c:Manual()
        local p=self:Panel("manual","Record a contact manually")
        if not p.name then
            U.Label(p,"Name",4,-39,240,"GameFontNormalSmall");p.name=U.Edit(p,10,-61,230,160)
            U.Label(p,"Displayed NPC sublabel",4,-101,240,"GameFontNormalSmall");p.sublabel=U.Edit(p,10,-123,230,160)
            U.Label(p,"Creates a labelled manual record without goods, service claims or invented coordinates. Add roles and access notes afterwards.",4,-173,240,"GameFontHighlightSmall")
            U.Button(p,"Record contact",4,-285,250,function()
                local e,err=journal:Manual({name=p.name:GetText(),sublabel=p.sublabel:GetText()})
                if e then c:ClosePanel();c:Reset();c:Select(e.id);c:Notes() else c:Message(err) end
            end);p.inputs={p.name,p.sublabel}
        end
    end
    function c:Identity()
        local e=journal:Get(state.selected);if not e then return end
        local p=self:Panel("identity","Resolve contact identity")
        if not p.choice then
            p.description=U.ReadArea(p,7,-35,221,265)
            p.choice=U.Button(p,"Choose the same contact",4,-327,250,function(self)
                c:Menu(self,function(_,root)
                    root:SetScrollMode(420);local source=journal:Get(p.contact)
                    for _,row in ipairs(journal:List({})) do local target=row.contact
                        if source and target.id~=source.id and (not source.npcID or not target.npcID or source.npcID==target.npcID) then
                            local id=target.id;local location=journal:Locations(target)[1]
                            root:CreateButton(target.name.." • "..(location and location.zone or "Unknown zone").." • "..id,function()
                                p.destination=id;p.choice:SetText(target.name.." • "..id)
                                p.description:SetText("You are identifying these two records as the same individual contact:\n\n"..source.name.." • "..source.id.."\n"..target.name.." • "..target.id..
                                    "\n\nTheir personal observations will be combined, preserving the newest quoted stock and earliest observation of each offering. Reported facts remain reported. Notes are combined. Use this only when you recognize the same individual; a matching name or NPC template is insufficient.",true)
                            end)
                        end
                    end
                end)
            end)
            U.Button(p,"Confirm same individual",4,-476,250,function()
                if not p.destination then c:Message("Choose the other record first.");return end
                local e,err=journal:Link(p.contact,p.destination)
                if e then
                    for _,visit in pairs(tracking.visits) do if visit.contact==p.contact or visit.contact==p.destination then
                        -- Close old visit contexts. The next readable interface update starts a fresh inspection.
                        visit.closed=true
                    end end
                    for _,job in pairs(tracking.pending) do if job.contact==p.contact then job.contact=e.id end end
                    for kind,visit in pairs(tracking.visits) do if visit.closed then tracking.visits[kind]=nil;tracking:Begin(kind) end end
                    c:ClosePanel();c:Reset();c:Select(e.id);c:Message("Identity linked by your explicit annotation; reports remain reported.")
                else c:Message(err) end
            end)
        end
        p.contact=e.id;p.destination=nil;p.choice:SetText("Choose the same contact")
        p.description:SetText("Different NPCs may share a name, sublabel or template. This contact keeps its own inventory.\n\nFor a recognized returning or travelling NPC, select its earlier record and confirm the same individual. You can also link a personally encountered record to an imported report without confirming its reported goods.\n\nThis is an explicit identity annotation; no stock is combined until confirmation.",true)
    end
    function c:UpdateDetailToggles()
        for key,button in pairs(self.main.detailButtons or {}) do
            if button.SetSelected then
                local active=self.panel~=nil and ((key=="services" and self.panel==self.panels.notes) or
                    (self.panel==self.panels.catalogue and self.panel.kind==key))
                button:SetSelected(active)
            end
        end
    end
    function c:Catalogue(kind)
        kind=kind or (state.detail=="training" and "training" or "goods")
        if self.panel and self.panel==self.panels.catalogue and self.panel.kind==kind then self:ClosePanel();return end
        state.detail=kind
        local p=self:Panel("catalogue",kind=="training" and "Observed Training" or "Known Goods")
        p.kind=kind;p.title:SetText(kind=="training" and "Observed Training" or "Known Goods")
        if not p.read then p.read=self:GoodsReadArea(p,7,-33,221,527) end
        p.read:SetContact(journal:Get(state.selected),true,kind)
        self:UpdateDetailToggles()
    end
    function c:Reports()
        local p=self:Panel("reports","Prepare / import contact report")
        if not p.data then
            p.source=U.Button(p,"Personal / manual facts",4,-28,250,function()
                local e=journal:Get(p.contact);local n=e and #e.reports or 0;p.report=(p.report or 0)+1;if p.report>n then p.report=0 end
                p.source:SetText(p.report==0 and "Personal / manual facts" or "Forward received report "..p.report)
            end)
            p.notes=U.Check(p,"Include notes (opt in)",4,-59,220,function() end)
            p.goods=U.Check(p,"Goods",4,-85,80,function() end);p.goods:SetChecked(true)
            p.training=U.Check(p,"Training",119,-85,100,function() end);p.training:SetChecked(true)
            p.locations=U.Check(p,"Locations",4,-111,100,function() end);p.locations:SetChecked(true)
            p.prepare=U.Button(p,"Prepare",137,-111,115,function()
                local selection
                if state.query~="" then
                    selection={};local e=journal:Get(p.contact)
                    if e then for _,o in ipairs(journal:Index(e).offerings) do if o.text:find(state.query:lower(),1,true) then selection[o.key]=true end end end
                end
                local report,err=R.Build(journal,p.contact,{report=p.report and p.report>0 and p.report or nil,notes=p.notes:GetChecked()==true,
                    goods=p.goods:GetChecked()==true,lessons=p.training:GetChecked()==true,locations=p.locations:GetChecked()==true,selection=selection})
                local data;if report then data,err=R.Encode(report) end
                if data then p.data:SetText(data);p.preview:SetText(R.Preview(report),true);c:Message("Report prepared for copying. No Ledger addon-message delivery exists.") else c:Message(err) end
            end)
            p.data,p.dataScroll=U.TextArea(p,9,-147,217,92,R.MAX_BYTES);p.inputs={p.data}
            local changed=p.data:GetScript("OnTextChanged")
            p.data:SetScript("OnTextChanged",function(...) if changed then changed(...) end;R.Cancel(p.ticket);p.ticket=nil;if p.accept then p.accept:Disable() end end)
            p.review=U.Button(p,"Preview pasted data",4,-252,250,function()
                R.Cancel(p.ticket);local ticket,err=R.Prepare(p.data:GetText());p.ticket=ticket
                if ticket then p.preview:SetText(ticket.preview,true);p.accept:Enable();c:Message("Review reported claims before accepting.") else p.preview:SetText(err,true);p.accept:Disable() end
            end)
            p.preview=U.ReadArea(p,7,-287,221,190)
            p.attach=U.Check(p,"Attach to selected contact",4,-486,217,function() end)
            p.accept=U.Button(p,"Accept reported facts",4,-521,250,function()
                local e,err=R.Accept(journal,p.ticket,p.attach:GetChecked() and p.contact or nil)
                if e then p.ticket=nil;p.accept:Disable();c:ClosePanel();c:Reset();c:Select(e.id);c:Message("Report accepted; personal evidence and notes preserved.") else c:Message(err) end
            end);p.accept:Disable()
            U.Label(p,"Copy/paste boundary; no points or delivery.",4,-554,250,"GameFontDisableSmall")
        end
        if p.contact~=state.selected then
            p.contact=state.selected;p.report=0;p.source:SetText("Personal / manual facts");p.notes:SetChecked(false);p.attach:SetChecked(false)
            p.data:SetText("");p.preview:SetText("Notes are excluded by default. Current item/lesson search limits prepared offerings. Report sources are claims, not authentication.",true)
        end
    end
    function c:RefreshPortrait(e)
        local m=self.main;local token,guid
        if e then for _,unit in ipairs({"npc","target","mouseover"}) do
            local candidate=L.Read(UnitGUID,unit)
            if L.Text(candidate,160) and e.aliases[candidate] then token,guid=unit,candidate;break end
        end end
        local key=guid or (e and e.npcID and ("npc:"..e.npcID)) or "unknown"
        if m.portraitKey==key then return end
        m.portraitKey=key;m.portraitResolver.key=nil;m.portraitResolver:ClearModel()
        m.portrait:Hide();m.portraitUnknown:Show()
        if token and type(SetPortraitTexture)=="function" then
            local ok=pcall(SetPortraitTexture,m.portrait,token)
            if ok then m.portrait:Show();m.portraitUnknown:Hide();return end
        end
        if e and L.Integer(e.npcID,1,10000000) then
            m.portraitResolver.key=key
            pcall(m.portraitResolver.SetCreature,m.portraitResolver,e.npcID)
            self:ResolvePortrait()
        end
    end
    function c:ResolvePortrait()
        local m=self.main;local resolver=m.portraitResolver
        if not resolver.key or resolver.key~=m.portraitKey then return end
        local displayID=L.Read(resolver.GetDisplayInfo,resolver)
        if L.Integer(displayID,1,2147483647) and type(SetPortraitTextureFromCreatureDisplayID)=="function" then
            local ok=pcall(SetPortraitTextureFromCreatureDisplayID,m.portrait,displayID)
            if ok then m.portrait:Show();m.portraitUnknown:Hide() end
        end
    end
    function c:Refresh(preserveTop)
        if not self.main then return end;local m=self.main
        local top=preserveTop and self.rows and self.rows[state.offset+1];local topID=top and top.contact.id
        local rows,total=journal:List(state);self.rows=rows
        local oldTop=self.contactTops and self.contactTops[state.offset+1] or 0
        local within=math.max(0,(state.contactScroll or 0)-oldTop)
        local tops={};local fullHeight=0
        for i,found in ipairs(rows) do
            tops[i]=fullHeight;fullHeight=fullHeight+(journal:Sublabel(found.contact)=="" and 53 or 65)
        end
        local scroll=state.contactScroll or 0
        if topID then for i,found in ipairs(rows) do if found.contact.id==topID then scroll=tops[i]+within;break end end end
        scroll=math.max(0,math.min(scroll,math.max(0,fullHeight-420)))
        state.contactScroll=scroll;state.offset=0;self.contactTops=tops
        for i=1,#rows do if tops[i]<=scroll then state.offset=i-1 else break end end
        m.updatingList=true;m.listBody:SetHeight(math.max(420,fullHeight));m.contactList:SetVerticalScroll(scroll)
        m.contactList:UpdateScrollChildRect();m.contactList:RefreshScrollBar();m.updatingList=nil
        m.count:SetText(#rows.." / "..total.." contacts")
        m.empty:SetText(total==0 and "Your Ledger begins empty.\n\nMeet a service provider and open its interface, record a contact manually, or import a labelled report." or "No matching contacts.\nReset filters to show your known directory.")
        m.empty:SetShown(#rows==0)
        local rowTop=tops[state.offset+1] or 0
        for i,row in ipairs(m.rows) do
            local found=rows[state.offset+i];row:Hide();row.id=nil
            if found then
                local e=found.contact;local p=journal:Index(e).locations[1];row.id=e.id;row.match=found.match
                row.name:SetText((e.favourite and U.SavedIcon(true) or "")..L.Safe(e.name))
                local sublabel=journal:Sublabel(e);local lineOffset=sublabel=="" and 12 or 0
                row.sublabel:SetText(L.Safe(sublabel));row.sublabel:SetShown(sublabel~="")
                row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-rowTop);row:SetSize(228,64-lineOffset)
                rowTop=rowTop+65-lineOffset
                for key,y in pairs({zone=-25,roles=-37,reason=-49}) do
                    row[key]:ClearAllPoints();row[key]:SetPoint("TOPLEFT",3,y+lineOffset)
                end
                row.zone:SetText(L.Safe((p and p.zone or "Unknown zone")..(p and p.subzone~="" and " / "..p.subzone or "")))
                row.roles:SetText(L.Safe(journal:RoleText(e)))
                row.reason:SetText(found.match and L.Safe((found.match.reported and "Report: " or "Offers: ")..found.match.name) or (e.personal and "Personally encountered" or e.recorded and "Manually recorded" or "Reported only"))
                row:SetSelected(e.id==state.selected);row:Show()
            end
        end
        m.roles:SetText(next(state.roles) and "Roles ("..L.Count(state.roles)..")" or "All roles")
        m.zone:SetText(L.Safe(state.subzone or state.zone or "All zones"))
        m.knowledge:SetText(({personal="Personal",reported="Reported only"})[state.knowledge] or "All contacts")
        m.sort:SetText(state.sort=="recent" and "Last encounter" or "Sort: name")
        m.favourites:SetChecked(state.favourites==true);m.recipes:SetChecked(state.recipes==true)
        local e=journal:Get(state.selected)
        if not e and rows[1] then
            state.selected=rows[1].contact.id;state.sighting=1;state.sightingKey=nil;e=rows[1].contact;if m.rows[1].id==e.id then m.rows[1]:SetSelected(true) end
            state.detail=self:DefaultDetail(e)
        end
        m.remove:SetEnabled(e~=nil and not journal.readOnly)
        self:RefreshPortrait(e)
        m.name:SetText(L.Safe(e and e.name or "Merchant’s Ledger"))
        local sublabel=e and journal:Sublabel(e) or "Your directory of encountered help"
        m.sublabel:SetText(L.Safe(sublabel));m.sublabel:SetShown(sublabel~="")
        local lineOffset=sublabel=="" and 23 or 0
        for key,y in pairs({services=-108,location=-128,dates=-158}) do
            m[key]:ClearAllPoints();m[key]:SetPoint("TOPLEFT",key=="services" and 392 or 342,y+lineOffset)
        end
        m.services:SetText(e and L.Safe(journal:RoleText(e)) or "")
        local sightings=e and journal:Locations(e) or {};state.sighting=1
        local explicitlySelected=false
        if state.sightingKey then for i,p in ipairs(sightings) do
            if state.sightingKey==L.Key(p.reported==true,p.origin.source,p.origin.key) then
                state.sighting=i;explicitlySelected=true;break
            end
        end end
        if not explicitlySelected then
            local latest=sightings[1]
            if latest and not L.Position(latest) then
                -- Passive sightings know the zone, not the NPC's coordinates.
                -- Prefer the latest positioned sighting in that same area so
                -- the header describes the recorded point shown on the map.
                for i,p in ipairs(sightings) do
                    if L.Position(p) and p.mapID==latest.mapID and p.zone==latest.zone and p.subzone==latest.subzone
                        and not p.reported==not latest.reported then state.sighting=i;break end
                end
            end
        end
        local p=sightings[state.sighting]
        m.location:SetText(L.Safe((p and p.reported and "REPORTED • " or "")..L.PositionLabel(p)))
        m.dates:SetText(e and ("First encounter: "..date(e.first).." • Last: "..date(e.last).."\nShop: "..date(e.merchantInspection and e.merchantInspection.at).." • Trainer: "..date(e.trainerInspection and e.trainerInspection.at)) or "")
        local matches=false;for _,row in ipairs(rows) do if row.contact==e then matches=true;break end end
        m.status:SetText(e and ((e.personal and "Personal" or e.recorded and "Manual" or "Reported only")..(matches and "" or " · filtered")) or "")
        m.sightings:SetText("Locations ("..#sightings..")");m.sightings:SetEnabled(#sightings>0)
        m.favourite:SetSaved(e and e.favourite,e~=nil);m.favourite:SetText(e and e.favourite and "Saved" or "Favourite");m.favourite:SetEnabled(e~=nil)
        for key,button in pairs(m.detailButtons) do button:SetEnabled(e~=nil) end
        self:UpdateDetailToggles()
        m.details:SetText(self:Details(e,false,"services"));m.map:Render()
        if self.panel==self.panels.catalogue and self.panel then self.panel.read:SetContact(e,false,self.panel.kind) end
    end
    local function build(content)
        c.frame=content;local m=CreateFrame("Frame",nil,content);m:SetAllPoints();c.main=m
        local spine=m:CreateTexture(nil,"ARTWORK");spine:SetColorTexture(0.25,0.13,0.055,0.35);spine:SetPoint("TOPLEFT",306,-53);spine:SetSize(3,661)
        U.Label(m,"Merchant’s Ledger",42,-60,260,"GameFontNormalLarge")
        m.directory=CreateFrame("Frame",nil,m);m.directory:SetAllPoints();local d=m.directory
        m.search=U.Edit(d,48,-92,240,200);m.search:SetText(state.query)
        m.search:SetScript("OnTextChanged",function() state.query=m.search:GetText();c:Filter() end)
        m.roles=U.MenuButton(d,"All roles",42,-121,121,function(self)
            c:Menu(self,function(_,root)
                root:CreateButton("All roles",function() state.roles={};c:Filter() end)
                for _,role in ipairs(L.roleOrder) do local k=role;root:CreateCheckbox(L.roles[k],function() return state.roles[k]==true end,function() state.roles[k]=not state.roles[k] or nil;c:Filter() end) end
            end)
        end)
        m.zone=U.MenuButton(d,"All zones",170,-121,122,function(self)
            c:Menu(self,function(_,root)
                root:SetScrollMode(400);root:CreateButton("All zones",function() state.zone=nil;state.subzone=nil;c:Filter() end)
                local zones=journal:Zones();for _,zone in ipairs(sortedKeys(zones)) do
                    local name=zone;local sub=root:CreateButton(name);sub:CreateButton("All of "..name,function() state.zone=name;state.subzone=nil;c:Filter() end)
                    for _,s in ipairs(sortedKeys(zones[name])) do local subzone=s;sub:CreateButton(s,function() state.zone=name;state.subzone=subzone;c:Filter() end) end
                end
            end)
        end)
        m.knowledge=U.Button(d,"All contacts",42,-150,121,function() state.knowledge=state.knowledge==nil and "personal" or state.knowledge=="personal" and "reported" or nil;c:Filter() end)
        m.sort=U.Button(d,"Sort: name",170,-150,122,function() state.sort=state.sort=="recent" and "name" or "recent";c:Filter() end)
        m.favourites=U.Check(d,"Favourites",42,-177,98,function(on) state.favourites=on;c:Filter() end)
        m.recipes=U.Check(d,"Recipes",170,-177,90,function(on) state.recipes=on;c:Filter() end)
        m.reset=U.Button(d,"Reset filters",42,-206,121,function() c:Reset() end)
        m.reports=U.Button(d,"Reports",170,-206,122,function() c:Reports() end)
        m.count=U.Label(d,"",42,-238,250,"GameFontHighlightSmall");m.rows={}
        m.contactsBackground=d:CreateTexture(nil,"BACKGROUND")
        m.contactsBackground:SetPoint("TOPLEFT",38,-254);m.contactsBackground:SetSize(258,424)
        m.contactsBackground:SetColorTexture(0,0,0,0.12)
        m.contactList,m.listBody=U.Scroll(d,42,-258,228,420)
        m.contactList:HookScript("OnVerticalScroll",function(self,value)
            if not m.updatingList then state.contactScroll=value or self:GetVerticalScroll();c:Refresh() end
        end)
        for i=1,10 do
            local row=CreateFrame("Button",nil,m.listBody,"BackdropTemplate");row:SetPoint("TOPLEFT",0,-(i-1)*65);row:SetSize(228,64)
            ns.FieldbookUI.StyleMenuRow(row)
            row.name=U.Label(row,"",3,-1,222,"GameFontNormalSmall")
            row.sublabel=U.Label(row,"",3,-13,222,"GameFontHighlightSmall")
            row.zone=U.Label(row,"",3,-25,222,"GameFontDisableSmall")
            row.roles=U.Label(row,"",3,-37,222,"GameFontHighlightSmall")
            row.reason=U.Label(row,"",3,-49,222,"GameFontDisableSmall")
            for _,k in ipairs({"name","sublabel","zone","roles","reason"}) do row[k]:SetWordWrap(false) end
            row:SetScript("OnClick",function(self) c:Select(self.id,self.match) end);m.rows[i]=row
        end
        m.empty=U.Label(d,"",49,-285,235,"GameFontHighlight");m.empty:SetWordWrap(true);m.empty:SetSpacing(5)
        m.manual=U.Button(d,"Record contact",42,-687,121,function() c:Manual() end)
        m.remove=U.Button(d,"Remove contact",170,-687,122,function() c:RemoveContact() end)
        m.portraitFrame=CreateFrame("Frame",nil,m)
        m.portraitFrame:SetPoint("TOPLEFT",342,-54);m.portraitFrame:SetSize(42,42)
        m.portrait=m.portraitFrame:CreateTexture(nil,"ARTWORK")
        m.portrait:SetPoint("CENTER");m.portrait:SetSize(38,38)
        if type(m.portraitFrame.CreateMaskTexture)=="function" and type(m.portrait.AddMaskTexture)=="function" then
            local mask=m.portraitFrame:CreateMaskTexture()
            if mask then
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(m.portrait);m.portrait:AddMaskTexture(mask);m.portraitMask=mask
            end
        end
        local function portraitCircle(size,r,g,b,layer)
            local texture=m.portraitFrame:CreateTexture(nil,"BACKGROUND",nil,layer)
            texture:SetSize(size,size);texture:SetPoint("CENTER");texture:SetColorTexture(r,g,b,1)
            local mask=m.portraitFrame:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(texture);texture:AddMaskTexture(mask)
            return texture
        end
        m.portraitRim=portraitCircle(45,0.20,0.12,0.055,-2)
        m.portraitRing=portraitCircle(43,0.67,0.43,0.19,-1)
        m.portraitBacking=portraitCircle(38,0.035,0.025,0.015,0)
        m.portraitUnknown=U.Label(m.portraitFrame,"?",0,-7,42,"GameFontNormalLarge")
        m.portraitUnknown:SetJustifyH("CENTER")
        -- Resolve an offline NPC's display ID without displaying a 3D widget.
        m.portraitResolver=CreateFrame("PlayerModel",nil,m)
        m.portraitResolver:SetSize(1,1);m.portraitResolver:SetPoint("TOPLEFT");m.portraitResolver:SetAlpha(0)
        m.portraitResolver:EnableMouse(false)
        m.portraitResolver:SetScript("OnModelLoaded",function() c:ResolvePortrait() end)
        m.name=U.Label(m,"",392,-59,376,"GameFontNormalLarge");m.name:SetWordWrap(false)
        m.favourite=U.SavedButton(m,"Favourite",812,-55,110,function() journal:Favourite(state.selected) end)
        m.sublabel=U.Label(m,"",392,-85,385,"GameFontHighlight");m.sublabel:SetWordWrap(false)
        m.status=U.Label(m,"",785,-86,137,"GameFontHighlightSmall")
        m.services=U.Label(m,"",392,-108,530,"GameFontHighlightSmall");m.services:SetWordWrap(false)
        m.location=U.Label(m,"",342,-128,580,"GameFontHighlightSmall");m.location:SetWordWrap(true)
        m.dates=U.Label(m,"",342,-158,580,"GameFontDisableSmall");m.dates:SetWordWrap(false)
        m.sightings=U.MenuButton(m,"Locations",342,-174,287,function(self)
            local e=journal:Get(state.selected);if not e then return end
            c:Menu(self,function(_,root)
                root:SetScrollMode(400)
                for i,p in ipairs(journal:Locations(e)) do local index=i;root:CreateButton((p.reported and "Reported: " or "Personal: ")..L.PositionLabel(p).." • "..date(p.last),function() c:Sighting(index) end) end
            end)
        end)
        m.link=U.Button(m,"Link identity",635,-174,287,function() c:Identity() end)
        m.map=ns.CreateLedgerMap(m,journal,function() return state.selected,state.sighting end,function(index) c:Sighting(index) end)
        m.map:SetPoint("TOP",m,"TOPLEFT",632,-205)
        m.detailButtons={}
        for i,v in ipairs({{"goods","Known Goods"},{"training","Observed Training"},{"services","Edit notes"}}) do
            local key=v[1];local button=U.Button(m,v[2],342+(i-1)*195,-588,190,function()
                if key=="services" then c:Notes() else c:Catalogue(key) end
            end)
            m.detailButtons[key]=button
            U.StyleSelection(button)
        end
        m.details=U.ReadArea(m,342,-621,555,80)
        m.message=U.Label(m,"",342,-712,580,"GameFontHighlightSmall");m.message:SetWordWrap(false)
        content:SetScript("OnHide",function()
            state.detailScroll=m.details:GetVerticalScroll();m.map:SuspendPlayer();m.search:ClearFocus()
            for _,p in pairs(c.panels) do for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
            if GameTooltip then GameTooltip:Hide() end
        end)
        c:Refresh();m.details:SetVerticalScroll(state.detailScroll or 0)
        if journal.readOnly then c:Message("Newer Ledger schema: read-only; saved data is untouched.") end
    end
    shell:RegisterSection("merchants",{title="Merchant’s Ledger",icon="Interface\\Icons\\INV_Misc_Coin_01",frameName="AzerothFieldbookLedgerSection",build=build,
        help=L.VISION.."\n\n|cffffd100Directory|r\nFind remembered merchants, trainers and services by name, goods, training, zone or notes. Use role, location and recipe filters to narrow the directory; Reset filters shows the full directory again. Record contact adds a contact manually.\n\n"..
            "|cffffd100Observation|r\nOpen a merchant or trainer to record readable offerings without buying. Supported service interactions also record contacts; recognizable class-trainer titles can reveal a trainer before you open its services.\n\nGoods, prices and stock describe past inspections, not live availability. A partial or filtered view may miss offerings. Something absent from the latest inspection is not proof it is no longer sold.\n\n"..
            "|cffffd100Locations and identity|r\nLocations shows remembered encounters. Encountered near means your approximate position during an interaction, not the NPC's exact position. Distant targeting does not add your position as the contact's location.\n\nContacts with the same name may be different individuals. Use Link identity only when you recognize two entries as the same contact; their goods and history are combined after confirmation.\n\n"..
            "|cffffd100Access notes and details|r\nUse Edit notes for entrances, floors, personal notes or a manual role annotation. Known Goods and Observed Training open offering lists; click the same button again or Back to contacts to return to the directory.\n\n"..
            "|cffffd100Reports|r\nSelect a contact and open Reports. Choose what to include, then Prepare text for copying. When preparing your own observations, the current search limits included offerings. Notes start excluded. To import, use Preview pasted data, review it, then Accept reported facts. Received facts remain Reported with their original source and observation dates; receiving them is not a personal encounter. Reports use copy and paste and cost no Knowledge.\n\n"..
            "|cffffd100Your journal|r\nContacts, notes and browsing settings follow the global Account-wide tracking option. It starts on in Options; turn it off to use this character's separate journal after /reload. Existing character records import once; later changes in the two scopes stay separate.",
        onOpen=function() if c.main then c:Refresh();c.main.details:SetVerticalScroll(state.detailScroll or 0) end end})
    journal.onMerchantDiscovered=function(entry)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAzeroth Fieldbook:|r Merchant discovered: |cffffd100"..
                L.Safe(entry.name).."|r — added to the Merchant's Ledger.")
        end
    end
    journal.onChange=function()
        if not c.main or shell.active~="merchants" or not shell:GetFrame():IsShown() or c.refreshQueued then return end
        c.refreshQueued=true
        local function refresh() c.refreshQueued=false;if shell.active=="merchants" and shell:GetFrame():IsShown() then c:Refresh(true) end end
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.1,refresh) else refresh() end
    end
    return c
end
function ns.InitializeLedger(shell)
    if type(AzerothFieldbookLedgerDB)~="table" then AzerothFieldbookLedgerDB={} end
    local storage=ns.SelectSectionStorage and ns.SelectSectionStorage("ledger",AzerothFieldbookLedgerDB) or AzerothFieldbookLedgerDB
    local journal=ns.CreateLedgerJournal(storage)
    return ns.CreateLedgerBook(journal,ns.CreateLedgerTracking(journal),shell)
end
