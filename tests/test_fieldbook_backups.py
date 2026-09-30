"""O1: whole-save portability, atomic recovery and real seven-journal reloads."""
import unittest
import zlib

from test_player_names_preservation import full_client


SUPPORT = r'''
    B=ns.FieldbookBackups
    function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
    function disk(v)
        if type(v)=='string' then return string.format('%q',v) end
        if type(v)~='table' then return tostring(v) end
        local rows={};for k,x in pairs(v) do rows[#rows+1]='['..disk(k)..']='..disk(x) end
        return '{'..table.concat(rows,',')..'}'
    end
    function journals(shared)
        local s=shared and AzerothFieldbookAccountDB.sections
        return {
            bestiary=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() end,shared and AzerothFieldbookAccountDB or AzerothFieldbookDB),
            gathering=ns.CreateGatheringJournal(s and s.gathering or AzerothFieldbookGatheringDB),
            atlas=ns.CreateAtlasJournal(s and s.atlas or AzerothFieldbookAtlasDB),
            angling=ns.CreateAnglingJournal(s and s.angling or AzerothFieldbookAnglingDB),
            ledger=ns.CreateLedgerJournal(s and s.ledger or AzerothFieldbookLedgerDB),
            treasure=ns.CreateTreasureJournal(s and s.treasure or AzerothFieldbookTreasureDB),
            lore=ns.CreateLoreJournal(s and s.lore or AzerothFieldbookLoreDB),
        }
    end
    function populate(j,tag)
        local e=j.bestiary:Ensure(42,false,'Forest Lurker',{level=9})
        assert(j.bestiary:SetCreatureNotes(42,tag..' private Bestiary notes'))
        assert(j.bestiary:AddManual(42,'Poison','private observation',123,{Poison=true}))
        local gathering=j.gathering.entries
        gathering['herb:peacebloom']={id='herb:peacebloom',kind='herb',name='Peacebloom',note=tag..' private gather notes',
            interactions=3,completed=2,firstSeen=1,lastSeen=2,zones={Elwynn=true},loot={
                [2447]={name='Peacebloom',minQuantity=1,maxQuantity=2,firstSeen=1,lastSeen=2}},locations={}}
        local p=assert(j.atlas:Save({name=tag..' landmark',category='landmark',mapID=1,zone='Coast',x=1250,y=2500,notes='Private route note'}))
        p=j.atlas.records[p]
        assert(j.atlas:Save({name=tag..' route',category='route',related={p.id,'deleted'},stops={{recordID=p.id,name=p.name}},references={{section='bestiary',key='42',name='Forest Lurker'}}}))
        assert(j.atlas:Save({name=tag..' expedition',related={p.id},notes='Expedition notes'},nil,true))
        local water=assert(j.angling:Ensure('water',{zone='Coast',mapID=1,x=2000,y=3000},'recorded',now))
        assert(j.angling:RecordCatch('catch-'..tag,{waterID=water.id,source='open',association='assigned',method='recorded',at=now},{{itemID=6291,name='Fish',quantity=3}}))
        water.note=tag..' private fishing notes'
        local contact=assert(j.ledger:New(tag..' merchant'));contact.note=tag..' private contact note'
        contact.migrationEvidence={retained={id='former',reference='ledger:former',note='Full original annotations'}}
        j.ledger.db.contactAliases={former=contact.id}
        local kind=assert(j.treasure:Record(nil,{name=tag..' chest',form='world',category='container',note='Private treasure notes'},
            {context='world',location={zone='Coast'},facts={inspected=true},capture='partial',items={{itemID=2001,quantity=3,recovered=1}},note='Historical contents'},'manual'))
        local writing=assert(j.lore:CapturePage({sessionID=tag,identity='item:'..tag,title=tag..' Writing',locale='enUS',sourceKind='item'},
            {number=1,raw='Original |cffff0000source|r\n熊\t100%',method='displayed',personallyViewed=true,first=true,last=true}))
        assert(j.lore:Update(writing.id,{notes=tag..' annotations',theory='Private theory',tags={'private'}}))
        local passage=assert(j.lore:AddPassage(writing.id,{raw='Private passage',origin='manual',nature='annotation'}))
        assert(j.lore:AddLink(writing.id,{section='atlas',id=p.reference,label='Landmark'}))
        assert(j.lore:AddLink(writing.id,{section='treasure',id=kind.reference,label='Chest'}))
        assert(j.lore:AddLink(writing.id,{section='lore',id='lore:99999',label='Missing evidence'}))
        j.lore.state.reading={[writing.id]={source='passage:'..passage.id,scroll=27.5}}
        local source=ns.CreateLoreJournal({});local r=assert(source:Create('writing',{title='Received writing'}))
        assert(source:AddPassage(r.id,{raw='Original source',nature='source',source='Original writer'}))
        local report=assert(ns.LoreReports.Build(source,r.id));report.sender='Courier'
        assert(ns.LoreReports.Accept(j.lore,assert(ns.LoreReports.Prepare(assert(ns.LoreReports.Encode(report))))))
        -- This invalid evidence is deliberately retained outside the active view.
        j.lore.db.entries['invalid-retained']={id='invalid-retained',reports={[true]={raw='Never discard'}}}
        j.treasure.db.encounters['invalid-retained']={id='invalid-retained',note='Never discard'}
        return p,writing
    end
'''


