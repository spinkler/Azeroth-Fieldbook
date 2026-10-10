"""Early protected-action diagnostics stay bounded and ignore other addons."""
from pathlib import Path
import unittest
from lupa import LuaRuntime


class BlockedActionsTests(unittest.TestCase):
    def test_capture_and_report(self):
        lua = LuaRuntime()
        lua.execute('''
            SlashCmdList={}; registrations={}; output={}
            function CreateFrame()
                return {RegisterEvent=function(_,e) registrations[e]=true end,
                    SetScript=function(_,_,fn) dispatch=fn end}
            end
            function print(s) output[#output+1]=s end
            function issecretvalue(v) return v=='SECRET' end
        ''')
        source = Path(__file__).resolve().parents[1] / 'BlockedActions.lua'
        lua.execute(source.read_text(), 'AzerothFieldbook')
        lua.execute('''
            assert(registrations.ADDON_ACTION_BLOCKED and registrations.ADDON_ACTION_FORBIDDEN)
            dispatch(nil,'ADDON_ACTION_BLOCKED','OtherAddon','OtherCall')
            dispatch(nil,'ADDON_ACTION_BLOCKED','AzerothFieldbook','SECRET')
            SlashCmdList.AZEROTHFIELDBOOKBLOCKED()
            assert(#output==1 and output[1]:match(': 0$'))
            for i=1,25 do dispatch(nil,'ADDON_ACTION_BLOCKED','AzerothFieldbook','Call'..i) end
            output={};SlashCmdList.AZEROTHFIELDBOOKBLOCKED()
            assert(#output==21 and output[2]=='ADDON_ACTION_BLOCKED: Call6')
            assert(output[21]=='ADDON_ACTION_BLOCKED: Call25')
            dispatch(nil,'ADDON_ACTION_FORBIDDEN','AzerothFieldbook','|bad\\ntext')
            output={};SlashCmdList.AZEROTHFIELDBOOKBLOCKED()
            assert(output[21]=='ADDON_ACTION_FORBIDDEN: bad text')
        ''')


if __name__ == '__main__':
    unittest.main()
