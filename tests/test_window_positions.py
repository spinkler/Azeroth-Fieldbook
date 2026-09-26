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

    def test_opening_moves_overlapping_saved_dialog_to_a_free_side(self):
        self.lua.execute('''
            UIParent.width=1600; UIParent.height=1000
            AzerothFieldbookBestiary=CreateFrame()
            local book=AzerothFieldbookBestiary
            book.left=300;book.top=700;book.width=600;book.height=500;book.shown=true
            a=CreateFrame();a.width=300;a.height=200
            ns.WindowPositions:Register(a,'Help')
            moved(a,700,650);a:Fire('OnShow')
            near(a.left,900);near(a.top,650)
            book.left=950;book.top=1000;book.height=950
            moved(a,1100,650);a:Fire('OnShow')
            near(a.left,650);near(a.top,650)
            a:Fire('OnHide');near(db.windowPositions.Help.left,650)
        ''')

    def test_vertical_edges_and_no_room_fallback_stay_inside_screen(self):
        self.lua.execute('''
            UIParent.width=1000;UIParent.height=1000
            AzerothFieldbookBestiary=CreateFrame()
            local book=AzerothFieldbookBestiary
            book.left=150;book.top=600;book.width=700;book.height=300;book.shown=true
            a=CreateFrame();a.width=400;a.height=200;a.left=300;a.top=500
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.top,300);near(a.left,300)
            a.left=300;a.top=650;ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.top,800);near(a.left,300)
            UIParent.height=800
            book.left=100;book.top=700;book.width=800;book.height=600
            a.width=400;a.height=300;a.left=350;a.top=650
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.top,800)
            assert(a.left>=0 and a.left+a.width<=1000 and a.top<=800 and a.top-a.height>=0,
                'visibility wins when every side overlaps')
        ''')

    def test_opening_geometry_accounts_for_scale_and_hidden_book(self):
        self.lua.execute('''
            UIParent.width=1600;UIParent.height=1000;UIParent.scale=0.8
            AzerothFieldbookBestiary=CreateFrame()
            local book=AzerothFieldbookBestiary
            book.scale=0.8;book.left=300;book.top=700;book.width=600;book.height=500;book.shown=true
            a=CreateFrame();a.scale=1.2;a.width=200;a.height=100;a.left=450;a.top=400
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.left*1.5,900);near(a.top*1.5,600)
            a.left=650;a.top=400
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.left,650);near(a.top,400) -- Already beside the book.
            book.shown=false;a.left=1200;a.top=20
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.left*1.5,1300);near(a.top*1.5,150)
            UIParent.scale=1;a.scale=1;a.width=2000;a.height=1200;a.left=-50;a.top=100
            ns.WindowPositions:AvoidWindowOverlap(a)
            near(a.scale,0.8)
            assert(a.left*a.scale>=0 and a.top*a.scale<=1000)
            assert((a.top-a.height)*a.scale>=0,'oversized windows fit vertically too')
        ''')

    def test_multiple_neighbours_are_avoided_together_on_show(self):
        self.lua.execute('''
            UIParent.width=1400;UIParent.height=900
            local function window(left,top,width,height)
                local frame=CreateFrame()
                frame.left=left;frame.top=top;frame.width=width;frame.height=height;frame.shown=true
                ns.WindowPositions:Track(frame)
                return frame
            end
            AzerothFieldbookBestiary=window(0,800,700,600)
            local notes=window(700,800,300,300)
            notes.afbPinned=true
            local rumours=window(700,500,300,300)
            local opening=window(600,700,200,200)
            opening:Fire('OnShow')
            near(opening.left,1000);near(opening.top,700)
            near(notes.left,700);near(notes.top,800)
            near(rumours.left,700);near(rumours.top,500)
            -- Hidden and transparent windows must not consume layout space.
            opening.left=700;opening.top=700
            notes.shown=false
            rumours.GetAlpha=function() return 0 end
            opening:Fire('OnShow')
            near(opening.left,700);near(opening.top,700)
        ''')

    def test_pins_allow_overlap_but_never_override_screen_bounds(self):
        self.lua.execute('''
            UIParent.width=1000;UIParent.height=800
            local neighbour=CreateFrame()
            neighbour.left=200;neighbour.top=600;neighbour.width=400;neighbour.height=400;neighbour.shown=true
            ns.WindowPositions:Track(neighbour)
            local pinned=CreateFrame()
            pinned.left=300;pinned.top=500;pinned.width=200;pinned.height=200;pinned.afbPinned=true
            ns.WindowPositions:Track(pinned)
            pinned:Fire('OnShow')
            near(pinned.left,300);near(pinned.top,500)
            pinned.left=950;pinned.top=50;pinned:Fire('OnShow')
            near(pinned.left,800);near(pinned.top,200)
            pinned.left=300;pinned.top=500;pinned.afbPinned=false;pinned:Fire('OnShow')
            assert(pinned.left+200<=200 or pinned.left>=600 or pinned.top<=200 or pinned.top-200>=600,
                'unpinning restores placement around other windows, even without the main book')
        ''')

    def test_main_window_also_avoids_existing_windows_without_dragging_them(self):
        self.lua.execute('''
            UIParent.width=1400;UIParent.height=900
            local book=CreateFrame()
            AzerothFieldbookBestiary=book
            book.width=600;book.height=400;book.left=400;book.top=700
            ns.WindowPositions:Track(book)
            local notes=CreateFrame()
            notes.width=300;notes.height=300;notes.shown=true;notes.afbPinned=true
            notes:SetPoint('TOPLEFT',book,'TOPLEFT',800,650)
            ns.WindowPositions:Track(notes)
            book:Fire('OnShow')
            near(book.left,200);near(book.top,700)
            near(notes.left,800);near(notes.top,650)
            assert(notes.anchor[2]==UIParent,'an already-visible anchored neighbour stays in place')
        ''')

    def test_book_edges_take_priority_over_nearer_unrelated_windows(self):
        self.lua.execute('''
            UIParent.width=1400;UIParent.height=900
            local book=CreateFrame();AzerothFieldbookBestiary=book
            book.left=400;book.top=900;book.width=400;book.height=900;book.shown=true
            local neighbour=CreateFrame()
            neighbour.left=800;neighbour.top=900;neighbour.width=400;neighbour.height=900;neighbour.shown=true
            ns.WindowPositions:Track(neighbour)
            local dialog=CreateFrame()
            dialog.left=1000;dialog.top=700;dialog.width=200;dialog.height=200;dialog.afbPreferBookEdge=true
            ns.WindowPositions:AvoidWindowOverlap(dialog)
            near(dialog.left,200);near(dialog.top,700)
            -- Blocking the last free book edge permits the unrelated edge.
            local leftBlock=CreateFrame()
            leftBlock.left=0;leftBlock.top=900;leftBlock.width=400;leftBlock.height=900;leftBlock.shown=true
            ns.WindowPositions:Track(leftBlock)
            dialog.left=1000;dialog.top=700
            ns.WindowPositions:AvoidWindowOverlap(dialog)
            near(dialog.left,1200);near(dialog.top,700)
            assert(dialog.left+dialog.width<=UIParent.width)
        ''')


    def test_default_on_direction_rules_and_disabled_or_pinned_positions(self):
        self.lua.execute('''
            UIParent.width=1800;UIParent.height=1000
            local function window(x,y,w,h)
                local f=CreateFrame();f.left=x;f.top=y;f.width=w;f.height=h;f.shown=true
                ns.WindowPositions:Track(f);return f
            end
            AzerothFieldbookBestiary=window(600,900,500,600)
            local dialog=CreateFrame();dialog.width=200;dialog.height=200;dialog.afbPreferBookEdge=true
            local function place(rule)
                dialog.left=100;dialog.top=600;dialog.afbAnchorRule=rule
                ns.WindowPositions:AvoidWindowOverlap(dialog)
            end
            place('right');near(dialog.left,1100)
            db.alwaysAnchorToMain=false
            place('right');near(dialog.left,100)
            db.alwaysAnchorToMain=true;dialog.afbPinned=true
            place('right');near(dialog.left,100)
            dialog.afbPinned=false
            local right=window(1100,1000,200,1000)
            place('right');near(dialog.left,1300)
            place('pages');near(dialog.left,400)
            right.shown=false
            place('pages');near(dialog.left,1100)
            place('filters');near(dialog.left,400)
            local left=window(400,1000,200,1000)
            place('filters');near(dialog.top,300)
            local bottom=window(600,300,500,300)
            place('filters');near(dialog.left,200)
            -- A crowded screen may overlap, but never place any edge off-screen.
            UIParent.width=800;UIParent.height=600
            AzerothFieldbookBestiary.left=0;AzerothFieldbookBestiary.top=600
            AzerothFieldbookBestiary.width=800;AzerothFieldbookBestiary.height=600
            left.shown=false;bottom.shown=false
            place('right')
            assert(dialog.left>=0 and dialog.left+200<=800 and dialog.top<=600 and dialog.top>=200)
        ''')


    def test_observation_windows_prefer_bottom_alignment_without_leaving_screen(self):
        self.lua.execute("""
            UIParent.width=1800;UIParent.height=1000
            local book=CreateFrame()
            book.left=100;book.top=900;book.width=800;book.height=700;book.shown=true
            AzerothFieldbookBestiary=book
            local dialog=CreateFrame()
            dialog.left=900;dialog.top=900;dialog.width=300;dialog.height=250
            dialog.afbPreferBookEdge=true;dialog.afbAnchorRule='right';dialog.afbAlignBookBottom=true
            ns.WindowPositions:AvoidWindowOverlap(dialog)
            near(dialog.left,900);near(dialog.top,450)
            dialog.height=400
            ns.WindowPositions:AvoidWindowOverlap(dialog)
            near(dialog.left,900);near(dialog.top,600)
            dialog.afbPinned=true;dialog.top=800
            ns.WindowPositions:AvoidWindowOverlap(dialog);near(dialog.top,800)
            dialog.afbPinned=false
            local blocker=CreateFrame()
            blocker.left=900;blocker.top=1000;blocker.width=300;blocker.height=1000;blocker.shown=true
            ns.WindowPositions:Track(blocker)
            ns.WindowPositions:AvoidWindowOverlap(dialog);near(dialog.left,1200)
            UIParent.width=1000;UIParent.height=500
            ns.WindowPositions:AvoidWindowOverlap(dialog)
            assert(dialog.left>=0 and dialog.left+dialog.width<=1000)
            assert(dialog.top<=500 and dialog.top-dialog.height>=0)
        """)


    def test_always_anchor_attaches_restored_observation_windows_even_without_moving(self):
        self.lua.execute('''
            UIParent.width=1800;UIParent.height=1000
            local book=CreateFrame()
            book.left=100;book.top=900;book.width=800;book.height=700;book.shown=true
            AzerothFieldbookBestiary=book
            for _,name in ipairs({'Offenses','Defenses','Behaviour'}) do
                local dialog=CreateFrame()
                dialog.width=300;dialog.height=250
                dialog.afbPreferBookEdge=true;dialog.afbAnchorRule='right'
                dialog.afbAlignBookBottom=true
                db.windowPositions[name]={left=900,top=450}
                ns.WindowPositions:Register(dialog,name)
                assert(dialog.anchor[2]==UIParent,'saved position initially uses screen coordinates')
                ns.WindowPositions:AvoidWindowOverlap(dialog)
                assert(dialog.anchor[2]==book,'enabled option must attach even when already correctly positioned')
                near(dialog.anchor[4],800);near(dialog.anchor[5],-450)
                db.alwaysAnchorToMain=false
                ns.WindowPositions:Restore(dialog)
                ns.WindowPositions:AvoidWindowOverlap(dialog)
                assert(dialog.anchor[2]==UIParent,'disabled option preserves independent saved position')
                db.alwaysAnchorToMain=true;dialog.afbPinned=true
                ns.WindowPositions:AvoidWindowOverlap(dialog)
                assert(dialog.anchor[2]==UIParent,'pinned windows remain independent')
            end
        ''')

    def test_secret_geometry_on_show_is_neither_calculated_nor_saved(self):
        self.lua.execute('''
            UIParent.width=1400;UIParent.height=900
            local secretNumber=987654
            function issecretvalue(value) return value==secretNumber end
            local abs=math.abs
            math.abs=function(value)
                assert(not issecretvalue(value),'secret reached numeric validation')
                return abs(value)
            end
            local cast=CreateFrame()
            cast.left=100;cast.top=600;cast.width=200;cast.height=100;cast.shown=true
            ns.WindowPositions:Track(cast)
            for _,field in ipairs({'left','top','width','height','scale'}) do
                local original=cast[field]
                cast[field]=secretNumber
                cast:Fire('OnShow') -- Cast-ID panel Show invokes this hook.
                assert(cast[field]==secretNumber,'restricted geometry must not be rearranged')
                cast[field]=original
            end
            cast.left=secretNumber
            ns.WindowPositions:Save(cast,'Cast')
            assert(db.windowPositions.Cast==nil,'secret coordinates are not persisted')
            cast.left=100
            local neighbour=CreateFrame()
            neighbour.left=100;neighbour.top=600;neighbour.width=300;neighbour.height=300;neighbour.shown=true
            neighbour.GetAlpha=function() return secretNumber end
            ns.WindowPositions:Track(neighbour)
            cast:Fire('OnShow');near(cast.left,100)
            neighbour.GetAlpha=function() return 1 end
            neighbour.IsVisible=function() return secretNumber end
            cast:Fire('OnShow');near(cast.left,100)
            neighbour.IsVisible=function() return true end
            neighbour.shown=secretNumber
            cast:Fire('OnShow');near(cast.left,100)
            neighbour.shown=true;neighbour.left=secretNumber
            cast:Fire('OnShow');near(cast.left,100)
            neighbour.left=100
            cast:Fire('OnShow')
            assert(cast.left~=100 or cast.top~=600,'public geometry resumes overlap placement')
        ''')


if __name__ == '__main__':
    unittest.main()
