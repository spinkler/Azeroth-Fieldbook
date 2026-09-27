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
                local ancestor=self.parent
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

    def test_passive_events_and_sent_only_never_record_or_sample(self):
        self.lua.execute('''
            for _,event in ipairs({'UPDATE_MOUSEOVER_UNIT','PLAYER_TARGET_CHANGED','CURSOR_CHANGED',
                'CHAT_MSG_LOOT','LOOT_OPENED','BAG_UPDATE','MINIMAP_UPDATE_TRACKING'}) do
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
            for i=1,270 do px=i/1000;now=now+1;gather('Silverleaf','point'..i) end
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
    def setUp(self):
        self.lua = client(ui=True)

    def test_model_loads_after_page_is_visible_and_reloads_on_tab_or_book_return(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575)
            shell:EnsureSection('gathering');local book=gathering.frame
            assert(not book:IsShown() and not book.model.modelLoads,'building a hidden section must not load its model')
            shell:ShowSection('gathering')
            assert(book.model.modelLoads==1 and book.model.requestedModel==219514)
            assert(book.model:GetFrameLevel()>book.modelBorder:GetFrameLevel())
            book.model.loadedModel=219514;book.model.scripts.OnModelLoaded(book.model)
            book.note:SetText('Keep my draft');book.search:SetText('Copper')
            shell:ShowSection('atlas');book.model:ClearModel() -- Native render state lost while hidden.
            local loads=book.model.modelLoads
            gathering:Refresh();assert(book.model.modelLoads==loads)
            shell:ShowSection('gathering')
            assert(book.model.modelLoads==loads+1 and book.model.requestedModel==219514 and book.model:IsShown())
            assert(book.note:GetText()=='Keep my draft' and book.search:GetText()=='Copper')
            assert(book.model.cameraDistance==3.125)
            shell:Hide();book.model:ClearModel();gathering:Refresh()
            assert(book.model.modelLoads==loads+1,'hidden refresh must not reload')
            shell:Toggle()
            assert(book.model.modelLoads==loads+2 and book.model.requestedModel==219514)
            local reopened=book.model.modelLoads;gathering:Refresh()
            assert(book.model.modelLoads==reopened,'ordinary updates must not continually reload models')
        ''')

    def test_reopening_retries_failed_model_without_stale_preview(self):
        self.lua.execute('''
            gather('Copper Vein','copper',2575);gather('Peacebloom','peace')
            shell:ShowSection('gathering');local book=gathering.frame
            local load=book.model.SetModel
            book.model.SetModel=function() error('temporary native model failure') end
            book.rows[2].scripts.OnClick(book.rows[2])
            assert(not book.model:IsShown() and not book.model.requestedModel)
            assert(book.modelCaption:GetText()=='Model unavailable')
            book.model.SetModel=load;shell:ShowSection('atlas');shell:ShowSection('gathering')
            assert(book.title:GetText()=='Peacebloom • Herb' and book.model.requestedModel==219481 and book.model:IsShown())
        ''')

    def test_hover_locations_and_object_previews_match_bestiary_panel_and_rotate(self):
        self.lua.execute('''
            hover('Peacebloom');discover();shell:ShowSection('gathering')
            local book=gathering.frame
            assert(book.model:GetWidth()==203 and book.model:GetHeight()==164)
            assert(book.modelBorder:GetWidth()==207 and book.modelBorder:GetHeight()==168)
            assert(book.model.point[2]==366 and book.model.point[3]==-111)
            assert(book.model.requestedModel==219481 and book.model:IsShown())
            assert(book.model.cameraDistance==3.125)
            assert(book.zoneRows[1]:GetText()=='Elwynn  •  0 mapped positions')
            assert(positionReads==0 and entry('herb:peacebloom').interactions==0)
            book.model.cameraDistance=1;book.model.loadedModel=219481;book.model.scripts.OnModelLoaded(book.model)
            assert(book.model.cameraDistance==3.125,'async loading must restore gathering zoom')
            assert(book.modelCaption:GetText()=='')
            local loads=book.model.modelLoads;gathering:Refresh();assert(book.model.modelLoads==loads)
            cursorX=100;GetCursorPosition=function() return cursorX,0 end
            book.model.scripts.OnMouseDown();cursorX=120;book.model.scripts.OnUpdate(book.model)
            assert(book.model.rotation>0)
            book.model.scripts.OnMouseUp();local rotation=book.model.rotation
            cursorX=140;book.model.scripts.OnUpdate(book.model);assert(book.model.rotation==rotation)
            hover('Copper Vein','Requires Mining');discover();gathering:Refresh()
            book.rows[1].scripts.OnClick(book.rows[1]);assert(book.model.requestedModel==219514)
            assert(book.model.cameraDistance==3.125,'mineral selection must retain gathering zoom')
            book.model.loadedModel=219481;book.model.scripts.OnModelLoaded(book.model)
            assert(book.modelCaption:GetText()=='Loading model…','stale load must not clear the caption')
            hover('Unknown herb');discover();gathering:Refresh()
            book.rows[3].scripts.OnClick(book.rows[3])
            assert(not book.model:IsShown() and not book.model.requestedModel)
            assert(book.modelCaption:GetText()=='Model unavailable')
        ''')

    def test_lazy_empty_page_opens_without_discovery_and_has_bestiary_dimensions(self):
        self.lua.execute('''
            assert(not shell:GetFrame() and not gathering.frame)
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book:GetWidth()==960 and book:GetHeight()==740 and #book.rows==16)
            assert(book.parent==shell:GetFrame() and book:GetScale()==1)
            assert(book.rows[1]:GetWidth()==162 and book.rows[1]:GetHeight()==28)
            assert(book.rows[1].point[2]==135 and book.rows[1].point[3]==-110)
            assert(book.rows[16].point[3]==-560)
            assert(book.search:GetWidth()==146 and book.search.point[2]==145 and book.search.point[3]==-78)
            assert(book.resourceScrollBar:GetHeight()==446 and book.resourceScrollBar:GetWidth()==14)
            assert(book.empty:IsShown() and not book.details:IsShown() and not book.locations.enabled)
            assert(not book.previous.enabled and not book.next.enabled and count(journal.entries)==0)
            assert(positionReads==0,'opening the journal never samples locations')
        ''')

    def test_search_categories_alphabet_sort_scroll_and_cycle(self):
        self.lua.execute('''
            for i=1,24 do gather(string.format('Herb %02d',i),'herb'..i) end
            gather('Copper Vein','copper',2575)
            shell:ShowSection('gathering');local book=gathering.frame
            assert(book.resourceScrollBar:IsShown() and book.rows[1].id=='mineral:copper vein')
            book.typeButtons.herb.scripts.OnClick();assert(book.rows[1].id=='herb:herb 01')
            book.rows[1].scripts.OnClick(book.rows[1])
            book.rows[1].scripts.OnMouseWheel(book.rows[1],-1);assert(book.rows[1].id=='herb:herb 04')
            book.next.scripts.OnClick();assert(book.title:GetText()=='Herb 02 • Herb' and book.resourceScrollBar:GetValue()==1)
            book.search:SetText('Herb 2');assert(book.rows[1].id=='herb:herb 20' and not book.resourceScrollBar:IsShown())
            book.searchClear.scripts.OnClick();assert(book.search:GetText()=='')
            book.clearFilters.scripts.OnClick();book.indexButton.scripts.OnClick()
            book.letterButtons[3].scripts.OnClick();assert(book.rows[1].id=='mineral:copper vein' and not book.rows[2]:IsShown())
            book.clearFilters.scripts.OnClick();book.sortButton.scripts.OnClick()
            book.sortChoices[8].control.scripts.OnClick()
            assert(book.rows[1].id=='herb:herb 24' and select(2,journal:GetListSort()))
            book.search:SetText('no such resource');assert(book.noMatches:IsShown() and not book.next.enabled)
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
            assert(map.trackingMode:GetText()=='Tracking: Interactions')
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
        ''')


if __name__ == '__main__':
    unittest.main()
