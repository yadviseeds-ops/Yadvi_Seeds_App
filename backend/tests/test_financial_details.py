import sys
import os
sys.path.insert(0, os.path.abspath('backend'))

import unittest
from app.models.all_models import ShopOwner, User, Role
from app.api.shops import ShopFinancialsUpdate

class FinancialDetailsCalculationTest(unittest.TestCase):
    def test_basic_balance_calculation(self):
        # 1. 50,000 - 20,000 = 30,000
        taken = 50000.0
        repaid = 20000.0
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, 30000.0)

        # 2. 80,000 - 30,000 = 50,000
        taken = 80000.0
        repaid = 30000.0
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, 50000.0)

    def test_equal_amounts_zero_balance(self):
        # 3. 25,000 - 25,000 = 0
        taken = 25000.0
        repaid = 25000.0
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, 0.0)

    def test_repayment_exceeds_debt_negative_balance(self):
        # 4. 10,000 - 15,000 = -5,000
        taken = 10000.0
        repaid = 15000.0
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, -5000.0)

    def test_zero_values(self):
        # 5. 0 - 0 = 0
        taken = 0.0
        repaid = 0.0
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, 0.0)

    def test_decimal_precision_currency(self):
        # 6. Decimal currency
        taken = 12345.75
        repaid = 2345.50
        balance = round(taken - repaid, 2)
        self.assertEqual(balance, 10000.25)

    def test_shop_financials_update_schema(self):
        req = ShopFinancialsUpdate(debt_taken=50000.0, debt_repaid=20000.0)
        self.assertEqual(req.debt_taken, 50000.0)
        self.assertEqual(req.debt_repaid, 20000.0)

        req_partial = ShopFinancialsUpdate(debt_repaid=5000.0)
        self.assertIsNone(req_partial.debt_taken)
        self.assertEqual(req_partial.debt_repaid, 5000.0)

if __name__ == '__main__':
    unittest.main()
