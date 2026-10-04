"""Optional synthetic cleanup timing; not a native WoW FPS measurement."""
import time
from atlas_test_harness import new_atlas


def benchmark(side):
    lua=new_atlas()
    lua.globals().clock=lambda: time.perf_counter()*1000
    lua.execute(f'''
        debugprofilestop=function() return clock() end
        S=ns.AtlasSubzones;s=j.subzones
        C_Map.GetMapWorldSize=function() return 4000,4000 end
        s.store[101]={{}}
        for i=1,{side} do for k=1,{side} do
            s.store[101][#s.store[101]+1]={{kind='interior',mapID=101,name='Lake',x=1000+(i-1)*250,y=1000+(k-1)*250}}
        end end
        s.index={{}};s:Changed(101)
        S.CleanInterior(j,101,function(n) removed=n end)
    ''')
    start=time.perf_counter();frames=0;peak=0
    while lua.eval('S.worker:IsShown()'):
        tick=time.perf_counter();lua.execute('S.Step()')
        peak=max(peak,(time.perf_counter()-tick)*1000);frames+=1
        assert frames<100000, 'Worker did not settle'
    return dict(samples=side*side,removed=lua.eval('removed'),
                work_ms=round((time.perf_counter()-start)*1000,2),worker_frames=frames,
                peak_ms=round(peak,2),coverage_characters=lua.eval('#j.saved.subzoneCoverage.maps[101].Lake'))


if __name__=='__main__':
    for side in (16,32):
        print(benchmark(side),flush=True)
