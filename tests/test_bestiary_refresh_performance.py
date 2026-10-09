"""Refresh-local metadata reuse; filters remain live without revision changes."""
import unittest
from test_zone_colours import client


class BestiaryRefreshTests(unittest.TestCase):
    def test_metadata_is_reused_for_category_and_location_availability(self):
        lua = client()
        lua.execute('''
            for i=1,128 do
                local e=j:Ensure(1000+i,true,string.format('Zebra %03d',i))
                e.category='Beast';e.locations={['Distant zone']=true}
            end
            section.search:SetText('no matching creature')
            local basic=j.GetBasicInfo;local reads=0
            j.GetBasicInfo=function(self,id)
                if id>1000 then reads=reads+1 end
                return basic(self,id)
            end
            book:Refresh()
            print('Bestiary 128 off-page entries: '..reads..' metadata reads per refresh')
            assert(reads==256,'one availability read and one List read per off-page entry')
            assert(section.typeButtons.Beast:IsEnabled())
            local revision=j.revision
            section.search:SetText('Zebra 001')
            assert(section.rows[1].id==1001 and section.rows[2].id==nil)
            section.search:SetText('Zebra 002')
            assert(section.rows[1].id==1002 and section.rows[2].id==nil)
            assert(j.revision==revision,'search changes need no journal revision')
        ''')


if __name__ == '__main__':
    unittest.main()
