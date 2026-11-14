"""
Regression test suite for authoritative EOD visit calculation and IST reporting window.
Verifies that:
1. Two visited visits and one pending visit produces completed=2, pending=1.
2. Visits scheduled earlier but completed today in IST are counted as completed.
3. Client submitting 0s does NOT overwrite authoritative database visit counts.
4. Duplicate visits are prevented on the same IST day.
5. Strict FE isolation: visits from other FEs are never counted.
"""
import pytest
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.all_models import Base, User, Role, FieldExecutive, ShopOwner, Visit, EODReport
from app.api.eod import submit_eod_report, EODReportIn
from app.api.visits import get_ist_reporting_window_utc

# Create in-memory SQLite for deterministic, completely isolated unit testing
@pytest.fixture
def test_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    db = Session()

    # Seed roles and users
    role_admin = Role(id=1, name="administrator")
    role_fe = Role(id=2, name="field_executive")
    db.add_all([role_admin, role_fe])
    db.commit()

    user_fe1 = User(id=10, phone="9848099001", full_name="Ravi Kumar", role_id=2)
    user_fe2 = User(id=20, phone="9848011223", full_name="Suresh Babu", role_id=2)
    db.add_all([user_fe1, user_fe2])
    db.commit()

    exec1 = FieldExecutive(id=1, user_id=10, employee_code="YHS-EMP-003", assigned_territory="Krishna")
    exec2 = FieldExecutive(id=2, user_id=20, employee_code="YHS-EMP-002", assigned_territory="Guntur")
    db.add_all([exec1, exec2])
    db.commit()

    user_so1 = User(id=101, phone="9848011111", full_name="Shop Owner 1", role_id=1)
    user_so2 = User(id=102, phone="9848022222", full_name="Shop Owner 2", role_id=1)
    user_so3 = User(id=103, phone="9848033333", full_name="Shop Owner 3", role_id=1)
    db.add_all([user_so1, user_so2, user_so3])
    db.commit()

    shop1 = ShopOwner(id=1, user_id=101, shop_name="ABC Seeds & Fertilizers", market_location="Guntur", address="Market Yard, Guntur", status="Active")
    shop2 = ShopOwner(id=2, user_id=102, shop_name="Sri Ram Agro Stores", market_location="Vijayawada", address="Rythu Bazar, Vijayawada", status="Active")
    shop3 = ShopOwner(id=3, user_id=103, shop_name="Krishna Agri Mart", market_location="Ongole", address="Main Market, Ongole", status="Active")
    db.add_all([shop1, shop2, shop3])
    db.commit()

    yield db, user_fe1, user_fe2, exec1, exec2, [shop1, shop2, shop3]
    db.close()


def test_ist_reporting_window_calculation():
    """Verify UTC-to-IST midnight boundary calculations."""
    # Test 18:40 UTC on Oct 25 -> 00:10 IST on Oct 26
    dt_utc = datetime(2026, 10, 25, 18, 40, 0)
    utc_start, utc_end = get_ist_reporting_window_utc(dt_utc)
    
    # In IST, day is Oct 26.
    # Start: Oct 26 00:00 IST -> Oct 25 18:30 UTC
    assert utc_start == datetime(2026, 10, 25, 18, 30, 0)
    # End: Oct 26 23:59:59.999999 IST -> Oct 26 18:29:59.999999 UTC
    assert utc_end.year == 2026 and utc_end.month == 10 and utc_end.day == 26
    assert utc_end.hour == 18 and utc_end.minute == 29


