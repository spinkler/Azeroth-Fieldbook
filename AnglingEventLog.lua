local _, ns = ...
local A,U=ns.Angling,ns.FieldbookUI

function ns.CreateAnglingEventLog(journal,shell)
    local page,body=shell:CreatePage("AzerothFieldbookAnglingEventLog","Angler’s Almanac - Event log",65)
    local text=U.Label(body,"",30,0,530,"GameFontHighlightSmall")
    text:SetWordWrap(true);text:SetNonSpaceWrap(false)
    local status=U.Label(page,"",0,0,220,"GameFontHighlightSmall")
    status:ClearAllPoints();status:SetPoint("BOTTOMRIGHT",-30,28);status:SetJustifyH("RIGHT")
    page.index=0;page.text=text
    function page:Refresh()
        local entries=journal.db.eventLog
        self.index=math.max(0,math.min(self.index,math.max(0,math.ceil(#entries/50)-1)))
        local lines={}
        for i=#entries-self.index*50,math.max(1,#entries-self.index*50-49),-1 do
            local e=entries[i]
            local stamp=A.Read(date,"%Y-%m-%d %H:%M:%S",e.at) or "Unknown time"
            lines[#lines+1]="|cff999999"..A.Safe(stamp).."|r  |cffffd100"..A.Safe(e.kind).."|r\n"..A.Safe(e.message)
        end
        text:SetText(#lines>0 and table.concat(lines,"\n\n") or
            "No Almanac events recorded yet. New catches, fishing failures, pool discoveries and journal corrections will appear here.\n\nThis character keeps an ongoing history until you clear the log. Older journal entries are not reconstructed as new events.")
        local contentHeight=math.max(1,text:GetStringHeight()+20)
        local height=math.max(220,math.min(767,self.contentTop+contentHeight+65))
        local resized=self:GetHeight()~=height;self:SetHeight(height);body:SetHeight(contentHeight)
        local range=math.max(0,contentHeight-(height-self.contentTop-65))
        self.scroll:SetVerticalScroll(math.min(self.scroll:GetVerticalScroll() or 0,range))
        self.scroll:UpdateScrollChildRect()
        local bar=self.scroll.ScrollBar;if bar and type(bar)~="function" then bar:SetShown(range>0) end
        self.scroll:EnableMouseWheel(range>0)
        self.newer:SetEnabled(self.index>0);self.older:SetEnabled((self.index+1)*50<#entries)
        self.clear:SetEnabled(#entries>0 and not journal.readOnly)
        status:SetText(#entries.." events"..(#entries>50 and " · "..(self.index+1).." / "..math.ceil(#entries/50) or ""))
        if resized and self:IsShown() and ns.WindowPositions then ns.WindowPositions:AvoidWindowOverlap(self) end
    end
    local function move(delta)
        page.index=page.index+delta;page.confirmClear=nil;page.clear:SetText("Clear log")
        page.scroll:SetVerticalScroll(0);page:Refresh()
    end
    page.newer=U.Button(page,"Newer",0,0,90,function() move(-1) end)
    page.older=U.Button(page,"Older",0,0,90,function() move(1) end)
    page.clear=U.Button(page,"Clear log",0,0,105,function()
        if not page.confirmClear then page.confirmClear=true;page.clear:SetText("Confirm clear");return end
        page.confirmClear=nil;page.clear:SetText("Clear log");page.index=0
        page.scroll:SetVerticalScroll(0);journal:ClearEventLog();page:Refresh()
    end)
    for i,button in ipairs({page.newer,page.older,page.clear}) do
        button:ClearAllPoints();button:SetPoint("BOTTOMLEFT",30+(i-1)*98,21)
    end
    page:SetScript("OnShow",function() page:Refresh() end)
    page:HookScript("OnHide",function() page.confirmClear=nil;page.clear:SetText("Clear log") end)
    journal.onLogChange=function() if page:IsShown() then page:Refresh() end end
    page:Hide();page:Refresh()
    return page
end
