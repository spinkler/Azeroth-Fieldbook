"""Native F7 PlayerNames bypass, using actual full-TOC callbacks in Lua 5.1."""
import unittest
from ui_test_harness import ROOT, new_ui_client


SUPPORT = r'''
    function literal(v)
        if type(v)=='string' then return string.format('%q',v) end
        if type(v)=='number' then return string.format('%.17g',v) end
        if type(v)~='table' then return type(v)..':'..tostring(v) end
        local rows={}
        for k,x in pairs(v) do rows[#rows+1]='['..literal(k)..']='..literal(x) end
        table.sort(rows);return '{'..table.concat(rows,',')..'}'
    end
    stores={'AzerothFieldbookDB','AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB',
        'AzerothFieldbookAtlasDB','AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB',
        'AzerothFieldbookTreasureDB','AzerothFieldbookLoreDB'}
    function capture()
        local result={}
        for _,key in ipairs(stores) do result[key]={object=_G[key],text=literal(_G[key])} end
        return result
    end
    function unchanged(before,label)
        for key,value in pairs(before) do
            assert(_G[key]==value.object and literal(_G[key])==value.text,
                label..' mutated '..key..': '..literal(_G[key]))
        end
    end
    SlashCmdList={};messages={};observedClass='MAGE'
    DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
    function GetTime() return now end
    function UnitExists() return false end
    function UnitIsEnemy() return false end
    function UnitPlayerControlled() return false end
    function UnitIsPlayer(unit) return unit=='player' end
    function UnitNameUnmodified(unit) if unit=='player' then return 'Native','Witness' end end
    function UnitClass(unit) if unit=='player' then return 'Localized',observedClass end end
    RAID_CLASS_COLORS={MAGE={r=0.25,g=0.78,b=0.92},WARRIOR={r=0.78,g=0.61,b=0.43}}
'''


def full_client(root="{version=1,spellIDTooltipInitialized=true}", initialize=True):
    lua = new_ui_client()
    lua.execute(SUPPORT + '\nAzerothFieldbookDB=' + root + '\nboot=capture()')
    for name in (ROOT / 'AzerothFieldbook.toc').read_text().splitlines():
        if not name.endswith('.lua'):
            continue
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        if name == 'PlayerNames.lua':
            lua.execute('namesFrame=objects[#objects];namesEvent=namesFrame.scripts.OnEvent')
        elif name == 'AzerothFieldbook.lua':
            lua.execute('main=objects[#objects];mainEvent=main.scripts.OnEvent')
    if initialize:
        lua.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(not ns.InitializationBlocked)")
    return lua


