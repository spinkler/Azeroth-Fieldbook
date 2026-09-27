local _, ns = ...
local A,U,R=ns.Atlas,ns.AtlasUI,ns.AtlasReports
local function sourceName()
    local fn=UnitNameUnmodified or UnitName
    if type(fn)~="function" then return "Unknown character" end
    local ok,first,surname=pcall(fn,"player")
    if not ok or not A.Text(first,160) or not A.Public(surname) then return "Unknown character" end
    if surname and surname~="" and A.Text(surname,80) then
        local full=A.Read(NameUtil and NameUtil.GetFullNameWithoutRealm,first,surname)
        return A.Text(full,160) and full or first.." "..surname
    end
    return first
end
function ns.InstallAtlasReportUI(c)
    local j=c.journal
    function c:Report()
        local p=self.pages.report
        if not p then
            p=U.Panel(self.frame,self.shell,"Prepare a regional field report",function() c:Show();c:Refresh() end)
            self.pages.report=p;p.offset=0;p.mode="records"
            if not j.readOnly and type(j.saved.reportDraft)~="table" then j.saved.reportDraft={} end
            local d=j.readOnly and {} or j.saved.reportDraft
            p.draft=d;d.records=type(d.records)=="table" and d.records or {};d.notes=type(d.notes)=="table" and d.notes or {}
            for id,on in pairs(d.records) do if on~=true then d.records[id]=nil end end
            for id,on in pairs(d.notes) do if on~=true or not d.records[id] then d.notes[id]=nil end end
            d.expeditions=type(d.expeditions)=="table" and d.expeditions or {}
            d.region=type(d.region)=="table" and d.region or {kind="selection",name="Selected discoveries"}
            p.titleEdit=U.Field(p,"Report title",24,-56,480,160);p.titleEdit:SetText(d.title or "")
            p.region=U.Field(p,"Region / selection name",525,-56,330,160);p.region:SetText(d.region.name or "")
            p.titleEdit:SetScript("OnTextChanged",function() d.title=p.titleEdit:GetText() end)
            p.region:SetScript("OnTextChanged",function() d.region.name=p.region:GetText() end)
            p.zone=U.Button(p,"Choose zone",24,-115,190,function()
                c:PickZone(function(z)
                    d.region={kind="zone",name=z.zone,mapID=z.mapID};d.records={};d.notes={}
                    p.region:SetText(z.zone);p.offset=0;p:Render();c:Show(p)
                end,function() c:Show(p) end)
            end)
            U.Button(p,"Named selection",224,-115,170,function()
                d.region={kind="selection",name=p.region:GetText()};p.offset=0;p:Render()
            end)
            p.modeButton=U.Button(p,"Choose expeditions",405,-115,212,function()
                p.mode=p.mode=="records" and "expeditions" or "records";p.offset=0;p:Render()
            end)
            U.Button(p,"Clear selection",630,-115,222,function() d.records={};d.notes={};d.expeditions={};p:Render() end)
            p.search=U.Edit(p,29,-155,555,200);p.search:SetScript("OnTextChanged",function() p.offset=0;p:Render() end)
            p.refs=U.Check(p,"Include reference names",609,-155,217,function(on) d.includeReferences=on end)
            p.hint=U.Label(p,"",24,-189,822,"GameFontHighlightSmall");p.hint:SetWordWrap(true)
            p.rows={}
            for i=1,7 do
                local y=-233-(i-1)*40
                local row=U.Button(p,"",24,y,605,function(self)
                    if not self.data then return end
                    local id=self.data.id
                    if p.mode=="records" then d.records[id]=not d.records[id] or nil;if not d.records[id] then d.notes[id]=nil end
                    else if d.expeditions[id]~=nil then d.expeditions[id]=nil else d.expeditions[id]="" end end
                    p:Render()
                end)
                row:SetHeight(35);row:SetNormalFontObject("GameFontHighlightSmall")
                row.note=U.Button(p,"",641,y,210,function()
                    if not row.data then return end
                    local id=row.data.id
                    if p.mode=="records" then
                        if d.records[id] then d.notes[id]=not d.notes[id] or nil end;p:Render()
                    else c:ReportExcerpt(id) end
                end)
                p.rows[i]=row
            end
            p.previous=U.Button(p,"Previous",24,-524,100,function() p.offset=math.max(0,p.offset-7);p:Render() end)
            p.next=U.Button(p,"Next",134,-524,100,function() p.offset=p.offset+7;p:Render() end)
            p.count=U.Label(p,"",254,-531,595,"GameFontHighlightSmall")
            U.Button(p,"Preview report",24,-571,200,function()
                local payload,err=R.Build(j,d,sourceName())
                if not payload then p.message:SetText(err);return end
                c:ReportPreview(payload)
            end)
            U.Label(p,"No delivery or import occurs. Draft selections are saved for this character.",243,-577,608,"GameFontHighlightSmall")
            p.inputs={p.titleEdit,p.region,p.search}
            function p:Render()
                local exp=self.mode=="expeditions";local rows=j:List(self.search:GetText(),d.region.mapID,d.region.kind~="zone",exp)
                local seen={};for _,r in ipairs(rows) do seen[r.id]=true end
                for id,on in pairs(exp and d.expeditions or d.records) do
                    if on~=false and not seen[id] and not j:Get(id,exp) then rows[#rows+1]={id=id,name=id.." (missing — remove selection)",zone=""} end
                end
                self.offset=math.max(0,math.min(self.offset,math.floor(math.max(0,#rows-1)/7)*7))
                self.modeButton:SetText(exp and "Choose discoveries" or "Choose expeditions")
                self.zone:SetText(d.region.kind=="zone" and "Zone: "..tostring(d.region.mapID) or "Choose zone")
                self.refs:SetChecked(d.includeReferences==true)
                self.hint:SetText(exp and "Select a note, then choose an excerpt or explicitly include its full text. A selected note initially contains no journal text."
                    or "Select discoveries on the left. Include private notes separately on the right. Routes include stop names/positions; they do not include linked places’ notes.")
                for i,row in ipairs(self.rows) do
                    local r=rows[self.offset+i];row.data=r;row:SetShown(r~=nil);row.note:SetShown(r~=nil)
                    if r then
                        local selected=exp and d.expeditions[r.id]~=nil or not exp and d.records[r.id]==true
                        row:SetText(A.Safe((selected and "[Included] " or "[ ] ")..r.name.."\n"..(r.zone or "")))
                        row.note:SetEnabled(selected and j:Get(r.id,exp)~=nil)
                        row.note:SetText(exp and "Choose note excerpt…" or (d.notes[r.id] and "Notes included: yes" or "Include private notes"))
                    end
                end
                self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+7<#rows)
                local n=0;for _,v in pairs(d.records) do if v then n=n+1 end end
                self.count:SetText(n.." discoveries, "..A.Count(d.expeditions).." expedition excerpts selected • "..#rows.." results")
                self.message:SetText("Preview lists every included note. Attribution in an exported report is not authenticated.")
            end
        end
        p:Render();self:Show(p)
    end
    function c:ReportExcerpt(id)
        local e=j:Get(id,true);if not e then return end
        local p=self.pages.excerpt
        if not p then
            p=U.Panel(self.frame,self.shell,"Choose expedition text",function() c:Report() end);self.pages.excerpt=p
            U.Label(p,"Only the text in this box will be included. Paste an excerpt or explicitly copy the entire note.",24,-67,820,"GameFontHighlight")
            p.text,p.scroll=U.TextArea(p,28,-108,796,426,8000)
            U.Button(p,"Use entire note",24,-572,182,function() local n=j:Get(p.id,true);if n then p.text:SetText(n.notes) end end)
            U.Button(p,"Include this excerpt",223,-572,225,function()
                local text=p.text:GetText();if not A.Text(text,8000,true) then p.message:SetText("Use plain text within 8000 bytes.");return end
                c.pages.report.draft.expeditions[p.id]=text;c:Report()
            end)
            p.inputs={p.text}
        end
        p.id=id;p.title:SetText("Expedition excerpt: "..e.name);p.text:SetText(self.pages.report.draft.expeditions[id] or "")
        p.scroll:SetVerticalScroll(0);self:Show(p)
    end
    function c:ReportPreview(payload)
        local p=self.pages.preview
        if not p then
            p=U.Panel(self.frame,self.shell,"Regional field report preview",function() c:Report() end);self.pages.preview=p
            p.preview=U.ReadArea(p,25,-62,803,531)
        end
        local encoded,err=R.Encode(payload);if not encoded then self.pages.report.message:SetText(err);return end
        p.payload,p.serialized=payload,encoded;p.preview:SetText(R.Preview(payload),true)
        p.message:SetText(#payload.records.." discoveries • "..#payload.expeditions.." expedition excerpts • "..#encoded.." serialized bytes • schema 1")
        self:Show(p)
    end
end
