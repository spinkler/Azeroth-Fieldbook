"""Mouseover zones, interaction-only coordinates and the real section/map UI."""
import unittest
from ui_test_harness import ROOT, new_ui_client
from atlas_test_harness import ATLAS_MODULES


MODULES = [
    'Scrollbars.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
    'CreatureLocations.lua', 'FieldbookShell.lua', 'FieldbookSections.lua',
    'GatheringJournal.lua', 'GatheringModels.lua', 'GatheringTracking.lua', 'GatheringLocationsWindow.lua',
    'GatheringMapPins.lua', 'GatheringBook.lua',
    *ATLAS_MODULES,
]

ENV = r'''
    elapsed=10;mapID=37;px=0.2;py=0.3;mapName='Elwynn';positionReads=0
    function GetTime() return elapsed end
    function GetPlayerFacing() return 1 end
    spellNames={[2366]='Herbalism',[2368]='Herbalism',[2575]='Mining',[2576]='Mining',
        [8613]='Skinning',[2657]='Smelt Copper',[2580]='Find Minerals',[2383]='Find Herbs'}
    C_Spell={GetSpellName=function(id) return spellNames[id] end}
    C_Map={
        GetBestMapForUnit=function() return mapID end,
        GetMapInfo=function(id) return {name=mapName,mapID=id} end,
        GetMapWorldSize=function() return 4000,3000 end,
        GetPlayerMapPosition=function()
            positionReads=positionReads+1;return {x=px,y=py}
        end,
        GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=668,tileWidth=256,tileHeight=256}} end,
        GetMapArtLayerTextures=function() local t={};for i=1,12 do t[i]=9000+i end;return t end,
    }
    GameTooltip=CreateFrame('Frame')
    function GameTooltip:SetOwner(owner) self.owner=owner end
    function GameTooltip:IsOwned(owner) return self.owner==owner end
    Enum.TooltipDataType={Item=0,Unit=2,Object=4}
    WorldFrame=CreateFrame('Frame');mouseFocus=WorldFrame
    function GetMouseFoci() return {mouseFocus} end
    function GameTooltip:GetPrimaryTooltipInfo() return cursorInfo end
    C_TooltipInfo={GetWorldCursor=function() return cursorData end}
    function hover(name,requirement,kind)
        GameTooltip:Show();cursorInfo={getterName='GetWorldCursor'}
        cursorData={type=kind or 4,lines={{leftText=name},{leftText=requirement or 'Requires Herbalism'}}}
    end
    function discover() tracker.frame.scripts.OnUpdate(tracker.frame,0.21) end
    function clickNode() fire('GLOBAL_MOUSE_DOWN','RightButton') end
    function skillError(message) fire('UI_ERROR_MESSAGE',269,message or 'Requires Herbalism') end
    local create=CreateFrame
    function CreateFrame(...)
        local frame=create(...);frame.events={}
        if select(1,...)=='PlayerModel' then
            function frame:SetCreature() error('game objects are not creatures') end
            function frame:SetModel(id)
                local ancestor=self
                while ancestor do
                    assert(ancestor:IsShown(),'model requested under a hidden ancestor')
                    ancestor=ancestor.parent
                end
                self.requestedModel=id;self.modelLoads=(self.modelLoads or 0)+1
                self.cameraDistance=1 -- Simulate a camera reset during model replacement.
            end
            function frame:SetCamDistanceScale(value) self.cameraDistance=value end
            function frame:GetModelFileID() return self.loadedModel end
            function frame:ClearModel() self.loadedModel=nil;self.requestedModel=nil end
            function frame:SetRotation(value) self.rotation=value end
        end
        function frame:RegisterEvent(event) self.events[event]=true end
        function frame:RegisterUnitEvent(event,unit) self.events[event]=unit end
        return frame
    end
    function fire(event,...)
        for _,frame in ipairs(objects) do
            if frame.events and frame.events[event] and frame.scripts.OnEvent
                and (frame.events[event]==true or frame.events[event]==select(1,...)) then
                frame.scripts.OnEvent(frame,event,...)
            end
        end
    end
    function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
    function sent(name,guid,spell,unit) fire('UNIT_SPELLCAST_SENT',unit or 'player',name,guid or 'cast',spell or 2366) end
    function start(guid,spell,unit) fire('UNIT_SPELLCAST_START',unit or 'player',guid or 'cast',spell or 2366) end
    function finish(guid,spell,unit) fire('UNIT_SPELLCAST_SUCCEEDED',unit or 'player',guid or 'cast',spell or 2366) end
    function gather(name,guid,spell) sent(name,guid,spell);start(guid,spell);finish(guid,spell) end
    function entry(id) return journal.entries[id or 'herb:silverleaf'] end
    function points(id,map) return entry(id).locations[map or 37].points end
'''


def client(ui=False):
    lua = new_ui_client(MODULES)
    lua.execute(ENV)
    if ui:
        lua.execute('''
            settings={};ns.UIScale:Initialize(settings)
            shell=ns.CreateFieldbookShell()
            gathering=ns.InitializeGathering(shell)
            journal=gathering.journal;tracker=gathering.tracking
            ns.InitializeAtlas(shell)
            ns.RegisterFieldbookWishlistSections(shell)
        ''')
    else:
        lua.execute('''
            saved={};journal=ns.CreateGatheringJournal(saved)
            tracker=ns.CreateGatheringTracking(journal)
        ''')
    return lua


