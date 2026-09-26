local _,ns=...

function ns.CreateSpellBlacklistWindow(window)
    local ui=ns.FieldbookUI
    local panel=CreateFrame("Frame","AzerothFieldbookSpellBlacklist",UIParent,"BackdropTemplate")
    panel:SetSize(540,490);panel:SetPoint("CENTER");panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true);panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
    panel:SetBackdropColor(0.04,0.04,0.04,0.97)
    ui.Label(panel,"Spell ID window blacklist",18,-18,455,"GameFontNormalLarge")
    ui.Close(panel,function() panel:Hide() end)
    ui.Label(panel,"Hide these IDs in the spell window. Journal recording is unchanged.",18,-48,500,"GameFontHighlightSmall")
    panel.input=ui.Edit(panel,24,-72,140,10)
    panel.input:SetNumeric(true)
    local page=0
    local rows={}
    local status=ui.Label(panel,"",18,-427,500,"GameFontHighlightSmall")
    status:SetHeight(47);status:SetJustifyV("TOP")
    function panel:Refresh()
        local ids=window:GetBlacklist()
        page=math.max(0,math.min(page,math.max(0,math.ceil(#ids/8)-1)))
        for i,row in ipairs(rows) do
            row.id=ids[page*8+i]
            row.text:SetShown(row.id~=nil);row.remove:SetShown(row.id~=nil)
            if row.id then
                local name
                if C_Spell and type(C_Spell.GetSpellName)=="function" then
                    local ok,value=pcall(C_Spell.GetSpellName,row.id)
                    if ok and not (issecretvalue and issecretvalue(value)) and type(value)=="string" then name=value end
                end
                row.text:SetText(row.id.."  "..(name or "Name unavailable"))
            end
        end
        self.pageLabel:SetText(#ids==0 and "No blacklisted abilities" or ("Page "..(page+1).." / "..math.ceil(#ids/8)))
        self.previous:SetEnabled(page>0);self.next:SetEnabled((page+1)*8<#ids)
    end
    local function add()
        local ok,message=window:AddBlacklist(panel.input:GetText())
        status:SetText(message)
        if ok then panel.input:SetText("");panel.input:ClearFocus();panel:Refresh() end
    end
    panel.add=ui.Button(panel,"Add spell ID",180,-72,135,add)
    panel.input:SetScript("OnEnterPressed",add)
    for i=1,8 do
        local row={}
        row.text=ui.Label(panel,"",18,-115-(i-1)*32,395,"GameFontHighlightSmall")
        row.text:SetHeight(28)
        row.remove=ui.Button(panel,"Remove",426,-109-(i-1)*32,92,function()
            if row.id then
                local id=row.id
                window:RemoveBlacklist(id);status:SetText("Removed spell ID "..id..".");panel:Refresh()
            end
        end)
        rows[i]=row
    end
    panel.previous=ui.Button(panel,"Previous",18,-380,100,function() page=page-1;panel:Refresh() end)
    panel.next=ui.Button(panel,"Next",420,-380,100,function() page=page+1;panel:Refresh() end)
    panel.pageLabel=ui.Label(panel,"",140,-386,260,"GameFontHighlightSmall");panel.pageLabel:SetJustifyH("CENTER")
    panel:SetScript("OnHide",function() panel.input:ClearFocus();panel:StopMovingOrSizing() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookSpellBlacklist" end
    if ns.WindowFocus then ns.WindowFocus:Register(panel) end
    if ns.UIScale then ns.UIScale:Register(panel,"AzerothFieldbookSpellBlacklist") end
    function panel:Open(message)
        status:SetText(message or "Right-click dismisses a section. Ctrl+Right-click blacklists a readable ID. Restricted IDs cannot be matched automatically.")
        self:Refresh();self:Show();self:Raise()
    end
    panel:Hide()
    return panel
end
