from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'.codex-test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
lua.execute("ns={}")
lua.execute((Path(__file__).resolve().parents[1]/'UIScale.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
lua.execute(r'''local function frame(base)
 return {value=base,GetScale=function(self) return self.value end,SetScale=function(self,v) self.value=v end}
end
local db={uiScale=1.2}
local scale=ns.UIScale
scale:Initialize(db)
assert(scale:Get()==1.2 and db.uiScale==nil)
scale:Set(1)
local book=frame(0.9); scale:Register(book); assert(book.value==0.9)
scale:Set(0.5); assert(book.value==0.45 and AzerothFieldbookAccountDB.uiScale==0.5)
scale:Register(book); assert(book.value==0.45) -- Registration must not compound scaling.
local lateWindow=frame(1); scale:Register(lateWindow); assert(lateWindow.value==0.5)
scale:Set(1.5); assert(math.abs(book.value-1.35)<0.00001 and lateWindow.value==1.5)
scale:Set(2); assert(AzerothFieldbookAccountDB.uiScale==1.5)
scale:Set(0.1); assert(AzerothFieldbookAccountDB.uiScale==0.5)
scale:Initialize(db); assert(book.value==0.45)
scale:Set(1); assert(book.value==0.9 and lateWindow.value==1)
local second={uiScale=0.7,accountWideTracking=false}
scale:Initialize(second); assert(scale:Get()==1 and second.uiScale==nil)
scale:Set(0.8); scale:Initialize(db); assert(scale:Get()==0.8)
scale:Initialize({}); assert(scale:Get()==0.8,'character reset preserves account scale')
''')
print('PASS: UI scale defaults, bounds, persistence, late windows and no compounding')
