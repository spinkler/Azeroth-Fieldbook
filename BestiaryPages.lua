local _, ns = ...

-- Bestiary settings and help content; shared page frames live in FieldbookShell.
function ns.CreateBestiaryPages(journal,shell,book,callbacks)
    local ui=ns.FieldbookUI
    local label,button,edit=ui.Label,ui.Button,ui.Edit
    local function createBookPage(...) return shell:CreatePage(...) end
    local function showBookPage(page) shell:ShowPage(page) end
    local eventLog,eventBody=createBookPage("AzerothFieldbookEventLog","Event log",65)
    book.eventLog=eventLog
    local eventPage=0
    local eventText=label(eventBody,"",30,0,530,"GameFontHighlightSmall")
    local eventStatus=label(eventLog,"",255,-722,300,"GameFontHighlightSmall")
    local newer,older
    local legacySectionLabels={
        ["atlas-recorded"]={section="atlas",prefix="Atlas recorded: "},
        ["lore-recorded"]={section="lore",prefix="Lore recorded: "},
    }
    local function refreshEventLog()
        local log=journal:GetEventLog()
        local entries=log.entries
        eventPage=math.max(0,math.min(eventPage,math.max(0,math.ceil(#entries/50)-1)))
        local lines={}
        for index=#entries-eventPage*50,math.max(1,#entries-eventPage*50-49),-1 do
            local entry=entries[index]
            local stamp=entry.timestamp and date and date("%Y-%m-%d %H:%M:%S",entry.timestamp) or "Unknown time"
            local message=entry.message
            local legacy=type(entry.details)=="table" and legacySectionLabels[entry.details.kind]
            local section=legacy and shell.sections[legacy.section]
            -- Update old section labels for display without rewriting saved events or entry names.
            if section and message:sub(1,#legacy.prefix)==legacy.prefix then
                message=section.definition.title.." recorded: "..message:sub(#legacy.prefix+1)
            end
            lines[#lines+1]="|cff999999"..stamp.."|r\n"..message
        end
        eventText:SetText(#lines>0 and table.concat(lines,"\n\n") or "No events recorded yet. Events are saved even when chat messages are disabled.")
        local contentHeight=math.max(1,eventText:GetStringHeight()+20)
        local height=math.max(200,math.min(767,eventLog.contentTop+contentHeight+65))
        local resized=eventLog:GetHeight()~=height
        eventLog:SetHeight(height)
        eventBody:SetHeight(contentHeight)
        local range=math.max(0,contentHeight-(height-eventLog.contentTop-65))
        eventLog.scroll:SetVerticalScroll(math.min(eventLog.scroll:GetVerticalScroll() or 0,range))
        eventLog.scroll:UpdateScrollChildRect()
        local bar=eventLog.scroll.ScrollBar
        if bar and type(bar)~="function" then bar:SetShown(range>0) end
        eventLog.scroll:EnableMouseWheel(range>0)
        if resized and eventLog:IsShown() and ns.WindowPositions then ns.WindowPositions:AvoidWindowOverlap(eventLog) end
        eventStatus:SetText(#entries.." events"..(#entries>50 and (" · Page "..(eventPage+1).." / "..math.ceil(#entries/50)) or ""))
        newer:SetShown(#entries>50);older:SetShown(#entries>50)
        newer:SetEnabled(eventPage>0);older:SetEnabled((eventPage+1)*50<#entries)
    end
    newer=button(eventLog,"Newer",30,-722,100,function() eventPage=eventPage-1;eventLog.scroll:SetVerticalScroll(0);refreshEventLog() end)
    older=button(eventLog,"Older",140,-722,100,function() eventPage=eventPage+1;eventLog.scroll:SetVerticalScroll(0);refreshEventLog() end)
    newer:ClearAllPoints();newer:SetPoint("BOTTOMLEFT",30,21)
    older:ClearAllPoints();older:SetPoint("BOTTOMLEFT",140,21)
    eventStatus:ClearAllPoints();eventStatus:SetPoint("BOTTOMRIGHT",-35,28)
    eventLog.text,eventLog.newer,eventLog.older=eventText,newer,older
    eventLog:SetScript("OnShow",refreshEventLog)
    journal:SetEventLogChangedCallback(function() if eventLog:IsShown() then refreshEventLog() end end)
    eventLog:Hide()
    local help,helpBody=createBookPage("AzerothFieldbookHelp","AZEROTH FIELDBOOK - HELP",24)
    local helpInstructions=label(helpBody,"|cffffd1001. Encounter|r\nBuild a creature journal by targeting or mousing over attackable NPCs. Readable names, creature types and levels are recorded automatically. Clicking a creature adds its entry even when Location is suppressed. Automatic locations require a positive range check within 40 yards and agreement with your zone at all 25 map samples within 42 yards. A newly recorded zone announces New Location Observed once per creature. Observations in saved zones stay silent, including after reload. Location capture checks at most once per second per creature and needs about 10 yards of movement after an accepted capture. Kills count toward credit and rewards without recording locations. A skull means the level is unknown. While flying, including flight paths, target a creature or use the mouseover-open keybinding to record it; passive hovering does not count.\n\n|cffffd100Dungeons and raids|r\nIn instances such as Hall of Thanes, the game may hide creature identity, so selecting or hovering over a creature may not add it. A later readable target or mouseover observation can create the entry. Retained damage-meter records can add abilities to an existing entry, but cannot create or restore one. Use /fieldbook scan outside combat to retry ability imports; details the game still hides cannot be recorded.\n\n|cffffd1002. Record|r\nCasts with readable spell IDs are automatically confirmed with a cyan [A]; readable buffs are recorded outside combat. Player debuffs and Loss of Control IDs appear only with a verified NPC source. A matching player aura with a verified NPC source can add its ability with [A]. Player-controlled and unidentified casters are ignored. Cast, buff and debuff rows also have portraits for manual assignment. Hover to check the captured creature; buffs identify the recipient. Portraits keep their captured creature when targets change. Unlock its entry before assigning; restricted IDs require manual entry. Change this under Options > Ability recording. Observed fleeing can also record Flees at low health; a screech calling for help records Calls allies. Other ability observations may remain pending for your review. Add missing abilities and damage observations manually; use your own measurements for damage ranges.\n\n|cffffd1003. Review|r\nSelect a creature to review abilities, defenses, behaviour and Notes. Confirm accurate abilities, reject doubtful ones or remove unwanted records. Optional Show expected immunities in Options starts off: [Type] labels are expectations, not observed or shareable immunity marks.\n\nOpen Locations and switch between Tracking: Kills and Tracking: Observations. Violet preserves historical kill positions; cyan shows where you stood during qualified nearby observations. New observations add the zone and observer position, including while locked. Hover zone names to see retained historical subzones. Approximate historical markers are not exact creature positions.\n\n|cffffd1004. Lock Entry|r\nUse Lock this entry to protect manual edits and the saved basic information; Unlock this entry resumes editing. Locked creatures stop adding casts, channels and reliably attributed buff/debuff observations to Last observed spell IDs, even when spell IDs are restricted. Buffs use the identified recipient; debuffs use the verified caster, never an unverified target. Their unpinned rows clear; pinned casts remain. Unlock to resume observations. While testing, a locked target shows a red Suppressed target hint, including with auto-fade enabled. Locking does not stop kill credit or fresh automatic abilities and behaviours. Some basic facts, such as disposition and previously unknown levels, can still update. Notes remain editable.\n\nEnable all AFB tooltips in Options starts on and controls creature facts and spell IDs. Spell observation and ID feedback in chat starts off, separately from discovery announcements.\n\nConfirmed abilities can appear in creature tooltips. Use each ability's checkbox to choose which ones appear, even while locked. Hold Ctrl over a creature for available spell descriptions.\n\n|cffffd1005. Browse|r\nNarrow the index with creature-type filters, search and sorting. Index shows or hides the A-Z filters. The Next Bestiary entry and Previous Bestiary entry keybindings follow the filtered list while the Bestiary is open and no text field has focus.\n\nOptions > Data has an individual account-wide toggle for each of the seven supported journals. Uncheck a journal to use this character's separate data; changes apply after /reload. Annals always stays character-specific. Existing character journals import once into the account journals. Later changes in the two scopes stay separate.\n\n|cffffd1006. Share|r\nOutside combat, use Share to offer one creature's information to a named player using the same addon version. Select the traits to include and review the cost before Send. Received traits appear as unverified Rumours with the sender's name. Open Rumours, then use the green tick to verify a claim or x to reject it. Unlock the entry before verifying. Beast Lore is shared separately as a free, read-only client observation with sender attribution.\n\nThe book shows knowledge earned; Share shows what remains available after spending and reservations. If delivery is uncertain, knowledge stays spent. Reopen Share and use Retry for the same report without another charge, up to three times within 24 hours.",35,0,535)
    local pointsBlock=CreateFrame("Frame",nil,helpBody,"BackdropTemplate")
    pointsBlock:SetPoint("TOPLEFT",helpInstructions,"BOTTOMLEFT",0,-18)
    pointsBlock:SetWidth(535)
    pointsBlock:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    pointsBlock:SetBackdropColor(0.12,0.08,0.03,0.35)
    pointsBlock:SetBackdropBorderColor(0.55,0.40,0.20,1)
    pointsBlock.title=label(pointsBlock,"Knowledge",14,-14,507,"GameFontNormalLarge")
    pointsBlock.title:SetTextColor(1,0.82,0.14)
    pointsBlock.awardHeading=label(pointsBlock,"Earning knowledge",14,0,507,"GameFontNormal")
    pointsBlock.awardHeading:SetTextColor(1,0.82,0.14)
    pointsBlock.awards=label(pointsBlock,"+1 for first kill\n+1 for silver star (25 kills)\n+2 for gold star (50 kills)\n+3 for crown (100 kills)\n\nElite: 1.5x each award. Rare and Rare Elite: 2x, without stacking. Round each award down to a whole point.\n\nQualifying kills earn knowledge even at an unknown/skull level. Discovery, locations, levels and received reports earn none. Each milestone pays once per creature; deleting an entry does not reset its credit.",14,0,507,"GameFontHighlightSmall")
    pointsBlock.spendHeading=label(pointsBlock,"Sharing knowledge",14,0,507,"GameFontNormal")
    pointsBlock.spendHeading:SetTextColor(1,0.82,0.14)
    pointsBlock.spending=label(pointsBlock,"1 knowledge for basic information; free if the recipient already knows it.\n1 knowledge per selected rumour.\n\nRemove known basics from the cost, then multiply the total by 1.5 for Elite or 2 for Rare and Rare Elite and round down. Beast Lore reports are free.\n\nSend reserves the maximum cost; acceptance spends the final cost. Declines and cancellation before spending are free. Receiving information is free.",14,0,507,"GameFontHighlightSmall")
    help.pointsBlock=pointsBlock
    local helpDetails=CreateFrame("Frame",nil,helpBody)
    helpDetails:SetPoint("TOPLEFT",pointsBlock,"BOTTOMLEFT",-35,-18)
    helpDetails:SetWidth(570)
    label(helpDetails,"|cffffd100ABOUT|r",35,0,120,"GameFontNormal")
    local about=label(helpDetails,"Created by |cff40c7ebSpinkler|r\nSPECIAL THANKS to |cfff48cbaErna|r, |cffaad372Labrick|r, and |cffff7c0aRhysdogg|r for beta testing\n\nDeveloped with AI-assisted coding tools.\nDesign, direction, testing and final development decisions by the author.",35,-22,535,"GameFontHighlightSmall")
    help:SetScript("OnShow",function(self)
        local pointsHeight=14
        for i,text in ipairs({pointsBlock.title,pointsBlock.awardHeading,pointsBlock.awards,pointsBlock.spendHeading,pointsBlock.spending}) do
            if i>1 then pointsHeight=pointsHeight+((i==2 or i==4) and 16 or 8) end
            text:ClearAllPoints(); text:SetPoint("TOPLEFT",14,-pointsHeight)
            pointsHeight=pointsHeight+text:GetStringHeight()
        end
        pointsHeight=pointsHeight+14
        pointsBlock:SetHeight(pointsHeight)
        helpDetails:SetHeight(22+about:GetStringHeight())
        helpBody:SetHeight(helpInstructions:GetStringHeight()+18+pointsHeight+18+22+about:GetStringHeight()+16)
        showBookPage(self)
    end)
    help:Hide(); book.help=help
    local options,optionsBody=createBookPage("AzerothFieldbookOptions","AZEROTH FIELDBOOK - OPTIONS",65)
    local optionItems,optionSections={},{}
    local originalLabel,originalButton,originalEdit=label,button,edit
    local originalCreateFrame=CreateFrame
    local function remember(control,parent)
        if parent==optionsBody then optionItems[#optionItems+1]=control end
        return control
    end
    label=function(parent,...) return remember(originalLabel(parent,...),parent) end
    button=function(parent,...) return remember(originalButton(parent,...),parent) end
    edit=function(parent,...) return remember(originalEdit(parent,...),parent) end
    local function CreateFrame(kind,name,parent,...)
        return remember(originalCreateFrame(kind,name,parent,...),parent)
    end
    optionsBody:SetHeight(2450)
    local function optionHeading(title,y)
        local heading=label(optionsBody,title,30,-y,510,"GameFontNormalLarge")
        heading:SetTextColor(1,0.82,0.14)
        local font,size,flags=heading:GetFont()
        if font and type(size)=="number" then heading:SetFont(font,size-2,flags) end
        optionSections[#optionSections+1]={heading=heading,originalY=y,items={}}
    end
    optionHeading("Bestiary entry locking",0)
    optionHeading("Chat notifications",122)
    label(optionsBody,"Events are saved in the Event log even when chat messages are off.",35,-248,510,"GameFontHighlightSmall")
    optionHeading("Appearance",266)
    optionHeading("Window behavior",562)
    optionHeading("Sharing",700)
    optionHeading("Tooltips and cast IDs",774)
    optionHeading("Ability recording",1204)
    options.autoRecordBuffs=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.autoRecordBuffs:SetPoint("TOPLEFT",30,-1230);options.autoRecordBuffs:SetSize(24,24)
    label(optionsBody,"Automatically record verified creature abilities",58,-1236,470,"GameFontHighlightSmall")
    label(optionsBody,"Readable casts and player Loss of Control IDs with verified NPC aura sources work in combat; buffs require both units out of combat. New records get cyan [A] and chat/Event log messages. Fresh evidence restores removed or rejected abilities even on locked entries; turn off to keep them removed.",35,-1268,510,"GameFontHighlightSmall")
    options.autoRecordBuffs:SetScript("OnClick",function(self)
        journal:SetAutoRecordAbilities(self:GetChecked()==true)
    end)
    optionHeading("Expected immunities",1360)
    options.expectedImmunities=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.expectedImmunities:SetPoint("TOPLEFT",30,-1386);options.expectedImmunities:SetSize(24,24)
    label(optionsBody,"Show expected immunities",58,-1392,470,"GameFontHighlightSmall")
    label(optionsBody,"Off by default. Optional creature-type guidance, not knowledge your character has observed. Hides or shows [Type] suggestions without changing recorded immunities or saved overrides.",35,-1424,510,"GameFontHighlightSmall")
    options.expectedImmunities:SetScript("OnClick",function(self)
        journal:SetShowExpectedImmunities(self:GetChecked()==true)
    end)
    optionHeading("Lorekeeper's Chronicle",1640)
    options.autoArchiveLore=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.autoArchiveLore:SetPoint("TOPLEFT",30,-1666);options.autoArchiveLore:SetSize(24,24)
    label(optionsBody,"Automatically archive readable lore",58,-1672,470,"GameFontHighlightSmall")
    options.autoArchiveLore:SetScript("OnClick",function(self)
        if ns.LoreSettings then ns.LoreSettings.Set("autoArchiveLore",self:GetChecked()==true) end
    end)
    options.loreOnlyOpenedPages=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.loreOnlyOpenedPages:SetPoint("TOPLEFT",30,-1700);options.loreOnlyOpenedPages:SetSize(24,24)
    label(optionsBody,"Only archive pages I open",58,-1706,470,"GameFontHighlightSmall")
    options.loreOnlyOpenedPages:SetScript("OnClick",function(self)
        if ns.LoreSettings then ns.LoreSettings.Set("loreOnlyOpenedPages",self:GetChecked()==true) end
    end)
    label(optionsBody,"Both start on. Only displayed pages are archived by default. Disable the second option to archive the whole accessible book where supported; the original reader may turn pages. Keep the interaction open until archiving finishes. Automatically retrieved pages are labelled separately. Disabling capture or enabling the restriction stops automatic work and keeps stored text. Manual capture and transcription remain available.",35,-1740,510,"GameFontHighlightSmall")
    optionHeading("Account-wide journals",2600)
    label(optionsBody,"Choose which journals this character shares with your account. Checked means account-wide; unchecked means character-specific.",35,-2630,510,"GameFontHighlightSmall")
    options.trackingSections={}
    for index,section in ipairs(ns.TrackingSections) do
        local key,title=section[1],section[2]
        local row=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        row:SetPoint("TOPLEFT",30,-2684-(index-1)*34);row:SetSize(24,24)
        label(optionsBody,title,58,-2690-(index-1)*34,280,"GameFontHighlightSmall")
        row.status=label(optionsBody,"",350,-2690-(index-1)*34,185,"GameFontHighlightSmall")
        options.trackingSections[key]=row
        row:SetScript("OnClick",function(self)
            journal:SetAccountWideTracking(self:GetChecked()==true,key)
            options:RefreshStorageScope()
        end)
    end
    options.trackingReload=label(optionsBody,"",35,-2930,510,"GameFontHighlightSmall")
    label(optionsBody,"Adventurer's Annals always stays character-specific. Each character journal imports once when enabled. Account and character journals then remain separate: disabling does not copy account data back, and re-enabling does not import later character-only changes.",35,-2960,510,"GameFontHighlightSmall")
    function options:RefreshStorageScope()
        for _,section in ipairs(ns.TrackingSections) do
            local key=section[1];local row=self.trackingSections[key]
            row:SetChecked(journal:GetAccountWideTracking(key))
            local title
            if key=="bestiary" then title=journal:IsAccountWideTrackingActive() and "Account-wide" or "Character-specific"
            elseif ns.GetActiveStorageScope then title=ns.GetActiveStorageScope(key) end
            row.status:SetText(journal:IsTrackingChangePending(key) and "Pending reload" or title or (journal:GetAccountWideTracking(key) and "Account-wide" or "Character-specific"))
        end
        self.trackingReload:SetText(journal:IsTrackingChangePending() and "Changes apply after /reload." or "Changes apply after reloading the UI.")
    end
    local function refreshTrackingOption() options:RefreshStorageScope() end
    options.autoLockEnabled=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.autoLockEnabled:SetPoint("TOPLEFT",30,-26);options.autoLockEnabled:SetSize(24,24)
    label(optionsBody,"Auto-lock after",58,-32,100,"GameFontHighlightSmall")
    options.autoLockKills=edit(optionsBody,166,-28,45,5)
    options.autoLockKills:SetNumeric(true)
    label(optionsBody,"kills without changes",226,-32,300,"GameFontHighlightSmall")
    options.autoLockEnabled:SetScript("OnClick",function(self)
        journal:SetAutoLockEnabled(self:GetChecked()==true)
        options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
    end)
    options.autoLockKills:SetScript("OnEditFocusLost",function(self)
        journal:SetAutoLockKills(self:GetText())
        self:SetText(tostring(journal:GetAutoLockKills()))
    end)
    options.lockNewCritters=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.lockNewCritters:SetPoint("TOPLEFT",30,-58);options.lockNewCritters:SetSize(24,24)
    label(optionsBody,"Lock newly encountered critters",58,-64,470,"GameFontHighlightSmall")
    options.lockNewCritters:SetScript("OnClick",function(self)
        journal:SetLockNewCritters(self:GetChecked()==true)
    end)
    options.lockNewCritters:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Lock newly encountered critters")
        GameTooltip:AddLine("Start new critter entries locked after recording their basic information. Existing entries and manual unlocks are kept. Automatic [A] records still apply; unlock for manual edits.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.lockNewCritters:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.creatureAnnouncement=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.creatureAnnouncement:SetPoint("TOPLEFT",30,-148); options.creatureAnnouncement:SetSize(24,24)
    label(optionsBody,"Chat messages for discoveries and recorded treasure contents",58,-154,460,"GameFontHighlightSmall")
    options.creatureAnnouncement:SetScript("OnClick",function(self) journal:SetCreatureAnnouncement(self:GetChecked() == true) end)
    options.spellFeedback=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.spellFeedback:SetPoint("TOPLEFT",30,-212);options.spellFeedback:SetSize(24,24)
    label(optionsBody,"Spell observation and ID feedback in chat",58,-218,460,"GameFontHighlightSmall")
    options.spellFeedback:SetScript("OnClick",function(self) journal:SetSpellFeedback(self:GetChecked()==true) end)
    options.tooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.tooltips:SetPoint("TOPLEFT",30,-904);options.tooltips:SetSize(24,24)
    label(optionsBody,"Enable all AFB tooltips",58,-910,460,"GameFontHighlightSmall")
    options.tooltips:SetScript("OnClick",function(self) journal:SetTooltips(self:GetChecked()==true) end)
    options.tooltips:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("AFB tooltips")
        GameTooltip:AddLine("On by default. Controls creature abilities, behaviours, kills and spell IDs. Disabling also turns off the client-wide aura spell-ID preference. Individual tooltip choices are retained.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.tooltips:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.spellIDTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.spellIDTooltips:SetPoint("TOPLEFT",30,-826); options.spellIDTooltips:SetSize(24,24)
    label(optionsBody,"Show spell IDs on tooltips if possible",58,-832,460,"GameFontHighlightSmall")
    options.spellIDTooltips:SetScript("OnClick",function(self) journal:SetSpellIDTooltips(self:GetChecked() == true) end)
    options.spellIDTooltips:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Spell IDs on tooltips")
        GameTooltip:AddLine("Starts on. Applies WoW's client-wide spell/aura ID tooltip preference at login and when changed here, and controls Fieldbook tooltip IDs. Your choice is saved; a Bestiary settings reset restores the default.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.spellIDTooltips:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.displayCastIDs=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.displayCastIDs:SetPoint("TOPLEFT",30,-852); options.displayCastIDs:SetSize(24,24)
    label(optionsBody,"Display Cast IDs",58,-858,460,"GameFontHighlightSmall")
    options.displayCastIDs:SetScript("OnClick",function(self) journal:SetDisplayCastIDs(self:GetChecked() == true) end)
    label(optionsBody,"Background brightness",58,-332,170,"GameFontHighlightSmall")
    options.backgroundBrightness=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
    options.backgroundBrightness:SetPoint("TOPLEFT",30,-354)
    options.backgroundBrightness:SetSize(180,16)
    local brightnessTrack=options.backgroundBrightness:CreateTexture(nil,"BACKGROUND")
    brightnessTrack:SetPoint("TOPLEFT",2,-4)
    brightnessTrack:SetPoint("BOTTOMRIGHT",-2,4)
    brightnessTrack:SetColorTexture(0.045,0.032,0.018,1)
    options.backgroundBrightness:SetMinMaxValues(0.5,1.5)
    options.backgroundBrightness:SetValueStep(0.05)
    options.backgroundBrightness:SetObeyStepOnDrag(true)
    options.backgroundBrightness:SetScript("OnValueChanged",function(_,value)
        journal:SetBackgroundBrightness(value)
        shell:SetBackgroundBrightness(value)
    end)
    options.darkMode=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.darkMode:SetPoint("TOPLEFT",255,-348);options.darkMode:SetSize(24,24)
    label(optionsBody,"Dark Mode",283,-354,230,"GameFontHighlightSmall")
    options.darkMode:SetScript("OnClick",function(self)
        journal:SetDarkMode(self:GetChecked()==true)
        shell:SetDarkMode(journal:GetDarkMode())
    end)
    options.killCountTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.killCountTooltips:SetPoint("TOPLEFT",30,-800);options.killCountTooltips:SetSize(24,24)
    label(optionsBody,"Show kill count in creature tooltips",58,-806,460,"GameFontHighlightSmall")
    options.killCountTooltips:SetScript("OnClick",function(self) journal:SetKillCountTooltips(self:GetChecked()==true) end)
    options.behaviourTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.behaviourTooltips:SetPoint("TOPLEFT",30,-878);options.behaviourTooltips:SetSize(24,24)
    label(optionsBody,"Show behaviour traits in creature tooltips",58,-884,460,"GameFontHighlightSmall")
    options.behaviourTooltips:SetScript("OnClick",function(self) journal:SetBehaviourTooltips(self:GetChecked()==true) end)
    options.behaviourTooltips:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Behaviour traits in creature tooltips")
        GameTooltip:AddLine("Show checked Behaviour traits such as Melee, Patrols and Flees at low health. Disposition and unverified Rumours are excluded. On by default.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.behaviourTooltips:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    optionHeading("Spell ID window",914)
    local function windowCheck(key, title, y)
        local check=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        check:SetPoint("TOPLEFT",30,y); check:SetSize(24,24)
        label(optionsBody,title,58,y-6,470,"GameFontHighlightSmall")
        check:SetScript("OnClick",function(self) journal:SetSpellIDWindowOption(key,self:GetChecked() == true) end)
        options[key]=check
    end
    windowCheck("displaySpellIDWindow","Display Spell ID window",-940)
    windowCheck("spellIDWindowLocked","Lock Spell ID window",-968)
    windowCheck("spellIDWindowIndefinite","Display Spell IDs in the ID window indefinitely",-996)
    windowCheck("displayHoveredAuraSnapshots","Retain hovered aura tooltips",-1024)
    windowCheck("spellIDWindowAutoFade","Auto-fade when the Spell ID window contains no data",-1052)
    local alphaLabel=label(optionsBody,"Window background opacity: 35%",58,-1090,460,"GameFontHighlightSmall")
    options.spellIDWindowAlpha=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
    options.spellIDWindowAlpha:SetPoint("TOPLEFT",30,-1110); options.spellIDWindowAlpha:SetSize(180,16)
    local alphaTrack=options.spellIDWindowAlpha:CreateTexture(nil,"BACKGROUND")
    alphaTrack:SetPoint("TOPLEFT",2,-4)
    alphaTrack:SetPoint("BOTTOMRIGHT",-2,4)
    alphaTrack:SetColorTexture(0.045,0.032,0.018,1)
    options.spellIDWindowAlpha:SetMinMaxValues(0,1); options.spellIDWindowAlpha:SetValueStep(0.05)
    options.spellIDWindowAlpha:SetObeyStepOnDrag(true)
    options.spellIDWindowAlpha:SetScript("OnValueChanged",function(_,value)
        journal:SetSpellIDWindowOption("spellIDWindowAlpha",value)
        alphaLabel:SetText("Window background opacity: " .. math.floor(value*100+0.5) .. "%")
    end)
    options.spellIDBlacklist=button(optionsBody,"Spell ID window blacklist",255,-1106,265,function()
        if ns.SpellIDWindow then ns.SpellIDWindow:OpenBlacklist() end
    end)
    label(optionsBody,"Each row expires two minutes after observation unless kept indefinitely. The ID window is display-only. Automatic ability recording below works independently.",35,-1150,510,"GameFontHighlightSmall")
    options.blockIncomingOffers=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.blockIncomingOffers:SetPoint("TOPLEFT",30,-726); options.blockIncomingOffers:SetSize(24,24)
    label(optionsBody,"Block incoming offers",58,-732,470,"GameFontHighlightSmall")
    options.blockIncomingOffers:SetScript("OnClick",function(self)
        journal:SetBlockIncomingOffers(self:GetChecked() == true)
    end)
    options.blockIncomingOffers:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Block incoming offers")
        GameTooltip:AddLine("Automatically decline new offers and close unaccepted offers. Reports already accepted can still finish.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.blockIncomingOffers:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.alwaysAnchorToMain=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.alwaysAnchorToMain:SetPoint("TOPLEFT",30,-626); options.alwaysAnchorToMain:SetSize(24,24)
    label(optionsBody,"Always attempt to anchor to main window",58,-632,470,"GameFontHighlightSmall")
    options.alwaysAnchorToMain:SetScript("OnClick",function(self)
        journal:SetAlwaysAnchorToMain(self:GetChecked()==true)
    end)
    local scaleLabel=label(optionsBody,"UI scale: 100%",58,-392,460,"GameFontHighlightSmall")
    options.uiScale=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
    options.uiScale:SetPoint("TOPLEFT",30,-414); options.uiScale:SetSize(180,16)
    options.uiScale:SetMinMaxValues(0.5,1.5); options.uiScale:SetValueStep(0.05)
    options.uiScale:SetObeyStepOnDrag(true)
    local scaleTrack=options.uiScale:CreateTexture(nil,"BACKGROUND")
    scaleTrack:SetPoint("TOPLEFT",2,-4); scaleTrack:SetPoint("BOTTOMRIGHT",-2,4)
    scaleTrack:SetColorTexture(0.045,0.032,0.018,1)
    local pendingScale
    local function updateScaleControls(value)
        scaleLabel:SetText("UI scale: " .. math.floor(value*100+0.5) .. "%")
        options.uiScaleDecrease:SetEnabled(value>0.5)
        options.uiScaleIncrease:SetEnabled(value<1.5)
    end
    local function applyScale(value)
        value=math.max(0.5,math.min(1.5,value))
        options.uiScale:SetValue(value)
        pendingScale=nil
        journal:SetUIScale(value)
        updateScaleControls(value)
    end
    local function stepScale(percent)
        applyScale((math.floor(journal:GetUIScale()*100+0.5)+percent)/100)
    end
    options.uiScaleDecrease=button(optionsBody,"-",230,-409,28,function() stepScale(-5) end)
    options.uiScaleReset=button(optionsBody,"100%",264,-409,65,function() applyScale(1) end)
    options.uiScaleIncrease=button(optionsBody,"+",335,-409,28,function() stepScale(5) end)
    options.uiScale:SetScript("OnValueChanged",function(_,value)
        pendingScale=math.max(0.5,math.min(1.5,value))
        updateScaleControls(pendingScale)
    end)
    local function applyPendingScale()
        if pendingScale then applyScale(pendingScale) end
    end
    options.uiScale:SetScript("OnMouseUp",applyPendingScale)
    options.uiScale:EnableKeyboard(false)
    options.uiScale:SetScript("OnHide",function() pendingScale=nil end)
    local textSizeLabel=label(optionsBody,"Text size: Default",58,-450,460,"GameFontHighlightSmall")
    options.textSize=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
    options.textSize:SetPoint("TOPLEFT",30,-476);options.textSize:SetSize(180,16)
    options.textSize:SetMinMaxValues(-3,3);options.textSize:SetValueStep(1)
    options.textSize:SetObeyStepOnDrag(true);options.textSize:EnableKeyboard(false)
    local textTrack=options.textSize:CreateTexture(nil,"BACKGROUND")
    textTrack:SetPoint("TOPLEFT",2,-4);textTrack:SetPoint("BOTTOMRIGHT",-2,4)
    textTrack:SetColorTexture(0.045,0.032,0.018,1)
    local function updateTextSizeControls()
        local value=ns.TextSize and ns.TextSize:Get() or 0
        textSizeLabel:SetText("Text size: "..(value==0 and "Default" or string.format("%+d points",value)))
        options.textSizeReload:SetEnabled(ns.TextSize and ns.TextSize:NeedsReload() or false)
    end
    options.textSizeReset=button(optionsBody,"Default",230,-471,85,function()
        if ns.TextSize then ns.TextSize:Set(0) end
        options.textSize:SetValue(0);updateTextSizeControls()
    end)
    options.textSizeReload=button(optionsBody,"Apply / reload",325,-471,150,function()
        if ReloadUI then ReloadUI() end
    end)
    label(optionsBody,"Seven steps (-3 to +3 points). Applies after reloading the UI.",35,-510,510,"GameFontHighlightSmall")
    local infoBarOptions=CreateFrame("Frame",nil,optionsBody)
    infoBarOptions:SetPoint("TOPLEFT",30,-536);infoBarOptions:SetSize(510,56)
    options.suppressRankInfo=CreateFrame("CheckButton",nil,infoBarOptions,"UICheckButtonTemplate")
    options.suppressRankInfo:SetPoint("TOPLEFT",0,0);options.suppressRankInfo:SetSize(24,24)
    label(infoBarOptions,"Hide Elite, Rare and Rare Elite text in creature info bar",28,-6,470,"GameFontHighlightSmall")
    options.suppressRankInfo:SetScript("OnClick",function(self) journal:SetSuppressRankInfo(self:GetChecked()==true) end)
    options.suppressRankInfo:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Creature rank text")
        GameTooltip:AddLine("Hide Elite, Rare and Rare Elite labels from the Bestiary info bar. Portrait dragon artwork remains visible. World Boss text is always shown. On by default; applies immediately.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.suppressRankInfo:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.dispositionNameColour=CreateFrame("CheckButton",nil,infoBarOptions,"UICheckButtonTemplate")
    options.dispositionNameColour:SetPoint("TOPLEFT",0,-32);options.dispositionNameColour:SetSize(24,24)
    label(infoBarOptions,"Show hostility through creature name colour",28,-38,470,"GameFontHighlightSmall")
    options.dispositionNameColour:SetScript("OnClick",function(self) journal:SetDispositionNameColour(self:GetChecked()==true) end)
    options.dispositionNameColour:SetScript("OnEnter",function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Creature hostility")
        GameTooltip:AddLine("Hide hostility text from the info bar and colour the creature name: red for hostile, yellow for neutral and green for friendly. Unknown disposition keeps the normal gold name. On by default; applies immediately.",1,1,1,true)
        GameTooltip:Show()
    end)
    options.dispositionNameColour:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    options.textSize:SetScript("OnValueChanged",function(_,value)
        if ns.TextSize then ns.TextSize:Set(value) end
        updateTextSizeControls()
    end)
    options.showMinimapButton=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.showMinimapButton:SetPoint("TOPLEFT",30,-292); options.showMinimapButton:SetSize(24,24)
    label(optionsBody,"Show minimap button",58,-298,470,"GameFontHighlightSmall")
    options.showMinimapButton:SetScript("OnClick",function(self) journal:SetMinimapButton(self:GetChecked() == true) end)
    options.pointAnnouncements=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.pointAnnouncements:SetPoint("TOPLEFT",30,-180); options.pointAnnouncements:SetSize(24,24)
    label(optionsBody,"Show a chat message when knowledge is earned",58,-186,470,"GameFontHighlightSmall")
    options.pointAnnouncements:SetScript("OnClick",function(self) journal:SetPointAnnouncements(self:GetChecked() == true) end)
    options.creatureNotesFollowTarget=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.creatureNotesFollowTarget:SetPoint("TOPLEFT",30,-588); options.creatureNotesFollowTarget:SetSize(24,24)
    label(optionsBody,"Creature notes follow target selection",58,-594,470,"GameFontHighlightSmall")
    options.creatureNotesFollowTarget:SetScript("OnClick",function(self)
        journal:SetNotesFollowTarget(self:GetChecked() == true)
        callbacks.followNotesTarget()
    end)
    optionHeading("Atlas and Almanac maps",1500)
    options.mapClickNavigation=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.mapClickNavigation:SetPoint("TOPLEFT",30,-1526);options.mapClickNavigation:SetSize(24,24)
    label(optionsBody,"World-map click navigation",58,-1532,470,"GameFontHighlightSmall")
    label(optionsBody,"Left-click a zone to enter it; right-click to view its parent map. Scroll-wheel zoom and marker actions remain available.",35,-1562,510,"GameFontHighlightSmall")
    options.mapClickNavigation:SetScript("OnClick",function(self) journal:SetMapClickNavigation(self:GetChecked()==true) end)
    if type(StaticPopupDialogs) == "table" then
        StaticPopupDialogs.AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM = {
            text = "Reset the " .. (journal:IsAccountWideTrackingActive() and "account-wide" or "character") .. " Azeroth Fieldbook Bestiary? This deletes its creature entries, notes, abilities, damage records and sharing knowledge/history, plus this character's settings. Saved backups and the Event log are kept.",
            button1 = YES, button2 = NO,
            OnAccept = function()
                journal:ResetDatabase()
                options.behaviourTooltips:SetChecked(journal:GetBehaviourTooltips())
                options.lockNewCritters:SetChecked(journal:GetLockNewCritters())
                options.autoRecordBuffs:SetChecked(journal:GetAutoRecordAbilities())
                options.autoLockEnabled:SetChecked(journal:GetAutoLockEnabled())
                options.autoLockKills:SetText(tostring(journal:GetAutoLockKills()))
                options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
                options.blockIncomingOffers:SetChecked(journal:GetBlockIncomingOffers())
                options.alwaysAnchorToMain:SetChecked(journal:GetAlwaysAnchorToMain())
                options.mapClickNavigation:SetChecked(journal:GetMapClickNavigation())
                refreshTrackingOption()
                options.darkMode:SetChecked(journal:GetDarkMode())
                shell:SetDarkMode(journal:GetDarkMode())
                shell:SetBackgroundBrightness(journal:GetBackgroundBrightness())
                callbacks.onReset()
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    optionHeading("Bestiary backup and reset",3100)
    button(optionsBody,"Reset Bestiary",30,-3134,160,function()
        if StaticPopup_Show then StaticPopup_Show("AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM") end
    end)
    if ns.CreateBackupWindow and journal.CreateBackup then
        local backupWindow=ns.CreateBackupWindow(journal,{page=createBookPage,label=label,button=button},callbacks.onRestored)
        book.backupWindow=backupWindow
        options.backupButton=button(optionsBody,"Backup Bestiary",208,-3134,160,function() backupWindow:Open(true) end)
        options.restoreButton=button(optionsBody,"Restore Bestiary",378,-3134,160,function() backupWindow:Open(false) end)
    end
    if ns.OpenFieldbookBackups then
        optionHeading("Whole-Fieldbook backup and recovery",1900)
        label(optionsBody,"Protect all eight journals, including private notes, the account journals and this character's Annals. Export a copy outside the game. Reports are not backups.",35,-1934,510,"GameFontHighlightSmall")
        options.fieldbookBackups=button(optionsBody,"Fieldbook backups",30,-1990,200,function() ns.OpenFieldbookBackups() end)
        label(optionsBody,"Also available with /fieldbook backups, even if normal startup is blocked.",35,-2028,510,"GameFontHighlightSmall")
    end
    optionHeading("Traveller's Atlas",2100)
    options.legacySubzones=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
    options.legacySubzones:SetPoint("TOPLEFT",30,-2130);options.legacySubzones:SetSize(24,24)
    label(optionsBody,"Legacy Fill",58,-2136,470,"GameFontHighlightSmall")
    label(optionsBody,"Uses less CPU to calculate simpler convex outlines, at the expense of sub-zone detail. Off uses traced fill. Applies to Atlas and the world map.",35,-2168,510,"GameFontHighlightSmall")
    options.legacySubzones:SetScript("OnClick",function(self)
        if ns.AtlasOptions then ns.AtlasOptions.SetLegacy(self:GetChecked()==true) end
    end)
    if ns.FieldbookBackups and ns.FieldbookBackups.StageFullReset then
        optionHeading("Reset entire Fieldbook",2250)
        label(optionsBody,"Deletes all account journals, this character's journals and settings, and saved backups. Other characters' separate saves are not accessible and may import again when those characters log in. Two confirmations are required; the UI then reloads.",35,-2284,510,"GameFontHighlightSmall")
        if type(StaticPopupDialogs)=="table" then
            StaticPopupDialogs.AZEROTHFIELDBOOK_FULL_RESET_REVIEW={
                text="Reset the entire Fieldbook? This deletes all account-wide journals, this character's journals and settings, and saved backups. Other characters' separate saves remain. Continue to the final confirmation?",
                button1="Continue",button2=NO,
                OnAccept=function() StaticPopup_Show("AZEROTHFIELDBOOK_FULL_RESET_CONFIRM") end,
                timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
            }
            StaticPopupDialogs.AZEROTHFIELDBOOK_FULL_RESET_CONFIRM={
                text="Final confirmation: permanently delete all accessible Fieldbook data, including saved backups, and reload now? This cannot be undone. Other characters' retained journals may import again when they log in.",
                button1="Delete and reload",button2=NO,
                OnAccept=function() ns.FieldbookBackups.StageFullReset() end,
                timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
            }
        end
        options.fullReset=button(optionsBody,"Reset entire Fieldbook",30,-2368,230,function()
            if StaticPopup_Show then StaticPopup_Show("AZEROTHFIELDBOOK_FULL_RESET_REVIEW") end
        end)
    end
    -- Keep each section's existing rows together, then space sections from
    -- their measured content instead of accumulating hard-coded blank gaps.
    optionHeading("Adventurer's Annals",2450)
    options.rebuildTimelineData=button(optionsBody,"Rebuild timeline data",30,-2480,230,function()
        local controller=ns.AnnalsController
        if controller then controller:RebuildTimelineData() end
    end)
    label(optionsBody,"Rebuild the current timeline and journey view from recorded history. New events appear automatically; this preserves your filters, timeline page and playback position.",35,-2520,510,"GameFontHighlightSmall")
    table.sort(optionSections,function(a,b) return a.originalY<b.originalY end)
    for _,control in ipairs(optionItems) do
        local point,relative,relativePoint,x,y=control:GetPoint()
        if type(relative)=="number" then x,y=relative,relativePoint;relative,relativePoint=optionsBody,point end
        if type(y)=="number" then
            local section=optionSections[1]
            for _,candidate in ipairs(optionSections) do if -y>=candidate.originalY then section=candidate end end
            section.items[#section.items+1]={control=control,point=point,x=x or 0,offset=-y-section.originalY}
        end
    end
    for i,section in ipairs(optionSections) do
        if i>1 then
            section.divider=originalCreateFrame("Frame",nil,optionsBody)
            section.divider:SetSize(510,1)
            ui.EntryDivider(section.divider,0,510)
        end
    end
    local categories={
        ["Bestiary entry locking"]="Journals",["Ability recording"]="Journals",["Expected immunities"]="Journals",
        ["Lorekeeper's Chronicle"]="Journals",["Atlas and Almanac maps"]="Journals",
        ["Traveller's Atlas"]="Journals",["Adventurer's Annals"]="Journals",
        ["Account-wide journals"]="Data",["Whole-Fieldbook backup and recovery"]="Data",["Reset entire Fieldbook"]="Data",
        ["Bestiary backup and reset"]="Data",
    }
    for _,section in ipairs(optionSections) do section.tab=categories[section.heading:GetText()] or "General" end
    -- Put scope choices before recovery actions on the Data tab.
    table.sort(optionSections,function(a,b)
        if a==b then return false end
        if a.originalY==2600 then return true end
        if b.originalY==2600 then return false end
        return a.originalY<b.originalY
    end)
    options.activeTab="General";options.tabs={}
    local function layoutOptions()
        local top,count=0,0
        for _,section in ipairs(optionSections) do
            local visible=section.tab==options.activeTab
            if section.divider then section.divider:SetShown(visible and count>0) end
            if visible and count>0 then
                if section.divider then section.divider:ClearAllPoints();section.divider:SetPoint("TOPLEFT",30,-top-18) end
                top=top+37
            end
            local bottom=0
            for _,item in ipairs(section.items) do
                local control=item.control;control:SetShown(visible)
                if visible then
                    control:ClearAllPoints();control:SetPoint(item.point,optionsBody,item.point,item.x,-top-item.offset)
                    local height=control:GetHeight() or 0
                    if control.GetStringHeight then height=math.max(height,control:GetStringHeight() or 0) end
                    bottom=math.max(bottom,item.offset+height)
                end
            end
            if visible then top=top+bottom;count=count+1 end
        end
        optionsBody:SetHeight(top+18)
        for name,tab in pairs(options.tabs) do tab:SetEnabled(name~=options.activeTab) end
        options.scroll:UpdateScrollChildRect()
    end
    options.contentTop=80
    options.scroll:ClearAllPoints()
    options.scroll:SetPoint("TOPLEFT",0,-80);options.scroll:SetPoint("BOTTOMRIGHT",-32,65)
    for index,name in ipairs({"General","Journals","Data"}) do
        options.tabs[name]=originalButton(options,name,30+(index-1)*174,-40,164,function()
            options.activeTab=name;options.scroll:SetVerticalScroll(0);layoutOptions()
        end)
    end
    layoutOptions()
    options:SetScript("OnShow",function(self)
        layoutOptions()
        showBookPage(self)
        refreshTrackingOption()
        options.legacySubzones:SetChecked(ns.AtlasOptions and ns.AtlasOptions.GetLegacy() or false)
        options.legacySubzones:SetEnabled(ns.AtlasOptions and ns.AtlasOptions.Writable() or false)
        options.mapClickNavigation:SetChecked(journal:GetMapClickNavigation())
        options.lockNewCritters:SetChecked(journal:GetLockNewCritters())
        options.autoRecordBuffs:SetChecked(journal:GetAutoRecordAbilities())
        options.autoLockEnabled:SetChecked(journal:GetAutoLockEnabled())
        options.autoLockKills:SetText(tostring(journal:GetAutoLockKills()))
        options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
        options.alwaysAnchorToMain:SetChecked(journal:GetAlwaysAnchorToMain())
        options.blockIncomingOffers:SetChecked(journal:GetBlockIncomingOffers())
        options.uiScale:SetValue(journal:GetUIScale())
        pendingScale=nil; updateScaleControls(journal:GetUIScale())
        options.textSize:SetValue(ns.TextSize and ns.TextSize:Get() or 0)
        updateTextSizeControls()
        options.showMinimapButton:SetChecked(journal:GetMinimapButton())
        options.suppressRankInfo:SetChecked(journal:GetSuppressRankInfo())
        options.dispositionNameColour:SetChecked(journal:GetDispositionNameColour())
        options.pointAnnouncements:SetChecked(journal:GetPointAnnouncements())
        options.creatureNotesFollowTarget:SetChecked(journal:GetNotesFollowTarget())
        options.creatureAnnouncement:SetChecked(journal:GetCreatureAnnouncement())
        options.spellIDTooltips:SetChecked(journal:GetSpellIDTooltips())
        options.tooltips:SetChecked(journal:GetTooltips())
        options.spellFeedback:SetChecked(journal:GetSpellFeedback())
        options.killCountTooltips:SetChecked(journal:GetKillCountTooltips())
        options.behaviourTooltips:SetChecked(journal:GetBehaviourTooltips())
        options.expectedImmunities:SetChecked(journal:GetShowExpectedImmunities())
        options.autoArchiveLore:SetChecked(not ns.LoreSettings or ns.LoreSettings.Get("autoArchiveLore"))
        options.loreOnlyOpenedPages:SetChecked(not ns.LoreSettings or ns.LoreSettings.Get("loreOnlyOpenedPages"))
        options.displayCastIDs:SetChecked(journal:GetDisplayCastIDs())
        for _, key in ipairs({"displaySpellIDWindow","spellIDWindowLocked","spellIDWindowIndefinite","displayHoveredAuraSnapshots","spellIDWindowAutoFade"}) do
            options[key]:SetChecked(journal:GetSpellIDWindowOption(key))
        end
        options.spellIDWindowAlpha:SetValue(journal:GetSpellIDWindowOption("spellIDWindowAlpha"))
        options.darkMode:SetChecked(journal:GetDarkMode())
        options.backgroundBrightness:SetValue(journal:GetBackgroundBrightness())
    end)
    options:Hide(); book.options=options
    shell:SetSectionPages("bestiary",{help=help,options=options,eventLog=eventLog})
end
