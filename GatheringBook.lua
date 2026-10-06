local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end

-- Gathering assets have different placement origins (including below-ground
-- origins). Use their render bounds, never a resource-name offset table.
local function createGatheringViewer(parent,onReady)
    local scene=CreateFrame("ModelScene",nil,parent)
    scene.isGatheringViewer=true
    local actor=scene:CreateActor()
    scene.actor=actor
    actor:SetUseCenterForOrigin(true,true,true)
    actor:SetPreferModelCollisionBounds(false)
    actor:SetPosition(0,0,0)
    scene:SetCameraFieldOfView(math.rad(30))
    -- Match Blizzard's orbit camera at +X, looking toward the origin. Supplying
    -- (-X,+Y,+Z) as a basis reflects an axis instead of defining a rotation.
    scene:SetCameraOrientationByYawPitchRoll(math.pi,0,0)
    scene:SetLightType(0) -- Directional.
    scene:SetLightAmbientColor(0.75,0.75,0.75)
    scene:SetLightDiffuseColor(0.8,0.8,0.8)
    scene:SetLightDirection(-1,-1,-1)
    scene:SetLightVisible(true)
    local pending,elapsed
    function scene:ClearModel()
        pending=nil;actor:ClearModel();actor:Hide()
    end
    function scene:SetModel(fileID)
        -- The scene and actor must be visible when the native load begins.
        pending=fileID;elapsed=0;actor:Show()
        if not actor:SetModelByFileID(fileID) then
            pending=nil;actor:Hide();error("Gathering model unavailable")
        end
    end
    function scene:SetRotation(angle) actor:SetYaw(angle) end
    function scene:UpdateFraming(dt)
        if not pending then return end
        elapsed=elapsed+(dt or 0)
        if actor:IsLoaded() and actor:GetModelFileID()==pending then
            local x0,y0,z0,x1,y1,z1=actor:GetActiveBoundingBox()
            -- Clients expose either two Vector3 values or six scalar values.
            if not (issecretvalue and (issecretvalue(x0) or issecretvalue(y0)))
                and type(x0)=="table" and type(y0)=="table"
                and type(x0.GetXYZ)=="function" and type(y0.GetXYZ)=="function" then
                local bottom,top=x0,y0
                x0,y0,z0=bottom:GetXYZ();x1,y1,z1=top:GetXYZ()
            end
            local valid=true
            local values={x0,y0,z0,x1,y1,z1}
            for i=1,6 do
                local value=values[i]
                if (issecretvalue and issecretvalue(value)) or type(value)~="number"
                    or value~=value or math.abs(value)>100000 then valid=false;break end
            end
            if valid and x0 and y0 and z0 and x1 and y1 and z1
                and x1>=x0 and y1>=y0 and z1>z0 then
                local dx,dy,dz=x1-x0,y1-y0,z1-z0
                -- A bounding sphere keeps every yaw inside the same framing.
                local radius=math.sqrt(dx*dx+dy*dy+dz*dz)/2
                local aspect=self:GetWidth()/math.max(1,self:GetHeight())
                local halfFov=math.atan(math.tan(math.rad(15))*math.min(1,aspect)*0.70)
                local distance=radius/math.sin(halfFov)
                self:SetCameraPosition(distance,0,0)
                -- Tight bounds-derived planes clip loaded geometry on Forever.
                -- This range was verified in-client with the Copper Vein preview.
                self:SetCameraNearClip(0.01)
                self:SetCameraFarClip(10000)
                actor:Show();pending=nil;onReady(true)
                return
            end
        end
        if elapsed>=5 then pending=nil;actor:Hide();onReady(false) end
    end
    return scene
end

-- Selection borders and clipped hover names mirror the Bestiary. Kept local to
-- this section so its implementation cannot change any other page's controls.
local function addNameScroller(row,heading)
    local viewport=CreateFrame("ScrollFrame",nil,row)
    viewport:SetPoint("TOPLEFT",28,0);viewport:SetSize(140,28);viewport:EnableMouse(false)
    local body=CreateFrame("Frame",nil,viewport)
    body:SetSize(140,28);body:EnableMouse(false);viewport:SetScrollChild(body)
    local text=body:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlight"))
    text:SetPoint("TOPLEFT",0,-6);text:SetJustifyH("LEFT");text:SetWordWrap(false)
    text:SetShadowColor(0.05,0.05,0.05)
    if heading then
        viewport:ClearAllPoints();viewport:SetAllPoints(row)
        text:ClearAllPoints();text:SetPoint("TOPLEFT",0,0)
        text:SetFontObject(textFont("GameFontNormalLarge"))
        local path,size,flags=row.text:GetFont()
        if path then text:SetFont(path,size,flags) end
    end
    row.nameViewport,row.scrollingName=viewport,text
    function row:StopNameScroll()
        self:SetScript("OnUpdate",nil)
        viewport:SetHorizontalScroll(0);viewport:Hide();self.text:Show()
    end
    row:SetScript("OnEnter",function(self)
        local width=self.text:GetUnboundedStringWidth()
        if type(width)~="number" then width=self.text:GetStringWidth() end
        local visible=self.text:GetWidth()
        if not self.id or type(width)~="number" or width<=visible then return end
        width=math.ceil(width)+1
        viewport:SetWidth(visible);body:SetWidth(width);text:SetWidth(width)
        if heading then body:SetHeight(self:GetHeight()) end
        text:SetText(self.text:GetText());text:SetTextColor(self.text:GetTextColor())
        text:SetAlphaGradient(visible-20,20)
        self.text:Hide();viewport:Show();viewport:SetHorizontalScroll(0)
        local elapsed,distance=0,width-visible
        local travel=distance/24 -- Gentle movement in UI pixels per second.
        self:SetScript("OnUpdate",function(_,dt)
            if heading and self.text:GetWidth()~=visible then self:StopNameScroll();return end
            elapsed=(elapsed+dt)%(travel*2+2)
            local position
            if elapsed<0.8 then position=0
            elseif elapsed<0.8+travel then position=(elapsed-0.8)*24
            elseif elapsed<2+travel then position=distance
            else position=distance-(elapsed-2-travel)*24 end
            viewport:SetHorizontalScroll(position)
            -- Fade into the stationary right edge while travelling, then show
            -- the complete ending during the pause. The viewport clips the left.
            if position<distance then text:SetAlphaGradient(position+visible-20,20)
            else text:ClearAlphaGradient() end
        end)
    end)
    row:SetScript("OnLeave",function(self) self:StopNameScroll() end)
    row:SetScript("OnHide",function(self) self:StopNameScroll() end)
    row:StopNameScroll()
