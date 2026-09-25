"""Literal portable backups, restore accounting, recovery and saved-variable scopes."""
from pathlib import Path
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def client():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        ns={};now=1790300000;combat=false
        function time() return now end
        function UnitName() return 'Alice Sunstrider' end
        function InCombatLockdown() return combat end
        C_AddOns={GetAddOnMetadata=function() return '0.9.76' end}
        function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
    ''')
    for filename in ['SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryJournal.lua', 'Tracking.lua', 'Sharing.lua']:
        lua.execute((ROOT / filename).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        function fresh(account)
            local db={accountWideTracking=account==true}
            local store=account and ns.InitializeTracking(db) or db
            local j=ns.CreateBestiaryJournal(db,function() return 42 end,store)
            local e=j:Ensure(42,false,'Forest Lurker')
            e.category='Beast';e.levelMin=10;e.levelMax=11;e.locations['Loch Modan']=true
            assert(j:AddManual(42,'Poison','A note',nil,{Poison=true}))
            assert(j:AddDamage(42,10,4,7,11))
            assert(j:AddNoteSpell(42,'123'))
            assert(j:SetCreatureNotes(42,'Personal notes'))
            return j,db,store,e
        end
    ''')
    return lua


class BackupTests(unittest.TestCase):
    def test_round_trip_full_records_and_unicode(self):
        lua = client()
        lua.execute('''
            local j,db,store,e=fresh()
            e.tameable=true;e.tameabilitySource='gameTooltip'
            e.unchangedKills=9;e.rank='Rare'
            e.idNotes.text='Line 1\\nUnicode: Élan • 熊\\t100% :()[]'
            j:Offer(42,'Roar','Automatic observation',456)
            j:SetAbility(42,'Roar','rejected')
            e.ignoredAbilities={Ignored=true}
            e.sharedReports={{creatureID=42,name='Forest Lurker',category='Beast',locations={'Duskwood'},sender='Bob',received=now}}
            e.rumours={{kind='ability',value='Bite',sender='Bob',rejected=true,dismissed=true}}
            store.bestiary.creatures[42]={spells={[456]={name='Roar'}},names={Poison=true}}
            j:SetEntryConfirmed(42,true)
            local snapshot=assert(j:CreateBackup())
            local encoded=assert(ns.BestiaryBackups.Encode(snapshot))
            assert(not encoded:find('[|%s]'),'clipboard text has no markup or whitespace')
            local decoded=assert(ns.BestiaryBackups.Decode('  '..encoded..'\\n'))
            eq(ns.BestiaryBackups.Encode(decoded),encoded)
            eq(decoded.bestiary.entries[42].idNotes.text,e.idNotes.text)
            assert(decoded.bestiary.entries[42].confirmed and decoded.bestiary.entries[42].tameable)
            eq(decoded.bestiary.entries[42].damage[10].notes[1].playerLevel,11)
            eq(decoded.bestiary.entries[42].abilities.Roar.state,'rejected')
            assert(decoded.bestiary.entries[42].rumours[1].dismissed)
            assert(not decoded.bestiary.sharing and not decoded.bestiary.points.reservations)
            assert(not decoded.bestiary.entries[42].autoLockSignature)
            assert(not ns.BestiaryBackups.Decode(encoded:sub(1,-2)))
            assert(not ns.BestiaryBackups.Decode('print("never run")'))
        ''')

    def test_restore_recovery_points_and_active_transfer(self):
        lua = client()
        lua.execute('''
            local j,db,store,e=fresh()
            local snapshot=assert(j:CreateBackup())
            j:Ensure(43,false,'Second creature');j:Ensure(44,false,'Third creature')
            j:SetCreatureNotes(42,'After the backup')
            assert(j:ReserveShare('paid',1));assert(j:CommitShare('paid'))
            local sent={}
            local engine=ns.CreateSharing(j,{ready=true,addonVersion='0.9.76',character='Alice Sunstrider',
                now=time,blocked=function() return false end,send=function(_,message) sent[#sent+1]=message;return true end})
            local tx=assert(engine:Start(ns.SharingReport.Capture(j,42),'Bob',{}))
            local storage=j:GetSharingStorage()
            db.uiScale=0.75;db.eventLog.entries[#db.eventLog.entries+1]={message='Keep this history'}
            local log=db.eventLog
            assert(j:RestoreBackup(snapshot))
            eq(j.entries[42].idNotes.text,'Personal notes')
            assert(not j.entries[43] and not j.entries[44],'records are replaced, not merged')
            eq(db.uiScale,0.75);assert(db.eventLog==log)
            assert(storage==j:GetSharingStorage() and engine:GetOutgoing()==tx)
            local available,earned,spent,reserved=j:GetSharingBalance()
            eq(earned,3);eq(spent,1);eq(reserved,1);eq(available,1)
            engine:Tick();eq(#sent,1);assert(sent[1]:find('~H~',1,true),'in-flight queue preserved')
            local recovery=j:GetBackups().recovery
            eq(recovery.bestiary.entries[42].idNotes.text,'After the backup')
            assert(recovery.bestiary.entries[43])
            assert(j:RestoreBackup(recovery));eq(j.entries[42].idNotes.text,'After the backup')
            assert(j:RestoreBackup(snapshot));eq(select(2,j:GetSharingBalance()),3)
            j:Ensure(43,false,'Second creature');eq(select(2,j:GetSharingBalance()),3,'no repeat milestone')
        ''')

    def test_backup_retention_reset_reload_and_scope(self):
        lua = client()
        lua.execute('''
            local j,db,store=fresh()
            local first=j:CreateBackup()
            for i=2,7 do now=now+1;j:SetCreatureNotes(42,'Note '..i);assert(j:CreateBackup()) end
            eq(#j:GetBackups().saved,5);eq(first.bestiary.entries[42].idNotes.text,'Personal notes')
            local archive=j:GetBackups()
            local snapshot=archive.saved[1]
            j:ResetDatabase();assert(j:GetBackups()==archive);eq(#archive.saved,5)
            local again=ns.CreateBestiaryJournal(db,function() end)
            assert(again:RestoreBackup(snapshot));eq(again.entries[42].idNotes.text,'Note 7')
            eq(select(2,again:GetSharingBalance()),1,'fresh recovery restores earned progress')
            local a,settings,account=fresh(true)
            local shared=a:CreateBackup();local accountArchive=a:GetBackups()
            local other={accountWideTracking=true,accountTrackingKey=99}
            local otherJournal=ns.CreateBestiaryJournal(other,function() end,account)
            assert(otherJournal:GetBackups()==accountArchive,'account backups available across characters')
            assert(accountArchive~=archive)
            a:ResetDatabase();assert(a:GetBackups()==accountArchive)
            assert(a:RestoreBackup(shared));assert(account.importedCharacters[settings.accountTrackingKey])
            assert(not other.bestiaryBackups,'account archives do not leak into character settings')
        ''')

    def test_invalid_data_and_combat_leave_everything_unchanged(self):
        lua = client()
        lua.execute('''
            j,db,store=fresh()
            good=assert(j:CreateBackup())
            local entries=j.entries
            combat=true;assert(not j:RestoreBackup(good));combat=false
            assert(not j:GetBackups().recovery and j.entries==entries)
            local bad=assert(ns.BestiaryBackups.Decode(ns.BestiaryBackups.Encode(good)))
            bad.bestiary.entries[42].abilities.Poison.state='bad'
            assert(not j:RestoreBackup(bad));assert(j.entries==entries)
            bad=assert(ns.BestiaryBackups.Decode(ns.BestiaryBackups.Encode(good)))
            bad.bestiary.entries[42].damage[10].notes[1].low=99
            assert(not j:RestoreBackup(bad));assert(not j:GetBackups().recovery)
            bad=assert(ns.BestiaryBackups.Decode(ns.BestiaryBackups.Encode(good)))
            bad.bestiary.entries[42].idNotes.text='|Hdangerous link'
            assert(not ns.BestiaryBackups.Encode(bad))
            bad=assert(ns.BestiaryBackups.Decode(ns.BestiaryBackups.Encode(good)))
            bad.bestiary.entries[42].id=43;assert(not j:RestoreBackup(bad))
        ''')
        for payload in ['m2:s1:an1:s1:an2:', 'm1:m0:n1:', 's3:%xx', 's99:short',
                        'n-1:', 'm999999999999:', 'm0:trailing', ('m1:s1:a' * 40) + 'z']:
            encoded = 'AFB1:' + format(zlib.adler32(payload.encode()), '08x') + ':' + payload
            result = lua.globals().ns.BestiaryBackups.Decode(encoded)
            self.assertIsNone(result[0], payload)


if __name__ == '__main__':
    unittest.main()