class GatheringTrackingTests(unittest.TestCase):
    def setUp(self):
        self.lua = client()

    def test_mouseover_opens_live_herbs_and_minerals_without_gathering(self):
        lua=client(ui=True)
        lua.execute(r'''
            hover('Silverleaf');assert(gathering:OpenAtMouseover())
            local book=gathering.frame
            assert(shell.active=='gathering' and book.noteID=='herb:silverleaf')
            assert(journal.entries['herb:silverleaf'].interactions==0 and positionReads==0)
            book.note:SetText('Unsaved field note');book.note.scripts.OnTextChanged(book.note)
            book.search:SetText('no matches');book.search.scripts.OnTextChanged(book.search)
            for i=1,25 do journal:Discover('herb',string.format('Herb %02d',i),100) end
            hover('Zinc Deposit','Requires Mining');assert(gathering:OpenAtMouseover())
            assert(book.noteID=='mineral:zinc deposit' and book.search:GetText()=='')
            local visible=false
            for _,row in ipairs(book.rows) do if row.id=='mineral:zinc deposit' and row:IsShown() then visible=true end end
            assert(visible,'Reveal entries past the first page')
            hover('Silverleaf');assert(gathering:OpenAtMouseover())
            assert(book.note:GetText()=='Unsaved field note','Navigation preserves drafts')
            mouseFocus=book.search;assert(not gathering:OpenAtMouseover())
            mouseFocus=WorldFrame;cursorInfo={getterName='GetItemByID'};assert(not gathering:OpenAtMouseover())
            cursorInfo=nil;cursorData=nil;assert(not gathering:OpenAtMouseover(),'Ignore fading tooltip cache')
            assert(positionReads==0 and journal.entries['mineral:zinc deposit'].completed==0)
        ''')

    def test_loot_requires_completed_gather_and_readable_object_source(self):
        self.lua.execute(r'''
            local quantity=2
            function GetNumLootItems() return 1 end
            local source='GameObject-0-1-2-3-1618-abc'
            function GetLootSourceInfo() return source,quantity end
            function GetLootSlotLink() return '|Hitem:765|h[Silverleaf]|h' end
            fire('LOOT_OPENED');assert(not next(journal.entries),'Unrelated loot cannot discover nodes')
            sent('Silverleaf');fire('UNIT_SPELLCAST_START','player','cast',2366)
            fire('LOOT_OPENED');assert(not next(journal.entries['herb:silverleaf'].loot or {}))
            fire('UNIT_SPELLCAST_SUCCEEDED','player','cast',2366)
            local e=journal.entries['herb:silverleaf']
            assert(e.loot[765].minQuantity==2 and e.loot[765].name=='Silverleaf')
            fire('LOOT_READY');fire('LOOT_OPENED');assert(e.loot[765].maxQuantity==2)
            quantity=3;fire('LOOT_SLOT_CHANGED');assert(e.loot[765].maxQuantity==3)
            source='Creature-0-1-2-3-123-abc';quantity=9
            fire('LOOT_OPENED');assert(e.loot[765].maxQuantity==3,'Corpse loot is excluded')
            source='GameObject-0-1-2-3-1618-abc';fire('LOOT_CLOSED')
            fire('LOOT_OPENED');assert(e.loot[765].maxQuantity==3,'Closed context cannot attach later loot')
            local reloaded=ns.CreateGatheringJournal(saved)
            assert(reloaded.entries[e.id].loot[765].maxQuantity==3)
        ''')

    def test_locations_scrollbar_only_appears_for_overflow(self):
        lua=client(ui=True)
        lua.execute("""
            journal:Discover('mineral','Copper Vein',100,'Elwynn')
            shell:ShowSection('gathering');local book=gathering.frame
            local scroll=book.zoneScroll
            scroll.GetVerticalScrollRange=function() return 999 end
            scroll:RefreshScrollBar()
            assert(not scroll.ScrollBar:IsShown() and not scroll.mouseWheel)
            scroll.ScrollBar:Show();scroll.ScrollBar.scripts.OnShow(scroll.ScrollBar)
            assert(not scroll.ScrollBar:IsShown(),'Template cannot restore an unnecessary bar')
            book.zoneChild:SetHeight(196);scroll:RefreshScrollBar()
            assert(scroll.ScrollBar:IsShown() and scroll.mouseWheel)
            scroll:SetVerticalScroll(32)
            book.zoneChild:SetHeight(164);scroll:RefreshScrollBar()
            assert(not scroll.ScrollBar:IsShown() and not scroll.mouseWheel)
            assert(scroll:GetVerticalScroll()==0)
        """)

    def test_observed_loot_panel_and_note_layout(self):
        lua=client(ui=True)
        lua.execute(r'''
            local id=journal:Discover('herb','Silverleaf',100,'Elwynn')
            journal:ObserveLoot(id,{[765]={name='Silverleaf',quantity=2}},100)
            ITEM_QUALITY_COLORS={[2]={r=.1,g=1,b=.1}}
            function GetItemInfo() return 'Silverleaf',nil,2,nil,nil,nil,nil,nil,nil,123 end
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book.note:GetWidth()==242 and book.lootScroll:GetWidth()==230)
            assert(book.lootRows[1].itemID==765 and book.lootRows[1].name:GetText()=='Silverleaf')
            assert(book.lootRows[1].name.textColor[1]==.1)
            book.lootRows[1].scripts.OnEnter(book.lootRows[1])
            assert(GameTooltip:IsOwned(book.lootRows[1]))
            assert(not book.noLoot:IsShown())
            local scroll=book.lootScroll
            -- Stale template ranges must not show controls for fitting content.
            scroll.GetVerticalScrollRange=function() return 999 end
            scroll:RefreshScrollBar()
            assert(not scroll.ScrollBar:IsShown() and not scroll.mouseWheel)
            scroll.ScrollBar:Show()
            scroll.ScrollBar.scripts.OnShow(scroll.ScrollBar)
            assert(not scroll.ScrollBar:IsShown(),'Template must not restore a needless bar')
            book.lootChild:SetHeight(186);scroll:RefreshScrollBar()
            assert(scroll.ScrollBar:IsShown() and scroll.mouseWheel)
            scroll:SetVerticalScroll(17)
            book.lootChild:SetHeight(169);scroll:RefreshScrollBar()
            assert(not scroll.ScrollBar:IsShown() and not scroll.mouseWheel)
            assert(scroll:GetVerticalScroll()==0,'Shrinking content resets the offset')

        ''')

    def test_ten_yard_node_cleanup_and_capture(self):
        self.lua.execute('''
            local reads=0
            C_Map.GetMapWorldSize=function() reads=reads+1;return 1000,2000 end
            local function record(kind,name,x,y,mapID,stamp)
                return journal:RecordInteraction(kind,name,{mapID=mapID or 37,name='Test',
                    point={x=x,y=y,seenAt=stamp or 10}},'Test',stamp or 10)
            end
            local id=record('herb','Peacebloom',1000,1000)
            record('herb','Peacebloom',1100,1000,37,20)
            record('herb','Peacebloom',1000,1050,37,30)
            assert(count(journal.entries[id].locations[37].points)==1,'Exactly ten yards merges on either axis')
            record('herb','Peacebloom',1101,1000)
            assert(count(journal.entries[id].locations[37].points)==2)
            local ore=record('mineral','Copper Vein',1000,1000)
            record('herb','Peacebloom',1000,1000,38)
            assert(count(journal.entries[ore].locations[37].points)==1)
            assert(count(journal.entries[id].locations[38].points)==1 and reads==2)
            local points=journal.entries[id].locations[37].points
            points[1+1050*10001+1000]={x=1050,y=1000,seenAt=40}
            local interactions=journal.entries[id].interactions
            journal=ns.CreateGatheringJournal(saved)
            points=journal.entries[id].locations[37].points
            assert(count(points)==2 and points[1+1000*10001+1000].seenAt==40)
            assert(journal.entries[id].interactions==interactions)
            C_Map.GetMapWorldSize=nil
            points[1+1050*10001+1000]={x=1050,y=1000,seenAt=50}
            journal=ns.CreateGatheringJournal(saved)
            assert(count(journal.entries[id].locations[37].points)==3,'Unknown dimensions must not delete evidence')
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            record('herb','Peacebloom',1050,1000)
            assert(count(journal.entries[id].locations[37].points)==2,'Retry cleanup when dimensions become available')
        ''')

    def test_passive_events_and_sent_only_never_record_or_sample(self):
        self.lua.execute('''
            for _,event in ipairs({'UPDATE_MOUSEOVER_UNIT','PLAYER_TARGET_CHANGED','CURSOR_CHANGED',
                'CHAT_MSG_LOOT','BAG_UPDATE','MINIMAP_UPDATE_TRACKING'}) do
                fire(event,'player','Silverleaf',2366)
                assert(not tracker.frame.events[event],'no passive collection hook')
            end
            sent('Silverleaf')
            assert(count(journal.entries)==0 and positionReads==0,'SENT is only transient context')
            fire('UNIT_SPELLCAST_STOP','player','cast',2366)
            assert(count(journal.entries)==0 and positionReads==0)
        ''')

    def test_first_click_before_poll_captures_tooltip_then_skill_rejection(self):
        self.lua.execute("""
            local callback
            TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)
                assert(kind==Enum.TooltipDataType.Object);callback=fn
            end}
            tracker=ns.CreateGatheringTracking(journal)
            hover('Peacebloom');callback(GameTooltip)
            assert(entry('herb:peacebloom').interactions==0 and positionReads==0)
            elapsed=elapsed+0.01;cursorInfo=nil;cursorData=nil;GameTooltip:Hide()
            clickNode();skillError();skillError()
            assert(entry('herb:peacebloom').interactions==1 and positionReads==1)
            assert(entry('herb:peacebloom').completed==0)
            hover('Copper Vein','Requires Mining');callback(GameTooltip)
            elapsed=elapsed+0.01;cursorInfo=nil;cursorData=nil;GameTooltip:Hide()
            clickNode();skillError('Requires Mining')
            assert(entry('mineral:copper vein').interactions==1 and positionReads==2)
        """)

    def test_mouseover_records_zones_without_profession_or_coordinates(self):
        self.lua.execute('''
            IsPlayerSpell=function() error('discovery must not require learned skills') end
            GetSkillLineInfo=function() error('discovery must not require professions') end
            hover('Silverleaf','|cffff0000Requires Herbalism|r');discover()
            assert(entry().name=='Silverleaf' and entry().kind=='herb')
            assert(entry().interactions==0 and entry().completed==0 and entry().lastSeen==0)
            assert(count(entry().locations)==1 and entry().zones.Elwynn and positionReads==0)
            assert(count(points())==0)
            local revision=journal.revision;now=now+5;px=0.8;discover()
            assert(journal.revision==revision and entry().firstSeen==now-5)
            mapID=52;mapName='Westfall';GetRealZoneText=function() return mapName end;discover()
            assert(entry().zones.Westfall and count(entry().locations)==2 and count(points(nil,52))==0)
            assert(#journal:List(nil,'Westfall')==1 and entry().interactions==0)
            assert(ns.CreateGatheringJournal(saved).entries['herb:silverleaf'].zones.Westfall)
            hover('Copper Vein','Requires Mining (1)');discover()
            assert(entry('mineral:copper vein').interactions==0 and positionReads==0)
        ''')

    def test_discovery_uses_live_objects_not_items_units_faded_tooltips_or_secret_text(self):
        self.lua.execute('''
            for _,kind in ipairs({0,2}) do hover('Silverleaf','Requires Herbalism',kind);discover() end
            hover('Quest Object','A tale about Herbalism');discover()
            hover('Chest','Requires Lockpicking');discover()
            hover('Silverleaf');GameTooltip:Hide();discover()
            hover('Silverleaf');cursorInfo.getterName='GetBagItem';discover()
            hover('Silverleaf');cursorData=nil;discover()
            hover(secret);discover()
            hover('Silverleaf',secret);discover()
            hover('Silverleaf');cursorData.type=secret;discover()
            hover('Silverleaf');cursorData.lines=secret;discover()
            hover('Silverleaf');cursorData.lines[2]=secret;discover()
            hover('Conflicting object');cursorData.lines[3]={leftText='Requires Mining'};discover()
            assert(count(journal.entries)==0 and positionReads==0)
        ''')

    def test_skill_less_right_click_records_only_on_matching_skill_error(self):
        self.lua.execute('''
            hover('Silverleaf');discover();clickNode()
            assert(entry().interactions==0 and positionReads==0,'click alone is not a gathering interaction')
            skillError();skillError()
            assert(entry().interactions==1 and entry().completed==0 and count(points())==1)
            assert(positionReads==1 and select(2,next(points())).approximate)
            hover('Copper Vein','Requires Mining (1)');clickNode();skillError('Requires Mining 1')
            assert(entry('mineral:copper vein').interactions==1 and entry('mineral:copper vein').completed==0)
            assert(count(points('mineral:copper vein'))==1)
        ''')

    def test_error_rejects_unrelated_errors_ui_clicks_wrong_or_stale_objects(self):
        self.lua.execute('''
            hover('Silverleaf');discover();skillError('You are too far away.')
            assert(entry().interactions==0,'an unrelated error while hovering is insufficient')
            mouseFocus=CreateFrame('Button');clickNode();skillError();mouseFocus=WorldFrame
            fire('GLOBAL_MOUSE_DOWN','LeftButton');skillError()
            clickNode();elapsed=elapsed+3;GameTooltip:Hide();cursorData=nil;skillError();hover('Silverleaf')
            clickNode();skillError('You are too far away.');skillError()
            clickNode();skillError('Requires Mining')
            clickNode();hover('Peacebloom');skillError()
            hover('Silverleaf');clickNode();cursorInfo.getterName='GetBagItem';skillError()
            hover('Silverleaf');clickNode();skillError(secret)
            clickNode();fire('ZONE_CHANGED_NEW_AREA');skillError()
            assert(entry().interactions==0 and positionReads==0)
        ''')

    def test_matching_error_with_live_node_works_without_global_click_event(self):
        self.lua.execute('''
            tracker.frame.events.GLOBAL_MOUSE_DOWN=nil
            hover('Peacebloom');discover()
            assert(entry('herb:peacebloom').interactions==0 and positionReads==0)
            skillError();skillError()
            local peace=entry('herb:peacebloom')
            local point=select(2,next(points('herb:peacebloom')))
            assert(peace.interactions==1 and peace.completed==0 and point.x==2000 and point.y==3000)
            assert(point.approximate and positionReads==1)
            elapsed=elapsed+1;px=0.8;py=0.9;skillError()
            assert(peace.interactions==2 and count(points('herb:peacebloom'))==2)
            hover('Copper Vein','Requires Mining');skillError('Requires Mining')
            assert(entry('mineral:copper vein').interactions==1 and entry('mineral:copper vein').completed==0)
            tracker.frame.events.GLOBAL_MOUSE_DOWN=true
            elapsed=elapsed+1;clickNode();skillError('Requires Mining')
            elapsed=elapsed+3;skillError('Requires Mining')
            assert(entry('mineral:copper vein').interactions==3,'an old mouse click cannot disable later key interactions')
        ''')

    def test_world_focus_accepts_empty_or_root_only_but_rejects_ui_controls(self):
        self.lua.execute('''
            for i,foci in ipairs({{}, {UIParent}, {UIParent,WorldFrame}}) do
                GetMouseFoci=function() return foci end
                hover('Peacebloom');elapsed=elapsed+1;clickNode();skillError()
                assert(entry('herb:peacebloom').interactions==i)
            end
            local control=CreateFrame('Button')
            for _,foci in ipairs({{control}, {WorldFrame,control}, {secret}}) do
                GetMouseFoci=function() return foci end
                elapsed=elapsed+3;skillError()
                assert(entry('herb:peacebloom').interactions==3)
                clickNode();skillError()
                assert(entry('herb:peacebloom').interactions==3)
            end
        ''')

    def test_tooltip_cleared_before_mouse_down_uses_recent_identity_without_hover_sampling(self):
        self.lua.execute('''
            hover('Peacebloom');discover();elapsed=elapsed+0.1
            cursorInfo=nil;cursorData=nil -- Fading tooltip with handler data already cleared.
            clickNode();assert(positionReads==0)
            skillError()
            assert(entry('herb:peacebloom').interactions==1 and positionReads==1)
            hover('Copper Vein','Requires Mining');discover();elapsed=elapsed+0.1
            GameTooltip:Hide();cursorData=nil;clickNode();skillError('Requires Mining')
            assert(entry('mineral:copper vein').interactions==1)
            assert(entry('mineral:copper vein').completed==0 and positionReads==2)
        ''')

    def test_cached_hover_cannot_record_without_click_or_after_expiry_replacement_or_zone_change(self):
        self.lua.execute('''
            hover('Peacebloom');discover();GameTooltip:Hide();cursorData=nil;skillError()
            assert(entry('herb:peacebloom').interactions==0)
            elapsed=elapsed+1;clickNode();skillError()
            hover('Peacebloom');discover();cursorInfo.getterName='GetBagItem';clickNode();skillError()
            hover('Peacebloom');discover();hover('Unrelated object','Requires Lockpicking');clickNode();skillError()
            hover('Peacebloom');discover();fire('ZONE_CHANGED_NEW_AREA')
            GameTooltip:Hide();cursorData=nil;clickNode();skillError()
            assert(entry('herb:peacebloom').interactions==0 and positionReads==0)
        ''')

    def test_error_fallback_never_uses_nonworld_or_unreadable_identity_or_unrelated_cast(self):
        self.lua.execute('''
            for _,kind in ipairs({0,2}) do hover('Peacebloom','Requires Herbalism',kind);skillError() end
            hover('Peacebloom');cursorInfo.getterName='GetBagItem';skillError()
            hover('Peacebloom');cursorData.lines[1].leftText=secret;skillError()
            hover('Peacebloom');skillError('Requires Mining')
            hover('Peacebloom');sent('Other spell','unrelated',2657);skillError()
            assert(count(journal.entries)==0 and positionReads==0)
        ''')

    def test_error_fallback_and_cast_paths_share_one_interaction(self):
        self.lua.execute('''
            hover('Peacebloom');skillError();sent('Peacebloom');start();finish()
            assert(entry('herb:peacebloom').interactions==1 and positionReads==1)
            hover('Silverleaf');sent('Silverleaf','new');start('new');skillError();finish('new')
            assert(entry().interactions==1 and positionReads==2)
        ''')

    def test_skill_error_after_tooltip_dismissal_records_captured_node(self):
        self.lua.execute('''
            hover('Peacebloom');discover();clickNode()
            GameTooltip:Hide();cursorData=nil;elapsed=elapsed+0.1;skillError();skillError()
            local peace=entry('herb:peacebloom')
            assert(peace.interactions==1 and peace.completed==0 and peace.modelFileID==219481)
            local point=select(2,next(points('herb:peacebloom')))
            assert(point.x==2000 and point.y==3000 and positionReads==1)
            px=0.8;sent('Peacebloom');start();finish()
            assert(peace.interactions==1 and positionReads==1,'one click/cast must not sample twice')
        ''')

    def test_models_use_observed_object_id_for_localized_names_and_validate_reload(self):
        self.lua.execute('''
            hover('Friedensblume');cursorData.id=1618;discover()
            assert(entry('herb:friedensblume').modelFileID==219481)
            saved.entries['herb:friedensblume'].modelFileID=999999
            journal=ns.CreateGatheringJournal(saved)
            assert(entry('herb:friedensblume').modelFileID==nil)
            hover('Unknown plant');cursorData.id=secret;discover()
            assert(entry('herb:unknown plant').modelFileID==nil)
            hover('Unknown rock','Requires Mining');cursorData.id=1618;discover()
            assert(entry('mineral:unknown rock').modelFileID==nil)
        ''')

    def test_click_cast_and_error_share_one_interaction_and_localization_works(self):
        self.lua.execute('''
            hover('Silverleaf');clickNode();sent('Silverleaf');start();skillError();finish()
            assert(entry().interactions==1 and entry().completed==1 and positionReads==1)
            function GetLocale() return 'deDE' end
            spellNames[2366]='Kräutersammeln';spellNames[9134]='Kräuterkunde';spellNames[2575]='Bergbau'
            ERR_USE_LOCKED_WITH_SPELL_S='Benötigt %s'
            ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI='Benötigt %1$s (%2$d)'
            hover('Silberblatt','Benötigt Kräuterkunde (25)');discover()
            assert(entry('herb:silberblatt').interactions==0)
            clickNode();skillError('Benötigt Kräuterkunde (25)')
            assert(entry('herb:silberblatt').interactions==1)
            hover('Kupfervorkommen','Benötigt Bergbau');clickNode();skillError('Benötigt Bergbau')
            assert(entry('mineral:kupfervorkommen').interactions==1)
        ''')

    def test_start_is_an_interaction_success_is_deduplicated_and_does_not_resample(self):
        self.lua.execute('''
            sent('Silverleaf');start()
            assert(entry().interactions==1 and entry().completed==0 and count(points())==1)
            local p=select(2,next(points()))
            assert(p.x==2000 and p.y==3000 and p.approximate and p.seenAt==now)
            start();sent('Silverleaf');start()
            px=0.8;py=0.9
            fire('UNIT_SPELLCAST_STOP','player','cast',2366);finish();finish()
            sent('Silverleaf');start();finish()
            assert(entry().interactions==1 and entry().completed==1 and count(points())==1)
            assert(positionReads==1,'late success cannot move the interaction marker')
        ''')

    def test_minerals_instant_gathers_localized_ranks_and_identity(self):
        self.lua.execute('''
            sent('Copper Vein','copper',2575);finish('copper',2575)
            assert(entry('mineral:copper vein').completed==1 and entry('mineral:copper vein').kind=='mineral')
            spellNames[2366]='Kräutersammeln';spellNames[2368]='Kräutersammeln'
            gather('Silberblatt','herb',2368)
            assert(entry('herb:silberblatt').completed==1)
            gather(' COPPER VEIN ','rank',2576)
            assert(entry('mineral:copper vein').interactions==2 and count(journal.entries)==2)
            gather('Copper Vein','different kind',2366)
            assert(count(journal.entries)==3,'same names in different categories remain distinct')
        ''')

    def test_failed_before_start_ignored_started_then_interrupted_retains_only_interaction(self):
        self.lua.execute('''
            sent('Silverleaf','failed')
            fire('UNIT_SPELLCAST_FAILED','player','failed',2366);start('failed');finish('failed')
            assert(count(journal.entries)==0)
            sent('Silverleaf','interrupted');start('interrupted')
            fire('UNIT_SPELLCAST_INTERRUPTED','player','interrupted',2366);finish('interrupted')
            assert(entry().interactions==1 and entry().completed==0)
            sent('Peacebloom','quiet');fire('UNIT_SPELLCAST_FAILED_QUIET','player','quiet',2366);finish('quiet')
            assert(count(journal.entries)==1)
        ''')

    def test_wrong_unit_spell_guid_and_unrelated_professions(self):
        self.lua.execute('''
            for _,spell in ipairs({8613,2657,2580,2383,1}) do gather('Silverleaf','unrelated'..spell,spell) end
            sent('Silverleaf','other',2366,'party1');start('other',2366,'party1');finish('other',2366,'party1')
            sent('Silverleaf','mine');start('wrong');finish('mine',2575)
            assert(count(journal.entries)==0 and positionReads==0)
            sent('Other spell','new',2657);finish('mine')
            assert(count(journal.entries)==0,'new player cast invalidates older context')
        ''')

    def test_stale_context_zoning_and_success_without_sent(self):
        self.lua.execute('''
            start();finish();assert(count(journal.entries)==0)
            sent('Silverleaf','expired');elapsed=41;start('expired');finish('expired')
            sent('Silverleaf','zone');fire('ZONE_CHANGED_NEW_AREA');finish('zone')
            sent('Silverleaf','world');fire('PLAYER_ENTERING_WORLD');start('world')
            assert(count(journal.entries)==0 and positionReads==0)
        ''')

    def test_secrets_invalid_names_and_unreadable_map_fail_closed(self):
        self.lua.execute('''
            secret=setmetatable(secret,{__tostring=function() error('formatted secret') end,
                __index=function() error('indexed secret') end,__eq=function() error('compared secret') end})
            for _,name in ipairs({secret,'','  ','Bad|name','Bad\\nname',string.rep('x',161)}) do
                sent(name);start();finish()
            end
            tracker:OnEvent('UNIT_SPELLCAST_SENT',secret,'Silverleaf','secret',2366)
            sent('Silverleaf','secretID',secret);start('secretID',secret)
            sent('Silverleaf',secret);start(secret);finish(secret)
            assert(count(journal.entries)==0 and positionReads==0)
            px=secret;gather('Silverleaf','no position')
            assert(entry().completed==1 and count(entry().locations)==0 and entry().zones.Elwynn)
            mapID=secret;gather('Silverleaf','no map')
            assert(entry().completed==2 and count(entry().locations)==0)
            function GetTime() return secret end
            sent('Peacebloom','no clock');start('no clock');finish('no clock')
            assert(count(journal.entries)==1)
        ''')

    def test_bounded_history_duplicate_coordinates_multiple_zones_and_reload(self):
        self.lua.execute('''
            gather('Silverleaf','one');gather('Silverleaf','two')
            assert(entry().interactions==2 and count(points())==1)
            for i=1,270 do px=i/300;now=now+1;gather('Silverleaf','point'..i) end
            assert(count(points())==256)
            for i=1,70 do mapID=100+i;mapName='Zone '..i;gather('Silverleaf','map'..i) end
            assert(count(entry().locations)==64)
            journal:SetNote('herb:silverleaf','Near the old bridge')
            journal:SetListSort('completed',true);journal:SetLocationMapBrightness(0.8)
            local old=entry();journal=ns.CreateGatheringJournal(saved)
            assert(entry()==old and entry().note=='Near the old bridge' and count(points())==256)
            assert(journal:GetListSort()=='completed' and select(2,journal:GetListSort()))
            assert(journal:GetLocationMapBrightness()==0.8)
        ''')

    def test_list_filters_literal_search_and_all_sort_orders(self):
        self.lua.execute('''
            gather('Silverleaf','silver');now=now+10
            gather('Peacebloom','peace');gather('Copper Vein','copper',2575)
            mapID=52;mapName='Westfall';GetRealZoneText=function() return mapName end
            gather('Copper Vein','copper2',2575)
            assert(#journal:List('herb')==2 and #journal:List('mineral')==1)
            assert(#journal:List(nil,'westfall')==1 and #journal:List(nil,'mining')==1)
            assert(#journal:List(nil,'[')==0,'search is literal, never a Lua pattern')
            assert(#journal:List(nil,'','S')==1 and #journal:List(nil,'',nil,{Westfall=true})==1)
            for _,field in ipairs({'name','kind','interactions','completed','firstSeen','lastSeen'}) do
                journal:SetListSort(field,false);local ascending=journal:List()
                journal:SetListSort(field,true);local descending=journal:List()
                assert(ascending[1][field]<=ascending[3][field])
                assert(descending[1][field]>=descending[3][field])
            end
        ''')


