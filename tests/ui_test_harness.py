"""Reusable widget host. It checks control flow, not native WoW rendering."""
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def new_ui_client(modules=()):
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().buildVersion=re.search(r'^## Version: (\S+)', (ROOT/'AzerothFieldbook.toc').read_text(encoding='utf-8'), re.MULTILINE).group(1)
    lua.execute(r'''
    ns,objects,UISpecialFrames={},{},{}
    secret={}; now=1000000; combat=false; chatState=0; npcID=42; playerName='Alice Sunstrider'
    playerSurname=nil
    function issecretvalue(value) return rawequal(value,secret) end
    function time() return now end
    function InCombatLockdown() return combat end
    function UnitName(unit) if unit=='player' then return playerName,playerSurname end; return 'Creature '..npcID end
    function UnitNameUnmodified(unit) return UnitName(unit) end
    -- Forever's Camelot helper, unlike retail, preserves the surname.
    NameUtil={GetFullNameWithoutRealm=function(first,surname)
        if first and first~='' and surname and surname~='' then return first..' '..surname end
        return first
    end}
    function UnitCreatureType() return 'Humanoid' end
    function UnitLevel() return 9 end
    function UnitGUID() return 'Creature-0-1-2-3-'..npcID..'-1' end
    function UnitIsDead() return false end
    function GetNormalizedRealmName() error('sharing must not require a realm') end
    function GetRealmName() error('sharing must not require a realm') end
    function GetRealZoneText() return 'Elwynn' end
    metadataVersion=buildVersion
    C_AddOns={GetAddOnMetadata=function(addon,field)
        assert(addon=='AzerothFieldbook' and field=='Version');return metadataVersion
    end}
    Enum={RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1,InvalidPrefix=2,MaxPrefixes=3},
        SendAddonMessageResult={Success=0,AddonMessageThrottle=3,ChannelThrottle=8,AddOnMessageLockdown=11,TargetOffline=12},
        AddOnRestrictionType={Chat=5},AddOnRestrictionState={Inactive=0,Activating=1,Active=2}}
    C_RestrictedActions={GetAddOnRestrictionState=function(kind) assert(kind==5); return chatState end}
    local methods={}
    function methods:SetScript(event,fn)
        self.scripts[event]=fn
        if fn and (event=='OnMouseDown' or event=='OnMouseUp' or event=='OnEnter' or event=='OnLeave') then
            self:EnableMouse(true) -- WoW mouse scripts implicitly enable mouse input.
        end
    end
    function methods:HookScript(event,fn)
        local previous=self.scripts[event]
        self:SetScript(event,function(self,...)
            if previous then previous(self,...) end
            fn(self,...)
        end)
    end
    function methods:EnableMouse(value) self.mouseClick=value; self.mouseMotion=value end
    function methods:EnableMouseWheel(value) self.mouseWheel=value end
    function methods:IsMouseEnabled() return self.mouseClick or self.mouseMotion end
    function methods:IsMouseClickEnabled() return self.mouseClick end
    function methods:IsMouseMotionEnabled() return self.mouseMotion end
    function methods:SetMouseClickEnabled(value) self.mouseClick=value end
    function methods:SetMouseMotionEnabled(value) self.mouseMotion=value end
    function methods:SetText(text)
        assert(type(text)=='string' or type(text)=='number','UI received nonliteral text: '..type(text))
        self.text=tostring(text)
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function methods:GetText() return rawget(self,'text') or '' end
    function methods:SetSize(w,h) self.width=w;self.height=h end
    function methods:SetWidth(w) self.width=w end
    function methods:SetHeight(h) self.height=h end
    function methods:SetPoint(...)
        self.point={...};self.points=self.points or {};self.points[#self.points+1]=self.point
    end
    function methods:ClearAllPoints() self.point=nil;self.points={} end
    function methods:SetAlpha(value) self.alpha=value end
    function methods:SetTextColor(...) self.textColor={...} end
    function methods:SetTexCoord(...) self.texCoord={...} end
    function methods:GetPoint() return unpack(self.point or {'CENTER',UIParent,'CENTER',0,0}) end
    function methods:GetName() return self.name end
    function methods:GetLeft() return self.left end
    function methods:GetTop() return self.top end
    function methods:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
    function methods:GetWidth() return rawget(self,'width') or 100 end
    function methods:GetHeight() return rawget(self,'height') or 100 end
    function methods:GetStringHeight() return math.max(14,math.ceil(#self:GetText()/math.max(1,math.floor(self:GetWidth()/7)))*14) end
    function methods:SetHorizontalScroll(value) self.horizontalScroll=value end
    function methods:GetStringWidth()
        local text=self:GetText():gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        local _,characters=text:gsub('[^\128-\191]','')
        return characters*6
    end
    function methods:SetIndentedWordWrap(value) self.indentedWrap=value end
    function methods:GetFrameLevel() return rawget(self,'frameLevel') or 10 end
    function methods:SetFrameLevel(value) self.frameLevel=value end
    function methods:SetFrameStrata(value) self.strata=value end
    function methods:SetToplevel(value) self.toplevel=value end
    function methods:Raise() focusedWindow=self end
    function methods:GetChildren()
        local children={}
        for _,object in ipairs(objects) do
            if object.parent==self and object.kind~='Texture' and object.kind~='FontString' then
                children[#children+1]=object
            end
        end
        return unpack(children)
    end
    function methods:Show() self.shown=true end
    function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function methods:SetShown(v) self.shown=v end
    function methods:IsShown() return self.shown end
    function methods:SetEnabled(v) self.enabled=v end
    function methods:SetChecked(v) self.checked=v end
    function methods:GetChecked() return self.checked end
    function methods:SetScale(v) self.scale=v end
    function methods:GetScale() return rawget(self,'scale') or 1 end
    function methods:SetClampedToScreen(v) self.clamped=v end
    function methods:SetFocus() self.focus=true end
    function methods:ClearFocus() self.focus=false end
    function methods:SetVerticalScroll(v) self.scroll=v end
    function methods:GetVerticalScroll() return rawget(self,'scroll') or 0 end
    function methods:GetVerticalScrollRange() return 0 end
    function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
    function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
    function CreateFrame(kind,name,parent,template)
        local f={kind=kind,name=name,parent=parent,scripts={},shown=true,enabled=true}
        local interactive=kind=='Button' or kind=='CheckButton' or kind=='EditBox' or kind=='Slider'
        f.mouseClick=interactive; f.mouseMotion=interactive
        setmetatable(f,{__index=function(_,k)
            if methods[k] then return methods[k] end
            if k:match('^%u') then return function() end end
        end})
        objects[#objects+1]=f; if name then _G[name]=f end
        if template=='UIPanelScrollFrameTemplate' then
            f.ScrollBar=CreateFrame('Slider',nil,f)
            f.ScrollBar:SetWidth(16)
            f.ScrollBar.ScrollUpButton=CreateFrame('Button',nil,f.ScrollBar)
            f.ScrollBar.ScrollDownButton=CreateFrame('Button',nil,f.ScrollBar)
            f.ScrollBar.ScrollUpButton:SetSize(16,16)
            f.ScrollBar.ScrollDownButton:SetSize(16,16)
        end
        return f
    end
    function CreateFont(name)
        local font={}
        function font:CopyFontObject() end
        function font:GetFont() return 'test-font',12,'' end
        function font:SetFont(path,size,flags) self.size=size end
        _G[name]=font
        return font
    end
    UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080)
    function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
    function plain(text) return text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
    ''')
    for name in modules:
        lua.execute((ROOT/name).read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
    return lua
