from atlas_test_harness import new_atlas
from ui_test_harness import ROOT

lua = new_atlas(ui=True)
for name in ['AnnalsJournal.lua', 'AnnalsTrail.lua', 'AnnalsTracking.lua', 'AnnalsMap.lua', 'AnnalsBook.lua', 'AnnalsIntegration.lua']:
    lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
lua.execute('''
    AzerothFieldbookAnnalsDB={}
    local annals=ns.InitializeAnnals(shell,{atlas=c})
    j.state.autoEntrances=true
    local id=assert(j.entrances:Record({
        direction='entry',at=now,
        exterior={mapID=101,x=2500,y=7500},size={width=1000,height=2000},
        interior={zoneMapID=101,bestMapID=201,microMapID=201,parentMapID=101,
            zone='Synthetic coast',mapName='Cave',microName='Cave',subzone='Cave',minimap='Cave'}
    }))
    local events=annals.journal.db.events
    assert(#events==1 and events[1].link.section=='atlas')
    local link=events[1].link
    assert(link.key==id and annals:Resolve(link),'fixture requires a resolvable entrance')
    local deliberate=assert(j:Save({name='Deliberate landmark',category='landmark',mapID=101,x=2000,y=3000}))
    local record=j.records[deliberate]
    local other=ns.Atlas.Copy(j.entrances.records[id]);other.id=deliberate
    j.entrances.records[deliberate]=other
    local recordLink={section='atlas',key=deliberate,identity=record.reference}
    assert(annals:OpenLink(recordLink) and j.state.selected==deliberate,'entrance raw key hid deliberate source')
    j.entrances.records[deliberate]=nil
    local before=j.state.selected
    local result=annals:OpenLink(link)
    print('Annals entrance link:',link.key,'reported success:',result,'selected:',j.state.selected)
    assert(result==true and j.state.selected==ns.AtlasEntrances.PREFIX..id)
    assert(j.state.mapID==101)
    local savedReference=j.entrances.records[id].reference
    local duplicate=ns.Atlas.Copy(j.entrances.records[id]);duplicate.id='n999';j.entrances.records.n999=duplicate
    assert(not annals:Resolve(link),'duplicate references must be refused')
    j.entrances.records.n999=nil
    assert(j.entrances:Delete(id));assert(not annals:OpenLink(link))
    j.entrances.records[id]=duplicate;duplicate.id=id
    c:Select(ns.AtlasEntrances.PREFIX..id)
    assert(j.state.selected==ns.AtlasEntrances.PREFIX..id,'ordinary entrance navigation must work')
    print('Normal Atlas selection:',j.state.selected)
''')
