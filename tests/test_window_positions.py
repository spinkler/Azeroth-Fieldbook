"""Saved window lifecycle, scale changes, shared positions and full reset."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''
ns, db, eventFrames = {}, {}, {}
function CreateFrame()
    local f = {scale=1, shown=false, hooks={}, scripts={}}
    function f:SetPoint(point, relative, relativePoint, x, y)
        self.anchor={point,relative,relativePoint,x,y}
        if point=='TOPLEFT' then self.left=x; self.top=y end
    end
    function f:GetPoint() return unpack(self.anchor) end
    function f:ClearAllPoints() self.anchor=nil end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetScale(value) self.scale=value end
    function f:IsShown() return self.shown end
    function f:SetClampedToScreen(value) self.clamped=value end
    function f:SetClampRectInsets(...) self.clampInsets={...} end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:HookScript(event, callback)
        self.hooks[event]=self.hooks[event] or {}
        table.insert(self.hooks[event],callback)
    end
    function f:SetScript(event, callback) self.scripts[event]=callback end
    function f:RegisterEvent(event) eventFrames[event]=self end
    function f:Fire(event, ...)
        if self.scripts[event] then self.scripts[event](self,...) end
        for _,callback in ipairs(self.hooks[event] or {}) do callback(self,...) end
    end
    f:SetPoint('CENTER',UIParent,'CENTER',0,0)
    return f
end
UIParent=CreateFrame()
function moved(frame, left, top)
    frame.left=left; frame.top=top; frame.shown=true
    frame:Fire('OnDragStop')
end
function near(a,b) assert(math.abs(a-b)<0.000001,tostring(a)..' != '..tostring(b)) end
'''


class WindowPositionTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(MOCK)
        self.load()
        self.lua.execute('ns.UIScale:Initialize(db)')

    def load(self):
        for name in ('WindowPositions.lua', 'UIScale.lua'):
            self.lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', self.lua.globals().ns)

    def test_reload_and_per_character_storage(self):
        self.lua.execute('a=CreateFrame(); ns.UIScale:Register(a,"Book"); moved(a,140,810)')
        self.load()  # A fresh addon instance, retaining only the saved settings.
        self.lua.execute('''
            ns.UIScale:Initialize(db)
            b=CreateFrame(); ns.UIScale:Register(b,'Book')
            near(b.left,140); near(b.top,810); assert(b.clamped)
            ns.UIScale:Initialize({})
            assert(b.anchor[1]=='CENTER','another character uses default positions')
        ''')

    def test_scale_changes_preserve_screen_position_including_children(self):
        self.lua.execute('''
            book=CreateFrame(); ns.UIScale:Register(book,'Book')
            child=CreateFrame(); child.parent=book
            ns.WindowPositions:Register(child,'Effects')
            moved(book,100,700); moved(child,250,600)
            ns.UIScale:Set(0.5)
            near(book.left*book:GetEffectiveScale(),100)
            near(child.left*child:GetEffectiveScale(),250)
            near(child.top*child:GetEffectiveScale(),600)
            ns.UIScale:Set(1.5)
            near(child.left*child:GetEffectiveScale(),250)
            UIParent.scale=0.8; child.scale=0.6; child.parent=nil
            moved(child,400,500)
            near(db.windowPositions.Effects.left,300)
        ''')

    def test_drag_hide_logout_and_repeated_registration(self):
        self.lua.execute('''
            a=CreateFrame(); a:SetScript('OnDragStop',function(self) self.stopped=true end)
            ns.WindowPositions:Register(a,'Notes')
            moved(a,200,600); assert(a.stopped)
            a.left=250; a.top=650; a:Fire('OnHide')
            near(db.windowPositions.Notes.left,250)
            a.left=300
            ns.WindowPositions:Register(a,'Notes')
            near(a.left,300); assert(#a.hooks.OnHide==1)
            eventFrames.PLAYER_LOGOUT:Fire('OnEvent','PLAYER_LOGOUT')
            near(db.windowPositions.Notes.left,300)
        ''')

    def test_shared_group_reload_and_independent_mode(self):
        self.lua.execute('''
            single=true
            a=CreateFrame(); ns.WindowPositions:Register(a,'Offenses',function() return single and 'Observations' end)
            moved(a,80,500)
            a.left=90
            eventFrames.PLAYER_LOGOUT:Fire('OnEvent','PLAYER_LOGOUT')
        ''')
        self.load()
        self.lua.execute('''
            ns.UIScale:Initialize(db)
            b=CreateFrame(); ns.WindowPositions:Register(b,'Defenses',function() return single and 'Observations' end)
            assert(ns.WindowPositions:Restore(b,'Observations')); near(b.left,90)
            single=false; moved(b,300,400)
            near(db.windowPositions.Defenses.left,300)
            near(db.windowPositions.Observations.left,90)
        ''')

    def test_reset_and_malformed_saved_positions(self):
        self.lua.execute('''
            a=CreateFrame(); ns.WindowPositions:Register(a,'Book'); moved(a,200,800)
            db.windowPositions.Book={left=0/0,top=200}
            assert(not ns.WindowPositions:Restore(a))
            db.windowPositions.Book={left=math.huge,top=200}
            assert(not ns.WindowPositions:Restore(a))
            db.windowPositions.Book={left='200',top=200}
            assert(not ns.WindowPositions:Restore(a))
            db.windowPositions='invalid'; ns.UIScale:Initialize(db)
            assert(type(db.windowPositions)=='table' and a.anchor[1]=='CENTER')
            moved(a,200,800)
            for key in pairs(db) do db[key]=nil end
            ns.UIScale:Initialize(db)
            assert(a.anchor[1]=='CENTER' and next(db.windowPositions)==nil)
        ''')

    def test_untouched_defaults_stay_relative_through_hide_scale_and_reload(self):
        self.lua.execute('''
            book=CreateFrame(); book.left=100; book.top=800
            a=CreateFrame(); a:SetPoint('TOPLEFT',book,'TOPRIGHT',6,0)
            ns.WindowPositions:Register(a,'Help',function() return 'BookPages' end)
            a.left=800; a.top=800; a.shown=true
            a:Fire('OnHide'); ns.WindowPositions:SaveIfMoved(a,'BookPages')
            eventFrames.PLAYER_LOGOUT:Fire('OnEvent','PLAYER_LOGOUT')
            assert(next(db.windowPositions)==nil,'automatic saves must not pin default windows to the screen')
            ns.UIScale:Set(0.75)
            assert(a.anchor[2]==book)
            book.left=300; book.top=600; a:Fire('OnShow')
            assert(a.anchor[2]==book and a.anchor[3]=='TOPRIGHT')
            assert(a.clamped and #a.clampInsets==4)
            for _,inset in ipairs(a.clampInsets) do assert(inset==0,'entire window must stay inside the screen') end
        ''')
        self.load()
        self.lua.execute('''
            ns.UIScale:Initialize(db)
            b=CreateFrame(); b:SetPoint('TOPLEFT',book,'TOPRIGHT',6,0)
            ns.WindowPositions:Register(b,'Help')
            assert(b.anchor[2]==book,'reload keeps unmodified defaults relative')
            moved(b,400,700)
            b:Fire('OnShow')
            assert(db.windowPositions.Help.left==400,'manual placement is still remembered')
            assert(ns.WindowPositions:Restore(b) and b.anchor[2]==UIParent)
        ''')

    def test_restored_positions_clamp_all_edges_with_scale_and_smaller_screens(self):
        self.lua.execute('''
            UIParent.width=1000; UIParent.height=700; UIParent.scale=0.8
            a=CreateFrame(); a.width=300; a.height=200; a.scale=1.2
            ns.WindowPositions:Register(a,'Help')
            db.windowPositions.Help={left=1500,top=1200}
            assert(ns.WindowPositions:Restore(a))
            near(a.left*1.5,550); near(a.top*1.5,700)
            db.windowPositions.Help={left=-50,top=-100}
            assert(ns.WindowPositions:Restore(a))
            near(a.left,0); near(a.top*1.5,300)
            UIParent.width=600; UIParent.height=400
            db.windowPositions.Help={left=550,top=700}
            ns.WindowPositions:RestoreAll()
            near(a.left*1.5,150); near(a.top*1.5,400)
        ''')

    def test_dynamic_defaults_and_late_book_do_not_override_manual_positions(self):
        self.lua.execute('''
            a=CreateFrame(); ns.WindowPositions:Register(a,'Incoming')
            AzerothFieldbookBestiary=CreateFrame()
            a:Fire('OnShow'); assert(a.anchor[2]==AzerothFieldbookBestiary)
            b=CreateFrame(); height=178
            ns.WindowPositions:Register(b,'Rank',nil,function(frame)
                frame:SetPoint('TOPRIGHT',AzerothFieldbookBestiary,'TOPLEFT',-6,-height-6)
            end)
            height=570; b:Fire('OnShow')
            assert(b.anchor[2]==AzerothFieldbookBestiary and b.anchor[5]==-576)
            moved(b,200,600); ns.WindowPositions:Restore(b)
            height=200; b:Fire('OnShow')
            assert(b.anchor[2]==UIParent and b.anchor[5]==600,'dragged windows remain independent')
            ns.WindowPositions:Reset(); b:Fire('OnShow')
            assert(b.anchor[2]==AzerothFieldbookBestiary and b.anchor[5]==-206)
        ''')


if __name__ == '__main__':
    unittest.main()
