"""Optional Spoken playback: archive matching, discovery locks and UI lifecycle."""
import unittest

from test_lore_ui import new_lore_ui


SPOKEN = r'''
    compatible=true;partOn=true;unlocked=true;audio=true;narrating=false
    checksums={['Recorded first page']=101,['Recorded third page']=103,
        ['Aufgezeichnete Seite']=201,['<HTML>Recorded first page</HTML>']=999}
    corpus={index={['Observed title']={[1]={[101]=11},[3]={[103]=13}}},
        loose={[101]=11,[103]=13}}
    packs={}
    Spoken={IsCompatible=function(_,v) assert(v==1);return compatible end}
    SpokenReadables={
        Data=function() return corpus end,
        ChecksumOf=function(_,raw) return checksums[raw] or 0 end,
        MarkedChecksumOf=function(_,raw) if raw:find('<HTML>',1,true) then return 101 end end,
        GetAudioPacks=function() return packs end,
        PackLanguage=function(_,pack) return pack.language end,
        GetClientLanguage=function() return 'enUS' end,
        PlaceOf=function(_,id) if id==11 or id==13 then return 10 end end,
        CompendiumHas=function(_,book) assert(book==10);return unlocked end,
        HasAudio=function(_,id) assert(id==11 or id==13);return audio end,
        IsPartOn=function() return partOn end,
        IsNarrating=function(_,book) assert(book==10);return narrating end,
        PlayFrom=function(_,id,browsing,asked)
            assert(browsing==true and asked==true)
            played=id;narrating=true;return playCount or 1
        end,
        StopReading=function(_,book) stopped=book;narrating=false end,
    }
    function recorded()
        local e=writing();e.pages[1].raw='Recorded first page'
        e.pages[3].raw='Recorded third page';c:Select(e.id);return e
    end
    function tick() m.scripts.OnUpdate(m,0.5) end
    m:SetSize(960,740)
'''


class LoreSpokenTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_lore_ui()
        self.lua.execute(SPOKEN)

    def test_optional_module_late_load_and_incompatible_versions(self):
        self.lua.execute('''
            local module=SpokenReadables;local player=Spoken
            Spoken=nil;local e=recorded();assert(not m.spoken:IsShown())
            Spoken=player;SpokenReadables=nil;c:Refresh();assert(not m.spoken:IsShown())
            SpokenReadables=module;compatible=false;c:Refresh();assert(not m.spoken:IsShown())
            compatible=true;module.PlayFrom=nil;c:Refresh();assert(not m.spoken:IsShown())
            module.PlayFrom=function() return 1 end
            m.scripts.OnEvent(m,'ADDON_LOADED','Spoken_Readables')
            assert(m.spoken:IsShown())
        ''')

    def test_page_play_stop_and_external_queue_updates(self):
        self.lua.execute('''
            local e=recorded();local before=snapshot(saved)
            assert(m.spoken:IsShown() and m.spoken:GetText()=='Play')
            click(m.spoken);assert(played==11 and m.spoken:GetText()=='Stop')
            click(m.spoken);assert(stopped==10 and m.spoken:GetText()=='Play')
            narrating=true;tick();assert(m.spoken:GetText()=='Stop')
            narrating=false;tick();assert(m.spoken:GetText()=='Play')
            assert(snapshot(saved)==before)
            c:Page(2);click(m.spoken);assert(played==13)
        ''')

    def test_no_title_only_live_reader_or_personal_note_playback(self):
        self.lua.execute('''
            local e=recorded()
            ItemTextGetText=function() error('Must not inspect the live book') end
            e.pages[1].raw='Different words under the same title'
            c:Refresh();assert(not m.spoken:IsShown())
            c:Page(1);assert(not m.spoken:IsShown()) -- missing page 2
            c:Page(0,'overview');assert(m.spoken:IsShown() and c.spokenTarget.page==13)
            j:AddPassage(e.id,{raw='Recorded first page',nature='source',origin='manual',method='manual'})
            local passage=e.passages[1]
            c:Page(0,'passage:'..passage.id);assert(not m.spoken:IsShown())
            c:SetView('location');assert(not m.spoken:IsShown())
            c:Select(assert(j:Create('landmark',{title='Observed title'})).id)
            assert(not m.spoken:IsShown())
        ''')

    def test_discovery_part_and_audio_gates_rechecked_at_click(self):
        self.lua.execute('''
            local e=recorded();local target=c.spokenTarget
            unlocked=false;click(m.spoken);assert(not played and not m.spoken:IsShown())
            unlocked=true;tick();assert(m.spoken:IsShown())
            partOn=false;tick();assert(not m.spoken:IsShown())
            partOn=true;audio=false;tick();assert(not m.spoken:IsShown())
            audio=true;tick();assert(m.spoken:IsShown())
            SpokenReadables=nil;assert(not ns.LoreSpoken:Toggle(target))
        ''')

    def test_renamed_entry_unknown_number_and_html_legacy_checksum(self):
        self.lua.execute('''
            local e=recorded();j:Update(e.id,{title='My renamed writing'});c:Refresh()
            assert(m.spoken:IsShown() and c.spokenTarget.page==11)
            e.pages[1].raw='<HTML>Recorded first page</HTML>';c:Refresh()
            assert(m.spoken:IsShown() and c.spokenTarget.page==11)
            e.pages.unknown=e.pages[1];e.pages[1]=nil;e.pages.unknown.number=nil
            e.firstPage=nil;e.lastPage=nil;c:Page(0,'page:unknown')
            assert(m.spoken:IsShown() and c.spokenTarget.page==11)
        ''')

    def test_localized_pack_indexes_and_received_pages_obey_locks(self):
        self.lua.execute('''
            local e=recorded();e.locale='deDE';e.pages[1].raw='Aufgezeichnete Seite'
            packs={{language='deDE',extraIndex={['Observed title']={[1]={[201]=11}}}}}
            c:Refresh();assert(m.spoken:IsShown() and c.spokenTarget.page==11)
            e.reports={{title='Received writing',sourceTitle='Observed title',locale='enUS',
                pages={{number=3,raw='Recorded third page',nature='source',origin='reported'}},passages={}}}
            c:Page(0,'report:1:page:1');assert(m.spoken:IsShown() and c.spokenTarget.page==13)
            unlocked=false;tick();assert(not m.spoken:IsShown())
        ''')

    def test_failed_playback_and_addon_errors_are_contained(self):
        self.lua.execute('''
            recorded();playCount=0;click(m.spoken)
            assert(m.message:GetText():find('could not play',1,true))
            SpokenReadables.HasAudio=function() error('Broken optional addon') end
            tick();assert(not m.spoken:IsShown())
            SpokenReadables.ChecksumOf=function() error('Broken optional addon') end
            c:Refresh();assert(not m.spoken:IsShown())
        ''')

    def test_title_reserves_button_space_and_restores_width_without_audio(self):
        self.lua.execute('''
            local e=recorded();assert(m.name:GetWidth()==m.name:GetStringWidth())
            assert(j:Update(e.id,{title=string.rep('Long title ',18)}));c:Refresh()
            assert(m.name:GetWidth()==430)
            assert(m.spoken.point[2]==m.name and m.spoken.point[3]=='RIGHT')
            audio=false;tick();assert(m.name.point[2]==m.locationView)
        ''')


if __name__ == '__main__':
    unittest.main()
