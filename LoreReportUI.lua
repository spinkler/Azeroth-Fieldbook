local _,ns=...
local L,U,R=ns.Lore,ns.AtlasUI,ns.LoreReports
function ns.CreateLoreReportUI(parent,journal,getSelected,onChanged,shell)
    local c={selection={},mode='export'}
    local p=U.Panel(parent,shell,'Lore field report',function() c:Close() end);c.panel=p
    p:SetFrameLevel(parent:GetFrameLevel()+30)
    U.Label(p,'One entry per report. Copy/paste, preview and accept. No addon-message delivery or Knowledge cost.',20,-52,820,'GameFontHighlightSmall')
    p.preview=U.ReadArea(p,324,-86,507,471)
    p.options=CreateFrame('Frame',nil,p);p.options:SetPoint('TOPLEFT',20,-86);p.options:SetSize(274,250)
    local function invalidate()
        if c.ticket then R.Cancel(c.ticket);c.ticket=nil end
        c.targetID=nil
        if c.mode=='export' then
            c.reviewedText=''
            c.filling=true;p.data:SetText('');c.filling=false
            p.copy:SetEnabled(false);p.preview:SetText('Selections changed. Prepare the exact preview again.',true)
        else
            c.reviewedText=nil
        end
        p.accept:SetEnabled(false);p.message:SetText('Prepare or preview again after changing selections.')
    end
    local labels={includePages='Source pages',includePassages='Source passages',includeLocations='Locations',includeReferences='Related references only',
        description='Description / observations',notes='Private notes',theory='Working theory',nextStep='Next step',tags='Tags',status='My mystery status',interpretations='Private passages / interpretations'}
    local order={'includePages','includePassages','includeLocations','includeReferences','description','notes','theory','nextStep','tags','status','interpretations'}
    p.checks={}
    for i,key in ipairs(order) do
        p.checks[key]=U.Check(p.options,labels[key],0,-(i-1)*24,235,function(value) c.selection[key]=value;invalidate() end)
    end
    p.source=U.MenuButton(p,'Local sources',20,-362,274,function(self)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self,function(_,root)
            root:CreateButton('Local sources',function() c.selection.report=nil;p.source:SetText('Local sources');c:ResetSelection();invalidate() end)
            local e=journal:Get(c.id)
            for i,r in ipairs(e and e.reports or {}) do local index=i
                root:CreateButton(L.Safe('Received report '..i..' / '..r.sender),function()
                    c.selection.report=index;p.source:SetText('Received report '..index);c:ResetSelection();invalidate()
                end)
            end
        end)
    end)
    p.pick=U.MenuButton(p,'Select pages, passages and locations',20,-393,274,function(self)
        if not MenuUtil then return end
        local e=journal:Get(c.id);if not e then return end
        local base=c.selection.report and e.reports[c.selection.report] or e
        MenuUtil.CreateContextMenu(self,function(_,root)
            root:SetScrollMode(440)
            for _,kind in ipairs({'pages','passages','locations','references'}) do
                local values=base[kind] or (kind=='references' and base.links) or {}
                local menu=root:CreateButton(kind);menu:SetScrollMode(400)
                menu:CreateButton('All',function() c.selection[kind]=nil;invalidate() end)
                menu:CreateButton('None',function() c.selection[kind]={};invalidate() end)
                local keys={};for key in pairs(values) do keys[#keys+1]=key end
                table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return tostring(a)<tostring(b) end)
                for _,key in ipairs(keys) do local k=key;local category=kind;local item=values[k]
                    local caption=category=='pages' and ('Page '..tostring(item.number or '?')) or category=='locations' and L.LocationText(item)
                        or category=='references' and (item.label or item.name) or (item.source or item.nature or 'Passage')..' '..tostring(k)
                    menu:CreateCheckbox(L.Safe(caption or tostring(k)),function() return c.selection[category]==nil or c.selection[category][k]==true end,function()
                        if c.selection[category]==nil then c.selection[category]={};for _,all in ipairs(keys) do c.selection[category][all]=true end end
                        c.selection[category][k]=not c.selection[category][k];invalidate()
                    end)
                end
            end
        end)
    end)
    -- A native max-letter limit silently cuts pasted books before validation.
    -- Keep the input intact; the bounded decoder refuses oversized envelopes.
    p.data,p.dataScroll=U.TextArea(p,25,-444,244,97,0)
    p.inputs={p.data}
    p.from=U.Field(p,'Received from (your record; not authenticated)',25,-87,265,160);p.inputs[#p.inputs+1]=p.from
    p.attach=U.Check(p,'Attach to selected entry (same kind)',20,-150,245,invalidate)
    p.prepare=U.Button(p,'Prepare exact preview',20,-567,274,function() c:Prepare() end)
    p.accept=U.Button(p,'Accept reported material',324,-567,220,function()
        local e,err=R.Accept(journal,c.ticket,c.targetID)
        if e then c.ticket=nil;p.accept:SetEnabled(false);p.message:SetText(L.Safe(err or 'Reported material archived. Personal notes and encounters are unchanged.'));if onChanged then onChanged(e.id) end
        else p.message:SetText(L.Safe(err or 'Import failed.')) end
    end)
    p.copy=U.Button(p,'Select report text',556,-567,274,function() p.data:SetFocus();p.data:HighlightText() end)
    p.accept:SetEnabled(false)
    local onText=p.data:GetScript('OnTextChanged')
    p.data:SetScript('OnTextChanged',function(self,...)
        if onText then onText(self,...) end
        if not c.filling and self:GetText()~=c.reviewedText then invalidate() end
    end)
    p.from:SetScript('OnTextChanged',function(self)
        if not c.filling and c.mode=='import' and self:GetText()~=c.reviewedFrom then invalidate() end
    end)
    function c:ResetSelection()
        local report=self.selection.report
        self.selection={report=report,includePages=true,includePassages=true,includeLocations=true}
        for key,check in pairs(p.checks) do check:SetChecked(self.selection[key]==true) end
        local e=journal:Get(self.id);p.checks.status:SetEnabled(e~=nil and e.kind=='mystery')
    end
    function c:Close()
        R.Cancel(self.ticket);self.ticket=nil;p:Hide()
    end
    function c:Open(mode)
        R.Cancel(self.ticket);self.ticket=nil;self.targetID=nil;self.mode=mode;self.id=getSelected();self.filling=true
        self.reviewedText='';self.reviewedFrom=''
        self.selection={};self:ResetSelection();p.source:SetText('Local sources');p.data:SetText('');p.from:SetText('');p.attach:SetChecked(false)
        p.preview:SetText(mode=='export' and 'Choose exactly what to include, then prepare the preview. Private fields and related references start excluded.' or
            'Paste a Lore report. Record who gave it to you if known, then preview before accepting. Payload sender names are claims, not authentication.',true)
        p.options:SetShown(mode=='export');p.source:SetShown(mode=='export');p.pick:SetShown(mode=='export')
        p.from:SetShown(mode=='import');p.from.fieldLabel:SetShown(mode=='import');p.attach:SetShown(mode=='import')
        p.accept:SetShown(mode=='import');p.accept:SetEnabled(false);p.copy:SetShown(mode=='export');p.copy:SetEnabled(false)
        p.dataScroll:ClearAllPoints();p.dataScroll:SetPoint('TOPLEFT',25,mode=='export' and -444 or -198);p.dataScroll:SetHeight(mode=='export' and 97 or 342)
        p.prepare:SetText(mode=='export' and 'Prepare exact preview' or 'Preview pasted report')
        p.title:SetText(mode=='export' and 'Export Lore report' or 'Import Lore report')
        p.message:SetText('Up to 1 MiB per report. Larger works need explicitly selected page batches; no text is cut off.')
        self.filling=false;p:Show()
    end
    function c:OpenExport() self:Open('export') end
    function c:OpenImport() self:Open('import') end
    function c:Prepare()
        R.Cancel(self.ticket);self.ticket=nil;p.accept:SetEnabled(false)
        if self.mode=='export' then
            local report,err=R.Build(journal,self.id,self.selection)
            if not report then p.message:SetText(L.Safe(err));return end
            local data;data,err=R.Encode(report);if not data then p.message:SetText(L.Safe(err));return end
            p.preview:SetText(R.Preview(report),true);self.reviewedText=data
            self.filling=true;p.data:SetText(data);self.filling=false
            p.copy:SetEnabled(true)
            p.message:SetText('Exact preview prepared: '..#data..' bytes. Select report text and copy. Nothing has been sent.')
        else
            local ticket,err=R.Prepare(p.data:GetText(),p.from:GetText())
            if not ticket then p.message:SetText(L.Safe(err));return end
            self.targetID=p.attach:GetChecked() and getSelected() or nil
            if p.attach:GetChecked() and not self.targetID then R.Cancel(ticket);p.message:SetText('Select an entry before attaching a report.');return end
            local summary,canAccept=R.Preflight(journal,ticket,self.targetID)
            self.ticket=ticket;self.reviewedText=p.data:GetText();self.reviewedFrom=p.from:GetText()
            p.preview:SetText(summary..'\n\n'..(self.targetID and 'Attach to: '..journal:Title(self.targetID)..'\n\n' or 'Archive as reported material; match only an existing report identity.\n\n')..ticket.preview,true);p.accept:SetEnabled(canAccept)
            p.message:SetText('Review all included material. Accept stores a report; it does not confirm its claims.')
        end
    end
    p:Hide();return c
end
