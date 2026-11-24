local _,ns=...
local L=ns.Lore

-- Recognition metadata only: game-object IDs and source titles from the
-- installed Spoken Readables object-owner index. No source text, locations or
-- discovery credit are supplied. Keep this independent of Spoken being loaded.
local objects={
    [37]="Eliza's Tombstone",
    [1726]="Missing: Corporal Keeshan",
    [2082]="Uther the Lightbringer",
    [18664]="A Treatise on Military Ranks",
    [18675]="Military Ranks of the Horde & Alliance",
    [19025]="Ancient Inscription",
    [21004]="Monument to Grom Hellscream",
    [21581]="Aftermath of the Second War",
    [21582]="Beyond the Dark Portal",
    [21583]="The Kaldorei and the Well of Eternity",
    [24777]="Yuriv's Tombstone",
    [25329]="Kurdran Wildhammer",
    [25330]="General Turalyon",
    [25331]="Ranger Captain Alleria Windrunner",
    [25332]="Danath Trollbane",
    [25333]="Archmage Khadgar of the Kirin Tor",
    [123463]="Baelog's Journal",
    [124374]="Horatio Montgomery, M.D.",
    [164820]="Dark Keeper Nameplate",
    [164821]="Dark Keeper Nameplate",
    [164822]="Dark Keeper Nameplate",
    [164823]="Dark Keeper Nameplate",
    [164824]="Dark Keeper Nameplate",
    [164825]="Dark Keeper Nameplate",
    [174746]="Etched Note",
    [175658]="The Armor of Mannoroth",
    [175659]="Here Lies King Terenas Menethil II",
    [175679]="The Skull of Tyrannistrasz",
    [175680]="Fossilized Egg",
    [175681]="Roc Talon",
    [175682]="Geru Strider",
    [175683]="Toothgnasher's Skeleton",
    [175684]="Saurial Egg",
    [175685]="Pteradon Skeleton",
    [175686]="Highborne Astrolabe",
    [175687]="Uldaman Relics",
    [175688]="Horde Catapult",
    [175689]="Uldaman Reliefs",
    [175724]="Sargeras and the Betrayal",
    [175725]="The Old Gods and the Ordering of Azeroth",
    [175726]="Charge of the Dragonflights",
    [175727]="The War of the Ancients",
    [175729]="Mount Hyjal and Illidan's Gift",
    [175730]="The World Tree and the Emerald Dream",
    [175731]="Exile of the High Elves",
    [175732]="The Sentinels and the Long Vigil",
    [175733]="The Founding of Quel'Thalas",
    [175734]="Arathor and the Troll Wars",
    [175735]="The Guardians of Tirisfal",
    [175736]="Ironforge - the Awakening of the Dwarves",
    [175737]="The Seven Kingdoms",
    [175738]="Aegwynn and the Dragon Hunt",
    [175739]="War of the Three Hammers",
    [175740]="The Last Guardian",
    [175741]="Kil'jaeden and the Shadow Pact",
    [175742]="Rise of the Horde",
    [175745]="The Dark Portal and the Fall of Stormwind",
    [175746]="The Alliance of Lordaeron",
    [175747]="The Invasion of Draenor",
    [175748]="The Birth of the Lich King",
    [175749]="Icecrown and the Frozen Throne",
    [175750]="The Battle of Grim Batol",
    [175751]="Lethargy of the Orcs",
    [175752]="The New Horde",
    [175753]="War of the Spider",
    [175754]="Kel'Thuzad and the Forming of the Scourge",
    [175756]="The Scourge of Lordaeron",
    [175757]="Sunwell - The Fall of Quel'Thalas",
    [175758]="Archimonde's Return and the Flight to Kalimdor",
    [175759]="The Betrayer Ascendant",
    [175760]="Rise of the Blood Elves",
    [175761]="Civil War in the Plaguelands",
    [175762]="The Lich King Triumphant",
    [175763]="Old Hatreds - The Colonization of Kalimdor",
    [175771]="Arellas Fireleaf",
    [175772]="Admiral Barean Westwind",
    [175773]="Dorgar Stoenbrow",
    [175774]="Fellari Swiftarrow",
    [175775]="Ferren Marcus",
    [175776]="Harthal Truesight",
    [175777]="Holia Sunshield",
    [175778]="Invar One-Arm",
    [175779]="Orman of Stromgarde",
    [175780]="Valea Twinblades",
    [175781]="Yana Bloodspear",
    [175854]="The Twin Empires",
    [175855]="Empires' Fall",
    [175856]="Wrath of Soulflayer",
    [175933]="Decorated Headstone",
    [177199]="Archbishop Alonsus Faol",
    [177200]="King Llane I of the House of Wrynn",
    [177201]="Grand Admiral Daelin Proudmoore",
    [177202]="Lady Mara Fordragon",
    [177204]="Sorrow of the Earthmother",
    [177205]="Forestlord and the first Druids",
    [177207]="Mists of Dawn",
    [177208]="The White Stag and the Moon",
    [177209]="Hatred of the Centaur",
    [177222]="Pteradon Skeleton",
    [179706]="A Treatise on Military Ranks",
    [179707]="Military Ranks of the Horde & Alliance",
    [179735]="Alliance Military Ranks",
    [179741]="Horde Military Ranks",
    [179909]="Rock of Durotan",
    [180367]="Altar of Zanza",
    [180665]="Draconic for Dummies",
    [181062]="In Loving Memory",
}
-- Predefined readable item identities exclude player-written correspondence.
local items={
    [745]="Marshal McBride's Documents",
    [748]="Stormwind Armor Marker",
    [889]="A Dusty Unsent Letter",
    [910]="An Undelivered Letter",
    [916]="A Torn Journal Page",
    [921]="A Faded Journal Page",
    [938]="Muddy Journal Pages",
    [939]="A Bloodstained Journal Page",
    [957]="William's Shipment",
    [1208]="Maybell's Love Letter",
    [1252]="Gramma Stonefield's Note",
    [1283]="Verner's Note",
    [1284]="Crate of Horseshoes",
    [1293]="The State of Lakeshire",
    [1294]="The General's Response",
    [1327]="Wiley's Note",
    [1353]="Shaw's Report",
    [1358]="A Clue to Sander's Treasure",
    [1361]="Another Clue to Sander's Treasure",
    [1362]="Final Clue to Sander's Treasure",
    [1381]="A Mysterious Message",
    [1407]="Solomon's Plea to Westfall",
    [1408]="Stoutmantle's Response to Solomon",
    [1409]="Solomon's Plea to Darkshire",
    [1410]="Ebonlocke's Response to Solomon",
    [1637]="Letter to Ello",
    [1656]="Translated Letter",
    [1971]="Furlbrow's Deed",
    [2004]="Grelin Whitebeard's Journal",
    [2005]="The First Troll Legend",
    [2006]="The Second Troll Legend",
    [2007]="The Third Troll Legend",
    [2008]="The Fourth Troll Legend",
    [2113]="Calor's Note",
    [2154]="The Story of Morgan Ladimore",
    [2161]="Book from Sven's Farm",
    [2188]="A Letter to Grelin Whitebeard",
    [2223]="The Collector's Schedule",
    [2560]="Jitters' Completed Journal",
    [2619]="Grelin's Report",
    [2628]="Senir's Report",
    [2637]="Ironband's Progress Report",
    [2639]="Merrin's Letter",
    [2720]="Muddy Note",
    [2724]="Cloth Request",
    [2725]="Green Hills of Stranglethorn - Page 1",
    [2728]="Green Hills of Stranglethorn - Page 4",
    [2730]="Green Hills of Stranglethorn - Page 6",
    [2732]="Green Hills of Stranglethorn - Page 8",
    [2734]="Green Hills of Stranglethorn - Page 10",
    [2735]="Green Hills of Stranglethorn - Page 11",
    [2738]="Green Hills of Stranglethorn - Page 14",
    [2740]="Green Hills of Stranglethorn - Page 16",
    [2742]="Green Hills of Stranglethorn - Page 18",
    [2744]="Green Hills of Stranglethorn - Page 20",
    [2745]="Green Hills of Stranglethorn - Page 21",
    [2748]="Green Hills of Stranglethorn - Page 24",
    [2749]="Green Hills of Stranglethorn - Page 25",
    [2750]="Green Hills of Stranglethorn - Page 26",
    [2751]="Green Hills of Stranglethorn - Page 27",
    [2755]="Green Hills of Stranglethorn",
    [2756]="Green Hills of Stranglethorn - Chapter I",
    [2757]="Green Hills of Stranglethorn - Chapter II",
    [2758]="Green Hills of Stranglethorn - Chapter III",
    [2759]="Green Hills of Stranglethorn - Chapter IV",
    [2832]="Verna's Westfall Stew Recipe",
    [2837]="Thurman's Letter",
    [2885]="Scarlet Crusade Documents",
    [2956]="Report on the Defias Brotherhood",
    [3017]="Sevren's Orders",
    [3117]="Hildelve's Journal",
    [3248]="Translated Letter from The Embalmer",
    [3252]="Deathstalker Report",
    [3255]="Berard's Journal",
    [3518]="Decrypted Letter",
    [3601]="Syndicate Missive",
    [3657]="Hillsbrad Town Registry",
    [3711]="Belamoore's Research Journal",
    [3718]="Foreboding Plans",
    [3899]="Legends of the Gurubashi, Volume 3",
    [3921]="Bloodsail Orders",
    [4100]="Crumpled Note",
    [4101]="Ripped Note",
    [4102]="Torn Note",
    [4429]="Deepfury's Orders",
    [4432]="Sully Balloo's Letter",
    [4514]="Sara Balloo's Plea",
    [4649]="Bonegrip's Note",
    [4650]="Bel'dugur's Note",
    [4834]="Venture Co. Documents",
    [4883]="Admiral Proudmoore's Orders",
    [4992]="Recruitment Letter",
    [4995]="Signed Recruitment Letter",
    [5006]="Khazgorm's Journal",
    [5088]="Control Console Operating Manual",
    [5354]="Letter to Delgren",
    [5359]="Lorgalis Manuscript",
    [5428]="An Exotic Cookbook",
    [5455]="Divined Scroll",
    [5505]="Teronis' Journal",
    [5520]="Velinde's Journal",
    [5535]="Compendium of the Fallen",
    [5536]="Mythology of the Titans",
    [5594]="Letter to Jin'Zil",
    [5628]="Zamah's Note",
    [5737]="Covert Ops Plans: Alpha & Beta",
    [5790]="Lonebrow's Journal",
    [5799]="Kravel's Parts Order",
    [5804]="Goblin Rumors",
    [5807]="Fool's Stout Report",
    [5826]="Kravel's Scheme",
    [5827]="Fizzle Brassbolts' Letter",
    [5838]="Kodo Skin Scroll",
    [5839]="Journal Page",
    [5860]="Legacy of the Aspects",
    [5861]="Beginnings of the Undead Threat",
    [5882]="Captain's Documents",
    [5897]="Snufflenose Owner's Manual",
    [5917]="Spy's Report",
    [5947]="Defias Docket",
    [5948]="Letter to Jorgen",
    [5998]="Stormpike's Request",
    [6167]="Neeka's Report",
    [6283]="The Book of Ur",
    [6304]="Damp Diary Page (Day 4)",
    [6305]="Damp Diary Page (Day 87)",
    [6306]="Damp Diary Page (Day 512)",
    [6488]="Simple Tablet",
    [6842]="Furen's Instructions",
    [6846]="Defias Script",
    [6847]="Dark Iron Script",
    [6929]="Bath'rah's Parchment",
    [6996]="Jordan's Weapon Notes",
    [7266]="Ur's Treatise on Shadow Magic",
    [7516]="Tabetha's Instructions",
    [7587]="Thun'grim's Instructions",
    [7668]="Bloodstained Journal",
    [7907]="Certificate of Thievery",
    [7908]="Klaven Mortwake's Journal",
    [8046]="Kearnen's Journal",
    [8463]="Warchief's Orders",
    [9242]="Ancient Tablet",
    [9279]="White Punch Card",
    [9280]="Yellow Punch Card",
    [9281]="Red Punch Card",
    [9282]="Blue Punch Card",
    [9316]="Prismatic Punch Card",
    [9329]="A Short Note",
    [9330]="Snapshot of Gammerita",
    [9542]="Simple Letter",
    [9543]="Simple Rune",
    [9544]="Simple Memorandum",
    [9545]="Simple Sigil",
    [9546]="Simple Scroll",
    [9547]="Simple Note",
    [9548]="Hallowed Letter",
    [9550]="Encrypted Rune",
    [9551]="Encrypted Sigil",
    [9552]="Rune-Inscribed Note",
    [9553]="Etched Parchment",
    [9554]="Encrypted Tablet",
    [9555]="Encrypted Letter",
    [9556]="Hallowed Rune",
    [9557]="Hallowed Sigil",
    [9558]="Encrypted Memorandum",
    [9559]="Encrypted Scroll",
    [9560]="Encrypted Parchment",
    [9561]="Hallowed Tablet",
    [9562]="Rune-Inscribed Tablet",
    [9563]="Consecrated Rune",
    [9564]="Etched Tablet",
    [9565]="Etched Note",
    [9566]="Etched Rune",
    [9567]="Etched Sigil",
    [9568]="Rune-Inscribed Parchment",
    [9569]="Hallowed Scroll",
    [9570]="Consecrated Letter",
    [9571]="Glyphic Letter",
    [9573]="Glyphic Memorandum",
    [9574]="Glyphic Scroll",
    [9575]="Glyphic Tablet",
    [9576]="Tainted Letter",
    [9577]="Tainted Memorandum",
    [9578]="Tainted Scroll",
    [9579]="Tainted Parchment",
    [9580]="Verdant Sigil",
    [9581]="Verdant Note",
    [10022]="Proof of Deed",
    [10789]="Manual of Engineering Disciplines",
    [10832]="Fel Tracker Owner's Manual",
    [10839]="Crystallized Note",
    [10840]="Crystallized Note",
    [11108]="Faded Photograph",
    [11125]="Grape Manifest",
    [11368]="Bolvar's Decree",
    [11482]="Crystal Pylon User's Manual",
    [11727]="Goodsteel Ledger",
    [11732]="Libram of Rumination",
    [11733]="Libram of Constitution",
    [11734]="Libram of Tenacity",
    [11736]="Libram of Resilience",
    [11737]="Libram of Voracity",
    [11886]="Urgent Message",
    [12438]="Tinkee's Letter",
    [12562]="Important Blackrock Documents",
    [12564]="Assassination Note",
    [12635]="Simple Parchment",
    [12730]="Warosh's Scroll",
    [12765]="Secret Note #1",
    [12766]="Secret Note #2",
    [12768]="Secret Note #3",
    [12900]="Annals of Darrowshire",
    [13158]="Words of the High Chief",
    [13202]="Extended Annals of Darrowshire",
    [13507]="Cliffwatcher Longhorn Report",
    [14679]="Of Love and Family",
    [15790]="Studies in Spirit Speaking",
    [15847]="Quel'Thalas Registry",
    [15998]="Lewis' Note",
    [16189]="Maggran's Reserve Letter",
    [16209]="Podrig's Order",
    [16263]="Laird's Response",
    [16307]="Gryshka's Letter",
    [16310]="Brock's List",
    [16785]="Rexxar's Testament",
    [17355]="Rabine's Letter",
    [17735]="The Feast of Winter Veil",
    [17781]="The Pariah's Instructions",
    [18229]="Nat Pagle's Guide to Extreme Anglin'",
    [18332]="Libram of Rapidity",
    [18333]="Libram of Focus",
    [18334]="Libram of Protection",
    [18401]="Nostro's Compendium of Dragon Slaying",
    [18646]="The Eye of Divinity",
    [18708]="Petrified Bark",
    [18818]="Mor'zul's Instructions",
    [19483]="Peeling the Onion",
    [19484]="The Frostwolf Artichoke",
    [19978]="Fishing Tournament!",
    [20009]="For the Light!",
    [20010]="The Horde's Hellscream",
    [20405]="Decoded Tablet Transcription",
    [20415]="The War of the Shifting Sands",
    [20541]="Decoded Twilight Text",
    [20545]="Decoded Twilight Text",
    [20552]="Decoded Twilight Text",
    [20676]="Decoded Twilight Text",
    [20677]="Decoded Twilight Text",
    [20678]="Decoded Twilight Text",
    [20679]="Decoded Twilight Text",
    [20949]="Magical Ledger",
    [21037]="Crude Map",
    [21130]="Diary of Weavil",
    [21142]="From the Desk of Lord Victor Nefarius",
    [21314]="Metzen's Letters and Notes",
    [22344]="Brazier of Invocation: User's Manual",
    [22595]="Call to Arms Announcement",
    [22930]="A Bloodstained Envelope",
    [22932]="A Torn Letter",
    [22944]="A Crumpled Missive",
    [22945]="A Careworn Note",
    [22946]="A Ragged Page",
    [22948]="A Smudged Document",
    [23008]="Sealed Research Report",
    [23010]="Sealed Research Report",
    [23011]="Sealed Research Report",
    [23012]="Sealed Research Report",
    [23013]="Sealed Research Report",
    [23016]="Sealed Research Report",
}
local titles={}
function L.IsReadableItem(id) return L.Public(id) and items[id]~=nil end
function L.ReadableItemTitle(id) return items[id] end
for _,title in pairs(objects) do titles[title]=true end
function L.IsReadableObjectTitle(title) return titles[title]==true end

