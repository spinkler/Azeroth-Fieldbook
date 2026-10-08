"""Bounded native model allocation and fresh-setter ownership regressions.

The fake renderer deliberately delivers old native completions to the current
handler on ONE frame; Lua tokens alone cannot make these assertions pass.
Native visual/timing behavior still needs the owner-operated WoW check.
"""
import unittest
from test_bestiary_models import new_ui_client

FILES = ['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
         'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
         'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua']


class BestiaryModelReuseTests(unittest.TestCase):
    def client(self):
        lua = new_ui_client(FILES)
        lua.execute('''
            function SetPortraitTexture(texture,unit) texture:SetTexture(npcID) end
            function SetPortraitTextureFromCreatureDisplayID(texture,id) texture:SetTexture(id) end
            function modelSetup(frame) frame.complete=true end
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            c=ns.CreateBestiaryBook(j);c:OpenAtUnit('target')
            section=AzerothFieldbookBestiarySection;model=section.model
            assert(model.alpha==1 and not section.modelPending)
        ''')
        return lua

    def test_distinct_entries_revisits_delete_repopulate_and_reset_keep_one_frame(self):
        lua = self.client()
        lua.execute('''
            local instance=1
            function UnitGUID() return 'Creature-0-1-2-3-'..npcID..'-'..instance end
            local function countModels()
                local count=0
                for _,frame in ipairs(objects) do
                    if frame.kind=='PlayerModel' then count=count+1 end
                end
                return count
            end
            assert(countModels()==1)
            for cycle=1,3 do
                for id=1,60 do
                    npcID=cycle*1000+id;c:OpenAtUnit('target')
                    assert(section.model==model and model.scene==npcID and model.alpha==1)
                    assert(section.portrait:GetTexture()==npcID*100)
                end
                assert(countModels()==1,'distinct entries retained extra native models')
                for id=1,60 do
                    npcID=cycle*1000+id;c:OpenAtUnit('target')
                    assert(model.scene==npcID and model.alpha==1)
                    assert(j:DeleteEntry(npcID));c:Refresh()
                    assert(model.alpha==0 and not model:IsShown())
                    model:LoadScene(npcID);model.scripts.OnModelLoaded(model)
                    assert(model.alpha==0 and model.scene==nil,'deleted entry reappeared')
                end
                instance=instance+1 -- A fresh encounter after leaving the deleted target.
                npcID=cycle*1000+60;c:OpenAtUnit('target')
                assert(model.scene==npcID and model.alpha==1)
                j:Reset();c:Refresh()
                model:LoadScene(npcID);model.scripts.OnModelLoaded(model)
                assert(model.alpha==0 and model.scene==nil)
                assert(countModels()==1,'delete/repopulate/reset retained extra native models')
            end
        ''')

    def test_clear_callbacks_and_getters_without_setter_completion_cannot_authorize(self):
        lua = self.client()
        lua.execute('''
            function model:ClearModel()
                -- Simulate old scene notification during clear; even valid
                -- getters here must not count as a new setter completion.
                self:LoadScene(41);self.scripts.OnModelLoaded(self)
                self.scene=nil;self.file=nil
            end
            function model:SetCreature(id) self:LoadScene(id) end
            c:OpenAtUnit('target')
            assert(model.alpha==0 and section.modelPending)
            model.scripts.OnModelLoaded(model)
            assert(model.alpha==0 and section.modelPending)
            assert(section.portrait:GetTexture()==42,'unverified display used for portrait')
            function model:SetCreature(id)
                -- An outgoing notification before a new scene exists is not
                -- sufficient, even when getters are populated before return.
                self.scripts.OnModelLoaded(self);self:LoadScene(id)
            end
            model.scripts.OnUpdate(model,.5)
            assert(model.alpha==0 and section.modelPending)
            function model:SetCreature(id) self:LoadScene(id);self.scripts.OnModelLoaded(self) end
            model.scripts.OnUpdate(model,.5)
            assert(model.alpha==1 and not section.modelPending and model.scene==42)
        ''')

    def test_failed_or_unreadable_verification_stays_concealed(self):
        lua = self.client()
        lua.execute('''
            local clear=model.ClearModel
            local getDisplay=model.GetDisplayInfo
            local getFile=model.GetModelFileID
            for _,case in ipairs({'false','error','secretReturn','nilDisplay','zeroDisplay',
                'secretDisplay','errorDisplay','nilFile','zeroFile','secretFile','errorFile',
                'fileChanged','displayChanged','uncleared','clearError'}) do
                model.ClearModel=clear;model.GetDisplayInfo=getDisplay;model.GetModelFileID=getFile
                function model:SetCreature(id)
                    self:LoadScene(id);self.scripts.OnModelLoaded(self)
                    if case=='false' then return false end
                    if case=='error' then error('setter unavailable') end
                    if case=='secretReturn' then return secret end
                    if case=='fileChanged' then self.file=999 end
                    if case=='displayChanged' then self.display=999 end
                end
                if case=='nilDisplay' then function model:GetDisplayInfo() end end
                if case=='zeroDisplay' then function model:GetDisplayInfo() return 0 end end
                if case=='secretDisplay' then function model:GetDisplayInfo() return secret end end
                if case=='errorDisplay' then function model:GetDisplayInfo() error('restricted') end end
                if case=='nilFile' then function model:GetModelFileID() end end
                if case=='zeroFile' then function model:GetModelFileID() return 0 end end
                if case=='secretFile' then function model:GetModelFileID() return secret end end
                if case=='errorFile' then function model:GetModelFileID() error('restricted') end end
                if case=='uncleared' then function model:ClearModel() end end
                if case=='clearError' then function model:ClearModel() error('clear unavailable') end end
                c:OpenAtUnit('target')
                assert(model.alpha==0 and section.modelPending,case..' revealed model')
                assert(section.portrait:GetTexture()==42,case..' copied unverified display')
            end
        ''')

    def test_asynchronous_verification_has_bounded_work_and_later_recovers(self):
        lua = self.client()
        lua.execute('''
            local requests=0
            function model:SetCreature(id) requests=requests+1;self:LoadScene(id) end
            c:OpenAtUnit('target');assert(requests==1)
            for i=1,100 do model.scripts.OnModelLoaded(model) end
            assert(requests==2 and model.alpha==0 and section.modelPending)
            model.scripts.OnUpdate(model,.5);assert(requests==3)
            for i=1,100 do model.scripts.OnModelLoaded(model) end
            assert(requests==4 and model.alpha==0)
            function model:SetCreature(id)
                requests=requests+1;self:LoadScene(id);self.scripts.OnModelLoaded(self)
            end
            model.scripts.OnUpdate(model,.5)
            assert(requests==6 and model.alpha==1 and not section.modelPending)
        ''')

    def test_live_display_zero_uses_unit_portrait_and_changed_guid_falls_back(self):
        lua = self.client()
        lua.execute('''
            local fallback=0;local units=0
            local creature=model.SetCreature
            function model:SetCreature(id) fallback=fallback+1;creature(self,id) end
            function model:SetUnit(unit)
                units=units+1;self:LoadScene(npcID,0);self.scripts.OnModelLoaded(self)
                -- Native nil return must be accepted as well as true.
            end
            local portrait=SetPortraitTextureFromCreatureDisplayID
            function SetPortraitTextureFromCreatureDisplayID(texture,id)
                assert(id>0,'display zero is not an appearance ID');portrait(texture,id)
            end
            c:OpenAtUnit('target')
            assert(units==2 and fallback==0 and model.alpha==1)
            assert(section.portrait:GetTexture()==42)
            npcID=43;model:LoadScene(42,0);model.scripts.OnModelLoaded(model)
            assert(units==2 and fallback==1 and model.scene==42 and model.alpha==1)
            assert(section.portrait:GetTexture()==4200)
            -- Same creature ID with a different instance GUID also invalidates
            -- the captured unit request; do not borrow its live appearance.
            npcID=42;c:OpenAtUnit('target')
            function UnitGUID() return 'Creature-0-1-2-3-42-OTHER' end
            model.scripts.OnModelLoaded(model)
            assert(units==4 and fallback==2 and model.scene==42)
        ''')

    def test_live_guid_change_inside_setter_and_initialization_gate(self):
        lua = self.client()
        lua.execute('''
            local swaps=0
            function model:SetUnit(unit)
                self:LoadScene(42,0);self.scripts.OnModelLoaded(self)
                swaps=swaps+1;npcID=43;return true
            end
            c:OpenAtUnit('target')
            assert(swaps==1 and model.scene==42 and model.alpha==1)
            assert(section.portrait:GetTexture()==4200,'changed token became portrait source')
            ns.InitializationBlocked=true
            model:LoadScene(43);model.scripts.OnModelLoaded(model)
            assert(model.alpha==0 and model.scene==nil)
            local count=swaps;model.scripts.OnUpdate(model,60)
            assert(swaps==count)
        ''')

    def test_same_model_file_variants_rotation_and_scene_identity(self):
        lua = self.client()
        lua.execute('''
            local variant=0
            function model:SetCreature(id)
                variant=variant+1;self:LoadScene(id,id*100+variant);self.file=125512
                self.scripts.OnModelLoaded(self)
            end
            function model:SetRotation(value) self.rotation=value end
            c:OpenAtUnit('target')
            assert(model.alpha==1 and section.portrait:GetTexture()==4202)
            local x=100
            function GetCursorPosition() return x,0 end
            model.scripts.OnMouseDown(model);x=120;model.scripts.OnUpdate(model,.01)
            model.scripts.OnMouseUp(model)
            local rotation=model.rotation;assert(rotation and rotation~=math.rad(25))
            model:LoadScene(41,4100);model.file=125512;model.scripts.OnModelLoaded(model)
            assert(model.scene==42 and model.alpha==1 and model.rotation==rotation)
            assert(section.portrait:GetTexture()==4203,'variants must follow verified setter')
            npcID=43;c:OpenAtUnit('target')
            assert(model.scene==43 and model.alpha==1 and model.rotation==math.rad(25))
            assert(section.portrait:GetTexture()==4305)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
