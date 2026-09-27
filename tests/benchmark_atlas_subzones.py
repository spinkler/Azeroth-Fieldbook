"""Optional synthetic crossing/worker benchmark; not native WoW frame timings."""
import json
import time
from atlas_test_harness import new_atlas


def timed(lua, code):
    start = time.perf_counter()
    lua.execute(code)
    return (time.perf_counter() - start) * 1000


def benchmark(count):
    lua = new_atlas(ui=True)
    lua.globals().debugprofilestop = lambda: time.perf_counter() * 1000
    # Lupa exposes Python callbacks as userdata, so wrap it as a Lua function.
    lua.execute('local clock=debugprofilestop;debugprofilestop=function() return clock() end')
    lua.execute(f'''
        S=ns.AtlasSubzones;s=j.subzones;rows={{}}
        for i=1,{count} do
            local x,y=10+(i*127)%9990,(i*191)%10000
            rows[i]={{mapID=101,from='Meadow',to='Forest',x=x,y=y,fromX=x-10,fromY=y,at=100}}
        end
        s.store[101]=rows;s:Changed(101);j.state.showSubzones=true
        C_Map.GetMapWorldSize=function() return 4000,3000 end
        name='Benchmark A';function GetSubZoneText() return name end
        px=.4;py=.4;s:Reset();s:Observe(true)
        name='Benchmark B';px=.401
    ''')
    capture = timed(lua, "c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'ZONE_CHANGED')")
    queue = timed(lua, 'm.map:RenderSubzones()')
    frames = []
    while lua.eval('S.worker and S.worker:IsShown()'):
        frames.append(timed(lua, 'S.Step()'))
        assert len(frames) < 20000, 'Worker did not settle'
    lua.execute('assert(not m.map.subzoneError,m.map.subzoneError)')
    warm = timed(lua, "name='Benchmark A';px=.405;c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'ZONE_CHANGED')")
    ordered = sorted(frames)
    return dict(samples=count, capture_ms=round(capture, 3), request_ms=round(queue, 3),
                warm_capture_ms=round(warm, 3), worker_frames=len(frames),
                worker_total_ms=round(sum(frames), 3),
                worker_p95_ms=round(ordered[min(len(ordered)-1, int(len(ordered)*.95))], 3),
                worker_max_ms=round(max(frames), 3),
                triangles=lua.eval('#m.map.subzoneModel.triangles'),
                retained=lua.eval('#s.store[101]'))


if __name__ == '__main__':
    print(json.dumps([benchmark(n) for n in (4, 128, 4095)], indent=2))