def client(account=False, initialize=True):
    lua = full_client('{version=1,accountWideTracking='+str(account).lower()+'}', initialize=initialize)
    lua.execute(SUPPORT)
    return lua


def reload_client(lua, initialize=True):
    saves = '\n'.join(name+'='+lua.eval('disk('+name+')') for name in [
        'AzerothFieldbookDB','AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB',
        'AzerothFieldbookAtlasDB','AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB',
        'AzerothFieldbookTreasureDB','AzerothFieldbookLoreDB','AzerothFieldbookBackupDB'])
    fresh = client(initialize=False)
    fresh.execute(saves)
    if initialize:
        fresh.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(not ns.InitializationBlocked)")
    return fresh


class WholeFieldbookBackupTests(unittest.TestCase):
    def populated(self):
        lua=client()
        lua.execute("localJ=journals(false);populate(localJ,'Local');AzerothFieldbookDB.accountWideTracking=true")
        lua=reload_client(lua)
        lua.execute("accountJ=journals(true);populate(accountJ,'Shared')")
        return lua

    def test_exact_roundtrip_all_roots_private_fields_and_identity_maps(self):
        lua=self.populated()
        lua.execute(r'''
            AzerothFieldbookDB.unknown={[-2.5]=1/3,[false]='raw\0bytes',utf8='熊'}
            AzerothFieldbookDB.bestiaryBackups={saved={{old='excluded'}}}
            local before=capture();wire=assert(B.Capture());unchanged(before,'capture')
            saved=assert(B.Decode(wire));assert(B.Encode(saved)==wire)
            assert(B.CanRestore(saved));unchanged(before,'decode and preflight')
            for _,name in ipairs(B.roots) do
                local expected=copy(_G[name]);if type(expected)=='table' then expected.bestiaryBackups=nil end
                assert(literal(expected)==literal(saved.stores[name]),name)
            end
            assert(saved.stores.AzerothFieldbookAccountDB.atlasReferenceMaps[1])
            assert(saved.stores.AzerothFieldbookAccountDB.sectionImports.lore[1])
            assert(saved.stores.AzerothFieldbookAccountDB.sections.angling.captureOrigin)
            assert(saved.stores.AzerothFieldbookAccountDB.sections.lore.exportOrigin)
            assert(not saved.stores.AzerothFieldbookDB.bestiaryBackups)
            local summary=B.Summary(saved);assert(summary:find('Lorekeeper',1,true) and summary:find('Treasure',1,true))
        ''')

    def test_atomic_staging_fresh_reload_recovery_and_scope_toggles(self):
        lua=self.populated()
        lua.execute(r'''
            wire=assert(B.Create());saved=assert(B.Decode(wire))
            local j=journals(true)
            assert(j.lore:Create('mystery',{title='After backup'}))
            assert(j.bestiary:SetCreatureNotes(42,'After backup'))
            before=capture();recovery=assert(B.Capture())
            assert(B.RequestRestore(wire));unchanged(before,'staging')
            assert(ns.InitializationBlocked)
            -- Real callbacks cannot apply a staged restore in the same namespace.
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook');unchanged(before,'same namespace')
            assert(AzerothFieldbookBackupDB.pending)
        ''')
        fresh=reload_client(lua)
        fresh.globals().expected=lua.globals().wire
        fresh.execute(r'''
            assert(not AzerothFieldbookBackupDB.pending)
            local restored=assert(B.Decode(expected))
            local current=assert(B.Decode(assert(B.Capture())))
            for _,name in ipairs(B.roots) do
                if name~='AzerothFieldbookDB' and name~='AzerothFieldbookAccountDB' then
                    assert(literal(current.stores[name])==literal(restored.stores[name]),name)
                end
            end
            local acc=AzerothFieldbookAccountDB
            assert(acc.sections.lore.serial==restored.stores.AzerothFieldbookAccountDB.sections.lore.serial+1,'identity high-water mark')
            restored.stores.AzerothFieldbookAccountDB.sections.lore.serial=acc.sections.lore.serial
            assert(literal(acc.sections)==literal(restored.stores.AzerothFieldbookAccountDB.sections))
            assert(literal(acc.atlasReferenceMaps)==literal(restored.stores.AzerothFieldbookAccountDB.atlasReferenceMaps))
            local previous=assert(B.Decode(AzerothFieldbookBackupDB.recovery))
            assert(previous.stores.AzerothFieldbookAccountDB.bestiary.entries[42].idNotes.text=='After backup')
            assert(acc.bestiary.entries[42].idNotes.text=='Shared private Bestiary notes')
            restoredAccount=literal(acc);AzerothFieldbookDB.accountWideTracking=false
        ''')
        off=reload_client(fresh)
        off.globals().expectedAccount=fresh.globals().restoredAccount
        off.execute(r'''
            assert(literal(AzerothFieldbookAccountDB)==expectedAccount,'opt-out changed shared journals')
            assert(ns.ActiveSectionStores.lore==AzerothFieldbookLoreDB)
            assert(AzerothFieldbookDB.bestiary.entries[42].idNotes.text=='Local private Bestiary notes')
            AzerothFieldbookDB.accountWideTracking=true
        ''')
        on=reload_client(off)
        on.globals().expectedAccount=fresh.globals().restoredAccount
        on.execute("assert(literal(AzerothFieldbookAccountDB)==expectedAccount,'reimported restored journals')")
        on.execute("assert(B.RequestRestore(AzerothFieldbookBackupDB.recovery))")
        undone=reload_client(on)
        undone.execute("assert(AzerothFieldbookAccountDB.bestiary.entries[42].idNotes.text=='After backup')")

    def test_fresh_install_and_corrupt_main_recovery_without_normal_startup(self):
        original=self.populated()
        wire=original.eval('assert(B.Capture())')
        for broken in ('nil', "{version=99,raw='KEEP'}", "{version=1,bestiary='KEEP'}"):
            with self.subTest(broken=broken):
                lua=client(initialize=False);lua.globals().wire=wire
                lua.execute('AzerothFieldbookDB='+broken)
                lua.execute(r'''
                    mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    local before=capture()
                    SlashCmdList.AZEROTHFIELDBOOK('backups')
                    assert(AzerothFieldbookWholeBackups:IsShown());unchanged(before,'emergency UI')
                    assert(B.RequestRestore(wire));unchanged(before,'emergency staging')
                ''')
                fresh=reload_client(lua)
                fresh.execute("assert(AzerothFieldbookAccountDB.sections.lore.entries);assert(AzerothFieldbookBackupDB.recovery)")

    def test_bad_import_combat_failed_capture_and_unknown_schemas_are_non_destructive(self):
        lua=self.populated()
        lua.execute(r'''
            good=assert(B.Create());before=capture();archiveBefore=literal(AzerothFieldbookBackupDB)
            local function rejected(text)
                assert(not B.RequestRestore(text));unchanged(before,'rejected restore')
                assert(literal(AzerothFieldbookBackupDB)==archiveBefore)
            end
            rejected(good:sub(1,-2));rejected(good..'x');rejected('print("never execute")')
            combat=true;rejected(good);combat=false
            for _,change in ipairs({
                function(s) s.version=2 end,
                function(s) s.present.AzerothFieldbookLoreDB=nil end,
                function(s) s.stores.AzerothFieldbookAtlasDB.schema=99 end,
                function(s) s.stores.AzerothFieldbookAnglingDB.items='corrupt' end,
                function(s) s.stores.AzerothFieldbookLedgerDB.contacts.bad=false end,
                function(s) s.stores.AzerothFieldbookAccountDB.atlasReferenceMaps[1]='broken' end,
                function(s) s.stores.AzerothFieldbookAccountDB.bestiary.points.version=99 end,
                function(s) s.owner.name='Different character' end,
            }) do
                local s=assert(B.Decode(good));change(s)
                local text=B.Encode(s);if text then rejected(text) end
            end
            local previous=B.Capture;B.Capture=function() return nil,'synthetic failure' end
            rejected(good);B.Capture=previous
            AzerothFieldbookDB.cycle=AzerothFieldbookDB
            assert(not B.Create());assert(literal(AzerothFieldbookBackupDB)==archiveBefore)
            AzerothFieldbookDB.cycle=nil
        ''')

    def test_parser_rejects_duplicate_keys_sparse_envelope_bad_lengths_and_nonfinite(self):
        lua=client()
        payloads=['m2:s1:an1:s1:an2:', 'm1:m0:n1:', 's3:%xx','s99:short',
                  'nNaN:', 'ninf:', 'm999999999999:', 'm0:trailing', ('m1:s1:a'*70)+'z']
        for payload in payloads:
            wire='AFBWB1:'+format(zlib.adler32(payload.encode()), '08x')+':'+payload
            self.assertIsNone(lua.globals().B.Decode(wire)[0], payload)
        lua.execute(r'''
            good=assert(B.Decode(assert(B.Capture())))
            for _,v in ipairs({math.huge,-math.huge,0/0,function() end,coroutine.create(function() end),secret}) do
                good.stores.AzerothFieldbookDB.bad=v;assert(not B.Encode(good))
            end
            good.stores.AzerothFieldbookDB.bad=setmetatable({},{})
            assert(not B.Encode(good))
        ''')

    def test_multipart_out_of_order_duplicates_mixed_truncated_and_all_parts_required(self):
        lua=client()
        lua.execute(r'''
            AzerothFieldbookDB.longPrivate=string.rep('Source text 熊 | %\n',40000)
            local wire=assert(B.Capture());local parts=B.Parts(wire);assert(#parts>4)
            local s={};local before=capture()
            for i=#parts,2,-1 do s=assert(B.AddPart(s,parts[i]));assert(not s.complete) end
            local beforeParts=literal(s);local duplicate=assert(B.AddPart(s,parts[2]))
            assert(literal(s)==beforeParts and duplicate.received==s.received)
            assert(not B.AddPart(s,parts[1]:sub(1,-2)));assert(literal(s)==beforeParts)
            AzerothFieldbookDB.longPrivate='different'
            local other=B.Parts(assert(B.Capture()));assert(not B.AddPart(s,other[1]))
            AzerothFieldbookDB.longPrivate=assert(B.Decode(wire)).stores.AzerothFieldbookDB.longPrivate
            local all=assert(B.AddPart(s,parts[1]));assert(all.complete==wire and not s.complete)
            unchanged(before,'multipart import')
        ''')

    def test_retention_reset_legacy_isolation_and_backup_archive_guards(self):
        lua=self.populated()
        lua.execute(r'''
            local j=journals(true).bestiary
            local old=assert(j:CreateBackup());local oldArchive=j:GetBackups()
            local whole=assert(B.Create())
            for i=1,4 do now=now+1;assert(B.Create()) end
            assert(#AzerothFieldbookBackupDB.saved==2 and AzerothFieldbookBackupDB.saved[1]~=whole)
            local copies=literal(AzerothFieldbookBackupDB)
            j:ResetDatabase();assert(literal(AzerothFieldbookBackupDB)==copies)
            assert(j:GetBackups()==oldArchive and j:RestoreBackup(old))
            assert(not ns.BestiaryBackups.Decode(whole))
            assert(not B.Decode(assert(ns.BestiaryBackups.Encode(old))))
            for _,prefix in ipairs({'AFBLR1:','AFBF1:','AFBL1:','AFBA1:'}) do assert(not B.Decode(prefix..'report')) end
            local corrupt={version=99,saved={whole},evidence='KEEP'}
            AzerothFieldbookBackupDB=corrupt
            local before=capture();assert(not B.Create());assert(not B.RequestRestore(whole))
            assert(AzerothFieldbookBackupDB==corrupt and corrupt.evidence=='KEEP');unchanged(before,'archive refusal')
        ''')

    def test_pending_tampering_startup_failure_and_cancel_leave_original_roots_untouched(self):
        lua=self.populated();lua.execute("assert(B.RequestRestore(assert(B.Create())))")
        for failure in ('corrupt pending','corrupt schema','late initialization'):
            with self.subTest(failure=failure):
                fresh=reload_client(lua,initialize=False)
                if failure=='corrupt pending':
                    fresh.execute("AzerothFieldbookBackupDB.pending=AzerothFieldbookBackupDB.pending:sub(1,-2)")
                elif failure=='corrupt schema':
                    fresh.execute("local s=assert(B.Decode(AzerothFieldbookBackupDB.pending));s.stores.AzerothFieldbookLoreDB.schema=99;AzerothFieldbookBackupDB.pending=assert(B.Encode(s))")
                else:
                    fresh.execute("ns.InitializeLore=function() error('synthetic late startup failure') end")
                fresh.execute(r'''
                    local before=capture()
                    mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
                    assert(ns.InitializationBlocked and AzerothFieldbookBackupDB.pending)
                    unchanged(before,'failed pending startup')
                    local recovery=AzerothFieldbookBackupDB.recovery
                    ns.OpenFieldbookBackups();assert(B.CancelPending())
                    assert(ns.InitializationBlocked and not AzerothFieldbookBackupDB.pending)
                    assert(AzerothFieldbookBackupDB.recovery==recovery)
                    mainEvent(main,'ADDON_LOADED','AzerothFieldbook');unchanged(before,'cancel requires real reload')
                ''')
                resumed=reload_client(fresh)
                resumed.execute("assert(not ns.InitializationBlocked)")

    def test_bestiary_economy_transfers_and_identity_high_water_marks(self):
        lua=self.populated()
        lua.execute(r'''
            local j=journals(true).bestiary;local b=AzerothFieldbookAccountDB.bestiary
            b.points.earned=20
            wire=assert(B.Create())
            b.points.earned=30;b.points.spent=7
            assert(j:ReserveShare('current',2))
            local sharing=j:GetSharingStorage();sharing.sequence=20
            sharing.receipts.keep={received=now,creatureID=42}
            sharing.outgoing={id='current',stage='pending',cost=2,recipient='Someone'}
            AzerothFieldbookAccountDB.nextCharacter=99
            for _,store in pairs(AzerothFieldbookAccountDB.sections) do
                store.serial=999;store.nextID=999;store.referenceSerial=999
            end
            assert(B.RequestRestore(wire))
        ''')
        fresh=reload_client(lua)
        fresh.execute(r'''
            local b=AzerothFieldbookAccountDB.bestiary
            assert(b.points.earned==30 and b.points.spent==7)
            assert(AzerothFieldbookAccountDB.nextCharacter==99)
            for _,store in pairs(AzerothFieldbookAccountDB.sections) do
                assert(store.serial==999 and store.nextID==999 and store.referenceSerial==999)
            end
            local j=journals(true).bestiary;local sharing=j:GetSharingStorage()
            assert(sharing.sequence==20 and sharing.receipts.keep)
            assert(sharing.outgoing.id=='current','must not resurrect snapshot transfer state')
            assert(B.RequestRestore(assert(B.Create())))
        ''')
        again=reload_client(fresh)
        again.execute("assert(AzerothFieldbookAccountDB.bestiary.points.earned==30 and AzerothFieldbookAccountDB.bestiary.points.spent==7)")

    def test_ui_preview_invalidation_partial_import_and_confirmation(self):
        lua=self.populated()
        lua.execute(r'''
            StaticPopupDialogs={};local popup
            function StaticPopup_Show(name,a,b,data) popup={name=name,data=data} end
            function StaticPopup_Hide() popup=nil end
            function ReloadUI() reloadRequested=true end
            local before=capture()
            SlashCmdList.AZEROTHFIELDBOOK('backups');local f=AzerothFieldbookWholeBackups
            unchanged(before,'UI open')
            f.save.scripts.OnClick();assert(f.restore.enabled and f.export.enabled)
            local whole=AzerothFieldbookBackupDB.saved[1]
            f.export.scripts.OnClick();assert(f.text:GetText():sub(1,7)=='AFBWP1:')
            f.text:SetText(f.text:GetText()..'x');assert(not f.restore.enabled)
            f.check.scripts.OnClick();assert(not f.restore.enabled)
            f.import.scripts.OnClick();f.text:SetText(B.Parts(whole)[1]);f.check.scripts.OnClick()
            assert(f.restore.enabled)
            f.restore.scripts.OnClick();local old=popup.data
            f.text:SetText('changed');assert(not f.restore.enabled and not popup)
            StaticPopupDialogs.AZEROTHFIELDBOOK_WHOLE_RESTORE.OnAccept(nil,old)
            assert(not AzerothFieldbookBackupDB.pending and not reloadRequested)
            f.rows[1].scripts.OnClick(f.rows[1]);f.restore.scripts.OnClick()
            StaticPopupDialogs.AZEROTHFIELDBOOK_WHOLE_RESTORE.OnAccept(nil,popup.data)
            assert(AzerothFieldbookBackupDB.pending and reloadRequested and ns.InitializationBlocked)
        ''')

    def test_emergency_ui_raw_scalar_roots_and_retained_callbacks(self):
        lua=client(initialize=False)
        lua.execute(r'''
            AzerothFieldbookDB=false;AzerothFieldbookAccountDB=true
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(ns.InitializationBlocked)
            local before=capture();SlashCmdList.AZEROTHFIELDBOOK('backups')
            assert(AzerothFieldbookWholeBackups:IsShown());unchanged(before,'scalar recovery UI')
            local raw=assert(B.Create());local saved=assert(B.Decode(raw))
            assert(saved.present.AzerothFieldbookDB and saved.stores.AzerothFieldbookDB==false)
            assert(saved.stores.AzerothFieldbookAccountDB==true and not B.CanRestore(saved))
            unchanged(before,'raw scalar backup')
            AzerothFieldbookWholeBackups:Hide();unchanged(before,'emergency UI hide')
        ''')
        lua=self.populated()
        lua.execute(r'''
            local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1)
            local shell=book:GetShell();shell:ShowSection('bestiary',{creatureID=42})
            book:OpenNotes();local notes=AzerothFieldbookCreatureNotes
            local edit=notes.notes.scripts.OnTextChanged
            assert(B.RequestRestore(assert(B.Capture())))
            local before=capture()
            notes.notes:SetText('stale edit');edit(notes.notes)
            for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT',
                'ZONE_CHANGED','LOOT_READY','ITEM_TEXT_READY','PLAYER_LOGOUT'}) do
                mainEvent(main,event,'target');namesEvent(namesFrame,event,'player')
            end
            main.scripts.OnUpdate(main,1);ns.PlayerNames:Format('Someone')
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            unchanged(before,'retained callbacks during restore hold')
        ''')

    def test_preview_releases_decoded_data_and_hidden_window_buffers(self):
        lua=self.populated()
        lua.execute(r'''
            local decode=B.Decode;local weak=setmetatable({},{__mode='v'})
            B.Decode=function(...) local s,e=decode(...);weak[1]=s;return s,e end
            ns.OpenFieldbookBackups();local f=AzerothFieldbookWholeBackups
            f.save.scripts.OnClick();f.export.scripts.OnClick();assert(f.text:GetText()~='')
            f:Hide();collectgarbage('collect');collectgarbage('collect')
            assert(not weak[1] and f.text:GetText()=='' and not f.restore.enabled)
            for _,row in ipairs(f.rows) do assert(not row.backup) end
        ''')

    def test_received_report_identities_receipts_and_reimports_survive_recovery(self):
        lua=self.populated()
        lua.execute(r'''
            local j=journals(true)
            local a=ns.CreateAnglingJournal({})
            local water=assert(a:Ensure('water',{zone='Report waters'},'recorded',now))
            assert(a:RecordCatch('report-catch',{waterID=water.id,source='open',association='assigned',method='recorded',at=now},
                {{itemID=6291,name='Fish',quantity=5}}))
            local fish=next(a.db.items)
            fishing=assert(ns.AnglingReports.Encode(assert(ns.AnglingReports.Build(a,fish,'personal',true))))
            assert(ns.AnglingReports.Accept(j.angling,assert(ns.AnglingReports.Prepare(fishing))))
            local l=ns.CreateLedgerJournal({});local contact=assert(l:Manual({name='Original source contact'}))
            assert(l:Annotate(contact.id,'Original source note','merchant'))
            ledger=assert(ns.LedgerReports.Encode(assert(ns.LedgerReports.Build(l,contact.id,{notes=true}))))
            assert(ns.LedgerReports.Accept(j.ledger,assert(ns.LedgerReports.Prepare(ledger))))
            local t=ns.CreateTreasureJournal({})
            local kind=assert(t:Record(nil,{name='Reported chest',form='world',category='container'},
                {context='world',location={zone='Coast'},facts={inspected=true},capture='partial',
                    items={{itemID=2001,quantity=3}},note='Observed contents'},'manual'))
            treasure=assert(ns.TreasureReports.Build(t,kind.id,{notes=true}))
            assert(ns.TreasureReports.Accept(j.treasure,assert(ns.TreasureReports.Prepare(treasure))))
            wire=assert(B.Create());expected=literal(AzerothFieldbookAccountDB.sections)
            assert(B.RequestRestore(wire))
        ''')
        fresh=reload_client(lua)
        fresh.globals().expected=lua.globals().expected
        fresh.globals().fishing=lua.globals().fishing
        fresh.globals().ledger=lua.globals().ledger
        fresh.execute('treasure='+lua.eval('disk(treasure)'))
        fresh.execute(r'''
            assert(literal(AzerothFieldbookAccountDB.sections)==expected)
            local j=journals(true);local A=ns.Atlas
            local facts,contacts,encounters=A.Count(j.angling.db.reported),A.Count(j.ledger.db.contacts),A.Count(j.treasure.db.encounters)
            assert(ns.AnglingReports.Accept(j.angling,assert(ns.AnglingReports.Prepare(fishing))))
            assert(ns.LedgerReports.Accept(j.ledger,assert(ns.LedgerReports.Prepare(ledger))))
            assert(ns.TreasureReports.Accept(j.treasure,assert(ns.TreasureReports.Prepare(treasure))))
            assert(A.Count(j.angling.db.reported)==facts and A.Count(j.ledger.db.contacts)==contacts and A.Count(j.treasure.db.encounters)==encounters)
        ''')

    def test_backup_before_account_import_cannot_replay_imports_or_knowledge(self):
        lua=client()
        lua.execute(r'''
            local j=journals(false);populate(j,'Before account mode')
            AzerothFieldbookDB.bestiary.points.earned=10
            wire=assert(B.Create());assert(not AzerothFieldbookDB.accountTrackingKey)
            AzerothFieldbookDB.accountWideTracking=true
        ''')
        migrated=reload_client(lua)
        migrated.globals().wire=lua.globals().wire
        migrated.execute(r'''
            assert(AzerothFieldbookDB.accountTrackingKey==1)
            assert(AzerothFieldbookAccountDB.bestiary.points.earned==10)
            -- Simulate markers owned by another character whose local files
            -- remain offline and cannot be part of this character's export.
            AzerothFieldbookAccountDB.nextCharacter=2
            AzerothFieldbookAccountDB.importedCharacters[2]=true
            for _,markers in pairs(AzerothFieldbookAccountDB.sectionImports) do markers[2]=true end
            assert(B.RequestRestore(wire))
        ''')
        restored=reload_client(migrated)
        restored.execute(r'''
            assert(AzerothFieldbookDB.accountTrackingKey==1)
            assert(AzerothFieldbookAccountDB.importedCharacters[1] and AzerothFieldbookAccountDB.importedCharacters[2])
            assert(AzerothFieldbookAccountDB.bestiary.points.earned==10)
            assert(next(AzerothFieldbookLoreDB.entries),'retained character knowledge restored')
            AzerothFieldbookDB.accountWideTracking=true
        ''')
        shared=reload_client(restored)
        shared.execute(r'''
            assert(AzerothFieldbookAccountDB.bestiary.points.earned==10,'restoring pre-import backup repeated Knowledge')
            assert(not next(AzerothFieldbookAccountDB.sections.lore.entries),'replayed character import')
            assert(next(AzerothFieldbookLoreDB.entries),'local journal discarded')
            AzerothFieldbookDB.accountTrackingKey=2
        ''')
        other=reload_client(shared)
        other.execute(r'''
            assert(AzerothFieldbookAccountDB.bestiary.points.earned==10)
            assert(not next(AzerothFieldbookAccountDB.sections.lore.entries),'replayed offline character import')
        ''')


if __name__=='__main__':
    unittest.main()