class GatheringUITests(unittest.TestCase):
    def test_bruiseweed_uses_verified_scene_and_clipping_without_debug_command(self):
        lua=client(ui=True)
        lua.execute('''
            gather('Bruiseweed','bruise');shell:ShowSection('gathering')
            local book=gathering.frame;local scene=book.activeModel;local actor=scene.actor
            assert(actor and actor.requestedModel==219440 and scene==book.model)
            actor.loadedModel=219440;actor.bounds={-1,-1,-2,1,1,3}
            scene:UpdateFraming(.1)
            assert(scene.nearClip==.01 and scene.farClip==10000 and actor:IsShown())
            assert(book.modelCaption:GetText()=='')
            shell:Hide();shell:Toggle()
            assert(actor.requestedModel==219440 and not actor.loadedModel)
            scene:UpdateFraming(5)
            assert(not actor:IsShown() and book.modelCaption:GetText()=='Model unavailable')
        ''')

    def test_model_report_reads_live_state_without_reloading(self):
        lua = client(ui=True)
        lua.execute('''
            gather('Copper Vein','copper',2575);shell:ShowSection('gathering')
            local book=gathering.frame;local actor=book.mineralModel.actor
            actor.loadedModel=219514;actor.bounds={-2,-2,-8,2,2,-4}
            book.mineralModel:UpdateFraming(.1)
            actor.SetModelByFileID=function() error('Report must not reload models') end
            function actor:GetAlpha() return secret end
            function actor:GetPosition() error('unavailable on this client') end
            local lines={}
            gathering:ReportModel(function(line) lines[#lines+1]=line end)
            local report=table.concat(lines,'\\n')
            assert(report:find('Actor IsLoaded: true',1,true))
            assert(report:find('Actor GetModelFileID: 219514',1,true))
            assert(report:find('Actor GetAlpha: RESTRICTED',1,true))
            assert(report:find('Actor GetPosition: API error',1,true))
            assert(report:find('Actor GetActiveBoundingBox: -2, -2, -8, 2, 2, -4',1,true))
            assert(actor:IsShown() and book.modelCaption:GetText()=='')
        ''')

    def setUp(self):
        self.lua = client(ui=True)

    def test_model_loads_after_page_is_visible_and_reloads_on_tab_or_book_return(self):
        self.lua.execute('''
            gather('Peacebloom','peace')
            shell:EnsureSection('gathering');local book=gathering.frame
            assert(not book:IsShown() and not book.model.actor.modelLoads,'building a hidden section must not load its model')
            shell:ShowSection('gathering')
            assert(book.model.actor.modelLoads==1 and book.model.actor.requestedModel==219481)
            assert(book.model:GetFrameLevel()>book.modelBorder:GetFrameLevel())
            book.model.actor.loadedModel=219481;book.model.actor.bounds={-1,-1,0,1,1,2};book.model:UpdateFraming(.1)
            book.note:SetText('Keep my draft');book.search:SetText('Peace')
            shell:ShowSection('atlas');book.model:ClearModel() -- Native render state lost while hidden.
            local loads=book.model.actor.modelLoads
            gathering:Refresh();assert(book.model.actor.modelLoads==loads)
            shell:ShowSection('gathering')
            assert(book.model.actor.modelLoads==loads+1 and book.model.actor.requestedModel==219481 and book.model:IsShown())
            assert(book.note:GetText()=='Keep my draft' and book.search:GetText()=='Peace')
            assert(book.model.actor.centered[3])
            shell:Hide();book.model:ClearModel();gathering:Refresh()
            assert(book.model.actor.modelLoads==loads+1,'hidden refresh must not reload')
            shell:Toggle()
            assert(book.model.actor.modelLoads==loads+2 and book.model.actor.requestedModel==219481)
            local reopened=book.model.actor.modelLoads;gathering:Refresh()
            assert(book.model.actor.modelLoads==reopened,'ordinary updates must not continually reload models')
        ''')

    def test_reopening_retries_failed_model_without_stale_preview(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575);gather('Peacebloom','peace')
            shell:ShowSection('gathering');local book=gathering.frame
            local load=book.model.SetModel
            book.model.SetModel=function() error('temporary native model failure') end
            book.rows[2].scripts.OnClick(book.rows[2])
            assert(not book.model:IsShown() and not book.model.actor.requestedModel)
            assert(book.modelCaption:GetText()=='Model unavailable')
            book.model.SetModel=load;shell:ShowSection('atlas');shell:ShowSection('gathering')
            assert(book.title:GetText()=='Peacebloom • Herb' and book.model.actor.requestedModel==219481 and book.model:IsShown())
        ''')

    def test_mineral_framing_is_origin_independent_and_fits_rotation(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575)
            shell:EnsureSection('gathering');local book=gathering.frame
            local scene=book.mineralModel;local actor=scene.actor
            assert(not actor.requestedModel,'Do not load beneath a hidden book')
            shell:ShowSection('gathering')
            assert(actor.requestedModel==219514 and not book.model:IsShown())
            assert(actor.centered[1] and actor.centered[2] and actor.centered[3] and not actor.collisionBounds)
            local distance
            for _,offset in ipairs({-100,-7,0,5,100}) do
                scene:ClearModel();scene:SetModel(219514)
                actor.loadedModel=219514
                actor.bounds={-2,-3,offset,2,3,offset+4}
                scene:UpdateFraming(.1)
                assert(actor:IsShown() and book.modelCaption:GetText()=='')
                local d=scene.cameraPosition[1]
                assert(not distance or math.abs(distance-d)<1e-10,'Origin must not change framing')
                distance=d
                -- Project each centered corner over a complete turn. The
                -- perspective silhouette must stay inside the viewport.
                for angle=0,360,5 do
                    local a=math.rad(angle)
                    for _,x in ipairs({-2,2}) do for _,y in ipairs({-3,3}) do for _,z in ipairs({-2,2}) do
                        local depth=d-(x*math.cos(a)-y*math.sin(a))
                        local horizontal=x*math.sin(a)+y*math.cos(a)
                        assert(depth>scene.nearClip and depth<scene.farClip)
                        assert(math.abs(z/depth)<math.tan(math.rad(15)))
                        assert(math.abs(horizontal/depth)<math.tan(math.rad(15))*203/164)
                    end end end
                end
            end
            cursorX=100;GetCursorPosition=function() return cursorX,0 end
            scene.scripts.OnMouseDown();cursorX=120;scene.scripts.OnUpdate(scene,.1)
            assert(actor.yaw>0);scene.scripts.OnMouseUp()
            shell:Hide();shell:Toggle();assert(actor.requestedModel==219514)
            assert(actor:IsShown() and not actor.loadedModel,'New load starts visible with old geometry cleared')
        ''')

    def test_mineral_bounds_vectors_invalid_data_and_stale_loads(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575);gather('Dark Iron Deposit','dark',2575)
            shell:ShowSection('gathering');local book=gathering.frame
            local scene=book.mineralModel;local actor=scene.actor
            book.rows[2].scripts.OnClick(book.rows[2])
            assert(actor.requestedModel==189103)
            actor.loadedModel=219514;actor.bounds={-2,-2,-2,2,2,2}
            scene:UpdateFraming(.1);assert(book.modelCaption:GetText()=='Loading model…','Ignore stale Copper completion')
            actor.loadedModel=189103
            actor.bounds={{GetXYZ=function() return -2,-2,-8 end},{GetXYZ=function() return 2,2,-4 end}}
            scene:UpdateFraming(.1);assert(actor:IsShown())
            for _,bounds in ipairs({{}, {0,0,0,0,0,0}, {0,0,0,1,1,math.huge},
                {secret,0,0,1,1,1}, {0,0,0,1,1,0/0}, {2,0,0,1,1,1}}) do
                scene:ClearModel();scene:SetModel(189103);actor.loadedModel=189103;actor.bounds=bounds
                scene:UpdateFraming(5)
                assert(not actor:IsShown() and book.modelCaption:GetText()=='Model unavailable')
            end
            actor.SetModelByFileID=function() return false end
            shell:Hide();shell:Toggle()
            assert(not scene:IsShown() and book.modelCaption:GetText()=='Model unavailable')
        ''')

    def test_hover_locations_and_object_previews_match_bestiary_panel_and_rotate(self):
        self.lua.execute('''
            hover('Peacebloom');discover();shell:ShowSection('gathering')
            local book=gathering.frame
            assert(book.model:GetWidth()==223 and book.model:GetHeight()==164)
            assert(book.modelBorder:GetWidth()==227 and book.modelBorder:GetHeight()==168)
            assert(book.model.point[2]==346 and book.model.point[3]==-135)
            assert(book.model.actor.requestedModel==219481 and book.model:IsShown())
            assert(book.model.actor.centered[3])
            assert(book.zoneRows[1]:GetText()=='Elwynn  •  0 mapped positions')
            assert(positionReads==0 and entry('herb:peacebloom').interactions==0)
            book.model.actor.loadedModel=219481;book.model.actor.bounds={-1,-1,0,1,1,2};book.model:UpdateFraming(.1)
            assert(book.model.cameraPosition[1]>0 and book.model.nearClip==.01 and book.model.farClip==10000)
            assert(book.modelCaption:GetText()=='')
            local loads=book.model.actor.modelLoads;gathering:Refresh();assert(book.model.actor.modelLoads==loads)
            cursorX=100;GetCursorPosition=function() return cursorX,0 end
            book.model.scripts.OnMouseDown();cursorX=120;book.model.scripts.OnUpdate(book.model)
            assert(book.model.actor.yaw>0)
            book.model.scripts.OnMouseUp();local rotation=book.model.actor.yaw
            cursorX=140;book.model.scripts.OnUpdate(book.model);assert(book.model.actor.yaw==rotation)
            hover('Copper Vein','Requires Mining');discover();gathering:Refresh()
            book.rows[1].scripts.OnClick(book.rows[1]);assert(book.mineralModel.actor.requestedModel==219514)
            assert(not book.model:IsShown() and book.mineralModel:IsShown())
            book.model.actor.loadedModel=219481;book.model.actor.bounds={-1,-1,0,1,1,2};book.model:UpdateFraming(.1)
            assert(book.modelCaption:GetText()=='Loading model…','stale load must not clear the caption')
            hover('Unknown herb');discover();gathering:Refresh()
            book.rows[3].scripts.OnClick(book.rows[3])
            assert(not book.model:IsShown() and not book.model.actor.requestedModel)
            assert(book.modelCaption:GetText()=='Model unavailable')
        ''')

    def test_shared_panes_and_dropdown_filters(self):
        self.lua.execute("""
            hover('Peacebloom');discover();shell:ShowSection('gathering')
            local b=gathering.frame
            assert(b.spine.point[2]==306 and b.rows[1].point[2]==42 and b.rows[1]:GetWidth()==236)
            assert(b.resourceScrollBar.point[2]==282)
            assert(b.title.points[1][4]==342 and b.modelBorder.point[2]+b.modelBorder:GetWidth()==571)
            assert(b.noteScroll.parent.point[2]+b.noteScroll.parent:GetWidth()==632)
            assert(b.lootScroll.parent.point[2]==646)
            for _,control in pairs(b.typeButtons) do assert(control.parent==b.listFilterMenu) end
            assert(b.locationsButton.parent==b.listFilterMenu and b.clearFilters.parent==b.listFilterMenu)
            b.listFilterButton.scripts.OnClick();assert(b.listFilterMenu:IsShown())
            b.typeButtons.herb.scripts.OnClick();assert(b.typeButtons.herb.afbSelected and b.listFilterMenu:IsShown())
            b.locationsButton.scripts.OnEnter();assert(b.locationFrame:IsShown() and b.locationFrame.parent==b.listFilterMenu)
            function b.locationFrame:IsMouseOver() return true end
            b.listFilterMenu.scripts.OnEvent(b.listFilterMenu,'GLOBAL_MOUSE_DOWN')
            assert(b.listFilterMenu:IsShown())
            function b.locationFrame:IsMouseOver() return false end
            b.listFilterMenu.scripts.OnEvent(b.listFilterMenu,'GLOBAL_MOUSE_DOWN')
            assert(not b.listFilterMenu:IsShown() and not b.locationFrame:IsShown())
            b.listFilterButton.scripts.OnClick();b.listFilterButton.scripts.OnClick(b.listFilterButton,'RightButton')
            assert(b.typeButtons.all.afbSelected and b.search:GetText()=='')
            shell:Hide();assert(not b.listFilterMenu:IsShown())
        """)

    def test_lazy_empty_page_opens_without_discovery_and_has_bestiary_dimensions(self):
        self.lua.execute('''
            assert(not shell:GetFrame() and not gathering.frame)
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book:GetWidth()==960 and book:GetHeight()==740 and #book.rows==18)
            assert(book.parent==shell:GetFrame() and book:GetScale()==1)
            assert(book.rows[1]:GetWidth()==236 and book.rows[1]:GetHeight()==26)
            assert(book.rows[1].point[2]==42 and book.rows[1].point[3]==-140)
            assert(book.rows[18].point[3]==-599)
            assert(book.search:GetWidth()==168 and book.search.point[2]==70 and book.search.point[3]==-110)
            assert(book.resourceScrollBar:GetHeight()==454 and book.resourceScrollBar:GetWidth()==14)
            assert(book.empty:IsShown() and not book.details:IsShown() and not book.locations.enabled)
            assert(not book.previous and not book.next and count(journal.entries)==0)
            assert(positionReads==0,'opening the journal never samples locations')
        ''')

    def test_search_categories_sort_scroll_and_cycle(self):
        self.lua.execute('''
            for i=1,24 do gather(string.format('Herb %02d',i),'herb'..i) end
            gather('Copper Vein','copper',2575)
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book.resourceScrollBar:IsShown() and book.rows[1].id=='mineral:copper vein')
            book.typeButtons.herb.scripts.OnClick();assert(book.rows[1].id=='herb:herb 01')
            book.rows[1].scripts.OnClick(book.rows[1])
            book.rows[1].scripts.OnMouseWheel(book.rows[1],-1);assert(book.rows[1].id=='herb:herb 04')
            book.rows[1].scripts.OnClick(book.rows[1]);assert(book.title:GetText()=='Herb 04 • Herb' and book.resourceScrollBar:GetValue()==3)
            book.search:SetText('Herb 2');assert(book.rows[1].id=='herb:herb 20' and not book.resourceScrollBar:IsShown())
            book.searchClear.scripts.OnClick();assert(book.search:GetText()=='')
            assert(book.indexButton==nil and book.letterButtons==nil,'Compendium uses filters instead of an A-Z index')
            book.clearFilters.scripts.OnClick();book.typeButtons.mineral.scripts.OnClick()
            assert(book.rows[1].id=='mineral:copper vein' and not book.rows[2]:IsShown())
            book.clearFilters.scripts.OnClick();book.sortButton.scripts.OnClick()
            book.sortChoices[8].control.scripts.OnClick()
            assert(book.rows[1].id=='herb:herb 24' and select(2,journal:GetListSort()))
            book.search:SetText('no such resource');assert(book.noMatches:IsShown() and not book.next)
        ''')

    def test_notes_drafts_selection_and_filters_survive_switching_and_background_interactions(self):
        self.lua.execute('''
            gather('Silverleaf','silver');gather('Peacebloom','peace')
            shell:ShowSection('gathering');local book=gathering.frame
            book.rows[2].scripts.OnClick(book.rows[2]);book.search:SetText('Silver')
            book.note:SetText('Unfinished note');assert(book.saveNote.enabled)
            book.sortButton.scripts.OnClick();book.locations.scripts.OnClick();book.locationsButton.scripts.OnClick()
            shell:ShowSection('atlas')
            assert(not book.sortMenu:IsShown() and not book.locationFrame:IsShown() and not gathering.locations:IsShown())
            gather('Copper Vein','hidden',2575)
            shell:ShowSection('gathering')
            assert(book.title:GetText()=='Silverleaf • Herb' and book.search:GetText()=='Silver')
            assert(book.note:GetText()=='Unfinished note' and entry().note=='')
            book.saveNote.scripts.OnClick();assert(entry().note=='Unfinished note' and not book.saveNote.enabled)
            book.search:SetText('');book.rows[1].scripts.OnClick(book.rows[1]);book.rows[3].scripts.OnClick(book.rows[3])
            assert(book.note:GetText()=='Unfinished note')
        ''')

    def test_location_filter_per_resource_map_brightness_and_unavailable_map(self):
        self.lua.execute('''
            gather('Silverleaf','silver');mapID=52;mapName='Westfall'
            GetRealZoneText=function() return mapName end
            gather('Copper Vein','copper',2575)
            shell:ShowSection('gathering');local book=gathering.frame
            book.locationsButton.scripts.OnClick()
            local filter=book.locationFrame
            assert(#filter.rows==2)
            filter.rows[2]:SetChecked(true);filter.rows[2].scripts.OnClick(filter.rows[2])
            assert(book.rows[1].id=='mineral:copper vein' and not book.rows[2]:IsShown())
            book.locations.scripts.OnClick();local map=gathering.locations:GetFrame()
            assert(map.creature:GetText()=='Copper Vein' and map.zoneName:GetText()=='Westfall')
            assert(map.status:GetText():find('1 interaction positions',1,true))
            map.brightness.scripts.OnValueChanged(map.brightness,0.85);assert(journal:GetLocationMapBrightness()==0.85)
            local revision=journal.revision
            px=0.9;map.scripts.OnUpdate(map,1)
            assert(journal.revision==revision and count(points('mineral:copper vein',52))==1)
            C_Map.GetMapArtLayers=function() return nil end
            gathering.locations:Open('herb:silverleaf',37)
            assert(map.creature:GetText()=='Silverleaf' and map.empty:IsShown())
            assert(map.empty:GetText()=='Zone map unavailable.')
        ''')

    def test_node_map_draws_only_small_round_discrete_samples(self):
        self.lua.execute('''
            ns.LocationGeometry={Build=function() error('node data must never be triangulated') end}
            gather('Silverleaf','one');px=0.21;gather('Silverleaf','two')
            py=0.31;gather('Silverleaf','three')
            gathering.locations:Open('herb:silverleaf',37)
            local map=gathering.locations:GetFrame()
            local markers={}
            for _,object in ipairs(objects) do
                if object.parent==map.map and object.location and object:IsShown() then markers[#markers+1]=object end
            end
            assert(#markers==3 and count(points())==3)
            for _,dot in ipairs(markers) do
                assert(dot:GetWidth()==6 and dot:GetHeight()==6)
                assert(not rawget(dot.border,"mask") and not rawget(dot.texture,"mask"))
                assert(dot.texture.texture:find('GatheringDot.tga',1,true))
                assert(dot.point[4]==dot.location.x/10000*map.map:GetWidth())
                assert(dot.point[5]==-dot.location.y/10000*map.map:GetHeight())
            end
            local revision=journal.revision;px=0.8;map.scripts.OnUpdate(map,1)
            assert(journal.revision==revision and count(points())==3)
        ''')

    def test_locations_overlay_stays_in_right_pane_and_follows_selection(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575);gather('Silverleaf','silver')
            shell:ShowSection('gathering');local book=gathering.frame
            book.locations.scripts.OnClick();local overlay=gathering.locations:GetFrame()
            assert(overlay.parent==book and overlay:GetScale()==1)
            assert(overlay.point[1]=='TOPLEFT' and overlay.point[2]==book)
            assert(overlay.point[4]==333 and overlay.point[5]==-87)
            assert(333+overlay:GetWidth()==936 and 87+overlay:GetHeight()==714)
            assert(overlay.point[4]-309==960-overlay.point[4]-overlay:GetWidth())
            for _,object in ipairs(objects) do
                assert(object.parent~=overlay or object.template~='UIPanelCloseButton')
            end
            assert(overlay:GetFrameLevel()>book.details:GetFrameLevel())
            assert(not overlay.scripts.OnDragStart and not overlay.afbAnchorRule)
            assert(book.title.points[1][1]=='TOPLEFT' and book.title.points[1][4]==342)
            assert(book.title.points[1][5]==book.locations.point[3])
            assert(book.title.point[1]=='BOTTOMRIGHT' and book.title.point[2]==book.locations)
            assert(book.title.point[3]=='BOTTOMLEFT' and book.title.point[4]==-18 and book.title.point[5]==0)
            assert(overlay.map:GetWidth()<=overlay:GetWidth()-36)
            assert(overlay.map:GetHeight()<=372)
            book.rows[2].scripts.OnClick(book.rows[2])
            assert(overlay:IsShown() and overlay.creature:GetText()=='Silverleaf')
            assert(book.title:GetText()=='Silverleaf • Herb')
            book.locations.scripts.OnClick();assert(not overlay:IsShown())
            book.locations.scripts.OnClick();assert(overlay:IsShown())
            shell:ShowSection('atlas');assert(not overlay:IsShown())
        ''')

    def test_field_notes_focus_save_clear_and_reload_independently_per_resource(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575);gather('Peacebloom','peace')
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book.title:GetText()=='Copper Vein • Mineral' and book.note:IsMouseClickEnabled())
            book.noteScroll.scripts.OnMouseDown(book.noteScroll,'LeftButton')
            assert(book.note.focus)
            book.note:SetText('Copper near the bridge');assert(book.saveNote.enabled)
            book.saveNote.scripts.OnClick()
            assert(entry('mineral:copper vein').note=='Copper near the bridge')
            assert(book.message:GetText()=='Notes saved.' and not book.saveNote.enabled)
            book.rows[2].scripts.OnClick(book.rows[2])
            assert(book.title:GetText()=='Peacebloom • Herb' and book.note:GetText()=='' and not book.note.focus)
            local border=book.noteScroll.parent
            border.scripts.OnMouseDown(border,'LeftButton');assert(book.note.focus)
            book.note:SetText('Flowers by the stream');book.saveNote.scripts.OnClick()
            book.rows[1].scripts.OnClick(book.rows[1]);assert(book.note:GetText()=='Copper near the bridge')
            book.note:SetText('Unsaved copper draft');book.rows[2].scripts.OnClick(book.rows[2])
            assert(book.note:GetText()=='Flowers by the stream')
            book.rows[1].scripts.OnClick(book.rows[1]);assert(book.note:GetText()=='Unsaved copper draft')
            local reloaded=ns.CreateGatheringJournal(AzerothFieldbookGatheringDB)
            assert(reloaded.entries['mineral:copper vein'].note=='Copper near the bridge')
            assert(reloaded.entries['herb:peacebloom'].note=='Flowers by the stream')
            book.note:SetText('');book.saveNote.scripts.OnClick()
            assert(entry('mineral:copper vein').note=='' and entry('herb:peacebloom').note=='Flowers by the stream')
        ''')

    def test_bestiary_reset_and_backups_cannot_remove_or_include_gathering(self):
        for name in ['SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryJournal.lua']:
            self.lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', self.lua.globals().ns)
        self.lua.execute('''
            gather('Silverleaf','silver');journal:SetNote('herb:silverleaf','Keep this')
            local root=AzerothFieldbookGatheringDB
            local bestiary=ns.CreateBestiaryJournal(settings,function() return 42 end)
            bestiary:ResetDatabase()
            assert(AzerothFieldbookGatheringDB==root and entry().note=='Keep this' and count(points())==1)
            assert(settings.gathering==nil and settings.bestiary.entries['herb:silverleaf']==nil)
            local other=ns.CreateGatheringJournal({})
            assert(not next(other.entries),'different characters start empty')
        ''')

    def test_bootstrap_registers_gathering_and_tracks_without_opening_page(self):
        # Exercise the actual addon initialization hook, without building the book.
        self.lua.execute('SlashCmdList={};ns.CreateBestiaryBook=nil;ns.UIScale=nil')
        for name in ['BestiaryJournal.lua', 'AzerothFieldbook.lua']:
            self.lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', self.lua.globals().ns)
        self.lua.execute('''
            local initialize=ns.InitializeGathering
            ns.InitializeGathering=function(shell,brightness)
                bootShell=shell;bootGathering=initialize(shell,brightness);return bootGathering
            end
            -- Disable the separately constructed test tracker before booting.
            tracker.frame.events={}
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(bootShell.sections.gathering and not bootGathering.frame)
            gather('Silverleaf','boot')
            assert(bootGathering.journal.entries['herb:silverleaf'].completed==1)
            assert(AzerothFieldbookDB.bestiary.entries['herb:silverleaf']==nil)
            local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,message) messages[#messages+1]=message end}
            local journal=bootGathering.journal
            AzerothFieldbookDB.creatureAnnouncements=true
            journal:Discover('mineral','Copper Vein',42,'Elwynn',{mapID=37,name='Elwynn'})
            assert(#messages==1 and messages[1]=="|cff80d0ffAFB:|r |cffffd100[New node type]|r |cff80d0ffGatherer's Compendium:|r |cffffffffCopper Vein|r |cff999999(Mineral • Elwynn)|r")
            journal:Discover('mineral','Copper Vein',43,'Elwynn',{mapID=37,name='Elwynn'})
            assert(#messages==1,'repeat hover stays quiet')
            journal:Discover('mineral','Copper Vein',44,'Westfall',{mapID=52,name='Westfall'})
            assert(#messages==2 and messages[2]:find('[New observed location]',1,true))
            local sample={mapID=52,name='Westfall',point={x=2000,y=3000,seenAt=45}}
            journal:RecordInteraction('mineral','Copper Vein',sample,'Westfall',45)
            assert(#messages==3 and messages[3]:find('Westfall — 20.0, 30.0',1,true))
            journal:RecordInteraction('mineral','Copper Vein',sample,'Westfall',46)
            assert(#messages==3,'known coordinates stay quiet')
            sample.point.x=8000
            journal:RecordInteraction('mineral','Copper Vein',sample,'Westfall',47)
            assert(#messages==4,'new coordinates announced')
            AzerothFieldbookDB.creatureAnnouncements=false
            journal:Discover('herb','Peacebloom',48,'Westfall')
            sample.point.x=5000
            journal:RecordInteraction('mineral','Copper Vein',sample,'Westfall',49)
            assert(#messages==4 and journal.entries['herb:peacebloom'],'muting retains discoveries')
        ''')


if __name__ == '__main__':
    unittest.main()