class PlayerNamesPreservationTests(unittest.TestCase):
    def test_native_pinned_transition_and_ordered_retained_event_replay(self):
        lua = full_client(initialize=False)
        lua.execute(r'''
            local journal=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return nil end)
            journal:Ensure(42,false,'Synthetic preservation creature')
            journal:SetCreatureNotes(42,'NATIVE KEEP');assert(journal:AddNoteSpell(42,'6268'))
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            local name,book=debug.getupvalue(AzerothFieldbookNextEntry,1);assert(name=='book')
            book:GetShell():ShowSection('bestiary',{creatureID=42})
            book:OpenNotes()
            local editor=AzerothFieldbookCreatureNotes
            editor.pinButton.scripts.OnClick();editor.notes:SetFocus()
            assert(editor:IsShown() and editor.afbPinned and editor.notes:GetText()=='NATIVE KEEP')
            local previous=AzerothFieldbookDB;local previousBefore=literal(previous)
            local record=AzerothFieldbookAccountDB.bestiary.entries[42];local recordBefore=literal(record)
            local text,add,remove=editor.notes.scripts.OnTextChanged,
                editor.spellInput.scripts.OnEnterPressed,editor.rows[1].remove.scripts.OnClick
            AzerothFieldbookDB={version=2,marker='SYNTHETIC KEEP'}
            local before=capture()
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            assert(ns.InitializationBlocked and not editor:IsShown() and editor.afbPinned)
            unchanged(before,'shutdown')
            editor.notes:SetText('MUST NOT SAVE');text(editor.notes)
            editor.spellInput:SetText('134');add(editor.spellInput);remove();book:OpenNotes()
            unchanged(before,'retained editor callbacks')
            -- Same ordered event list delivered to retained callbacks by the
            -- preserved native helper. PLAYER_LOGIN is first; the diagnostic
            -- also isolated PLAYER_ENTERING_WORLD (tested separately below).
            for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED',
                'UPDATE_MOUSEOVER_UNIT','UNIT_AURA','UNIT_HEALTH','ZONE_CHANGED',
                'UNIT_SPELLCAST_START','UNIT_SPELLCAST_SUCCEEDED','PARTY_KILL','UNIT_DIED',
                'PLAYER_REGEN_ENABLED','LOOT_READY','ITEM_TEXT_BEGIN','ITEM_TEXT_READY','PLAYER_LOGOUT'}) do
                namesEvent(namesFrame,event,'target','Creature-0-1-2-3-42-synthetic',123)
                unchanged(before,'native replay '..event)
            end
            assert(AzerothFieldbookDB.sourceClasses==nil)
            assert(literal(previous)==previousBefore and literal(record)==recordBefore)
        ''')

    def test_all_retained_callers_preserve_absent_existing_and_malformed_fields(self):
        fixtures = {
            'absent': '',
            'existing': ",sourceClasses={['native witness']='MAGE',['unknown source']=false,[true]={evidence='KEEP'}}",
            'malformed': ",sourceClasses='KEEP malformed'",
        }
        actions = {
            'registered events': r"for _,e in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','GROUP_ROSTER_UPDATE','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','UNIT_NAME_UPDATE','UNIT_CONNECTION'}) do retained.event(namesFrame,e,'player');unchanged(before,e) end",
            'Observe': "retained.Observe(names,'player')",
            'Refresh': 'retained.Refresh(names)',
            'Remember': "retained.Remember(names,'Native Witness');retained.Remember(names,'Unknown Source')",
            'Format': "assert(type(retained.Format(names,'Native Witness'))=='string');assert(type(retained.Format(names,'Unknown Source'))=='string')",
            'writer': "assert(retained.writer()==nil,'blocked writer exposed a mutable saved table')",
        }
        for fixture, field in fixtures.items():
            for action, call in actions.items():
                with self.subTest(fixture=fixture, action=action):
                    lua = full_client()
                    lua.execute(r'''
                        names=ns.PlayerNames
                        names:Remember('Native Witness')
                        previous=AzerothFieldbookDB;previousBefore=literal(previous)
                        previousClasses=previous.sourceClasses
                        retained={event=namesEvent,Observe=names.Observe,Refresh=names.Refresh,
                            Remember=names.Remember,Format=names.Format}
                        local index=1
                        while true do
                            local key,value=debug.getupvalue(names.Format,index)
                            if not key then break end
                            if key=='savedClasses' then retained.writer=value end
                            index=index+1
                        end
                        assert(type(retained.writer)=='function','real writer not found')
                    ''')
                    lua.execute("unsupported={version=2,marker='SYNTHETIC KEEP'" + field + "};AzerothFieldbookDB=unsupported")
                    lua.execute(r'''
                        before=capture()
                        originalClasses=unsupported.sourceClasses
                        mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
                        assert(ns.InitializationBlocked);unchanged(before,'block setup')
                        observedClass='WARRIOR'
                        blockedRevision=names.revision
                    ''')
                    # Snapshot only raw fixture values. No writer/formatter is
                    # called to construct an expected value or initialize it.
                    lua.execute('for attempt=1,3 do ' + call + ";unchanged(before,'retained caller') end")
                    lua.execute(r'''
                        assert(previous.sourceClasses==previousClasses and literal(previous)==previousBefore)
                        assert(unsupported.sourceClasses==originalClasses and names.revision==blockedRevision)
                        heldUnsupported=literal(unsupported)
                    ''')
                    lua.execute("AzerothFieldbookDB={version=1,marker='SUPPORTED LOOKING'" + field + '};before=capture();restoredClasses=AzerothFieldbookDB.sourceClasses')
                    lua.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(ns.InitializationBlocked)")
                    lua.execute('for attempt=1,3 do ' + call + ";unchanged(before,'still latched') end")
                    lua.execute('assert(literal(unsupported)==heldUnsupported and literal(previous)==previousBefore)')
                    lua.execute('assert(AzerothFieldbookDB.sourceClasses==restoredClasses and names.revision==blockedRevision)')

    def test_fresh_unsupported_root_untouched_during_load_and_after_latch(self):
        for field in ('', ",sourceClasses={['native witness']='WARRIOR',[true]='KEEP'}", ",sourceClasses='KEEP malformed'"):
            with self.subTest(field=field):
                lua = full_client("{version=2,marker='FRESH KEEP'" + field + '}', initialize=False)
                lua.execute(r'''
                    unchanged(boot,'preflight file loading')
                    mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    assert(ns.InitializationBlocked)
                    for attempt=1,3 do
                        namesEvent(namesFrame,'PLAYER_ENTERING_WORLD')
                        namesEvent(namesFrame,'PLAYER_LOGIN')
                        ns.PlayerNames:Observe('player');ns.PlayerNames:Remember('Native Witness')
                        ns.PlayerNames:Format('Unknown Source')
                        unchanged(boot,'fresh blocked callback')
                    end
                ''')

    def test_supported_login_recording_backfill_and_formatting(self):
        lua = full_client()
        lua.execute(r'''
            namesEvent(namesFrame,'PLAYER_LOGIN')
            assert(ns.PlayerNames:Format('Native Witness')=='|cff40c7ebNative Witness|r')
            ns.PlayerNames:Remember('Native Witness');ns.PlayerNames:Remember('Unknown Source')
            local classes=AzerothFieldbookDB.sourceClasses
            assert(classes['native witness']=='MAGE' and classes['unknown source']==false)
            observedClass='WARRIOR';namesEvent(namesFrame,'UNIT_NAME_UPDATE','player')
            assert(classes['native witness']=='WARRIOR')
            assert(ns.PlayerNames:Format('Native Witness')=='|cffc79c6eNative Witness|r')
            assert(not ns.InitializationBlocked)
        ''')


if __name__ == '__main__':
    unittest.main()
