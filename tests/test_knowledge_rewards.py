"""Integer rank rewards through actual kill events, reload and spending."""
import unittest
from kill_test_harness import new_client

class KnowledgeRewards(unittest.TestCase):
    def test_rank_milestones_and_reload(self):
        for rank, expected in [('normal', [1, 2, 4, 7]), ('elite', [1, 2, 5, 9]),
                               ('rare', [2, 4, 8, 14]), ('rareelite', [2, 4, 8, 14])]:
            with self.subTest(rank=rank):
                lua = new_client()
                lua.globals().rank = rank
                lua.execute("function UnitClassification() return rank end")
                for limit, total in zip([1, 25, 50, 100], expected):
                    lua.globals().limit = limit
                    lua.execute("for i=(AzerothFieldbookDB.bestiary.entries[42] and kills() or 0)+1,limit do beginKill('rank'..i);finishKill() end")
                    self.assertEqual(lua.eval('points()'), total)
                    lua.execute("fire('ADDON_LOADED','AzerothFieldbook')")
                    self.assertEqual(lua.eval('points()'), total)
                lua.execute("beginKill('extra');finishKill()")
                self.assertEqual(lua.eval('points()'), expected[-1])

if __name__ == '__main__':
    unittest.main()