function L.GameObjectID(guid)
    if not L.Text(guid,160) then return end
    return tonumber(guid:match('^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$'))
end
function L.ReadableObjectTitle(id) return objects[id] end
local function paused()
    return ns.InitializationBlocked or ns.IsFieldbookSectionEnabled and not ns.IsFieldbookSectionEnabled("lore")
end

function ns.CreateLoreTooltips(journal,settings)
    settings=settings or AzerothFieldbookDB or {}
    local t={}
    local revision,index,byIdentity
    local function archive()
        if revision==journal.revision then return index end
        revision=journal.revision;index={};byIdentity={}
        local function add(title,source,summary,hasText)
            if not title or title=="" then return end
            index[title]=index[title] or {}
            local record={identity=source.identity,locale=source.locale,
                complete=summary.complete,missing=summary.missing,hasText=hasText}
            table.insert(index[title],record)
            if source.identity then
                byIdentity[source.identity]=byIdentity[source.identity] or {}
                table.insert(byIdentity[source.identity],record)
            end
        end
        for _,e in pairs(journal.entries) do
            if e.kind=="writing" then
                -- A renamed entry retains its original source title. Empty
                -- placeholders and annotations alone do not store a source.
                local hasText=next(e.pages)~=nil
                for _,p in ipairs(e.passages) do if p.nature=="source" then hasText=true end end
                local title=e.sourceTitle and e.sourceTitle~="" and e.sourceTitle or e.title
                add(title,e,journal:WritingSummary(e),hasText)
                for _,report in ipairs(e.reports) do
                    -- Attached reports can describe a different source. Their
                    -- text belongs to the report's title, not the host entry.
                    if next(report.pages or {}) then
                        local writing={kind='writing',pages={}}
                        for _,p in ipairs(report.pages) do if L.Integer(p.number,1,L.MAX_PAGES) then
                            writing.pages[p.number]=p
                            if p.first then writing.firstPage=p.number end
                            if p.last then writing.lastPage=p.number end
                        end end
                        add(report.sourceTitle and report.sourceTitle~="" and report.sourceTitle or report.title,
                            report,journal:WritingSummary(writing),true)
                    end
                end
            end
        end
        return index
    end
    function t:Status(name,id,sourceKind)
        if paused() or settings.showTooltips==false or journal.readOnly or journal.invalid>0 then return end
        local known=archive()
        local locale=L.Read(GetLocale) or "unknown"
        local english=locale=="enUS" or locale=="enGB"
        sourceKind=sourceKind or 'gameobject'
        local registry=sourceKind=='item' and items or objects
        local canonical=english and registry[id]
        if sourceKind=='item' then
            -- A book-like name or a generic readable flag alone also matches
            -- player correspondence. Only predefined lore item IDs qualify.
            if not registry[id] then return end
        elseif not registry[id] and not (english and titles[name]) and not known[name]
            and not (id and byIdentity['gameobject:'..id]) then return end
        local stored,missing=false
        for _,records in ipairs({known[name] or {},canonical~=name and known[canonical] or {},
            id and byIdentity[sourceKind..':'..id] or {}}) do
            for _,e in ipairs(records) do
                local kind,sourceID=(e.identity or ""):match('^(%a+):(%d+)$')
                local typed=kind=='item' or kind=='gameobject'
                if (not typed or kind==sourceKind and (not id or tonumber(sourceID)==id))
                    and (not e.locale or e.locale=="" or e.locale==locale) then
                    if e.complete then return nil,true end
                    stored=stored or e.hasText
                    if #e.missing>0 and (not missing or #e.missing<#missing) then missing=e.missing end
                end
            end
        end
        if missing then return "[AFB] Chronicle: Missing pages ("..table.concat(missing,", ")..")",false end
        if not stored then return "[AFB] Chronicle: Unread",false end
        return nil,true
    end
    function t:Append(tooltip,data)
        if not tooltip or (tooltip~=GameTooltip and tooltip~=ItemRefTooltip) or paused() or settings.showTooltips==false then return end
        if data~=nil and (not L.Public(data) or type(data)~='table' or not L.Public(data.type)) then return end
        data=data or L.Read(tooltip.GetTooltipData,tooltip)
        local kinds=Enum and Enum.TooltipDataType or {}
        local sourceKind
        if L.Public(data) and type(data)=='table' and L.Public(data.type) and kinds.Item and data.type==kinds.Item then
            sourceKind='item'
        else
            if tooltip~=GameTooltip then return end
            local info=L.Read(tooltip.GetPrimaryTooltipInfo,tooltip)
            if not L.Public(info) or type(info)~="table" or not L.Public(info.getterName) or info.getterName~="GetWorldCursor" then return end
            data=L.Read(C_TooltipInfo and C_TooltipInfo.GetWorldCursor)
            sourceKind='gameobject'
        end
        local kind=sourceKind=='item' and kinds.Item or kinds.Object
        if not kind or not L.Public(data) or type(data)~="table" or not L.Public(data.type) or data.type~=kind
            or not L.Public(data.lines) or type(data.lines)~="table" then return end
        local first=data.lines[1]
        local name=L.Public(first) and type(first)=="table" and L.Text(first.leftText,240) and first.leftText
        if not name then return end
        local id=(sourceKind=='gameobject' and L.GameObjectID(data.guid)) or (L.Integer(data.id,1,2147483647) and data.id)
        local text=self:Status(name,id,sourceKind)
        if not text then return end
        -- Both the data processor and the fallback hook can see one tooltip.
        -- Check its rendered lines so native rebuilds work without stale flags.
        local count=L.Read(tooltip.NumLines,tooltip)
        local tooltipName=L.Read(tooltip.GetName,tooltip)
        if type(count)~="number" or type(tooltipName)~="string" then return end
        for i=1,count do
            local line=_G[tooltipName.."TextLeft"..i]
            local value=line and L.Read(line.GetText,line)
            if type(value)=="string" and value:find("[AFB] Chronicle:",1,true) then return end
        end
        if type(tooltip.AddLine)~="function" then return end
        tooltip:AddLine("|cff80d0ff[AFB] Chronicle:|r "..text:sub(#"[AFB] Chronicle: "+1),1,0.82,0.14,true)
    end
    local kind=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
    if kind and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" then
        TooltipDataProcessor.AddTooltipPostCall(kind,function(tooltip,data) t:Append(tooltip,data) end)
    elseif GameTooltip and type(GameTooltip.SetWorldCursor)=="function" and type(hooksecurefunc)=="function" then
        hooksecurefunc(GameTooltip,"SetWorldCursor",function() t:Append(GameTooltip) end)
    end
    local itemKind=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if itemKind and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=='function' then
        TooltipDataProcessor.AddTooltipPostCall(itemKind,function(tooltip,data) t:Append(tooltip,data) end)
    else
        for _,tooltip in pairs({GameTooltip,ItemRefTooltip}) do if type(tooltip.HookScript)=='function' then
            pcall(tooltip.HookScript,tooltip,'OnTooltipSetItem',function(tip) t:Append(tip) end)
        end end
    end
    return t
end
