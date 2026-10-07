"""A7 probe isolation and bounds, not proof of native renderer semantics."""
import unittest
from ui_test_harness import new_ui_client, ROOT
from kill_test_harness import new_client


class ModelProbeTests(unittest.TestCase):
    def client(self):
        lua = new_ui_client(['BestiaryModelProbe.lua'])
        lua.execute('''
            book={detail=CreateFrame('Frame'),modelEntryID=42,modelPersonal=true,modelPending=true}
            book.model=CreateFrame('PlayerModel',nil,book.detail)
            book.model.afbEntryID=42
            function book.model:GetDisplayInfo() return 4200 end
            function book.model:GetModelFileID() return 42 end
            function GetTime() return now end
            p=ns.BestiaryModelProbe
        ''')
        return lua

    def test_disabled_probe_has_no_frames_or_loads_and_one_frame_is_reused(self):
        lua = self.client()
        lua.execute('''
            local count=#objects
            p:Select(book,42,true);p:Request(book,'SetCreature',42)
            assert(#objects==count and not p.model and #p.rows==0)
            p:SetEnabled(true);p:Select(book,42,true);p:Request(book,'SetCreature',42)
            local model=p.model
            assert(#objects==count+1 and model.alpha==0 and not model:IsMouseEnabled())
            for i=1,1000 do
                book.modelEntryID=i;p:Select(book,i,true);p:Request(book,'SetCreature',i)
            end
            assert(#objects==count+1 and #p.rows==240)
            assert(book.model.afbEntryID==42 and book.modelPending)
            p:SetEnabled(false)
            local rows=#p.rows
            model.scripts.OnModelLoaded(model,secret);model.scripts.OnUpdate(model,1)
            assert(not model:IsShown() and #p.rows==rows and p.book==nil)
            p:SetEnabled(true);book.modelEntryID=42
            p:Select(book,42,true);p:Request(book,'SetCreature',42)
            assert(#objects==count+1 and p.model==model)
            assert(p:Report():find('Probe frames: 1',1,true))
        ''')

    def test_sync_nil_false_errors_and_late_callbacks_are_observed_without_authorizing_view(self):
        lua = self.client()
        lua.execute('''
            p:SetEnabled(true);p:Select(book,42,true);p:Request(book,'SetCreature',42)
            local model=p.model
            function model:GetDisplayInfo() return self.display end
            function model:GetModelFileID() return self.file end
            function model:SetCreature(id)
                self.display=id*100;self.file=id
                self.scripts.OnModelLoaded(self,'native argument',nil)
            end
            p:Request(book,'SetCreature',42)
            assert(p:Report():find('probe callback | 2 | 42 | true | 4200 | 42',1,true))
            assert(p:Report():find('setter return: ok/value | true | <nil>',1,true))
            function model:SetUnit() return false end
            p:Request(book,'SetUnit','target')
            assert(p:Report():find('setter return: ok/value | true | false',1,true))
            function model:SetUnit() error('PRIVATE ERROR') end
            p:Request(book,'SetUnit','target')
            assert(p:Report():find('setter return: ok/value | false | <error>',1,true))
            book.modelEntryID=43;p:Select(book,43,true)
            model.display=4200;model.file=42;model.scripts.OnModelLoaded(model)
            assert(p:Report():find('probe callback | 4 | 43 | false | 4200 | 42',1,true))
            assert(book.modelPending and book.model.afbEntryID==42)
            assert(model.alpha==0,'probe must never display its scene')
            assert(not p:Report():find('PRIVATE ERROR',1,true))
            for i=1,20 do model.scripts.OnUpdate(model,0.2) end
            local rows=#p.rows;model.scripts.OnUpdate(model,60)
            assert(#p.rows==rows,'settled observations must stop')
        ''')

    def test_restricted_getters_callback_args_and_encounter_hold_guards(self):
        lua = self.client()
        lua.execute('''
            p:SetEnabled(true);book.modelPersonal=false
            p:Select(book,42,false);p:Request(book,'SetCreature',42)
            assert(not p.model,'report-only entry cannot query an appearance')
            book.modelPersonal=true;ns.InitializationBlocked=true
            p:Request(book,'SetCreature',42);assert(not p.model)
            ns.InitializationBlocked=false;p:Request(book,'SetCreature',42)
            local model=p.model
            function model:GetDisplayInfo() return secret end
            function model:GetModelFileID() error('PRIVATE ERROR') end
            function GetTime() return secret end
            model.scripts.OnModelLoaded(model,secret)
            p:Reference(book,book.model,secret)
            local report=p:Report()
            assert(report:find('<restricted>',1,true) and report:find('<error>',1,true))
            assert(not report:find('PRIVATE ERROR',1,true))
            p:Select(book,42,false);assert(not model:IsShown())
        ''')

    def test_verification_reissues_latest_selection_and_does_not_trust_old_display(self):
        lua = self.client()
        lua.execute('''
            p:SetEnabled(true,true);p:Select(book,42,true);p:Request(book,'SetCreature',42)
            local model=p.model
            function model:GetDisplayInfo() return self.display end
            function model:GetModelFileID() return self.file end
            function model:ClearModel() self.file=nil end -- Native display survives clear.
            function model:SetCreature(id)
                self.display=id*100;self.file=id
                self.scripts.OnModelLoaded(self)
            end
            model.display=4100;model.file=41;model.scripts.OnModelLoaded(model)
            assert(model.display==4200 and model.file==42 and model.alpha==0)
            assert(p:Report():find('verification result: entry/method/sync/display/file/candidate | 42 | SetCreature | true | 4200 | 42 | true',1,true))
            book.modelEntryID=43;p:Select(book,43,true);p:Request(book,'SetCreature',43)
            model.display=4200;model.file=42;model.scripts.OnModelLoaded(model)
            assert(model.display==4300 and model.file==43 and model.alpha==0)
            assert(book.model.afbEntryID==42 and book.modelPending)
        ''')

    def test_verification_ignores_clear_callbacks_and_caps_asynchronous_loops(self):
        lua = self.client()
        lua.execute('''
            p:SetEnabled(true,true);p:Select(book,42,true);p:Request(book,'SetCreature',42)
            local model=p.model
            function model:GetDisplayInfo() return 4100 end
            function model:GetModelFileID() return self.file end
            function model:ClearModel() self.file=nil;self.scripts.OnModelLoaded(self) end
            local calls=0
            function model:SetCreature(id) calls=calls+1;self.file=id end -- Always completes later.
            for i=1,20 do model.scripts.OnModelLoaded(model) end
            assert(calls==3 and p.verifyAttempts==3 and model.alpha==0)
            assert(p:Report():find('verification attempt limit | 42',1,true))
            assert(p:Report():find('verification result: entry/method/sync/display/file/candidate | 42 | SetCreature | false | 4100 | 42 | false',1,true))
            book.modelEntryID=43;p:Select(book,43,true)
            model.scripts.OnModelLoaded(model);assert(calls==3,'No stale request between selections')
        ''')

    def test_verification_rechecks_live_guid_and_falls_back_to_current_creature(self):
        lua = self.client()
        lua.execute('''
            p:SetEnabled(true,true);p:Select(book,42,true);p:Request(book,'SetUnit','target')
            local model=p.model
            function model:GetDisplayInfo() return self.display end
            function model:GetModelFileID() return self.file end
            function model:ClearModel() self.file=nil end
            function model:SetUnit(unit) error('Changed unit must not be reused') end
            function model:SetCreature(id)
                assert(id==42);self.display=4200;self.file=42
                self.scripts.OnModelLoaded(self)
            end
            npcID=43;model.scripts.OnModelLoaded(model)
            assert(p:Report():find('verification result: entry/method/sync/display/file/candidate | 42 | SetCreature | true | 4200 | 42 | true',1,true))
            assert(model.alpha==0)
        ''')


    def test_book_integration_keeps_production_frames_and_faults_isolated(self):
        lua = new_ui_client(['SharingReport.lua','BestiaryJournal.lua','Scrollbars.lua',
            'ActionButtons.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua',
            'FieldbookShell.lua','BestiaryPages.lua','BestiaryModelProbe.lua','BestiaryBook.lua'])
        lua.execute('''
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            c=ns.CreateBestiaryBook(j);c:OpenAtUnit('target')
            local section=AzerothFieldbookBestiarySection
            local original=section.model
            p=ns.BestiaryModelProbe;assert(not p.model)
            p:SetEnabled(true);c:OpenAtUnit('target')
            assert(p.model and p.model~=section.model and section.model==original)
            npcID=43;c:OpenAtUnit('target')
            assert(section.model==original and section.model.afbEntryID==43)
            function original:GetDisplayInfo() return 4200 end
            original.scripts.OnModelLoaded(original)
            assert(section.modelPending and original.alpha==0)
            function p:Request() error('probe failure') end
            function section.model:ClearModel() self.file=nil end
            function section.model:GetModelFileID() return self.file end
            function section.model:SetCreature() self.file=43;self.scripts.OnModelLoaded(self) end
            function section.model:GetDisplayInfo() return 4300 end
            c:OpenAtUnit('target')
            assert(not section.modelPending and section.model.alpha==1)
        ''')

    def test_slash_dispatch_enables_reports_and_disables(self):
        lua = new_client(diagnostics=True)
        lua.execute((ROOT/'BestiaryModelProbe.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
        lua.execute('''
            SlashCmdList.AZEROTHFIELDBOOK('debug bestiary model on')
            assert(ns.BestiaryModelProbe.enabled and not ns.BestiaryModelProbe.model)
            SlashCmdList.AZEROTHFIELDBOOK('debug bestiary model')
            assert(copiedReport:find('A7 model reuse probe v2',1,true))
            SlashCmdList.AZEROTHFIELDBOOK('debug bestiary model verify')
            assert(ns.BestiaryModelProbe.verify and ns.BestiaryModelProbe.enabled)
            SlashCmdList.AZEROTHFIELDBOOK('debug bestiary model off')
            assert(not ns.BestiaryModelProbe.enabled)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