def test_eod_authoritative_calculation_scenario_16_17_18(test_db):
    """Scenario: Visits #16 and #17 are visited, #18 is pending. EOD must record completed=2, pending=1."""
    db, user_fe1, _, exec1, _, shops = test_db

    now_utc = datetime.utcnow()
    # Create Visit #16: Visited with photo
    v16 = Visit(
        id=16,
        executive_id=exec1.id,
        shop_id=shops[0].id,
        status="Visited",
        scheduled_date=now_utc - timedelta(minutes=10),
        visited_at=now_utc - timedelta(minutes=8),
        visit_photo_url="/public/visits/visit_16.jpg",
        bags_ordered=10,
    )
    # Create Visit #17: Visited with photo
    v17 = Visit(
        id=17,
        executive_id=exec1.id,
        shop_id=shops[1].id,
        status="Visited",
        scheduled_date=now_utc - timedelta(minutes=6),
        visited_at=now_utc - timedelta(minutes=4),
        visit_photo_url="/public/visits/visit_17.jpg",
        bags_ordered=15,
    )
    # Create Visit #18: Pending
    v18 = Visit(
        id=18,
        executive_id=exec1.id,
        shop_id=shops[2].id,
        status="Pending",
        scheduled_date=now_utc - timedelta(minutes=2),
        visited_at=None,
    )
    db.add_all([v16, v17, v18])
    db.commit()

    # Client submits EOD with stale counts 0 and 0
    client_payload = EODReportIn(
        completed_visits=0,
        pending_visits=0,
        total_bags_ordered=0,
        notes="Testing EOD ground-truth protection"
    )

    out = submit_eod_report(report=client_payload, db=db, current_user=user_fe1)

    assert out.completed_visits == 2, f"Expected 2 completed visits, got {out.completed_visits}"
    assert out.pending_visits == 1, f"Expected 1 pending visit, got {out.pending_visits}"
    assert out.total_bags_ordered == 25, f"Expected 25 total bags ordered, got {out.total_bags_ordered}"
    assert out.executive_id == exec1.id


def test_earlier_scheduled_visit_completed_today_is_counted(test_db):
    """A visit scheduled 3 days ago but completed today must be counted under completed."""
    db, user_fe1, _, exec1, _, shops = test_db
    now_utc = datetime.utcnow()

    # Scheduled 3 days ago, visited today
    v_old_sched = Visit(
        id=101,
        executive_id=exec1.id,
        shop_id=shops[0].id,
        status="Visited",
        scheduled_date=now_utc - timedelta(days=3),
        visited_at=now_utc - timedelta(minutes=15),
        visit_photo_url="/public/visits/v_101.jpg",
        bags_ordered=5,
    )
    db.add(v_old_sched)
    db.commit()

    payload = EODReportIn(completed_visits=0, pending_visits=0, total_bags_ordered=0)
    out = submit_eod_report(report=payload, db=db, current_user=user_fe1)

    assert out.completed_visits == 1
    assert out.pending_visits == 0
    assert out.total_bags_ordered == 5


def test_fe_data_isolation_in_eod_calculation(test_db):
    """Visits belonging to other field executives must never bleed into another executive's EOD report."""
    db, user_fe1, user_fe2, exec1, exec2, shops = test_db
    now_utc = datetime.utcnow()

    # 3 visits for exec2
    v_exec2_1 = Visit(executive_id=exec2.id, shop_id=shops[0].id, status="Visited", scheduled_date=now_utc, visited_at=now_utc)
    v_exec2_2 = Visit(executive_id=exec2.id, shop_id=shops[1].id, status="Visited", scheduled_date=now_utc, visited_at=now_utc)
    v_exec2_3 = Visit(executive_id=exec2.id, shop_id=shops[2].id, status="Pending", scheduled_date=now_utc)
    db.add_all([v_exec2_1, v_exec2_2, v_exec2_3])

    # 0 visits for exec1
    db.commit()

    # Exec1 submits EOD
    payload = EODReportIn(completed_visits=0, pending_visits=0, total_bags_ordered=0)
    out_exec1 = submit_eod_report(report=payload, db=db, current_user=user_fe1)

    assert out_exec1.completed_visits == 0
    assert out_exec1.pending_visits == 0

    # Exec2 submits EOD
    out_exec2 = submit_eod_report(report=payload, db=db, current_user=user_fe2)
    assert out_exec2.completed_visits == 2
    assert out_exec2.pending_visits == 1


def test_no_duplicate_counting_in_eod(test_db):
    """A visit that matches both visited_at and scheduled_date must be counted exactly once."""
    db, user_fe1, _, exec1, _, shops = test_db
    now_utc = datetime.utcnow()

    v = Visit(
        id=201,
        executive_id=exec1.id,
        shop_id=shops[0].id,
        status="Visited",
        scheduled_date=now_utc,
        visited_at=now_utc,
        bags_ordered=5,
    )
    db.add(v)
    db.commit()

    payload = EODReportIn(completed_visits=0, pending_visits=0, total_bags_ordered=0)
    out = submit_eod_report(report=payload, db=db, current_user=user_fe1)

    assert out.completed_visits == 1
    assert out.pending_visits == 0
    assert out.total_bags_ordered == 5


if __name__ == "__main__":
    pytest.main(["-v", __file__])
