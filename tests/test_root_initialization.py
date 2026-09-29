"""Main save preflight through the actual addon callback and Lua 5.1 host."""
import unittest
from kill_test_harness import new_client
from ui_test_harness import ROOT, new_ui_client


SNAPSHOT = r'''
function snapshot(v)
    if type(v)~='table' then return type(v)..':'..tostring(v) end
    local rows={}
    for k,x in pairs(v) do rows[#rows+1]=snapshot(k)..'='..snapshot(x) end
    table.sort(rows);return '{'..table.concat(rows,';')..'}'
end
function exerciseBlocked()
    units.target=spawn('blocked',false)
    for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED',
        'UPDATE_MOUSEOVER_UNIT','UNIT_AURA','UNIT_HEALTH','ZONE_CHANGED',
        'UNIT_SPELLCAST_START','UNIT_SPELLCAST_SUCCEEDED','PARTY_KILL','UNIT_DIED',
        'PLAYER_REGEN_ENABLED','LOOT_READY','ITEM_TEXT_BEGIN','ITEM_TEXT_READY'}) do
        fire(event,'target','Creature-0-1-2-3-42-blocked',123)
    end
    tick()
    for _,command in ipairs({'book','notes','scan','debug on','wipe','wipe confirm','clear'}) do
        SlashCmdList.AZEROTHFIELDBOOK(command)
    end
    AzerothFieldbookToggleBestiary();AzerothFieldbookOpenMouseover()
    AzerothFieldbookOpenMouseoverBestiary();AzerothFieldbookNextEntry();AzerothFieldbookPreviousEntry()
    if AzerothFieldbookRecordAtlasPoint then AzerothFieldbookRecordAtlasPoint() end
end
'''


