local _, ns = ...
local T,U=ns.Treasure,ns.AtlasUI
-- Page-owned left-column editors keep the Atlas-sized map and outside tabs clear.
function T.ParseItems(text)
    if type(text)~="string" or #text>12000 then return nil,"Contents text is too long." end
    local rows={}
    for line in text:gmatch('[^\r\n]+') do if line:find('%S') then
        local identity,quantity,recovered=line:match('^%s*(.-)%s*;%s*(%d+)%s*;%s*(%d*)%s*$')
        if not identity then identity,quantity=line:match('^%s*(.-)%s*;%s*(%d+)%s*$') end
        if not identity then identity=line:match('^%s*(.-)%s*$');quantity="1" end
        local id=tonumber(identity) or tonumber(identity:match('item:(%d+)'))
        rows[#rows+1]={itemID=id,name=not id and identity or nil,quantity=tonumber(quantity),recovered=tonumber(recovered)}
        if #rows>T.MAX_ITEMS then return nil,"At most 80 contents rows." end
    end end
    return rows
end
function T.InstallEditors(c)
    local journal,state=c.journal,c.state
    function c:ClosePanel()
        for _,p in pairs(self.panels) do p:Hide();for _,input in ipairs(p.inputs or {}) do input:ClearFocus() end end
        self.main.directory:Show();self.panel=nil
    end
    function c:Panel(key,title)
        self:ClosePanel();local p=self.panels[key]
        if not p then
            p=CreateFrame("Frame",nil,self.main);p:SetPoint("TOPLEFT",38,-90);p:SetSize(262,615)
            p.title=U.Label(p,title,4,-4,250,"GameFontNormalSmall");p.inputs={}
            p.scroll,p.body=U.Scroll(p,6,-30,230,506)
            p.back=U.Button(p,"Cancel / back",4,-581,250,function() c:ClosePanel() end)
            self.panels[key]=p
        end
        self.main.directory:Hide();self.panel=p;p:Show();return p
    end
    -- Notes and manual forms retain drafts when merely switching sections.
    function c:Notes()
        local e=journal:Get(state.selected);if not e then return end
        local p=self:Panel("notes","Kind notes & classification")
        if not p.label then
            p.label=U.Field(p.body,"Personal label",2,0,220,160)
            p.category=U.MenuButton(p.body,"Category",2,-58,220,function(self)
                c:Menu(self,function(_,root) for _,v in ipairs({{"container","Container"},{"find","Recoverable find"},{"salvage","Salvage"}}) do
                    local id=v[1];root:CreateButton(v[2],function() p.categoryID=id;p.category:SetText(v[2]) end)
                end end)
            end)
            U.Label(p.body,"General notes (private)",2,-96,220,"GameFontNormalSmall")
            p.note=U.TextArea(p.body,7,-119,195,188,4000)
            U.Label(p.body,"Look for again — reason (private)",2,-330,220,"GameFontNormalSmall")
            p.reason=U.TextArea(p.body,7,-353,195,116,4000)
            p.body:SetHeight(491);p.inputs={p.label,p.note,p.reason}
            U.Button(p,"Save notes / category",4,-548,250,function()
                local ok,err=journal:Annotate(p.kindID,{label=p.label:GetText(),note=p.note:GetText(),bookmarkNote=p.reason:GetText(),category=p.categoryID})
                if ok then c:ClosePanel();c:Message("Personal notes saved.") else c:Message(err) end
            end)
        end
        if p.kindID~=e.id then
            p.kindID=e.id;p.label:SetText(e.label);p.note:SetText(e.note);p.reason:SetText(e.bookmarkNote)
            p.categoryID=e.category;p.category:SetText(e.category)
        end
    end
    function c:Manual(encounterID)
        local existing=encounterID and journal.encounters[encounterID]
        if encounterID and (not existing or existing.reported) then self:Message("Reported observations retain their original claims; remove a mistaken report through History.");return end
        local p=self:Panel("manual",existing and "Correct personal encounter" or "Record a find")
        if not p.name then
            local b=p.body
            p.kind=U.MenuButton(b,"New provisional kind",2,0,220,function(self)
                if p.encounterID then c:Message("This correction retains its kind. Remove/re-record to change identity.");return end
                c:Menu(self,function(_,root)
                    root:SetScrollMode(420);root:CreateButton("New provisional kind",function() p.kindID=nil;p.kind:SetText("New provisional kind") end)
                    for _,row in ipairs(journal:List({})) do local e=row.entry
                        root:CreateButton(T.Safe(row.title).." • "..e.form.." • "..e.id,function()
                            p.kindID=e.id;p.kind:SetText(T.Safe(row.title));p.name:SetText(e.name);p.formID=e.form;p.form:SetText(e.form)
                            p.categoryID=e.category;p.category:SetText(e.category);p.item:SetText(e.itemID and tostring(e.itemID) or "")
                            p.contextID=e.form=="world" and "world" or "acquired";p.context:SetText(T.contexts[p.contextID])
                        end)
                    end
                end)
            end)
            p.name=U.Field(b,"Container / find name",2,-40,220,160)
            p.form=U.Button(b,"World find",2,-98,106,function()
                if p.kindID then c:Message("The existing kind determines its form.");return end
                p.formID=p.formID=="world" and "portable" or "world";p.form:SetText(p.formID)
                p.contextID=p.formID=="world" and "world" or "acquired";p.context:SetText(T.contexts[p.contextID])
            end)
            p.category=U.MenuButton(b,"Category",115,-98,107,function(self)
                c:Menu(self,function(_,root) for _,id in ipairs({"container","find","salvage"}) do
                    root:CreateButton(id,function() p.categoryID=id;p.category:SetText(id) end)
                end end)
            end)
            p.item=U.Field(b,"Portable item ID (optional)",2,-136,220,12)
            p.context=U.MenuButton(b,"World find",2,-194,220,function(self)
                c:Menu(self,function(_,root)
                    for _,id in ipairs(p.formID=="world" and {"world"} or {"acquired","opened","carried"}) do
                        root:CreateButton(T.contexts[id],function() p.contextID=id;p.context:SetText(T.contexts[id]) end)
                    end
                end)
            end)
            p.sighted=U.Check(b,"Sighted / encountered",2,-225,194,function() end)
            p.attempted=U.Check(b,"Access attempted",2,-252,194,function() end)
            p.inspected=U.Check(b,"Contents inspected",2,-279,194,function() end)
            p.result=U.Field(b,"Attempt result (optional)",2,-316,220,500)
            p.current=U.Button(b,"Use player position",2,-375,220,function()
                local loc=T.CurrentLocation(p.contextID);loc.method="manual";p:SetLocation(loc)
                c:Message("Suggested player position: approximate. Review the zone/map before saving.")
            end)
            p.unknown=U.Button(b,"Leave location unknown",2,-405,220,function() p:SetLocation(assert(T.Location({},p.contextID))) end)
            p.zone=U.Field(b,"Zone",2,-448,220,160)
            p.subzone=U.Field(b,"Subzone / area",2,-507,220,160)
            p.mapID=U.Field(b,"Map ID (optional)",2,-566,220,12)
            p.x=U.Field(b,"X %",2,-625,104,8);p.y=U.Field(b,"Y %",118,-625,104,8)
            p.precision=U.Label(b,"Coordinates unknown",2,-681,220,"GameFontDisableSmall")
            local function corrected()
                if not p.syncing then p.precisionID="manual";p.precision:SetText("Manual placement / correction") end
            end
            p.x:SetScript("OnTextChanged",corrected);p.y:SetScript("OnTextChanged",corrected)
            p.mapID:SetScript("OnTextChanged",corrected)
            p.floor=U.Field(b,"Floor / interior label",2,-714,220,160)
            p.instance=U.Field(b,"Instance (optional)",2,-773,220,160)
            p.access=U.Field(b,"Access observed / method (manual)",2,-832,220,500)
            p.capture=U.MenuButton(b,"Contents not recorded",2,-893,220,function(self)
                c:Menu(self,function(_,root) for _,id in ipairs({"missing","partial","full"}) do root:CreateButton(T.captures[id],function() p.captureID=id;p.capture:SetText(T.captures[id]) end) end end)
            end)
            U.Label(b,"Contents: one item ID, link or name per line. Optional ; observed quantity ; personally recovered quantity. Recovery is your explicit assertion.",2,-932,218,"GameFontHighlightSmall")
            p.items=U.TextArea(b,7,-1005,195,130,12000)
            U.Label(b,"Encounter notes (private)",2,-1156,220,"GameFontNormalSmall")
            p.note=U.TextArea(b,7,-1180,195,122,4000)
            U.Label(b,"Time defaults to when you save a new encounter. If this is an older find and its observation time is unknown, mark it below.",2,-1324,218,"GameFontHighlightSmall")
            p.timeUnknown=U.Check(b,"Observation time unknown",2,-1384,190,function() end)
            p.body:SetHeight(1420)
            p.inputs={p.name,p.item,p.result,p.zone,p.subzone,p.mapID,p.x,p.y,p.floor,p.instance,p.access,p.items,p.note}
            function p:SetLocation(loc)
                self.syncing=true
                self.zone:SetText(loc.zone);self.subzone:SetText(loc.subzone);self.mapID:SetText(loc.mapID and tostring(loc.mapID) or "")
                self.x:SetText(loc.x and tostring(loc.x/100) or "");self.y:SetText(loc.y and tostring(loc.y/100) or "")
                self.floor:SetText(loc.floor);self.instance:SetText(loc.instance)
                self.precisionID=loc.precision;self.precision:SetText(loc.precision=="player" and "Approximate player position" or loc.precision=="manual" and "Manually placed" or "Coordinates unknown")
                self.syncing=false
            end
            p.save=U.Button(p,"Save manual encounter",4,-548,250,function()
                local x,y,err=ns.Atlas.Coordinates(p.x:GetText(),p.y:GetText());if err then c:Message(err);return end
                local mapText=p.mapID:GetText();local mapID=tonumber(mapText)
                if mapText~="" and not T.Integer(mapID,1,2147483647) then c:Message("Enter a valid map ID or leave it blank.");return end
                local items;items,err=T.ParseItems(p.items:GetText());if not items then c:Message(err);return end
                local values={context=p.contextID,location={zone=p.zone:GetText(),subzone=p.subzone:GetText(),mapID=mapID,x=x,y=y,
                    floor=p.floor:GetText(),instance=p.instance:GetText(),precision=p.precisionID,method="manual"},
                    facts={sighted=p.sighted:GetChecked()==true,attempted=p.attempted:GetChecked()==true,inspected=p.inspected:GetChecked()==true},
                    result=p.result:GetText(),access=p.access:GetText(),accessMethod="manual",capture=p.captureID,items=items,note=p.note:GetText(),
                    timeUnknown=p.timeUnknown:GetChecked()==true}
                local e,enc
                if p.encounterID then
                    local ok;ok,err=journal:EditEncounter(p.encounterID,values)
                    if ok then enc=journal.encounters[p.encounterID];e=journal:Get(enc.kindID) end
                else
                    local idText=p.item:GetText();local itemID=tonumber(idText)
                    if idText~="" and not T.Integer(itemID,1,2147483647) then c:Message("Use a numeric portable item ID or leave it blank.");return end
                    e,enc=journal:Record(p.kindID,{name=p.name:GetText(),form=p.formID,category=p.categoryID,itemID=p.formID=="portable" and itemID or nil},values,"manual")
                    if not e then err=enc end
                end
                if e then c:ClosePanel();p.draft=nil;c:Select(e.id);c:Encounter(enc.id);c:Message("Encounter saved as historical knowledge.") else c:Message(err) end
            end)
        end
        if p.draft~=(encounterID or "new") then
            p.draft=encounterID or "new";p.encounterID=encounterID
            local e=existing and journal:Get(existing.kindID) or journal:Get(state.selected)
            p.kindID=e and e.id;p.kind:SetText(e and T.Safe(journal:Title(e)) or "New provisional kind")
            p.name:SetText(e and e.name or "");p.formID=e and e.form or "world";p.form:SetText(p.formID)
            p.categoryID=e and e.category or "container";p.category:SetText(p.categoryID);p.item:SetText(e and e.itemID and tostring(e.itemID) or "")
            p.contextID=existing and existing.context or p.formID=="world" and "world" or "acquired";p.context:SetText(T.contexts[p.contextID])
            p.sighted:SetChecked(not existing or existing.facts.sighted);p.attempted:SetChecked(existing and existing.facts.attempted or false)
            p.inspected:SetChecked(existing and existing.facts.inspected or false);p.result:SetText(existing and existing.result or "")
            p:SetLocation(existing and existing.location or assert(T.Location({},p.contextID)))
            p.access:SetText(existing and existing.access or "");p.captureID=existing and existing.capture or "missing";p.capture:SetText(T.captures[p.captureID])
            local lines={};for _,item in ipairs(existing and existing.items or {}) do lines[#lines+1]=tostring(item.itemID or item.name)..";"..item.quantity..(item.recovered and ";"..item.recovered or "") end
            p.items:SetText(table.concat(lines,"\n"));p.note:SetText(existing and existing.note or "");p.scroll:SetVerticalScroll(0)
            p.timeUnknown:SetChecked(existing and existing.origin.at==nil or false)
            p.title:SetText(existing and "Correct personal encounter" or "Record a find")
            p.save:SetText(existing and "Save correction" or "Save manual encounter")
            local automatic=existing and existing.origin.method=="observed"
            for _,control in ipairs({p.context,p.sighted,p.attempted,p.inspected,p.capture,p.form,p.category}) do control:SetEnabled(not automatic) end
            for _,control in ipairs({p.result,p.items,p.name,p.item}) do control:SetEnabled(not automatic) end
            p.timeUnknown:SetEnabled(not automatic)
            if automatic then c:Message("Automatic encounter: correct notes, access or location here. Contents/outcomes retain their original evidence.") end
        end
    end
    function c:RemoveEncounter()
        local v=journal.encounters[state.encounter];if not v then return end
        local p=self:Panel("remove","Remove recorded encounter")
        if not p.description then
            p.description=U.Label(p.body,"",2,0,220,"GameFontHighlight");p.description:SetWordWrap(true);p.description:SetSpacing(4)
            U.Button(p,"Confirm removal",4,-548,250,function()
                local ok,err=journal:Remove(p.encounterID,true)
                if ok then c:ClosePanel();if state.encounter==p.encounterID then state.encounter=nil end;c:Refresh();c:Message("Encounter removed; summaries and historical markers updated.") else c:Message(err) end
            end)
        end
        p.encounterID=v.id
        p.description:SetText(T.Safe("Remove this encounter, its contents and encounter notes?\n\n"..journal:Title(journal:Get(v.kindID)).."\n"..T.Date(v.origin.at).."\n"..T.Outcome(v).."\n\n"..T.LocationText(v.location).."\n\nKind notes and Look for again stay saved. This cannot be undone."))
    end
end
