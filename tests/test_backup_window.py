"""Legacy clipboard capture and approval lifecycle; native timing needs in-game retest."""
import unittest

from test_player_names_preservation import full_client


def client():
    lua = full_client('{version=1,accountWideTracking=false}')
    lua.execute(r'''
        local create=CreateFrame
        function CreateFrame(kind,...)
            local widget=create(kind,...)
            if kind=='EditBox' then
                function widget:SetMaxBytes(v) self.maxBytes=v end
                function widget:SetMaxLetters(v) self.maxLetters=v end
                function widget:SetMultiLine(v) self.multiLine=v end
                function widget:SetVisibleTextByteLimit() error('blocks native long paste') end
            end
            return widget
        end
        StaticPopupDialogs={}
        function StaticPopup_Show(name,a,b,data) popup={data=data} end
        function StaticPopup_Hide() popup=nil end
        B=ns.BestiaryBackups
        j=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return 42 end)
        for id=1,400 do
            j:Ensure(id,false,'Creature '..id,{level=9})
            assert(j:SetCreatureNotes(id,string.rep('x',350)..'\nÉlan 熊\t100%'))
        end
        local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1)
        book:GetShell():ShowSection('bestiary',{creatureID=42})
        window=AzerothFieldbookBestiarySection.backupWindow;window:Open(true);f=window.frame
        f.exportButton.scripts.OnClick();wire=f.text:GetText()
        assert(wire:sub(1,5)=='AFB1:' and #wire>262173, 'export length '..#wire..': '..f.status:GetText())
        assert(B.Decode(wire))
        before=capture()
        function flush() if f.scripts.OnUpdate then f.scripts.OnUpdate(f,0.016) end end
        function paste(text,perCharacter)
            assert(f.paste:IsShown())
            for i=1,#text do
                f.paste.scripts.OnChar(f.paste,text:sub(i,i))
                if perCharacter then
                    f.paste.text=((f.paste.text or '')..text:sub(i,i)):sub(1,95)
                    f.paste.scripts.OnTextChanged(f.paste,true)
                end
            end
            if not perCharacter then
                f.paste.text=((f.paste.text or '')..text):sub(1,95)
                f.paste.scripts.OnTextChanged(f.paste,true)
            end
        end
        local decode=B.Decode
        function B.Decode(text) submitted=text;return decode(text) end
    ''')
    return lua


