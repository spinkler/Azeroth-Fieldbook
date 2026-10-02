local _, ns = ...
local L,U=ns.Lore,ns.AtlasUI
local kindNames={writing="Writing",landmark="Landmark",person="Person",mystery="Mystery"}
local statuses={open="Open",investigating="Investigating",resolved="Resolved by me"}
local function tags(text)
    local out={};for tag in (text or ""):gmatch("[^,]+") do tag=tag:match("^%s*(.-)%s*$");if tag~="" then out[#out+1]=tag end end;return out
end
function L.InstallEditors(c)
    local j,state=c.journal,c.state
    function c:ClosePanel()
        for _,p in pairs(self.panels) do
            if p:IsShown() and p.StoreDraft then p:StoreDraft() end
            p:Hide();for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end
        end
        self.panel=nil;self.main:Show();self:Refresh()
    end
    function c:Panel(key,title)
        self:ClosePanel();local p=self.panels[key]
        if not p then p=U.Panel(self.frame,self.shell,title,function() c:ClosePanel() end);self.panels[key]=p end
        p.title:SetText(title);p.message:SetText("");self.main:Hide();self.panel=p;p:Show();return p
    end
    function c:Edit(kind,id)
        local e=id and j:Get(id);if id and not e then return end
        kind=e and e.kind or kind
        if not kindNames[kind] then return end
        local p=self:Panel("edit",(e and "Edit " or "Record ")..kindNames[kind])
        if not p.name then
            p.scroll,p.body=U.Scroll(p,24,-56,810,505);local b=p.body
            p.name=U.Field(b,"Title (original source title is preserved)",2,0,382,200)
            p.subtype=U.Field(b,"Subtype / person's title (optional)",424,0,370,80)
            p.tags=U.Field(b,"Tags (comma separated)",2,-61,382,1000)
            p.revisit=U.Check(b,"Revisit / follow up",424,-77,320,function() end)
            U.Label(b,"Description / your observations (private)",2,-125,382,"GameFontNormalSmall")
            p.description=U.TextArea(b,7,-151,353,144,16000)
            U.Label(b,"Personal notes (private)",424,-125,370,"GameFontNormalSmall")
            p.notes=U.TextArea(b,429,-151,340,144,32000)
            p.theoryLabel=U.Label(b,"Working theory (private)",2,-320,382,"GameFontNormalSmall")
            p.theory,p.theoryScroll=U.TextArea(b,7,-346,353,112,16000)
            p.nextLabel=U.Label(b,"Next step (private)",424,-320,370,"GameFontNormalSmall")
            p.nextStep,p.nextScroll=U.TextArea(b,429,-346,340,112,4000)
            p.status=U.MenuButton(b,"Open",2,-484,382,function(button)
                c:Menu(button,function(_,root) for _,key in ipairs({"open","investigating","resolved"}) do
                    root:CreateButton(statuses[key],function() p.statusID=key;p.status:SetText(statuses[key]) end)
                end end)
            end)
            p.hint=U.Label(b,"",2,-324,792,"GameFontHighlightSmall")
            p.inputs={p.name,p.subtype,p.tags,p.description,p.notes,p.theory,p.nextStep};p.drafts={}
            function p:StoreDraft()
                if not self.key then return end
                self.drafts[self.key]={title=self.name:GetText(),subtype=self.subtype:GetText(),tags=tags(self.tags:GetText()),
                    revisit=self.revisit:GetChecked()==true,description=self.description:GetText(),notes=self.notes:GetText(),
                    theory=self.theory:GetText(),nextStep=self.nextStep:GetText(),status=self.statusID}
            end
            p.save=U.Button(p,"Save entry",24,-571,180,function()
                p:StoreDraft();local fields=p.drafts[p.key];local saved,err
                if p.entryID then saved,err=j:Update(p.entryID,fields) else saved,err=j:Create(p.kind,fields) end
                if not saved then p.message:SetText(L.Safe(err or "Entry could not be saved."));return end
                local id=p.entryID or saved.id
                p.drafts[p.key]=nil;p.key=nil;c:ClosePanel();c:Select(id);c:Message("Entry saved. Source text and personal interpretation remain separate.")
            end)
            U.Button(p,"Discard this draft",220,-571,180,function()
                p.drafts[p.key]=nil;p.key=nil;c:ClosePanel()
            end)
        end
        p.entryID=id;p.kind=kind;p.key=id or "new:"..kind
        local data=p.drafts[p.key] or e or {}
        p.name:SetText(data.title or "");p.subtype:SetText(data.subtype or "");p.tags:SetText(table.concat(data.tags or {},", "))
        p.revisit:SetChecked(data.revisit==true);p.description:SetText(data.description or "");p.notes:SetText(data.notes or "")
        p.theory:SetText(data.theory or "");p.nextStep:SetText(data.nextStep or "");p.statusID=data.status or "open"
        p.status:SetText(statuses[p.statusID] or "Open")
        local mystery=kind=="mystery"
        for _,control in ipairs({p.theoryLabel,p.nextLabel,p.status}) do control:SetShown(mystery) end
        p.theoryScroll:SetShown(mystery);p.nextScroll:SetShown(mystery)
        p.hint:SetShown(not mystery);p.hint:SetText(kind=="writing" and "Preserve source text with Add passage / transcription after saving. Editing this title changes your label, not the original title or captured pages." or
            kind=="landmark" and "Add locations after saving. Your observation position and the landmark's position are distinct. No Atlas discovery is created." or
            "Record a supported NPC or save its displayed passage from the catalogue. Manual records preserve only what you enter.")
        p.body:SetHeight(mystery and 523 or 430);p.scroll:SetVerticalScroll(0)
        if mystery then p.message:SetText("Resolved by me records your conclusion; it does not establish canonical truth. You can reopen this mystery.") end
    end
    function c:Passage()
        local e=j:Get(state.selected);if not e then return end
        local p=self:Panel("passage","Add source / observation / interpretation")
        if not p.raw then
            p.source=U.Field(p,"Source / speaker / description",24,-58,806,200)
            p.nature=U.MenuButton(p,"Preserved source text",24,-118,380,function(button)
                c:Menu(button,function(_,root) for _,row in ipairs({{"source","Preserved source text"},{"observation","Direct observation"},{"account","Reported account"},{"interpretation","Personal interpretation"}}) do
                    root:CreateButton(row[2],function() p.natureID=row[1];p.nature:SetText(row[2]) end)
                end end)
            end)
            U.Label(p,"Manual transcription is labelled as manually recorded. Preserve corrections as a new passage; captured originals stay unchanged.",24,-156,805,"GameFontHighlightSmall")
            -- Unlimited edit buffer: validation refuses oversized source text instead
            -- of silently cutting a pasted transcription at the widget limit.
            p.raw=U.TextArea(p,29,-205,778,330,0)
            p.inputs={p.source,p.raw};p.drafts={};p.natureID="source"
            function p:StoreDraft()
                if self.entryID then self.drafts[self.entryID]={raw=self.raw:GetText(),source=self.source:GetText(),nature=self.natureID} end
            end
            p.save=U.Button(p,"Save manual passage",24,-571,240,function()
                local result,err=j:AddPassage(p.entryID,{raw=p.raw:GetText(),source=p.source:GetText(),origin="manual",nature=p.natureID,method="manual"})
                if not result then p.message:SetText(L.Safe(err or "Passage could not be saved."));return end
                p.drafts[p.entryID]=nil;p.entryID=nil;c:ClosePanel();c:Message("Manual passage saved separately from captured evidence.")
            end)
            U.Button(p,"Discard this draft",282,-571,220,function() p.drafts[p.entryID]=nil;p.entryID=nil;c:ClosePanel() end)
        end
        p.entryID=e.id;local d=p.drafts[e.id] or {}
        p.source:SetText(d.source or e.sourceTitle or j:Title(e));p.raw:SetText(d.raw or "");p.natureID=d.nature or "source"
        p.nature:SetText(({source="Preserved source text",observation="Direct observation",account="Reported account",interpretation="Personal interpretation"})[p.natureID])
    end
    function c:Location(index,placed)
        local e=j:Get(state.selected);if not e then return end
        local existing=index and L.VisibleLocations(e)[index]
        local p=self:Panel("location",existing and "Location details" or "Add a location")
        if not p.zone then
            p.meaning=U.MenuButton(p,"Observation position",24,-66,385,function(button)
                c:Menu(button,function(_,root) for _,key in ipairs({"observation","landmark","read","encounter","found","reported","mentioned"}) do
                    root:CreateButton(L.locationLabels[key],function()
                        p.meaningID=key;p.meaning:SetText(L.locationLabels[key])
                        if key=='mentioned' then p.x:SetText('');p.y:SetText('') end
                    end)
                end end)
            end)
            p.zone=U.Field(p,"Zone",24,-113,385,160);p.subzone=U.Field(p,"Subzone / area",446,-113,385,160)
            p.mapID=U.Field(p,"Map ID (optional)",24,-182,385,12)
            p.x=U.Field(p,"X % (optional)",446,-182,178,12);p.y=U.Field(p,"Y % (optional)",650,-182,178,12)
            p.label=U.Field(p,"Location context / explanation",24,-255,806,1000)
            p.current=U.Button(p,"Use current observation position",24,-330,385,function()
                p:Fill(L.CurrentLocation("observation"));p.message:SetText("This is the player's observation position. Choose Landmark position only after deliberately placing it.")
            end)
            p.clear=U.Button(p,"Leave coordinates unknown",446,-330,385,function() p.x:SetText("");p.y:SetText("") end)
            U.Label(p,"Read here means where a text was opened. Found here requires an established acquisition location. Places merely mentioned remain text without invented coordinates. To place a landmark deliberately, close this form, use Location view and Place on map.",24,-389,800,"GameFontHighlight")
            p.inputs={p.zone,p.subzone,p.mapID,p.x,p.y,p.label};p.drafts={}
            function p:Fields()
                return {meaning=self.meaningID,zone=self.zone:GetText(),subzone=self.subzone:GetText(),mapID=self.mapID:GetText(),
                    x=self.x:GetText(),y=self.y:GetText(),label=self.label:GetText()}
            end
            function p:StoreDraft() if self.key then self.drafts[self.key]=self:Fields() end end
            function p:Fill(v,draft)
                self.meaningID=v.meaning or "observation";self.meaning:SetText(L.locationLabels[self.meaningID] or self.meaningID)
                self.zone:SetText(v.zone or "");self.subzone:SetText(v.subzone or "");self.mapID:SetText(v.mapID and tostring(v.mapID) or "")
                self.x:SetText(v.x and (draft and v.x or tostring(v.x/100)) or "")
                self.y:SetText(v.y and (draft and v.y or tostring(v.y/100)) or "");self.label:SetText(v.note or v.label or "")
            end
            p.save=U.Button(p,"Add location",24,-571,220,function()
                local values=p:Fields();local x,y,err=ns.Atlas.Coordinates(values.x,values.y)
                if err then p.message:SetText(err);return end
                local mapID=tonumber(values.mapID)
                if values.mapID~="" and (not mapID or mapID<1 or mapID%1~=0) then p.message:SetText("Use a valid map ID or leave it blank.");return end
                values.x,values.y,values.mapID=x,y,mapID;values.origin="manual";values.method="manual";values.precision=x and "manual" or "unknown"
                values.note=values.label;values.label=nil
                local ok;ok,err=j:AddLocation(p.entryID,values)
                if not ok then p.message:SetText(L.Safe(err or "Location could not be saved."));return end
                p.drafts[p.key]=nil;p.key=nil;c:ClosePanel();state.location=#j:Get(p.entryID).locations;state.mapID=mapID;c:Refresh()
            end)
            p.remove=U.Button(p,"Remove location…",262,-571,220,function()
                c:Confirm("Remove location","Remove this location? Preserved text and other locations remain.",function()
                    return j:RemoveLocation(p.entryID,p.locationID)
                end)
            end)
        end
        p.entryID=e.id;p.index=index;p.locationID=existing and existing.id;p.key=e.id..":"..tostring(index or "new")
        local draft=not placed and p.drafts[p.key] or nil
        p:Fill(placed or draft or existing or L.CurrentLocation("observation"),type(draft)=='table')
        p.save:SetShown(not existing);p.remove:SetShown(existing~=nil and not existing.reported)
        for _,control in ipairs({p.meaning,p.zone,p.subzone,p.mapID,p.x,p.y,p.label,p.current,p.clear}) do control:SetEnabled(not existing) end
        if existing then p.message:SetText(existing.reported and "Received location claim. It is kept with its report, separate from your own observations." or "Original location evidence is retained. Add an adjusted location separately or remove a mistaken location explicitly.") end
    end
    function c:Confirm(title,description,action)
        local p=self:Panel("confirm",title)
        if not p.description then
            p.description=U.Label(p,"",24,-78,800,"GameFontHighlight");p.description:SetWordWrap(true);p.description:SetSpacing(5)
            p.accept=U.Button(p,"Confirm",24,-571,200,function()
                local ok,err=p.action();if ok then c:ClosePanel();c:Refresh() else p.message:SetText(L.Safe(err or "Could not complete the change.")) end
            end)
        end
        p.description:SetText(L.Safe(description));p.action=action
    end
    function c:Relationships()
        local e=j:Get(state.selected);if not e then return end
        local p=self:Panel("links","Related entries — references keep their own records")
        if not p.search then
            p.search=U.Search(p,29,-77,794,200)
            p.reason=U.Field(p,"Connection (optional): mentions the same emblem, conflicting account…",24,-119,804,500)
            p.mode=U.Button(p,"Show linked only",24,-184,220,function() p.linked=not p.linked;p.offset=0;p:Render() end)
            p.rows={};p.inputs={p.search,p.reason}
            for i=1,6 do
                local row=U.Button(p,"",24,-225-(i-1)*46,576,function() end);row:SetHeight(40)
                row.open=U.Button(p,"Open",614,-230-(i-1)*46,98,function()
                    if row.data then local ok,err=c.references:Open(row.data);if not ok then p.message:SetText(L.Safe(err)) end end
                end)
                row.action=U.Button(p,"Link",723,-230-(i-1)*46,106,function()
                    local d=row.data;if not d then return end;local ok,err
                    if d.index then ok,err=j:RemoveLink(p.entryID,d.key,d.section)
                    else ok,err=j:AddLink(p.entryID,{section=d.section,id=d.key,label=d.name,explanation=p.reason:GetText()}) end
                    if not ok then p.message:SetText(L.Safe(err or "Could not update relationship.")) end
                    p:Render()
                end)
                p.rows[i]=row
            end
            p.previous=U.Button(p,"Previous",24,-521,140,function() p.offset=math.max(0,p.offset-6);p:Render() end)
            p.next=U.Button(p,"Next",178,-521,140,function() p.offset=p.offset+6;p:Render() end)
            p.count=U.Label(p,"",340,-527,487,"GameFontHighlightSmall")
            function p:Render()
                local entry=j:Get(self.entryID);if not entry then return end
                local rows={};local query=self.search:GetText():lower()
                if self.linked then
                    for i,v in ipairs(entry.links or {}) do
                        local current,title=c.references:Resolve(v)
                        if ((v.label or "").." "..(v.explanation or "").." "..title):lower():find(query,1,true) then
                            local row=L.Copy(v);row.key=v.id;row.name=v.label;row.reason=v.explanation
                            row.index=i;row.title=title;row.missing=current.missing;rows[#rows+1]=row
                        end
                    end
                else
                    rows=c.references:List(query,self.entryID)
                    for _,row in ipairs(rows) do for index,v in ipairs(entry.links or {}) do
                        if v.section==row.section and v.id==row.key then row.index=index;row.reason=v.explanation end
                    end end
                end
                self.offset=math.max(0,math.min(self.offset,math.floor(math.max(0,#rows-1)/6)*6))
                for i,row in ipairs(self.rows) do
                    local d=rows[self.offset+i];row.data=d
                    row:SetShown(d~=nil);row.open:SetShown(d~=nil);row.action:SetShown(d~=nil)
                    if d then
                        row:SetText(L.Safe(d.name..(d.missing and " [unavailable]" or "").."\n"..d.title..(d.reason and d.reason~="" and " • "..d.reason or "")))
                        row.action:SetText(d.index and "Unlink" or "Link")
                    end
                end
                self.mode:SetText(self.linked and "Search all known entries" or "Show linked only")
                self.previous:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+6<#rows)
                self.count:SetText(#rows.." references / matching entries")
            end
            p.search:SetScript("OnTextChanged",function() if p.entryID then p.offset=0;p:Render() end end)
        end
        if p.entryID~=e.id then p.entryID=e.id;p.offset=0;p.linked=false;p.search:SetText("");p.reason:SetText("") end
        p:Render();p.message:SetText("Links share no ownership. Unlinking or deleting a mystery never deletes its evidence. Missing references keep their saved labels.")
    end
    function c:RemovePassage()
        local e=j:Get(state.selected);if not e then return end
        local p=self:Panel("removePassage","Remove an individual manual passage")
        if not p.choose then
            p.choose=U.MenuButton(p,"Choose a manual passage",24,-85,790,function(button)
                c:Menu(button,function(_,root)
                    local found=false;local entry=j:Get(p.entryID)
                    for i,v in ipairs(entry and entry.passages or {}) do if v.origin=="manual" then
                        found=true;root:CreateButton(L.Safe((v.source or "Manual passage").." • "..L.Plain(v.raw or ""):sub(1,100)),function() p.passageID=v.id;p.choose:SetText("Selected manual passage "..i);p.confirm:SetEnabled(true) end)
                    end end
                    if not found then root:CreateTitle("No manual passages to remove") end
                end)
            end)
            U.Label(p,"Captured source text stays preserved. Remove manual annotations/transcriptions individually here, without deleting the entry or its captured evidence.",24,-155,790,"GameFontHighlight")
            p.confirm=U.Button(p,"Remove selected manual passage",24,-571,360,function()
                local ok,err=j:RemovePassage(p.entryID,p.passageID)
                if ok then c:ClosePanel() else p.message:SetText(L.Safe(err or "Passage could not be removed.")) end
            end)
        end
        p.entryID=e.id;p.passageID=nil;p.choose:SetText("Choose a manual passage");p.confirm:SetEnabled(false)
    end
end
