import logging
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine, Base
from app.core.security import get_password_hash
from app.models.all_models import (
    Role, User, ShopOwner, FieldExecutive, Product, Inventory,
    Order, OrderItem, Visit, Attendance, Shipment
)

logger = logging.getLogger("yadvi_seed")


def init_db():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        _seed_roles(db)
        _seed_users(db)
        _seed_products(db)
        _seed_orders_and_shipments(db)
        _seed_visits(db)
        _seed_attendance(db)
        logger.info("Database initialized and seeded successfully!")
    except Exception as e:
        logger.error(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()


def _seed_roles(db: Session):
    roles_data = [
        ("administrator", "Full system administrator with access to all management modules"),
        ("field_executive", "On-field executive for retailer visits and order collection"),
        ("shop_owner", "Authorized seed dealer & shop proprietor"),
    ]
    for role_name, desc in roles_data:
        if not db.query(Role).filter(Role.name == role_name).first():
            db.add(Role(name=role_name, description=desc))
    db.commit()


def _seed_users(db: Session):
    role_map = {r.name: r for r in db.query(Role).all()}

    # --- Admin ---
    if not db.query(User).filter(User.phone == "9876543210").first():
        admin = User(
            phone="9876543210", email="admin@yadvi.com", username="ADMIN", full_name="Ramesh Kumar",
            hashed_password=get_password_hash("admin123"),
            role_id=role_map["administrator"].id, is_active=True
        )
        db.add(admin)
        db.commit()

    # --- Field Executives ---
    fe_data = [
        ("9848011223", "suresh@yadvi.com", "FE001", "Suresh Babu", "YHS-EMP-002",
         "Senior Field Sales Officer", "Guntur - Nuzvid Corridor", 16.3067, 80.4365, 88, "Present", 14.2),
        ("9848099001", "ravi@yadvi.com", "FE002", "Ravi Kumar", "YHS-EMP-003",
         "Field Sales Officer", "Krishna - Vijayawada Belt", 16.5062, 80.6480, 72, "In Field", 8.5),
        ("9848077002", "divya@yadvi.com", "FE003", "Divya Reddy", "YHS-EMP-004",
         "Junior Field Executive", "Prakasam - Ongole Zone", 15.5057, 80.0499, 95, "Present", 21.0),
    ]
    for phone, email, username, name, code, desig, territory, lat, lng, battery, status, dist in fe_data:
        if not db.query(User).filter(User.phone == phone).first():
            user = User(
                phone=phone, email=email, username=username, full_name=name,
                hashed_password=get_password_hash("field123"),
                role_id=role_map["field_executive"].id, is_active=True
            )
            db.add(user)
            db.flush()
            db.add(FieldExecutive(
                user_id=user.id, employee_code=code, designation=desig,
                assigned_territory=territory, current_lat=lat, current_lng=lng,
                battery_level=battery, attendance_status=status, distance_covered_km=dist
            ))
    db.commit()

    # --- Shop Owners ---
    shop_data = [
        ("9848023456", "abc@yadvi.com", "SHOP001", "M. Venkat Rao", "ABC Seeds & Fertilizers",
         "YHS-GNT-104", "Guntur Market Yard",
         "Shop No. 14, Agricultural Market Complex, Guntur, AP - 522004",
         16.3008, 80.4428, 450, 380, "Krishna-5 Chilli, YH-222 Okra"),
        ("9848033301", "sriram@yadvi.com", "SHOP002", "Sri Ram Agro", "Sri Ram Agro Stores",
         "YHS-VJA-201", "Vijayawada Rythu Bazar",
         "D.No. 7-45, Rythu Bazar Complex, Vijayawada, AP - 520001",
         16.5193, 80.6305, 600, 510, "YH-222 Okra, Dolichos"),
        ("9848044402", "krishna@yadvi.com", "SHOP003", "K. Prasad", "Krishna Agri Mart",
         "YHS-ONG-305", "Ongole Main Market",
         "Shop 3, Agricultural Trade Center, Ongole, AP - 523001",
         15.5057, 80.0499, 320, 290, "Black Gram, Chilli"),
    ]
    for phone, email, username, owner_name, shop_name, dealer_code, market, address, lat, lng, open_stock, cur_stock, crop in shop_data:
        if not db.query(User).filter(User.phone == phone).first():
            user = User(
                phone=phone, email=email, username=username, full_name=owner_name,
                hashed_password=get_password_hash("shop123"),
                role_id=role_map["shop_owner"].id, is_active=True
            )
            db.add(user)
            db.flush()
            db.add(ShopOwner(
                user_id=user.id, shop_name=shop_name, dealer_code=dealer_code,
                market_location=market, address=address, lat=lat, lng=lng,
                opening_stock_bags=open_stock, current_stock_bags=cur_stock,
                primary_demand_crop=crop, status="Active"
            ))
    db.commit()


def _seed_products(db: Session):
    if db.query(Product).count() > 0:
        return
    products = [
        Product(
            name="Krishna-5 F1 Hybrid Chilli", variety_type="F1 Hybrid Chilli",
            sku="YHS-CHL-K5", category="Chilli", image_url="/seeds/seed_12.jpeg",
            available_stock_bags=1420, germination_rate="85% Min", purity="98% Min",
            maturity_days="65 - 70 Days", crop_season="Kharif & Rabi", availability="In Stock",
            description="High-yielding pungent hybrid chilli with erect plant habit, deep glossy red fruits, and outstanding heat tolerance.",
            package_sizes="10g Packet, 50g Pouch, 100g Pouch"
        ),
        Product(
            name="YH-222 F1 Hybrid Okra", variety_type="F1 Hybrid Bhendi",
            sku="YHS-OKR-222", category="Okra", image_url="/seeds/seed_07.jpeg",
            available_stock_bags=2150, germination_rate="90% Min", purity="99% Min",
            maturity_days="42 - 45 Days", crop_season="Summer & Kharif", availability="In Stock",
            description="Premium dark-green 5-ridged tender okra with short internodes and heavy branching.",
            package_sizes="100g Pouch, 250g Pouch, 500g Pouch, 1kg Tin"
        ),
        Product(
            name="Lakshmi Research Dolichos", variety_type="Research Dolichos Bean",
            sku="YHS-DOL-LAK", category="Dolichos", image_url="/seeds/seed_02.jpeg",
            available_stock_bags=1200, germination_rate="85% Min", purity="98% Min",
            maturity_days="75 - 85 Days", crop_season="Rabi & Late Kharif", availability="In Stock",
            description="Famous pole type Dolichos (Chikkudu) renowned for broad light green fleshy aromatic pods.",
            package_sizes="500g Bag, 1kg Bag, 5kg Bag"
        ),
        Product(
            name="YHS Special Black Gram (మినుము)", variety_type="High Yielding Pulse Seed",
            sku="YHS-PLS-BG01", category="Pulses", image_url="/seeds/seed_01.jpeg",
            available_stock_bags=3400, germination_rate="85% Min", purity="98% Min",
            maturity_days="70 - 75 Days", crop_season="Kharif & Rabi Rice Fallows", availability="In Stock",
            description="Selected elite black gram seed with bold black grains and synchronous maturity.",
            package_sizes="2kg Bag, 5kg Bag, 25kg Seed Bag"
        ),
        Product(
            name="YHS Sunflower Hybrid-6", variety_type="F1 Hybrid Sunflower",
            sku="YHS-SFL-H6", category="Field Crops", image_url="/seeds/seed_04.jpeg",
            available_stock_bags=980, germination_rate="88% Min", purity="98% Min",
            maturity_days="90 - 95 Days", crop_season="Rabi & Kharif", availability="In Stock",
            description="High oil content sunflower hybrid with large bold seeds, disease resistance.",
            package_sizes="500g Pack, 1kg Pack, 5kg Bag"
        ),
        Product(
            name="Tomato YH-T300 Hybrid", variety_type="F1 Hybrid Tomato",
            sku="YHS-TOM-T300", category="Vegetables", image_url="/seeds/seed_09.jpeg",
            available_stock_bags=760, germination_rate="92% Min", purity="99% Min",
            maturity_days="55 - 60 Days", crop_season="All Seasons", availability="In Stock",
            description="Determinate compact plant with glossy red round fruits, TYLCV tolerant.",
            package_sizes="10g Packet, 50g Pouch, 100g Pouch"
        ),
    ]
    db.add_all(products)
    db.commit()


def _seed_orders_and_shipments(db: Session):
    if db.query(Order).count() > 0:
        return

    shops = db.query(ShopOwner).all()
    executives = db.query(FieldExecutive).all()
    products = db.query(Product).all()
    if not shops or not products:
        return

    now = datetime.utcnow()
    orders_data = [
        ("ORD-1021", shops[0].id, executives[0].id if executives else None, "Dispatched",
         "Shop Owner App", now - timedelta(days=3), "Standard delivery", "LR-NAV-7821", "Navata Road Transport"),
        ("ORD-1022", shops[1].id if len(shops) > 1 else shops[0].id, executives[0].id if executives else None,
         "Delivered", "Field Executive", now - timedelta(days=7), "Urgent delivery", "LR-NAV-7756", "Navata Road Transport"),
        ("ORD-1023", shops[0].id, executives[1].id if len(executives) > 1 else None,
         "New", "Shop Owner App", now - timedelta(hours=5), None, None, None),
        ("ORD-1024", shops[2].id if len(shops) > 2 else shops[0].id, executives[0].id if executives else None,
         "Processing", "Admin Portal", now - timedelta(days=1), "Handle with care", None, None),
        ("ORD-1025", shops[0].id, executives[0].id if executives else None,
         "Confirmed", "Shop Owner App", now - timedelta(hours=2), None, None, None),
    ]

    for order_num, shop_id, exec_id, status, source, created, notes, lr, transporter in orders_data:
        # Assign 2 random products
        selected = products[:2]
        total_bags = 0
        order = Order(
            order_number=order_num, shop_id=shop_id, assigned_executive_id=exec_id,
            total_quantity_bags=0, total_items_count=len(selected),
            status=status, source=source, delivery_notes=notes, created_at=created
        )
        db.add(order)
        db.flush()

        for i, product in enumerate(selected):
            qty = (i + 1) * 5
            total_bags += qty
            db.add(OrderItem(
                order_id=order.id, product_id=product.id,
                package_size=product.package_sizes.split(",")[0].strip(),
                quantity_bags=qty
            ))

        order.total_quantity_bags = total_bags

        if lr and transporter:
            db.add(Shipment(
                order_id=order.id, lr_number=lr, transporter_name=transporter,
                vehicle_number="AP 16 TZ 5519", driver_name="R. Koteswara Rao",
                driver_phone="+91 94402 88123", dispatch_date=created + timedelta(hours=6),
                estimated_delivery="Within 48 Hours",
                status="Delivered" if status == "Delivered" else "In Transit",
                current_location="Delivered to Shop" if status == "Delivered" else "Vijayawada Transit Hub"
            ))

    db.commit()


def _seed_visits(db: Session):
    if db.query(Visit).count() > 0:
        return

    executives = db.query(FieldExecutive).all()
    shops = db.query(ShopOwner).all()
    if not executives or not shops:
        return

    now = datetime.utcnow()
    visits_data = [
        (executives[0].id, shops[0].id, "Stock Booking & Dealer Audit", "Visited",
         now.replace(hour=9, minute=0), "https://example.com/photo1.jpg", 16.5, 80.5, 25),
        (executives[0].id, shops[1].id if len(shops) > 1 else shops[0].id,
         "New Season Demo & Order Collection", "Pending",
         None, None, None, None, 0),
        (executives[0].id, shops[2].id if len(shops) > 2 else shops[0].id,
         "Scheduled Visit & Stock Check", "Pending", 
         None, None, None, None, 0),
        (executives[1].id if len(executives) > 1 else executives[0].id,
         shops[0].id, "Product Demo - YH-222 Okra", "Visited",
         (now - timedelta(days=1)).replace(hour=10), "https://example.com/photo2.jpg", 16.6, 80.6, 15),
    ]

    for exec_id, shop_id, purpose, status, visited_at, photo_url, p_lat, p_lng, bags in visits_data:
        db.add(Visit(
            executive_id=exec_id, shop_id=shop_id, purpose=purpose, status=status,
            visited_at=visited_at, visit_photo_url=photo_url, photo_lat=p_lat, photo_lng=p_lng, bags_ordered=bags,
            scheduled_date=now
        ))
    db.commit()


def _seed_attendance(db: Session):
    if db.query(Attendance).count() > 0:
        return

    executives = db.query(FieldExecutive).all()
    if not executives:
        return

    now = datetime.utcnow()
    for exec_ in executives:
        today_record = Attendance(
            executive_id=exec_.id,
            date=now,
            check_in_time=now.replace(hour=8, minute=55),
            check_out_time=now.replace(hour=18, minute=10) if exec_.attendance_status != "In Field" else None,
            status=exec_.attendance_status if exec_.attendance_status in ["Present", "Late"] else "Present",
            distance_covered_km=exec_.distance_covered_km,
            check_in_location="Office / Field HQ"
        )
        db.add(today_record)

        # Yesterday
        yesterday = now - timedelta(days=1)
        db.add(Attendance(
            executive_id=exec_.id,
            date=yesterday,
            check_in_time=yesterday.replace(hour=9, minute=5),
            check_out_time=yesterday.replace(hour=18, minute=30),
            status="Present",
            distance_covered_km=18.5,
            check_in_location="Guntur Market Yard"
        ))

    db.commit()


if __name__ == "__main__":
    init_db()
