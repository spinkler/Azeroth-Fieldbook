import unittest
from atlas_test_harness import new_atlas


class AtlasStorageTests(unittest.TestCase):
    def test_measurement_preserves_samples_and_handles_unsupported_data(self):
        lua = new_atlas()
        lua.execute('''
            j.saved.subzones={[101]={
                {kind='interior',mapID=101,name='Sentinel Hill',x=5000,y=5000,at=1791000000},
                {mapID=101,from='Sentinel Hill',to='Westfall',fromX=4990,fromY=5000,x=5000,y=5000,at=1791000000}
            }}
            local before=snapshot(j.saved)
            local steps=0
            local title,detail=j:StorageStatus(function() steps=steps+1 end)
            assert(title:find('Archive: ~') and detail:find('1 survey points') and detail:find('1 crossing points'))
            assert(steps>0 and snapshot(j.saved)==before)
            j.saved.cycle=j.saved
            assert(j:StorageStatus()=='Archive: usage unavailable')
            j.saved.cycle=nil;j.readOnly=true
            assert(j:StorageStatus()=='Archive: read-only')
        ''')

    def test_counter_refreshes_and_tooltip_uses_completed_measurement(self):
        lua = new_atlas(ui=True)
        lua.execute('''
            m.scripts.OnUpdate(m,0.1)
            local S=ns.AtlasSubzones
            for i=1,1000 do if not S.worker:IsShown() then break end;S.Step() end
            assert(m.capacity:GetText():find('Archive: ~'))
            m.capacityHover.scripts.OnEnter(m.capacityHover)
            assert(GameTooltip.lines[1].text:find('estimated saved%-data bytes'))
            m:Hide()
            for i=1,1000 do if not S.worker:IsShown() then break end;S.Step() end
            assert(not S.worker:IsShown())
        ''')
