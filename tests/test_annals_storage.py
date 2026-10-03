import unittest
from annals_storage import measurements


class StorageTests(unittest.TestCase):
    def test_shipping_sampler_serialized_estimates_and_300_day_projection(self):
        results,events=measurements()
        self.assertEqual(results[0]['points'],1)
        for row in results:
            self.assertEqual(row['payload'],row['points']*9)
            self.assertGreater(row['saved'],row['payload'])
            self.assertGreater(row['saved']*7200/row['hours'],0)
        self.assertLess(results[2]['payload'],results[1]['payload'])
        self.assertLess(results[1]['payload'],results[4]['payload'])
        self.assertGreater(events['completedBytes'],events['acceptedBytes'])
        self.assertGreater(events['eventStoreBytes'],sum(events[k] for k in ('acceptedBytes','completedBytes','linkedBytes')))


if __name__=='__main__':
    unittest.main()