class RootInitializationTests(unittest.TestCase):
    def block_existing_client(self, lua):
        lua.execute('SlashCmdList=SlashCmdList or {}')
        lua.execute((ROOT/'AzerothFieldbook.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute(r'''
            AzerothFieldbookDB={version=2,marker='KEEP'}
            local main=objects[#objects]
            main.scripts.OnEvent(main,'ADDON_LOADED','AzerothFieldbook')
            assert(ns.InitializationBlocked)
        ''')

    def client(self, initialize=False):
        lua = new_client(tracking=True, initialize=initialize)
        lua.execute(SNAPSHOT)
        return lua

    def test_unsupported_originals_and_dependent_stores_remain_untouched(self):
        fixtures = {
            'future': "{version=2,marker='KEEP',bestiary={entries={[42]={notes='Private'}}}}",
            'missing marker': "{marker='KEEP',bestiary={entries={[42]={notes='Private'}}}}",
            'empty unversioned': '{}',
            'string marker': "{version='1',marker='KEEP'}",
            'scalar': "'KEEP original'",
            'false': 'false',
            'malformed bestiary': "{version=1,bestiary='KEEP original'}",
            'malformed entries': "{version=1,bestiary={entries='KEEP original'}}",
            'malformed creatures': "{version=1,bestiary={creatures='KEEP original'}}",
            'malformed key': "{version=1,accountTrackingKey='KEEP original'}",
        }
        for name, fixture in fixtures.items():
            with self.subTest(name=name):
                lua = self.client()
                lua.execute("original=" + fixture)
                lua.execute(r'''
                    AzerothFieldbookDB=original
                    AzerothFieldbookAccountDB={version=1,nextCharacter=7,importedCharacters={[7]=true},
                        sectionImports={atlas={[7]=true}},sections={atlas={marker='KEEP'}}}
                    local globals={'AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB','AzerothFieldbookAtlasDB',
                        'AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB','AzerothFieldbookLoreDB','AzerothFieldbookTreasureDB'}
                    for i=2,#globals do _G[globals[i]]={marker=globals[i]} end
                    local before=snapshot(original);local saved={}
                    for _,key in ipairs(globals) do saved[key]={object=_G[key],bytes=snapshot(_G[key])} end
                    fire('ADDON_LOADED','AzerothFieldbook')
                    assert(AzerothFieldbookDB==original,'unsupported root was replaced')
                    assert(snapshot(original)==before,'unsupported root was normalized')
                    assert(output():find('saved data',1,true) and output():find('disabled',1,true),'blocked initialization needs a clear diagnostic')
                    exerciseBlocked();fire('ADDON_LOADED','AzerothFieldbook');exerciseBlocked()
                    assert(AzerothFieldbookDB==original and snapshot(original)==before,'blocked lifecycle changed the root')
                    for _,key in ipairs(globals) do
                        assert(_G[key]==saved[key].object and snapshot(_G[key])==saved[key].bytes,'blocked lifecycle changed '..key)
                    end
                ''')

    def test_blocked_reload_drops_old_main_callbacks_and_pending_reset(self):
        lua = self.client(initialize=True)
        lua.execute(r'''
            beginKill('before');finishKill()
            SlashCmdList.AZEROTHFIELDBOOK('wipe')
            local previous=AzerothFieldbookDB
            local account=AzerothFieldbookAccountDB
            local before=snapshot(previous);local accountBefore=snapshot(account)
            local unsupported={version=2,marker='KEEP'};AzerothFieldbookDB=unsupported
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(AzerothFieldbookDB==unsupported,'unsupported reload replaced the root')
            exerciseBlocked()
            assert(snapshot(previous)==before and snapshot(account)==accountBefore,'stale callback mutated a previously active store')
            assert(unsupported.marker=='KEEP' and unsupported.accountTrackingKey==nil,'blocked reload allocated an import key')
            AzerothFieldbookDB=nil;fire('ADDON_LOADED','AzerothFieldbook')
            assert(AzerothFieldbookDB==nil and snapshot(account)==accountBefore,'blocked session resumed without a real reload')
        ''')

    def test_nil_supported_reload_and_character_switching(self):
        lua = self.client()
        lua.execute(r'''
            assert(AzerothFieldbookDB==nil)
            fire('ADDON_LOADED','AzerothFieldbook')
            local alice=AzerothFieldbookDB;assert(alice.version==1 and alice.accountTrackingKey==1)
            beginKill('first');finishKill()
            local account=AzerothFieldbookAccountDB;local before=snapshot(account)
            alice.marker='Private annotation'
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(AzerothFieldbookDB==alice and alice.marker=='Private annotation')
            assert(snapshot(account)==before and alice.accountTrackingKey==1,'supported reload repeated account import')
            local bob={version=1,accountWideTracking=false,marker='Other character'}
            AzerothFieldbookDB=bob;fire('ADDON_LOADED','AzerothFieldbook')
            beginKill('bob');finishKill()
            assert(bob.bestiary.entries[42].kills==1 and snapshot(account)==before)
            AzerothFieldbookDB=alice;fire('ADDON_LOADED','AzerothFieldbook')
            assert(alice.marker=='Private annotation' and bob.marker=='Other character' and snapshot(account)==before)
        ''')

    def test_real_toc_blocks_all_section_and_ui_initialization(self):
        modules = [line.strip() for line in (ROOT/'AzerothFieldbook.toc').read_text().splitlines()
                   if line.strip() and not line.startswith('#')]
        lua = new_ui_client()
        lua.execute('SlashCmdList={}')
        for name in modules:
            lua.execute((ROOT/name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute(SNAPSHOT + r'''
            function GetTime() return now end
            function SetCVar() error('blocked initialization must not change a CVar') end
            messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            SlashCmdList=SlashCmdList or {}
            local root={version=2,marker='KEEP'};AzerothFieldbookDB=root
            local stores={'AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB','AzerothFieldbookAtlasDB',
                'AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB','AzerothFieldbookLoreDB','AzerothFieldbookTreasureDB'}
            local before={}
            for _,key in ipairs(stores) do _G[key]={marker=key};before[key]=snapshot(_G[key]) end
            local frames=#objects
            for _,f in ipairs(objects) do if f.scripts.OnEvent then f.scripts.OnEvent(f,'ADDON_LOADED','AzerothFieldbook') end end
            assert(AzerothFieldbookDB==root and snapshot(root)==snapshot({version=2,marker='KEEP'}))
            for _,f in ipairs(objects) do
                if f.scripts.OnEvent then f.scripts.OnEvent(f,'PLAYER_ENTERING_WORLD') end
                if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1) end
            end
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            AzerothFieldbookToggleBestiary();AzerothFieldbookOpenMouseover()
            assert(#objects==frames,'blocked root created UI or capture frames')
            for _,key in ipairs(stores) do assert(snapshot(_G[key])==before[key],'blocked root changed '..key) end
            assert(ns.LoreSettings.db==nil and next(ns.ActiveSectionStores)==nil,'section setup ran before root validation')
        ''')

    def test_full_toc_blocked_transition_closes_pinned_notes_and_stale_writes(self):
        modules = [line.strip() for line in (ROOT/'AzerothFieldbook.toc').read_text().splitlines()
                   if line.strip() and not line.startswith('#')]
        for action in ('shutdown', 'text', 'add spell', 'remove spell', 'reopen'):
            with self.subTest(action=action):
                lua = new_ui_client()
                lua.execute(r'''
                    SlashCmdList={}
                    function GetTime() return now end
                    function UnitExists() return false end
                    function UnitIsEnemy() return false end
                    function UnitPlayerControlled() return false end
                    messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
                ''')
                for name in modules:
                    lua.execute((ROOT/name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
                lua.globals().action = action
                lua.execute(SNAPSHOT + r'''
                    local main=objects[#objects]
                    AzerothFieldbookDB={version=1}
                    local seed=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return nil end)
                    seed:Ensure(42,false,'Synthetic creature');seed:SetCreatureNotes(42,'KEEP')
                    assert(seed:AddNoteSpell(42,'6268'))
                    main.scripts.OnEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    -- Inspect the real binding's controller only to select the
                    -- synthetic entry; no production function is substituted.
                    local name,book=debug.getupvalue(AzerothFieldbookNextEntry,1)
                    assert(name=='book')
                    book:GetShell():ShowSection('bestiary',{creatureID=42})
                    SlashCmdList.AZEROTHFIELDBOOK('notes')
                    local editor=AzerothFieldbookCreatureNotes
                    local record=AzerothFieldbookAccountDB.bestiary.entries[42]
                    assert(editor:IsShown() and editor.notes:GetText()=='KEEP')
                    editor.notes:SetText('Supported edit')
                    assert(record.idNotes.text=='Supported edit')
                    editor.spellInput:SetText('4979')
                    local add=editor.spellInput.scripts.OnEnterPressed
                    add(editor.spellInput);assert(#record.idNotes.spells==2)
                    editor.rows[2].remove.scripts.OnClick();assert(#record.idNotes.spells==1)
                    local text=editor.notes.scripts.OnTextChanged
                    local remove=editor.rows[1].remove.scripts.OnClick
                    editor.pinButton.scripts.OnClick();assert(editor.afbPinned)
                    editor.pinButton.scripts.OnClick();assert(not editor.afbPinned)
                    editor.pinButton.scripts.OnClick();assert(editor.afbPinned)
                    local previous=AzerothFieldbookDB
                    local unsupported={version=2,marker='KEEP'};AzerothFieldbookDB=unsupported
                    -- Snapshot after installing the unsupported fixture, just
                    -- before shutdown can execute any real UI callbacks.
                    local stores={'AzerothFieldbookDB','AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB',
                        'AzerothFieldbookAtlasDB','AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB',
                        'AzerothFieldbookLoreDB','AzerothFieldbookTreasureDB'}
                    local before={}
                    for _,key in ipairs(stores) do before[key]={object=_G[key],bytes=snapshot(_G[key])} end
                    local previousBefore=snapshot(previous);local recordBefore=snapshot(record)
                    local function unchanged()
                        for _,key in ipairs(stores) do
                            assert(_G[key]==before[key].object and snapshot(_G[key])==before[key].bytes,
                                'blocked '..action..' changed '..key)
                        end
                        assert(snapshot(previous)==previousBefore and snapshot(record)==recordBefore,
                            'blocked callback changed a previously bound record')
                    end
                    main.scripts.OnEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    assert(ns.InitializationBlocked)
                    unchanged()
                    if action=='text' then editor.notes:SetText('MUST NOT SAVE');text(editor.notes)
                    elseif action=='add spell' then editor.spellInput:SetText('134');add(editor.spellInput)
                    elseif action=='remove spell' then remove()
                    elseif action=='reopen' then book:OpenNotes() end
                    unchanged()
                    assert(not editor:IsShown(),'blocked session retained an active pinned editor')
                    assert(editor.afbPinned,'shutdown must not unpin the editor')
                    assert(not AzerothFieldbookBestiary:IsShown())
                    local supported={version=1};AzerothFieldbookDB=supported
                    before.AzerothFieldbookDB={object=supported,bytes=snapshot(supported)}
                    main.scripts.OnEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    book:OpenNotes();editor.notes:SetText('STILL BLOCKED');text(editor.notes)
                    editor.spellInput:SetText('134');add(editor.spellInput);remove()
                    assert(ns.InitializationBlocked and not editor:IsShown())
                    unchanged()
                ''')

    def test_blocked_initialization_discards_the_atlas_survey_binding(self):
        from atlas_test_harness import new_atlas
        lua = new_atlas()
        lua.execute(r'''
            SlashCmdList={}
            ns.InitializeAtlas(ns.CreateFieldbookShell())
            assert(type(AzerothFieldbookRecordAtlasPoint)=='function')
            previous=AzerothFieldbookAtlasDB;before=snapshot(previous)
        ''')
        lua.execute((ROOT/'AzerothFieldbook.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute(r'''
            AzerothFieldbookDB={version=2,marker='KEEP'}
            local main=objects[#objects]
            main.scripts.OnEvent(main,'ADDON_LOADED','AzerothFieldbook')
            assert(AzerothFieldbookRecordAtlasPoint==nil,'blocked initialization retained the old Atlas binding')
            mapID=102;px=0.8;py=0.2
            for _,f in ipairs(objects) do
                if f~=main and f.scripts.OnEvent then f.scripts.OnEvent(f,'PLAYER_ENTERING_WORLD');f.scripts.OnEvent(f,'PLAYER_LOGOUT') end
                if f.scripts.OnUpdate then f.scripts.OnUpdate(f,1) end
            end
            assert(AzerothFieldbookAtlasDB==previous and snapshot(previous)==before)
        ''')

    def test_existing_section_observers_and_queued_captures_stop(self):
        from test_lore_tracking import client as lore_client
        from ledger_test_harness import new_ledger
        from treasure_test_harness import new_treasure
        from angling_test_harness import new_angling
        from test_gathering import client as gathering_client
        cases = [
            ('Lore', lore_client,
             'begin(1);assert(#timers>0)',
             "step(5);t:Event('ITEM_TEXT_READY');t:Event('ITEM_TEXT_CLOSED')"),
            ('Ledger', new_ledger,
             'visit();assert(#timers>0)',
             "vendorNPC=84;flush();fire('MERCHANT_SHOW');flush()"),
            ('Treasure', new_treasure,
             "bags[0]={bagitem(1001,'Item-exact-1')};fire('BAG_UPDATE_DELAYED');assert(#timers>0)",
             "flush();fire('BAG_UPDATE_DELAYED');flush()"),
            ('Angling', new_angling, "begin('pending')", "catch('after-block')"),
            ('Gathering', gathering_client, '',
             "hover('Silverleaf');tracker:ObserveWorldCursor();tracker:OnEvent('UPDATE_MOUSEOVER_UNIT')"),
        ]
        for name, factory, prepare, dispatch in cases:
            with self.subTest(section=name):
                lua = factory()
                lua.execute(SNAPSHOT)
                lua.execute(prepare + '\nbefore=snapshot(saved)')
                self.block_existing_client(lua)
                lua.execute(dispatch)
                lua.execute("assert(snapshot(saved)==before,'blocked observer or queued capture changed the old store')")


if __name__ == '__main__':
    unittest.main()