class BackupWindowTests(unittest.TestCase):
    def test_complete_clipboard_capture_bounded_native_work_and_restore(self):
        lua = client()
        lua.execute(r'''
            f.importButton.scripts.OnClick()
            assert(f.paste.maxBytes==96 and f.paste.maxLetters==0 and not f.paste.multiLine)
            assert(not f.paste.scripts.OnKeyDown and not f.textScroll:IsShown())
            f.previewButton.scripts.OnClick();assert(not submitted and not f.restoreButton.enabled)
            paste(string.rep('a',128),true);flush()
            assert(#f.paste:GetText()==95 and f.pasteStatus:GetText():find('128 bytes received',1,true))
            f.clearPaste.scripts.OnClick()
            local reads,updates=0,0
            local getText=f.paste.GetText;local setText=f.pasteStatus.SetText
            function f.paste:GetText()
                local text=getText(self);reads=reads+1;assert(#text<=95);return text
            end
            function f.pasteStatus:SetText(text) updates=updates+1;setText(self,text) end
            for i=1,#wire,1024 do paste(wire:sub(i,i+1023)) end
            assert(reads==math.ceil(#wire/1024) and updates==0 and not submitted)
            flush();assert(updates==1 and #f.pasteStatus:GetText()<400)
            assert(f.pasteStatus:GetText():find(#wire..' bytes received',1,true))
            f.previewButton.scripts.OnClick()
            assert(submitted==wire and f.restoreButton.enabled and f.exportButton.enabled)
            f.paste.scripts.OnTextChanged(f.paste,false);flush()
            assert(f.restoreButton.enabled,'deferred unchanged notification cleared approval')
            unchanged(before,'legacy preview')
            -- Import/export uses the original format and every Unicode note survives.
            f.exportButton.scripts.OnClick()
            assert(f.textScroll:IsShown() and not f.paste:IsShown())
            assert(f.text:GetText()==wire and not f.restoreButton.enabled)
            f.importButton.scripts.OnClick();paste(wire);f.previewButton.scripts.OnClick()
            assert(j:SetCreatureNotes(42,'post-backup mutation'))
            AzerothFieldbookGatheringDB.marker='other journal unchanged'
            local other=literal(AzerothFieldbookGatheringDB)
            f.restoreButton.scripts.OnClick();assert(popup)
            StaticPopupDialogs.AZEROTHFIELDBOOK_RESTORE_CONFIRM.OnAccept(nil,popup.data)
            assert(AzerothFieldbookDB.bestiary.entries[42].idNotes.text==string.rep('x',350)..'\nÉlan 熊\t100%')
            assert(literal(AzerothFieldbookGatheringDB)==other)
            assert(j:GetBackups().recovery.bestiary.entries[42].idNotes.text=='post-backup mutation')
            assert(f.status:GetText():find('Bestiary restored',1,true))
        ''')

    def test_edits_corruption_and_lifecycle_cannot_reuse_approval(self):
        lua = client()
        lua.execute(r'''
            f.importButton.scripts.OnClick();paste(wire:sub(1,-2));flush()
            f.previewButton.scripts.OnClick()
            assert(submitted==wire:sub(1,-2) and not f.restoreButton.enabled)
            assert(f.status:GetText():find('incomplete or changed',1,true))
            paste(wire);f.previewButton.scripts.OnClick();assert(f.restoreButton.enabled)
            f.restoreButton.scripts.OnClick();local old=popup.data
            paste('x');assert(not popup and not f.restoreButton.enabled)
            StaticPopupDialogs.AZEROTHFIELDBOOK_RESTORE_CONFIRM.OnAccept(nil,old)
            unchanged(before,'stale import confirmation')
            f.clearPaste.scripts.OnClick();paste(wire)
            f.paste.text=f.paste.text:sub(1,-2);f.paste.scripts.OnTextChanged(f.paste,true)
            submitted=nil;f.previewButton.scripts.OnClick()
            assert(not submitted and not f.restoreButton.enabled)
            assert(f.status:GetText():find('not captured',1,true))
            f.clearPaste.scripts.OnClick()
            f.paste.text=wire:sub(1,95);f.paste.scripts.OnTextChanged(f.paste,true)
            f.previewButton.scripts.OnClick();assert(not submitted and not f.restoreButton.enabled)
            -- Clear and mode changes cancel queued work and old confirmation.
            f.clearPaste.scripts.OnClick();paste(wire);f.previewButton.scripts.OnClick()
            f.restoreButton.scripts.OnClick();old=popup.data
            f.clearPaste.scripts.OnClick();assert(not popup and not f.scripts.OnUpdate)
            StaticPopupDialogs.AZEROTHFIELDBOOK_RESTORE_CONFIRM.OnAccept(nil,old)
            unchanged(before,'clear input confirmation')
            paste(wire:sub(1,2000));f.savedButton.scripts.OnClick();assert(not f.scripts.OnUpdate)
            f.importButton.scripts.OnClick();f.previewButton.scripts.OnClick()
            assert(not f.restoreButton.enabled)
            paste(wire);f.previewButton.scripts.OnClick();f.restoreButton.scripts.OnClick();old=popup.data
            window:Hide();assert(not popup and not f.scripts.OnUpdate and f.paste:GetText()=='' and f.text:GetText()=='')
            StaticPopupDialogs.AZEROTHFIELDBOOK_RESTORE_CONFIRM.OnAccept(nil,old)
            unchanged(before,'closed window confirmation')
            window:Open(false);f.importButton.scripts.OnClick();f.previewButton.scripts.OnClick()
            assert(not f.restoreButton.enabled and f.pasteStatus:GetText():find('Waiting',1,true))
            f.paste.scripts.OnEscapePressed(f.paste)
            assert(not f.paste.focused)
            unchanged(before,'clipboard failure paths')
        ''')

    def test_legacy_four_mib_boundary_fails_without_submitting_truncated_input(self):
        lua = client()
        lua.execute(r'''
            f.importButton.scripts.OnClick()
            local atLimit=string.rep('x',B.MAX_BYTES)
            paste(atLimit);f.previewButton.scripts.OnClick()
            assert(submitted==atLimit and not f.restoreButton.enabled)
            submitted=nil;paste(atLimit..'x');flush()
            assert(f.pasteStatus:GetText():find('too large',1,true))
            f.previewButton.scripts.OnClick();assert(not submitted and not f.restoreButton.enabled)
            paste(wire);f.previewButton.scripts.OnClick()
            assert(submitted==wire and f.restoreButton.enabled,'could not recover after overflow')
            unchanged(before,'legacy size limit')
        ''')


if __name__ == '__main__':
    unittest.main()
