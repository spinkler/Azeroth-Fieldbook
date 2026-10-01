"""Retained Lua heap, native-widget reuse, and release of transient snapshots.

The widget host deliberately retains every frame, like the client. Heap checks
hold saved discoveries constant and collect garbage before measuring growth.
"""
import unittest

from atlas_test_harness import new_atlas
from kill_test_harness import new_client
from test_gathering import client as gathering_client
from test_player_names import client as player_names_client
from ui_test_harness import new_ui_client


class MemoryLifecycleTests(unittest.TestCase):
    def test_player_class_cache_plateaus_and_preserves_report_sources(self):
        lua = player_names_client()
        lua.execute('''
            AzerothFieldbookDB={}
            function observePlayers(first,last)
                for i=first,last do
                    local suffix=string.format('%08d',i):gsub('%d',function(n) return string.char(97+tonumber(n)) end)
                    units.mouseover={player=true,first='Player '..suffix,class='MAGE'}
                    fire('UPDATE_MOUSEOVER_UNIT')
                end
            end
            observePlayers(1,1);ns.PlayerNames:Remember('Player aaaaaaab')
            observePlayers(2,1000)
            collectgarbage('collect');collectgarbage('collect')
            local baseline=collectgarbage('count')
            observePlayers(1001,11000)
            collectgarbage('collect');collectgarbage('collect')
            classGrowth=collectgarbage('count')-baseline
            assert(classGrowth<64,'Player class cache keeps growing: '..classGrowth..' KiB')
            assert(ns.PlayerNames:Format('Player aaaaaaab')=='|cff40c7ebPlayer aaaaaaab|r')
            local count=0;for _ in pairs(AzerothFieldbookDB.sourceClasses) do count=count+1 end
            assert(count==1,'Passing players must not all become saved report sources')
            local revision=ns.PlayerNames.revision
            fire('UPDATE_MOUSEOVER_UNIT');assert(ns.PlayerNames.revision==revision)
        ''')
        print(f"Player class cache: {lua.globals().classGrowth:.1f} KiB retained growth / 10,000 names")

    def test_sighting_cache_plateaus_without_changing_credit(self):
        lua = new_client()
        lua.execute('''
            function observeMany(first,last)
                for i=first,last do
                    clock=i
                    units.mouseover=spawn(string.format('%08d',i),false)
                    fire('UPDATE_MOUSEOVER_UNIT')
                end
            end
            observeMany(1,3000)
            collectgarbage('collect');collectgarbage('collect')
            local baseline=collectgarbage('count')
            local earned=points()
            observeMany(3001,13000)
            collectgarbage('collect');collectgarbage('collect')
            sightingGrowth=collectgarbage('count')-baseline
            assert(sightingGrowth<64,'Sighting cache keeps growing: '..sightingGrowth..' KiB')
            local entry=AzerothFieldbookDB.bestiary.entries[42]
            local sightings=entry.sightings
            for _=1,100 do fire('UPDATE_MOUSEOVER_UNIT') end
            assert(entry.sightings==sightings,'Current instance must remain deduplicated')
            assert(points()==earned,'Cache eviction must never award discovery credit')
        ''')
        print(f"Sighting cache: {lua.globals().sightingGrowth:.1f} KiB retained growth / 10,000 new GUIDs")

    def encounter_client(self):
        lua = new_ui_client(['BestiaryEncounterReader.lua'])
        lua.execute('''
            function UnitAffectingCombat() return false end
            Enum.DamageMeterType={EnemyDamageTaken=10,DamageTaken=7}
            sid=1
            C_DamageMeter={
                GetAvailableCombatSessions=function() return {{sessionID=sid}} end,
                GetCombatSessionFromID=function() return {combatSources={}} end,
                GetCombatSessionSourceFromID=function() return {combatSpells={}} end,
            }
            reader=ns.CreateBestiaryEncounterReader(function() error('No fixture spells') end)
        ''')
        return lua

    def test_encounter_cache_tracks_retained_history_only(self):
        lua = self.encounter_client()
        lua.execute('''
            for i=1,1000 do sid=i;reader:Scan();reader:ForgetHistory() end
            collectgarbage('collect');collectgarbage('collect')
            local baseline=collectgarbage('count')
            for i=1001,11000 do sid=i;reader:Scan();reader:ForgetHistory() end
            collectgarbage('collect');collectgarbage('collect')
            encounterGrowth=collectgarbage('count')-baseline
            assert(encounterGrowth<64,'Encounter caches keep growing: '..encounterGrowth..' KiB')
            reader:Scan();assert(reader.stats.sessions==0,'Wiped retained session stays excluded')
            sid=sid+1;reader:Scan();assert(reader.stats.sessions==1,'New session remains eligible')
        ''')
        print(f"Encounter caches: {lua.globals().encounterGrowth:.1f} KiB retained growth / 10,000 sessions")

    def test_meter_reset_allows_reused_session_ids(self):
        lua = self.encounter_client()
        lua.execute('''
            reader:Scan();reader:ForgetHistory();reader:Scan()
            assert(reader.stats.sessions==0)
            reader:Event('DAMAGE_METER_RESET');reader:Scan()
            assert(reader.stats.sessions==1,'A new meter history may reuse an old session ID')
        ''')

    def test_unreadable_history_waits_for_complete_wipe_snapshot(self):
        lua = self.encounter_client()
        lua.execute('''
            reader:Scan()
            local sessions=C_DamageMeter.GetAvailableCombatSessions
            C_DamageMeter.GetAvailableCombatSessions=function() return {{sessionID=secret}} end
            reader:ForgetHistory()
            sid=2;C_DamageMeter.GetAvailableCombatSessions=sessions
            reader:Scan();assert(reader.stats.sessions==0,'First readable history must be excluded')
            sid=3;reader:Scan();assert(reader.stats.sessions==1)
        ''')

    def test_atlas_releases_unused_pin_groups_and_reuses_widgets(self):
        lua = new_atlas(ui=True)
        lua.execute('''
            j:Save(fixture('Left','cave',101,1000,1000))
            j:Save(fixture('Right','cave',101,8000,8000));c:Refresh()
            local weak=setmetatable({m.map.pins[1].group,m.map.pins[2].group},{__mode='v'})
            c:SetZone(102,'Synthetic hills')
            collectgarbage('collect');collectgarbage('collect')
            assert(not weak[1] and not weak[2],'Unused pins retain detached discovery snapshots')
            local frames=#objects
            for _=1,100 do
                c:SetZone(101,'Synthetic coast');c:SetZone(102,'Synthetic hills')
            end
            assert(#objects==frames,'Revisiting maps must reuse native widgets')
        ''')

    def test_report_deselection_removes_saved_draft_keys(self):
        lua = new_atlas(ui=True)
        lua.execute('''
            saved.reportDraft={records={removed=false},notes={removed=false}}
            local id=j:Save(fixture());c:Report()
            local p=c.pages.report;local row=p.rows[1]
            assert(p.draft.records.removed==nil and p.draft.notes.removed==nil,'Clean up old deselection tombstones')
            click(row);click(row.note);assert(p.draft.notes[id])
            click(row.note);assert(p.draft.notes[id]==nil)
            click(row);assert(p.draft.records[id]==nil and p.draft.notes[id]==nil)
        ''')

    def gathering_client(self):
        lua = gathering_client(ui=True)
        lua.execute('''
            WorldMapFrame=CreateFrame('Frame');canvas=CreateFrame('Frame',nil,WorldMapFrame)
            canvas:SetSize(1000,600);shownMap=37
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return shownMap end
            Minimap=CreateFrame('Frame');Minimap:SetSize(200,200)
            C_Minimap={GetViewRadius=function() return 100 end}
            function GetCVar() return '0' end
            pins=gathering.mapPins
            journal:SetShowNodesOn('worldMap',true);journal:SetShowNodesOn('minimap',true)
        ''')
        return lua

    def test_gathering_pins_release_hidden_nodes(self):
        lua = self.gathering_client()
        lua.execute('''
            journal:RecordInteraction('herb','Silverleaf',
                {mapID=37,name='Elwynn',point={x=2100,y=3000,seenAt=10}},'Elwynn',10)
            pins:Refresh()
            local weak=setmetatable({pins.worldPins[1].node},{__mode='v'})
            journal:SetShowNodesOn('worldMap',false);journal:SetShowNodesOn('minimap',false)
            pins:Refresh();collectgarbage('collect');collectgarbage('collect')
            assert(not weak[1],'Disabled map overlays retain cached node snapshots')
            assert(not pins.worldPins[1].node and not pins.miniPins[1].node)
        ''')

    def test_gathering_pin_budget_and_repeated_map_navigation(self):
        lua = self.gathering_client()
        lua.execute('''
            for resource=1,6 do
                local id=journal:Discover('herb','Synthetic herb '..resource,1,'Elwynn',{mapID=37,name='Elwynn'})
                local points=journal.entries[id].locations[37].points
                for i=1,256 do
                    local x,y=2000+i,3000+resource
                    points[1+x*10001+y]={x=x,y=y,seenAt=i,approximate=true}
                end
            end
            journal:Changed();pins:Refresh()
            assert(#pins.worldPins<=512 and #pins.miniPins<=128,'Dense maps permanently allocate too many frames')
            assert(#pins.worldPins==512 and #pins.miniPins==128,'Budget must still display available points')
            assert(pins.worldPins[1].node.point.seenAt==256,'World map prioritizes recent positions')
            assert(pins.miniPins[1].node.point.x==2001,'Minimap prioritizes the nearest positions')
            local frames=#objects
            for _=1,50 do
                shownMap=38;mapID=38;pins:Refresh()
                shownMap=37;mapID=37;pins:Refresh()
            end
            assert(#objects==frames,'Map navigation must reuse the bounded pools')
            local count=0
            for _,e in pairs(journal.entries) do for _ in pairs(e.locations[37].points) do count=count+1 end end
            assert(count==1536,'Display budget must not delete saved locations')
        ''')

    def test_closing_backup_import_releases_decoded_snapshot(self):
        lua = new_ui_client(['Scrollbars.lua','SharingReport.lua','BestiaryBackups.lua',
                             'BestiaryJournal.lua','FieldbookShell.lua','BackupWindow.lua'])
        lua.execute('''
            local db={};local j=ns.CreateBestiaryJournal(db,function() end)
            j:Ensure(42,false,'Synthetic creature',{level=9})
            local shell=ns.CreateFieldbookShell()
            local ui={page=function(...) return shell:CreatePage(...) end,
                label=ns.FieldbookUI.Label,button=ns.FieldbookUI.Button}
            local window=ns.CreateBackupWindow(j,ui,function() end);window:Open(true)
            local frame=window.frame
            local data=ns.BestiaryBackups;local decode=data.Decode
            local weak=setmetatable({},{__mode='v'})
            data.Decode=function(...)
                local snapshot,err=decode(...);weak[1]=snapshot;return snapshot,err
            end
            frame.importButton.scripts.OnClick(frame.importButton)
            local wire=assert(data.Encode(j:GetBackups().saved[1]))
            for i=1,#wire do frame.paste.scripts.OnChar(frame.paste,wire:sub(i,i)) end
            frame.previewButton.scripts.OnClick(frame.previewButton)
            assert(weak[1] and frame.restoreButton.enabled)
            window:Hide();collectgarbage('collect');collectgarbage('collect')
            assert(not weak[1],'Closed import retains the full decoded backup')
            for _,row in ipairs(frame.rows) do assert(not row.snapshot) end
            window:Open(false);assert(frame.rows[1].snapshot==j:GetBackups().saved[1])
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
