import unittest
import os
import sys
from datetime import datetime, date, timedelta, timezone

sys.path.insert(0, os.path.abspath('backend'))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import Base
from app.models.all_models import User, Role, FieldExecutive, ShopOwner, Visit, Attendance
from app.api.attendance import list_attendance

class TestAttendanceAndVisits(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine('sqlite:///:memory:', echo=False)
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()

        # Seed basic roles
        self.admin_role = Role(id=1, name="administrator")
        self.fe_role = Role(id=2, name="field_executive")
        self.db.add_all([self.admin_role, self.fe_role])

        # Admin User
        self.admin_user = User(
            id=1,
            username="admin",
            phone="9529403798",
            full_name="Admin User",
            role_id=1,
            is_active=True
        )
        self.admin_user.role = self.admin_role

        # Field Executive User 1
        self.fe_user1 = User(
            id=10,
            username="fe_ravi",
            phone="9848011111",
            full_name="Ravi Kumar",
            role_id=2,
            is_active=True
        )
        self.fe_user1.role = self.fe_role

        # Field Executive User 2
        self.fe_user2 = User(
            id=11,
            username="fe_suresh",
            phone="9848022222",
            full_name="Suresh Patel",
            role_id=2,
            is_active=True
        )
        self.fe_user2.role = self.fe_role

        # Field Executive Profiles
        self.fe1 = FieldExecutive(
            id=1,
            user_id=10,
            employee_code="YHS-FE-001",
            assigned_territory="Guntur",
            attendance_status="Absent"
        )
        self.fe1.user = self.fe_user1

        self.fe2 = FieldExecutive(
            id=2,
            user_id=11,
            employee_code="YHS-FE-002",
            assigned_territory="Vijayawada",
            attendance_status="Absent"
        )
        self.fe2.user = self.fe_user2

        self.db.add_all([self.admin_user, self.fe_user1, self.fe_user2, self.fe1, self.fe2])
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    def test_attendance_roster_calculation_defaults_to_absent(self):
        """When no photos/attendance have been logged, all active FEs are marked ABSENT."""
        res = list_attendance(date=None, db=self.db, current_user=self.admin_user)
        self.assertEqual(len(res), 2)
        statuses = {item.full_name: item.status for item in res}
        self.assertEqual(statuses["Ravi Kumar"], "Absent")
        self.assertEqual(statuses["Suresh Patel"], "Absent")

    def test_visit_photo_upload_marks_fe_present_idempotently(self):
        """Simulate photo upload: marks FE Present for today in Asia/Kolkata timezone."""
        kolkata_tz = timezone(timedelta(hours=5, minutes=30))
        today_kolkata = datetime.now(kolkata_tz).date()
        ist_start_utc = datetime(today_kolkata.year, today_kolkata.month, today_kolkata.day)

        # 1. First photo upload for FE 1
        att1 = Attendance(
            executive_id=self.fe1.id,
            date=ist_start_utc,
            check_in_time=datetime.utcnow(),
            status="Present",
            check_in_location="Visit #101 - Kisan Seeds",
        )
        self.fe1.attendance_status = "Present"
        self.db.add(att1)
        self.db.commit()

        # Check roster: FE 1 must be Present, FE 2 must be Absent
        res = list_attendance(date=None, db=self.db, current_user=self.admin_user)
        statuses = {item.full_name: item.status for item in res}
        self.assertEqual(statuses["Ravi Kumar"], "Present")
        self.assertEqual(statuses["Suresh Patel"], "Absent")

        # 2. Second photo upload on same day for FE 1 (idempotency check)
        existing = self.db.query(Attendance).filter(
            Attendance.executive_id == self.fe1.id,
            Attendance.date == ist_start_utc
        ).all()
        self.assertEqual(len(existing), 1)

    def test_attendance_date_filtering(self):
        """Verify attendance for specific past date."""
        past_date = date(2026, 11, 15)
        dt_past = datetime(past_date.year, past_date.month, past_date.day)

        # Record attendance for FE 2 on past date
        att_past = Attendance(
            executive_id=self.fe2.id,
            date=dt_past,
            check_in_time=dt_past + timedelta(hours=9),
            status="Present",
            check_in_location="Visit #50 - Agro Shop",
        )
        self.db.add(att_past)
        self.db.commit()

        # Query for past date: FE 2 Present, FE 1 Absent
        res_past = list_attendance(date="2026-11-15", db=self.db, current_user=self.admin_user)
        statuses_past = {item.full_name: item.status for item in res_past}
        self.assertEqual(statuses_past["Suresh Patel"], "Present")
        self.assertEqual(statuses_past["Ravi Kumar"], "Absent")

        # Query for another date (2026-11-16): both Absent
        res_other = list_attendance(date="2026-11-16", db=self.db, current_user=self.admin_user)
        statuses_other = {item.full_name: item.status for item in res_other}
        self.assertEqual(statuses_other["Suresh Patel"], "Absent")
        self.assertEqual(statuses_other["Ravi Kumar"], "Absent")

if __name__ == "__main__":
    unittest.main()