end

    local filterFonts={}
    local function filterFont(base)
        if not filterFonts[base] then
            local name="AzerothFieldbookGatheringFilter"..base
            local font=CreateFont(name)
            font:CopyFontObject(_G[base])
            local path,size,flags=font:GetFont()
            if path and size then font:SetFont(path,math.max(1,size-1),flags) end
            filterFonts[base]=name
        end
        return filterFonts[base]
    end
    local function styleSelection(control,keepGoldText,borderOnly)
        if not borderOnly then
            control:SetHighlightTexture("")
            control:SetDisabledFontObject(textFont(filterFont("GameFontDisable")))
        end
        -- Crop the native bevel only; the red face is never tinted or brightened.
        local borders={}
        local function border(source,l,r,t,b,x1,y1,x2,y2)
            for layer=0,1 do
                local piece=control:CreateTexture(nil,"BORDER",nil,layer)
                piece:SetPoint("TOPLEFT",source,"TOPLEFT",x1,y1)
                piece:SetPoint("BOTTOMRIGHT",source,"BOTTOMRIGHT",x2,y2)
                piece:SetTexCoord(l,r,t,b)
                piece:SetVertexColor(1,1,0)
                piece:SetBlendMode(layer==0 and "BLEND" or "ADD")
                borders[#borders+1]={texture=piece,source=source}
            end
        end
        local function refreshBorder()
            for _,part in ipairs(borders) do
                part.texture:SetTexture(part.source:GetTexture())
                part.texture:SetShown(control.afbSelected and control:IsEnabled())
            end
        end
        -- UIPanelButtonTemplate uses a 128x32 texture with an 80x22 button,
        -- split into 12px end caps and a stretching middle. Its outer 4px
        -- contain the bevel; copying those pixels preserves the native shape.
        local function createBorder()
            local height=control:GetHeight()
            local edge=height*4/22
            for _,slice in ipairs({{"Left",0,12},{"Middle",12,68},{"Right",68,80}}) do
                local source=control[slice[1]]
                if source and type(source)~="function" then
                    border(source,slice[2]/128,slice[3]/128,0,4/32,0,0,0,height-edge)
                    border(source,slice[2]/128,slice[3]/128,18/32,22/32,0,-height+edge,0,0)
                    if slice[1]=="Left" then
                        border(source,0,4/128,4/32,18/32,0,-edge,-8,edge)
                    elseif slice[1]=="Right" then
                        border(source,76/128,80/128,4/32,18/32,8,-edge,0,edge)
                    end
                end
            end
        end
        control.SetSelected=function(self,selected)
            if not borderOnly then
                local font=filterFont((selected or keepGoldText) and "GameFontNormal" or "GameFontDisable")
                self:SetNormalFontObject(textFont(font))
                self:SetHighlightFontObject(textFont(font))
            end
            self.afbSelected=selected
            if selected and #borders==0 then createBorder() end
            refreshBorder()
        end
        for _,event in ipairs({"OnMouseDown","OnMouseUp","OnEnable","OnDisable","OnShow"}) do
            control:HookScript(event,refreshBorder)
        end
        control:SetSelected(false)
    end


function ns.CreateGatheringBook(journal,shell)
    local controller={journal=journal}
    local ui=ns.FieldbookUI
    local label,button,edit=ui.Label,ui.Button,ui.Edit
    local book,selected,category
    function controller:ReportModel(say)
        say("Gathering model preview")
        if not book or not book.activeModel then say("Select a gathering entry first.");return end
        local function value(v)
            if issecretvalue and issecretvalue(v) then return "RESTRICTED" end
            local kind=type(v)
            if kind=="number" or kind=="boolean" or kind=="nil" then return tostring(v) end
            if kind=="string" then return v:gsub("|",""):gsub("[%c]"," "):sub(1,160) end
            return "<"..kind..">"
        end
        local function read(label,object,method,...)
            if not object or type(object[method])~="function" then say(label..": API unavailable");return end
            local function result(ok,...)
                if not ok then say(label..": API error");return end
                local parts={}
                for i=1,select("#",...) do parts[i]=value(select(i,...)) end
                say(label..": "..table.concat(parts,", "))
            end
            result(pcall(object[method],object,...))
        end
        local model=book.activeModel
        say("Entry: "..value(selected).."; requested file: "..value(book.modelFileID))
        say("Renderer: "..(model.isGatheringViewer and "ModelScene" or "PlayerModel"))
        read("Caption",book.modelCaption,"GetText")
        for _,method in ipairs({"IsShown","IsVisible","GetAlpha","GetEffectiveAlpha","GetSize",
            "GetFrameLevel","GetFrameStrata","GetCameraPosition"}) do read("Viewer "..method,model,method) end
        if model.isGatheringViewer then
            for _,method in ipairs({"GetModelFileID","IsLoaded","IsShown","IsVisible","GetAlpha",
                "GetScale","GetPosition","IsUsingCenterForOrigin","GetActiveBoundingBox"}) do
                read("Actor "..method,model.actor,method)
            end
            for _,method in ipairs({"GetCameraForward","GetCameraRight","GetCameraUp","GetCameraFieldOfView",
                "GetCameraNearClip","GetCameraFarClip","GetDrawLayer","IsLightVisible"}) do
                read("Scene "..method,model,method)
            end
            read("Origin projection",model,"Project3DPointTo2D",0,0,0)
        else
            for _,method in ipairs({"GetModelFileID","GetModelAlpha","GetModelScale","GetPosition",
                "GetCameraTarget","GetCameraDistance","HasCustomCamera"}) do read("Model "..method,model,method) end
        end
    end
    local offset=0
    local PAGE_SIZE=18
    local locationFilters,drafts={},{}
    local locations=ns.CreateGatheringLocationsWindow(journal,function()
        if not book then shell:EnsureSection("gathering") end
        return book
    end)
    controller.locations=locations
    local refresh,refreshLocationFilter
    local function choose(id)
        selected=id
        locations:SetResource(id)
        if book then book.message:SetText("");refresh() end
    end
    local function currentRows()
        return journal:List(category,book.search:GetText(),nil,locationFilters)
    end
    local function dateText(stamp)
        return stamp and stamp>0 and type(date)=="function" and date("%d %b %Y, %H:%M",stamp) or "Unknown"
    end
    refresh=function(reloadModel)
        if not book then return end
        book.revision=journal.revision
        for key,control in pairs(book.mapOptions) do
            control:SetChecked(journal:ShowNodesOn(key))
        end
        local rows=currentRows()
        for kind,control in pairs(book.typeButtons) do control:SetSelected(kind==(category or "all")) end
        book.locationsButton:SetSelected(next(locationFilters)~=nil or book.locationFrame:IsShown())
        book.listFilterButton:SetSelected(book.listFilterMenu:IsShown() or category~=nil or next(locationFilters)~=nil)
        if not selected or not journal.entries[selected] then selected=rows[1] and rows[1].id end
        offset=math.max(0,math.min(offset,math.max(0,#rows-PAGE_SIZE)))
        book.updatingScroll=true
        book.resourceScrollBar:SetMinMaxValues(0,math.max(0,#rows-PAGE_SIZE))
        book.resourceScrollBar:SetValue(offset);book.resourceScrollBar:SetShown(#rows>PAGE_SIZE)
        book.updatingScroll=false
        for i,row in ipairs(book.rows) do
            local data=rows[offset+i]
            if row.id~=(data and data.id) then row:StopNameScroll() end
            row.id=data and data.id;row:SetShown(data~=nil);row:EnableMouseWheel(#rows>PAGE_SIZE)
            if data then
                row.text:SetText(data.name)
                local active=data.id==selected
                row.text:SetTextColor(active and 1 or 0.75,active and 0.82 or 0.8,active and 0.14 or 0.8)
                row:SetSelected(active)
            end
        end
        book.entryCount:SetCounts(#journal:List(),#rows)
        book.noMatches:SetShown(#rows==0)
        book.noMatches:SetText(journal.readOnly and "Saved by a newer addon version.\nUpdate Azeroth Fieldbook to view this journal.\nYour data has been left untouched."
            or next(journal.entries) and "No matching entries.\nTry clearing your filters."
            or "No herbs or minerals recorded yet.")
        local entry=selected and journal.entries[selected]
        book.deleteButton:SetEnabled(entry~=nil and not journal.readOnly)
        if book.deleteForm:IsShown() and book.deleteForm.entry~=entry then book.deleteForm:Hide() end
        book.title:SetText(entry and (entry.name.." • "..ns.GatheringKinds[entry.kind].title) or "Gatherer's Compendium")
        book.locations:SetEnabled(entry~=nil);book.details:SetShown(entry~=nil);book.empty:SetShown(entry==nil)
        if not entry then
            book.modelFileID=nil;book.model:ClearModel();book.model:Hide()
            book.mineralModel:ClearModel();book.mineralModel:Hide()
            return
        end
        local modelFileID=entry.modelFileID or ns.GatheringModel(entry.kind,entry.name)
        -- Load only after the section and its book are visible. Native model
        -- render state can be discarded while a section is hidden, even when
        -- the selected entry/file ID has not changed.
        if book:IsShown() and shell:GetFrame():IsShown()
            and (reloadModel or book.modelEntry~=selected or book.modelFileID~=modelFileID) then
            book.modelEntry=selected;book.modelFileID=modelFileID
            book.model:ClearModel();book.model:Hide();book.modelRotation=0
            book.mineralModel:ClearModel();book.mineralModel:Hide()
            local model=entry.kind=="mineral" and book.mineralModel or book.model
            book.activeModel=model
            book.modelCaption:SetText("Model unavailable")
            if modelFileID then
                book.modelCaption:SetText("Loading model…")
                -- Forever may retain the file ID but omit geometry when loading
                -- a hidden widget. Showing it afterwards does not repair that load.
                model:Show()
                local ok=pcall(model.SetModel,model,modelFileID)
                if not ok then
                    model:ClearModel();model:Hide()
                    book.modelCaption:SetText("Model unavailable")
                end
                model:SetRotation(0)
            end
        end
        book.stats:SetText("Interactions: "..entry.interactions.."\nCompleted gathers: "..entry.completed)
        book.history:SetText("First encountered: "..dateText(entry.firstSeen).."\nLast interaction: "..
            (entry.interactions>0 and dateText(entry.lastSeen) or "Not yet interacted"))
        local loot={}
        for itemID,item in pairs(entry.loot or {}) do
            local name,quality,icon
            local info=C_Item and C_Item.GetItemInfo or GetItemInfo
            if type(info)=="function" then
                local ok,n,_,q,_,_,_,_,_,_,texture=pcall(info,itemID)
                if ok then
                    name=ns.GatheringName(n)
                    if not (issecretvalue and issecretvalue(q)) and type(q)=="number" then quality=q end
                    if not (issecretvalue and issecretvalue(texture)) and (type(texture)=="number" or type(texture)=="string") then icon=texture end
                end
            end
            loot[#loot+1]={id=itemID,name=name or item.name or ("Item "..itemID),quality=quality,icon=icon,data=item}
            if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,itemID) end
        end
        table.sort(loot,function(a,b) if a.name~=b.name then return a.name<b.name end;return a.id<b.id end)
        for i,item in ipairs(loot) do
            local row=book.lootRows[i]
            if not row then
                row=CreateFrame("Button",nil,book.lootChild);row:SetSize(230,62);row:SetPoint("TOPLEFT",0,-(i-1)*62)
                row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("TOPLEFT",0,-3);row.icon:SetSize(28,28)
                row.name=label(row,"",34,-2,190,"GameFontNormal");row.name:SetHeight(32);row.name:SetWordWrap(true)
                row.quantity=label(row,"",34,-38,190,"GameFontHighlightSmall")
                row:SetScript("OnEnter",function(self)
                    if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..self.itemID);GameTooltip:Show() end
                end)
                row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                row:SetScript("OnHide",function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
                book.lootRows[i]=row
            end
            row.itemID=item.id;row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(item.name)
            local colour=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
            row.name:SetTextColor(colour and colour.r or 1,colour and colour.g or 1,colour and colour.b or 1)
            local data=item.data
            row.quantity:SetText("Observed stack: "..data.minQuantity..(data.maxQuantity~=data.minQuantity and ("–"..data.maxQuantity) or ""))
            row:Show()
        end
        for i=#loot+1,#book.lootRows do book.lootRows[i]:Hide() end
        book.noLoot:SetShown(#loot==0)
        book.lootChild:SetHeight(math.max(169,#loot*62))
        if book.lootID~=selected then book.lootID=selected;book.lootScroll:SetVerticalScroll(0) end
        book.lootScroll:UpdateScrollChildRect();book.lootScroll:RefreshScrollBar()
        local zones=journal:GetLocationZones(selected)
        for i,zone in ipairs(zones) do
            local row=book.zoneRows[i]
            if not row then
                row=button(book.zoneChild,"",0,-(i-1)*28,304,function(self)
                    locations:Open(selected,self.zone.mapID)
                end)
                row:SetNormalFontObject(textFont("GameFontHighlightSmall"))
                row:SetHighlightFontObject(textFont("GameFontHighlightSmall"))
                book.zoneRows[i]=row
            end
            local count=0;for _ in pairs(zone.data and zone.data.points or {}) do count=count+1 end
            row.zone=zone;row:SetText(zone.name.."  •  "..count.." mapped positions");row:Show()
        end
        for i=#zones+1,#book.zoneRows do book.zoneRows[i]:Hide() end
        book.noZones:SetShown(#zones==0)
        book.zoneChild:SetHeight(math.max(164,#zones*28))
        if book.noteID~=selected then
            book.note:ClearFocus()
            book.noteID=selected;book.loadingNote=true
            book.note:SetText(drafts[selected] or entry.note or "")
            book.noteScroll:SetVerticalScroll(0);book.loadingNote=false
            book.zoneScroll:SetVerticalScroll(0)
        end
        book.zoneScroll:UpdateScrollChildRect();book.zoneScroll:RefreshScrollBar()
        book.saveNote:SetEnabled((drafts[selected] or entry.note or "")~=(entry.note or ""))
        locations:SetResource(selected);locations:Refresh()
    end
    local function build(content)
        book=content;controller.frame=book
        -- Match the Bestiary's lower-left parchment illustration treatment.
        local mill=content:CreateTexture(nil,"BACKGROUND",nil,3)
        mill:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\GatheringTwilightJasmine.png")
        -- Let the full sprig extend below the page, cropping at the paper inset.
        mill:SetSize(281,284)
        mill:SetPoint("BOTTOMLEFT",content,"BOTTOMLEFT",6,6)
        -- Shift artwork 15 pixels left, clipping it at the paper edge.
        mill:SetTexCoord(39/320,1,0,284/320)
        mill:SetAlpha(0.33)
        shell:AddBackgroundLayer(mill,1,1,1,true)
        book.jasmineIllustration=mill
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
            fadeStrip(5+i,6,1,284,alpha)
            fadeStrip(6,5+i,281,1,alpha)
        end
        local function updateJasmineFade()
            local width,height=content:GetWidth()-8,content:GetHeight()-15
            if width<=0 or height<=0 then return end
            for _,fade in ipairs(fades) do
                local x,y=fade.x-6,fade.y-6
                fade.texture:SetTexCoord(x/width,(x+fade.width)/width,
                    1-(y+fade.height)/height,1-y/height)
            end
        end
        content:HookScript("OnSizeChanged",updateJasmineFade)
        updateJasmineFade()
        book.jasmineCornerFade=ui.IllustrationCornerFade(content,shell,6)
        book.pageTitle=ui.SectionTitle(book,"Gatherer's Compendium")
        book.spine=ns.FieldbookUI.PageDivider(book)
        book.entryCount=ui.EntryCount(book)
        local filterMenu=CreateFrame("Frame",nil,book,"BackdropTemplate");book.listFilterMenu=filterMenu
        filterMenu:SetSize(190,154);filterMenu:SetFrameLevel(book:GetFrameLevel()+40);filterMenu:EnableMouse(true)
        filterMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        filterMenu:SetBackdropColor(0.055,0.04,0.022,1)
        book.listFilterButton=ui.FilterButton(book,244,-110,function()
            book.search:ClearFocus();book.sortMenu:Hide()
            filterMenu:SetShown(not filterMenu:IsShown());refresh()
        end)
        styleSelection(book.listFilterButton,nil,true)
        book.listFilterButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Filter resources\nRight-click to reset filters.");GameTooltip:Show() end
        end)
        book.listFilterButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        filterMenu:SetPoint("TOPLEFT",book.listFilterButton,"BOTTOMLEFT",0,0)
        filterMenu:Hide()
        book.typeButtons={}
        for i,spec in ipairs({{"all","All"},{"herb","Herbs"},{"mineral","Minerals"}}) do
            local kind=spec[1]
            local control=button(filterMenu,spec[2],10,-10-(i-1)*27,170,function()
                if kind=="all" or category==kind then category=nil else category=kind end
                offset=0;refresh()
            end)
            styleSelection(control);book.typeButtons[kind]=control
        end
        book.locationsButton=ui.MenuButton(filterMenu,"Locations",10,-91,170,function()
            refreshLocationFilter();book.locationFrame:Show();refresh()
        end)
        styleSelection(book.locationsButton,true)
        local function resetFilters()
            category=nil;offset=0
            for zone in pairs(locationFilters) do locationFilters[zone]=nil end
            book.search:SetText("");refreshLocationFilter();refresh()
        end
        book.clearFilters=button(filterMenu,"Clear filters",10,-118,170,resetFilters)
        book.listFilterButton.ResetFilters=function()
            resetFilters();filterMenu:Hide();book.locationFrame:Hide();refresh()
        end
        book.search=ui.Search(book,70,-110,168,100)
        book.searchClear=book.search.clearButton
        book.searchPlaceholder=book.search.placeholder
        book.search:HookScript("OnTextChanged",function() offset=0;refresh() end)
        local dismiss=CreateFrame("Button","AzerothFieldbookGatheringSortMenu",UIParent)
        dismiss:SetAllPoints(UIParent);dismiss:SetFrameStrata("FULLSCREEN_DIALOG");dismiss:SetToplevel(true)
        dismiss:SetScript("OnShow",function(self) self:SetScale(shell:GetFrame():GetScale());self:Raise() end)
        dismiss:EnableMouse(true);dismiss:SetScript("OnClick",function(self) self:Hide() end)
        local menu=CreateFrame("Frame",nil,dismiss,"BackdropTemplate")
        menu:SetSize(184,290);menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetClampedToScreen(true);menu:EnableMouse(true)
        menu:SetFrameLevel(dismiss:GetFrameLevel()+1)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        menu:SetBackdropColor(0.08,0.055,0.025,1);menu:SetBackdropBorderColor(0.45,0.30,0.13,1)
        label(menu,"Sorting by",12,-12,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        book.sortChoices={}
        local function refreshSort()
            local field,descending=journal:GetListSort()
            for _,choice in ipairs(book.sortChoices) do
                choice.control:SetSelected(choice.field and choice.field==field or (not choice.field and choice.descending==descending))
            end
        end
        for i,spec in ipairs({{"name","Name"},{"kind","Type"},{"interactions","Interactions"},
            {"completed","Completed Gathers"},{"firstSeen","First Encountered"},{"lastSeen","Last Interaction"}}) do
            local field=spec[1]
            local control=button(menu,spec[2],12,-32-(i-1)*27,160,function()
                local _,descending=journal:GetListSort();journal:SetListSort(field,descending)
                offset=0;refresh();refreshSort()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG");styleSelection(control)
            book.sortChoices[#book.sortChoices+1]={control=control,field=field}
        end
        label(menu,"Order",12,-199,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        for i,title in ipairs({"Ascending","Descending"}) do
            local descending=i==2
            local control=button(menu,title,12,-219-(i-1)*27,160,function()
                journal:SetListSort(journal:GetListSort(),descending);offset=0;refresh();refreshSort()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG");styleSelection(control)
            book.sortChoices[#book.sortChoices+1]={control=control,descending=descending}
        end
        book.sortButton=button(book,"",270,-110,22,function()
            filterMenu:Hide();book.search:ClearFocus();refreshSort();dismiss:SetShown(not dismiss:IsShown())
        end)
        book.sortButton:SetSize(22,22)
        for i=0,4 do
            local stroke=book.sortButton:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-i*2,1);stroke:SetPoint("CENTER",0,2-i);stroke:SetColorTexture(1,0.82,0.14,1)
        end
        book.sortButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Sort");GameTooltip:Show() end
        end)
        book.sortButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        menu:SetPoint("TOPRIGHT",book.sortButton,"BOTTOMRIGHT",0,-4);dismiss:Hide();book.sortMenu=dismiss
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookGatheringSortMenu" end
        book.rows={}
        book.resourceScrollBar=CreateFrame("Slider",nil,book,"UIPanelScrollBarTemplate")
        book.resourceScrollBar:SetPoint("TOPLEFT",282,-156);book.resourceScrollBar:SetSize(14,454)
        ns.StyleScrollBarTrack(book.resourceScrollBar,0.3)
        book.resourceScrollBar:SetMinMaxValues(0,0);book.resourceScrollBar:SetValueStep(1)
        book.resourceScrollBar:SetObeyStepOnDrag(true)
        book.resourceScrollBar:SetScript("OnValueChanged",function(_,value)
            if book.updatingScroll then return end
            offset=math.floor(value+0.5);refresh()
        end)
        local function wheel(_,delta) offset=offset-delta*3;refresh() end
        book.resourceScrollBar:EnableMouseWheel(true);book.resourceScrollBar:SetScript("OnMouseWheel",wheel)
        for i=1,PAGE_SIZE do
            local row=CreateFrame("Button",nil,book,"BackdropTemplate")
            row:SetPoint("TOPLEFT",42,-140-(i-1)*27);row:SetSize(236,26)
            ns.FieldbookUI.StyleMenuRow(row)
            row.divider=ns.FieldbookUI.EntryDivider(row,1,236)
            for _,line in ipairs(row.divider) do line:SetShown(i>1) end
            row.text=label(row,"",28,-6,203);row.text:SetWordWrap(false);addNameScroller(row)
            row:SetScript("OnClick",function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true);row:SetScript("OnMouseWheel",wheel);book.rows[i]=row
        end
        book.noMatches=label(book,"",52,-152,226,"GameFontHighlightSmall");book.noMatches:SetSpacing(4)
        local deleteForm=ui.DeletePanel(book,shell,"Delete gathering entry",true);book.deleteForm=deleteForm
        book.deleteButton=button(book,"Delete",174,-672,118,function()
            local id=selected;local entry=id and journal.entries[id]
            if not entry or journal.readOnly then return end
            deleteForm.id,deleteForm.entry=id,entry
            deleteForm:Open("Permanently delete "..entry.name.."?\n\nIts observations, locations, loot and notes will be removed. This cannot be undone.\n\nFuture observations may record it again.",function()
                if selected~=id or journal.entries[id]~=entry then return nil,"Selection changed; nothing deleted." end
                if journal:DeleteEntry(id) then drafts[id]=nil;selected=nil;locations:Hide();refresh();return true end
                return nil,"Could not delete this entry."
            end)
        end)
        book.title=label(book,"Gatherer's Compendium",342,-60,494,"GameFontNormalLarge")
        book.title:SetTextColor(1,0.82,0.14);book.title:SetWordWrap(false)
        book.title:SetShadowColor(0,0,0,0.85);book.title:SetShadowOffset(1,-1)
        local path,size,flags=book.title:GetFont()
        if path and size then book.title:SetFont(path,size+2,flags) end
        book.locations=button(book,"Locations",854,-60,82,function() locations:Toggle(selected) end)
        book.title:ClearAllPoints()
        book.title:SetPoint("TOPLEFT",book,"TOPLEFT",342,-60)
        book.title:SetPoint("BOTTOMRIGHT",book.locations,"BOTTOMLEFT",-18,0)
        book.title:SetJustifyV("MIDDLE")

        styleSelection(book.locations,nil,true)
        locations:SetVisibilityCallback(function(shown) book.locations:SetSelected(shown) end)
        book.empty=label(book,"Mouse over a herb or mineral to discover it and its zone, even without the profession.\n\nInteract with it to record coordinates. Each entry keeps your interactions, completed gathers and field notes.",342,-115,558)
        book.empty:SetSpacing(6)
        book.details=CreateFrame("Frame",nil,book);book.details:SetAllPoints(book)
        local detail=book.details
        book.basicHeading=label(detail,"Basic info",342,-109,236,"GameFontNormalLarge")
        book.basicHeading:SetTextColor(1,0.82,0.14)
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",344,-133);book.modelBorder:SetSize(227,168)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model=createGatheringViewer(detail,function(ready)
            book.modelCaption:SetText(ready and "" or "Model unavailable")
        end)
        book.model:SetFrameLevel(book.modelBorder:GetFrameLevel()+1)
        book.model:SetPoint("TOPLEFT",346,-135);book.model:SetSize(223,164)
        book.model:EnableMouse(true)
        book.modelCaption=label(book.modelBorder,"",8,-76,211,"GameFontHighlightSmall")
        book.modelCaption:SetJustifyH("CENTER")
        book.mineralModel=createGatheringViewer(detail,function(ready)
            book.modelCaption:SetText(ready and "" or "Model unavailable")
        end)
        book.mineralModel:SetFrameLevel(book.modelBorder:GetFrameLevel()+1)
        book.mineralModel:SetPoint("TOPLEFT",346,-135);book.mineralModel:SetSize(223,164)
        book.mineralModel:Hide();book.mineralModel:EnableMouse(true)
        local rotating,lastCursorX=false,nil
        local function cursorX()
            local x=GetCursorPosition and GetCursorPosition()
            if type(x)=="number" and not (issecretvalue and issecretvalue(x)) then
                return x/(UIParent:GetEffectiveScale() or 1)
            end
        end
        for _,viewer in ipairs({book.model,book.mineralModel}) do
        viewer:SetScript("OnMouseDown",function() rotating=true;lastCursorX=cursorX() end)
        viewer:SetScript("OnMouseUp",function() rotating=false;lastCursorX=nil end)
        viewer:SetScript("OnUpdate",function(self,dt)
            if self.isGatheringViewer then self:UpdateFraming(dt) end
            if not rotating then return end
            local x=cursorX()
            if x and lastCursorX then
                book.modelRotation=(book.modelRotation or 0)+(x-lastCursorX)*0.015
                self:SetRotation(book.modelRotation)
            end
            lastCursorX=x
        end)
        viewer:SetScript("OnHide",function() rotating=false;lastCursorX=nil end)
        end
        book.stats=label(detail,"",342,-326,236);book.stats:SetSpacing(6)
        book.history=label(detail,"",590,-326,334,"GameFontHighlightSmall");book.history:SetSpacing(6)
        book.locationsHeading=label(detail,"Locations",590,-109,334,"GameFontNormalLarge")
        book.locationsHeading:SetTextColor(1,0.82,0.14)
        book.zoneScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        book.zoneScroll:SetPoint("TOPLEFT",590,-134);book.zoneScroll:SetSize(312,164)
        book.zoneChild=CreateFrame("Frame",nil,book.zoneScroll);book.zoneChild:SetSize(304,164)
        book.zoneScroll:SetScrollChild(book.zoneChild)
        ns.AutoHideScrollBar(book.zoneScroll,function() return book.zoneChild:GetHeight() end)
        book.zoneRows={};book.noZones=label(book.zoneChild,"Mouse over this herb or mineral to record its zone.",0,-6,296,"GameFontHighlightSmall")
        local divider=CreateFrame("Frame",nil,detail)
        divider:SetPoint("TOPLEFT",330,-391);divider:SetSize(598,3)
        ns.FieldbookUI.EntryDivider(divider,0,598,nil,3)
        label(detail,"Field notes",342,-415,290,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        local noteBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        noteBorder:SetPoint("TOPLEFT",342,-445);noteBorder:SetSize(290,185)
        noteBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
            insets={left=2,right=2,top=2,bottom=2}})
        noteBorder:SetBackdropColor(0.05,0.04,0.025,0.6);noteBorder:SetBackdropBorderColor(0.45,0.30,0.13,1)
        book.noteScroll=CreateFrame("ScrollFrame",nil,noteBorder,"UIPanelScrollFrameTemplate")
        book.noteScroll:SetPoint("TOPLEFT",8,-8);book.noteScroll:SetSize(250,169)
        book.note=CreateFrame("EditBox",nil,book.noteScroll)
        book.note:SetMultiLine(true);book.note:SetAutoFocus(false);book.note:SetMaxLetters(1000)
        book.note:EnableMouse(true);book.note:EnableKeyboard(true)
        book.note:SetFontObject(textFont("GameFontHighlight"));book.note:SetSize(242,169)
        book.noteScroll:SetScrollChild(book.note);ns.AutoHideScrollBar(book.noteScroll)
        local function focusNotes(_,mouseButton)
            if mouseButton=="LeftButton" and selected and book.noteID==selected then book.note:SetFocus() end
        end
        book.noteScroll:EnableMouse(true);book.noteScroll:SetScript("OnMouseDown",focusNotes)
        noteBorder:EnableMouse(true);noteBorder:SetScript("OnMouseDown",focusNotes)
        book.note:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        book.note:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local scroll=book.noteScroll:GetVerticalScroll();local top=-y
            if top<scroll then book.noteScroll:SetVerticalScroll(top)
            elseif top+height>scroll+169 then book.noteScroll:SetVerticalScroll(top+height-169) end
        end)
        book.note:SetScript("OnTextChanged",function(self)
            if book.loadingNote or not selected then return end
            drafts[selected]=self:GetText();book.message:SetText("")
            book.saveNote:SetEnabled(drafts[selected]~=(journal.entries[selected].note or ""))
            book.noteScroll:UpdateScrollChildRect();book.noteScroll:RefreshScrollBar()
        end)
        book.saveNote=button(detail,"Save notes",342,-642,108,function()
            local id=book.noteID
            if id and id==selected and journal:SetNote(id,book.note:GetText()) then
                drafts[id]=nil;book.message:SetText("Notes saved.");book.note:ClearFocus();refresh()
            end
        end)
        book.message=label(detail,"",482,-648,150,"GameFontHighlightSmall")
        label(detail,"Observed loot",646,-415,270,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        local lootBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        lootBorder:SetPoint("TOPLEFT",646,-445);lootBorder:SetSize(270,185)
        lootBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,
            insets={left=2,right=2,top=2,bottom=2}})
        lootBorder:SetBackdropColor(0.05,0.04,0.025,0.6);lootBorder:SetBackdropBorderColor(0.45,0.30,0.13,1)
        book.lootScroll=CreateFrame("ScrollFrame",nil,lootBorder,"UIPanelScrollFrameTemplate")
        book.lootScroll:SetPoint("TOPLEFT",8,-8);book.lootScroll:SetSize(230,169)
        book.lootChild=CreateFrame("Frame",nil,book.lootScroll);book.lootChild:SetSize(230,169)
        book.lootScroll:SetScrollChild(book.lootChild)
        ns.AutoHideScrollBar(book.lootScroll,function() return book.lootChild:GetHeight() end)
        book.lootRows={}
        book.noLoot=label(book.lootChild,"No loot recorded yet.\nGather this node to record its drops.",4,-6,218,"GameFontHighlightSmall")
        book.mapOptions={}
        for i,spec in ipairs({{"worldMap","Show nodes on world map"},{"minimap","Show nodes on minimap"}}) do
            local key=spec[1]
            local control=CreateFrame("CheckButton",nil,book,"UICheckButtonTemplate")
            control:SetSize(24,24);control:SetPoint("TOPLEFT",342+(i-1)*300,-673)
            label(control,spec[2],26,-6,250,"GameFontHighlightSmall")
            control:SetChecked(journal:ShowNodesOn(key))
            control:SetScript("OnClick",function(self)
                journal:SetShowNodesOn(key,self:GetChecked()==true)
                if controller.mapPins then controller.mapPins:Refresh() end
            end)
            book.mapOptions[key]=control
        end
        local filter=CreateFrame("Frame",nil,filterMenu,"BackdropTemplate")
        filter:SetSize(260,284);filter:SetPoint("TOPLEFT",book.locationsButton,"TOPRIGHT",0,8)
        filter:SetFrameLevel(filterMenu:GetFrameLevel()+5);filter:EnableMouse(true);filter:SetClampedToScreen(true)
        filter:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        filter:SetBackdropColor(0.055,0.04,0.022,1)
        label(filter,"None checked shows all.",12,-10,236,"GameFontHighlightSmall")
        book.locationFrame=filter
        filter.scroll=CreateFrame("ScrollFrame",nil,filter,"UIPanelScrollFrameTemplate")
        filter.scroll:SetPoint("TOPLEFT",10,-32);filter.scroll:SetSize(218,208)
        filter.body=CreateFrame("Frame",nil,filter.scroll);filter.body:SetSize(218,208)
        filter.scroll:SetScrollChild(filter.body);ns.AutoHideScrollBar(filter.scroll)
        if filter.scroll.ScrollBar then ns.StyleScrollBarTrack(filter.scroll.ScrollBar,0.4) end
        filter.rows={}
        filter.empty=label(filter.body,"No locations recorded yet.",0,0,214,"GameFontHighlightSmall")
        refreshLocationFilter=function()
            local seen,names={},{}
            for _,entry in pairs(journal.entries) do
                for _,zone in ipairs(journal:GetLocationZones(entry.id)) do
                    if not seen[zone.name] then seen[zone.name]=true;names[#names+1]=zone.name end
                end
            end
            table.sort(names)
            local height=0
            for i,name in ipairs(names) do
                local row=filter.rows[i]
                if not row then
                    row=CreateFrame("CheckButton",nil,filter.body,"UICheckButtonTemplate")
                    row:SetSize(24,24);row:SetPoint("TOPLEFT",0,-(i-1)*28)
                    row.text=label(row,"",28,-5,188,"GameFontHighlightSmall");row.text:SetWordWrap(true)
                    row:SetScript("OnClick",function(self)
                        locationFilters[self.zone]=self:GetChecked() and true or nil;offset=0;refresh()
                    end)
                    filter.rows[i]=row
                end
                row.zone=name;row.text:SetText(name);row:SetChecked(locationFilters[name]==true);row:Show()
                row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-height)
                height=height+math.max(28,row.text:GetStringHeight()+10)
            end
            for i=#names+1,#filter.rows do filter.rows[i]:Hide() end
            filter.empty:SetShown(#names==0);height=math.max(28,height)
            local viewport=math.min(208,height)
            filter.body:SetHeight(height);filter.scroll:SetHeight(viewport);filter:SetHeight(viewport+76)
            filter.scroll:SetVerticalScroll(math.min(filter.scroll:GetVerticalScroll(),height-viewport))
            filter.scroll:UpdateScrollChildRect();filter.scroll:RefreshScrollBar()
        end
        local clearLocations=button(filter,"Clear all",12,0,236,function()
            for zone in pairs(locationFilters) do locationFilters[zone]=nil end
            offset=0;refreshLocationFilter();refresh()
        end)
        clearLocations:ClearAllPoints();clearLocations:SetPoint("BOTTOMLEFT",12,10)
        filter:SetScript("OnShow",function() refreshLocationFilter();refresh() end)
        filter:SetScript("OnHide",function() if book.locationFrame then refresh() end end)
        filter:Hide()
        book.locationsButton:SetScript("OnEnter",function() refreshLocationFilter();filter:Show();refresh() end)
        for _,control in pairs(book.typeButtons) do control:HookScript("OnEnter",function() filter:Hide() end) end
        book.clearFilters:HookScript("OnEnter",function() filter:Hide() end)
        filterMenu:SetScript("OnHide",function() filter:Hide();refresh() end)
        ui.DismissOnOutsideClick(filterMenu,book.listFilterButton,{filter})
        book:SetScript("OnHide",function()
            dismiss:Hide();filterMenu:Hide();filter:Hide();locations:Hide();deleteForm:Hide();book.search:ClearFocus();book.note:ClearFocus()
            for _,row in ipairs(book.rows) do row:StopNameScroll() end
        end)
        local elapsed=0
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.25 then
                elapsed=0
                if book.revision~=journal.revision then refresh();if filter:IsShown() then refreshLocationFilter() end end
            end
        end)
    end
    shell:RegisterSection("gathering",{title="Gatherer's Compendium",icon="Interface\\Icons\\Trade_Herbalism",
        help="|cffffd1001. Discover|r\nBuild a record of herbs and minerals by hovering over their readable world tooltips. You do not need Herbalism or Mining to discover them. Hovering records the resource and zone, not a position or completed gather.\n\n"..
            "|cffffd1002. Record positions|r\nStarting a Herbalism or Mining cast records your approximate position, even if interrupted. A successful cast also counts as a completed gather, not a quantity of loot. An interaction rejected for missing profession or rank can still record a position when the matching skill error is readable.\n\n"..
            "|cffffd1003. Browse|r\nUse Herbs, Minerals, search, sorting and Locations filters to find an entry. Previous and Next browse matching entries. Scroll the list if there are more than sixteen matches.\n\n"..
            "|cffffd1004. Review locations|r\nClick a zone under Locations to see recorded interaction positions. Green dots mark herbs; gold dots mark minerals. Hover a dot for coordinates. These are approximate player positions, not proof that a node is currently available. Hover-only discoveries have no dots.\n\n"..
            "|cffffd1005. Map display|r\nEnable Show nodes on world map or Show nodes on minimap to see recorded positions while travelling. Both start off. These maps show a selection of recent or nearby positions; use an entry's Locations view to review its stored positions.\n\n"..
            "|cffffd1006. Field notes|r\nWrite a note and click Save notes. Observed loot records readable drops linked to completed gathers; its stack ranges describe past observations, not guaranteed yields.\n\nAccount-wide tracking in Options applies to this journal too. It starts on; turn it off to use this character's separate journal after /reload. Gathering records are separate from Bestiary resets, backups and sharing.",
        frameName="AzerothFieldbookGatheringSection",build=build,onOpen=function() refresh(true) end})
    function controller:OpenAtMouseover()
        local id=self.tracking and self.tracking:DiscoverAtMouseover()
        if not id or not journal.entries[id] then return false end
        selected=id;category=nil;offset=0
        for zone in pairs(locationFilters) do locationFilters[zone]=nil end
        shell:ShowSection("gathering")
        book.search:SetText("");book.search:ClearFocus();book.note:ClearFocus()
        book.locationFrame:Hide()
        for i,entry in ipairs(currentRows()) do
            if entry.id==id then offset=math.max(0,i-PAGE_SIZE);break end
        end
        choose(id)
        return true
    end
    function controller:Select(id)
        if not journal.entries[id] then return false end
        selected=id;category=nil;offset=0
        for zone in pairs(locationFilters) do locationFilters[zone]=nil end
        shell:ShowSection("gathering");book.search:SetText("")
        for i,entry in ipairs(currentRows()) do if entry.id==id then offset=math.max(0,i-PAGE_SIZE);break end end
        choose(id);return true
    end
    function controller:Refresh() refresh() end
    return controller
end

function ns.InitializeGathering(shell,getBrightness)
    if type(AzerothFieldbookGatheringDB)~="table" then AzerothFieldbookGatheringDB={} end
    local storage=ns.SelectSectionStorage and ns.SelectSectionStorage("gathering",AzerothFieldbookGatheringDB) or AzerothFieldbookGatheringDB
    local journal=ns.CreateGatheringJournal(storage,getBrightness)
    local controller=ns.CreateGatheringBook(journal,shell)
    controller.tracking=ns.CreateGatheringTracking(journal)
    controller.mapPins=ns.CreateGatheringMapPins(journal)
    return controller
end
