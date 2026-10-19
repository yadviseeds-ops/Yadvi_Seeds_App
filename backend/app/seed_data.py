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
    from app.core.config import settings
    env = (getattr(settings, "ENVIRONMENT", None) or "development").strip().lower()
    if env in ("production", "staging"):
        raise RuntimeError(
            f"Execution of init_db() is strictly forbidden in '{env}' mode. "
            "Database table creation and demo seeding can only be executed in development."
        )
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
    if not db.query(User).filter((User.email == "admin@yadvi.com") | (User.username == "ADMIN")).first():
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
         "Guntur Market Yard",
         "Shop No. 14, Agricultural Market Complex, Guntur, AP - 522004",
         16.3008, 80.4428, 450, 380, "Krishna-5 Chilli, YH-222 Okra"),
        ("9848033301", "sriram@yadvi.com", "SHOP002", "Sri Ram Agro", "Sri Ram Agro Stores",
         "Vijayawada Rythu Bazar",
         "D.No. 7-45, Rythu Bazar Complex, Vijayawada, AP - 520001",
         16.5193, 80.6305, 600, 510, "YH-222 Okra, Dolichos"),
        ("9848044402", "krishna@yadvi.com", "SHOP003", "K. Prasad", "Krishna Agri Mart",
         "Ongole Main Market",
         "Shop 3, Agricultural Trade Center, Ongole, AP - 523001",
         15.5057, 80.0499, 320, 290, "Black Gram, Chilli"),
    ]
    for phone, email, username, owner_name, shop_name, market, address, lat, lng, open_stock, cur_stock, crop in shop_data:
        if not db.query(User).filter(User.phone == phone).first():
            user = User(
                phone=phone, email=email, username=username, full_name=owner_name,
                hashed_password=get_password_hash("shop123"),
                role_id=role_map["shop_owner"].id, is_active=True
            )
            db.add(user)
            db.flush()
            db.add(ShopOwner(
                user_id=user.id, shop_name=shop_name,
                market_location=market, address=address, lat=lat, lng=lng,
                opening_stock_bags=open_stock, current_stock_bags=cur_stock,
                opening_stock_kg=float(open_stock), current_stock_kg=float(cur_stock),
                primary_demand_crop=crop, status="Active"
            ))
    db.commit()


def _seed_products(db: Session):
    genuine_products = [
        {
            "sku": "YHS-CHL-K5",
            "name": "Krishna-5 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_12.jpeg",
            "available_stock_kg": 1420.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "High-yielding pungent hybrid chilli with erect plant habit, deep glossy red fruits, and outstanding heat tolerance.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-OKR-222",
            "name": "YH-222 F1 Hybrid Okra",
            "variety_type": "F1 Hybrid Bhendi",
            "category": "Okra",
            "image_url": "/seeds/seed_07.jpeg",
            "available_stock_kg": 2150.0,
            "germination_rate": "90% Min",
            "purity": "99% Min",
            "maturity_days": "42 - 45 Days",
            "crop_season": "Summer & Kharif",
            "availability": "In Stock",
            "description": "Premium dark-green 5-ridged tender okra with short internodes and heavy branching.",
            "package_sizes": "100g, 250g, 500g, 1kg",
        },
        {
            "sku": "YHS-DOL-LAK",
            "name": "Lakshmi Research Dolichos",
            "variety_type": "Research Dolichos Bean",
            "category": "Dolichos",
            "image_url": "/seeds/seed_04.jpeg",
            "available_stock_kg": 1200.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "75 - 85 Days",
            "crop_season": "Rabi & Late Kharif",
            "availability": "In Stock",
            "description": "Famous pole type Dolichos (Chikkudu) renowned for broad light green fleshy aromatic pods.",
            "package_sizes": "500g, 1kg, 5kg",
        },
        {
            "sku": "YHS-PLS-BG01",
            "name": "Black Gram (మినుము)",
            "variety_type": "High Yielding Pulse Seed",
            "category": "Pulses",
            "image_url": "/seeds/seed_01.jpeg",
            "available_stock_kg": 3400.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "70 - 75 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Selected elite black gram seed with bold black grains and synchronous maturity.",
            "package_sizes": "2kg, 5kg, 25kg",
        },
        {
            "sku": "YHS-MZ-999",
            "name": "YHS 999 F1 Hybrid Maize",
            "variety_type": "F1 Hybrid Maize",
            "category": "Field Crops",
            "image_url": "/seeds/seed_40.jpeg",
            "available_stock_kg": 1500.0,
            "germination_rate": "90% Min",
            "purity": "98% Min",
            "maturity_days": "95 - 105 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "High yielding orange-yellow flint corn with well-filled cobs and strong lodging resistance.",
            "package_sizes": "1kg, 4kg",
        },
        {
            "sku": "YHS-BAJ-KRI",
            "name": "Krishna (ABV-04) F1 Hybrid Bajra",
            "variety_type": "F1 Hybrid Bajra",
            "category": "Field Crops",
            "image_url": "/seeds/seed_39.jpeg",
            "available_stock_kg": 1200.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "80 - 85 Days",
            "crop_season": "Kharif & Summer",
            "availability": "In Stock",
            "description": "High yielding dual-purpose pearl millet with compact long earheads and stay-green fodder quality.",
            "package_sizes": "1.5kg, 3kg",
        },
        {
            "sku": "YHS-CHL-CMP",
            "name": "Champion F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_02.jpeg",
            "available_stock_kg": 1100.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "70 - 75 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Prolific green chilli hybrid with high pungency and uniform straight pods.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-CHL-AMR",
            "name": "Amaran F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_03.jpeg",
            "available_stock_kg": 950.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "68 - 72 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Premium red dry chilli hybrid with deep red color value and high capsaicin content.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-DOL-HAR",
            "name": "Harsha Research Dolichos",
            "variety_type": "Research Dolichos Bean",
            "category": "Dolichos",
            "image_url": "/seeds/seed_05.jpeg",
            "available_stock_kg": 850.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "75 - 80 Days",
            "crop_season": "Rabi & Late Kharif",
            "availability": "In Stock",
            "description": "High yielding bush-type field bean producing clusters of tender aromatic pods.",
            "package_sizes": "500g, 1kg, 5kg",
        },
        {
            "sku": "YHS-DOL-CHO",
            "name": "Chola Research Dolichos",
            "variety_type": "Research Dolichos Bean",
            "category": "Dolichos",
            "image_url": "/seeds/seed_06.jpeg",
            "available_stock_kg": 920.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "70 - 75 Days",
            "crop_season": "All Season Suitable",
            "availability": "In Stock",
            "description": "Popular flat green podded dolichos variety with exceptional flavor and tenderness.",
            "package_sizes": "500g, 1kg, 5kg",
        },
        {
            "sku": "YHS-DOL-SIR",
            "name": "Siri Research Field Beans",
            "variety_type": "Research Field Beans",
            "category": "Dolichos",
            "image_url": "/seeds/seed_08.jpeg",
            "available_stock_kg": 800.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Early flowering photo-insensitive field bean with high market preference.",
            "package_sizes": "500g, 1kg, 5kg",
        },
        {
            "sku": "YHS-CHL-K999",
            "name": "Kanaka-999 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_09.jpeg",
            "available_stock_kg": 1050.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Dual purpose green and red dry chilli with high yield potential and thrips tolerance.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-OKR-LEON",
            "name": "Leon F1 Hybrid Okra",
            "variety_type": "F1 Hybrid Bhendi",
            "category": "Okra",
            "image_url": "/seeds/seed_10.jpeg",
            "available_stock_kg": 1780.0,
            "germination_rate": "92% Min",
            "purity": "99% Min",
            "maturity_days": "40 - 44 Days",
            "crop_season": "All Round Year",
            "availability": "In Stock",
            "description": "High performance hybrid bhendi engineered for exceptional early yield and dense pod set.",
            "package_sizes": "100g, 250g, 500g",
        },
        {
            "sku": "YHS-BG-SUR",
            "name": "Surya F1 Hybrid Bitter Gourd",
            "variety_type": "F1 Hybrid Bitter Gourd",
            "category": "Vegetables",
            "image_url": "/seeds/seed_11.jpeg",
            "available_stock_kg": 640.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "50 - 55 Days",
            "crop_season": "Summer & Kharif",
            "availability": "In Stock",
            "description": "Dark green spiny hybrid bitter gourd with continuous picking and excellent shelf life.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-BAJ-YBS33",
            "name": "YBS-33 Hybrid Bajra",
            "variety_type": "Hybrid Bajra",
            "category": "Field Crops",
            "image_url": "/seeds/seed_14.jpeg",
            "available_stock_kg": 1850.0,
            "germination_rate": "90% Min",
            "purity": "98% Min",
            "maturity_days": "82 - 86 Days",
            "crop_season": "Kharif & Summer",
            "availability": "In Stock",
            "description": "Top performing bajra hybrid with dense grain packing and excellent drought resilience.",
            "package_sizes": "1.5kg, 3kg",
        },
        {
            "sku": "YHS-BGD-GOW",
            "name": "Gowrav F1 Hybrid Bottle Gourd",
            "variety_type": "F1 Hybrid Bottle Gourd",
            "category": "Vegetables",
            "image_url": "/seeds/seed_15.jpeg",
            "available_stock_kg": 720.0,
            "germination_rate": "88% Min",
            "purity": "99% Min",
            "maturity_days": "50 - 55 Days",
            "crop_season": "Summer & Rainy",
            "availability": "In Stock",
            "description": "Uniform cylindrical light-green bottle gourd with tender pulp and high commercial yield.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-FLW-RAM",
            "name": "Ram F1 Hybrid Marigold",
            "variety_type": "F1 Hybrid Marigold",
            "category": "Flowers",
            "image_url": "/seeds/seed_16.jpeg",
            "available_stock_kg": 420.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "55 - 60 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Spectacular bright yellow large globular marigold flowers favored for festival demand.",
            "package_sizes": "10g, 25g, 50g",
        },
        {
            "sku": "YHS-BG-KAR",
            "name": "Karthi Research Bitter Gourd",
            "variety_type": "Research Bitter Gourd",
            "category": "Vegetables",
            "image_url": "/seeds/seed_17.jpeg",
            "available_stock_kg": 510.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "52 - 58 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Medium-long prickled green fruits with excellent shipping firmness and flavor.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-BG-RUH",
            "name": "Ruhan F1 Hybrid Bitter Gourd",
            "variety_type": "F1 Hybrid Bitter Gourd",
            "category": "Vegetables",
            "image_url": "/seeds/seed_18.jpeg",
            "available_stock_kg": 580.0,
            "germination_rate": "88% Min",
            "purity": "99% Min",
            "maturity_days": "48 - 52 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Deep green compact bitter gourd with high female flower ratio and heavy early yield.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-WM-MEG",
            "name": "Mega F1 Hybrid Watermelon",
            "variety_type": "F1 Hybrid Watermelon",
            "category": "Vegetables",
            "image_url": "/seeds/seed_19.jpeg",
            "available_stock_kg": 890.0,
            "germination_rate": "90% Min",
            "purity": "99% Min",
            "maturity_days": "75 - 80 Days",
            "crop_season": "Summer & Spring",
            "availability": "In Stock",
            "description": "Oblong dark rind watermelon with deep red crisp sweet flesh and high TSS 12-13%.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-CHL-P36",
            "name": "Panja-36 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_20.jpeg",
            "available_stock_kg": 1150.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Vigorous branching chilli hybrid with uniform long fruits and exceptional bearing habit.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-CHL-D27",
            "name": "Divya-27 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_21.jpeg",
            "available_stock_kg": 890.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "70 - 75 Days",
            "crop_season": "All Season Suitable",
            "availability": "In Stock",
            "description": "Specialty light-green elongated hybrid chilli highly favored by wholesale vegetable mandis.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-CHL-C22",
            "name": "Chervi-22 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_23.jpeg",
            "available_stock_kg": 980.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "68 - 72 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "High pungency hybrid chilli producing uniform attractive straight red fruits.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-FLW-BHM",
            "name": "Bheema F1 Hybrid Marigold",
            "variety_type": "F1 Hybrid Marigold",
            "category": "Flowers",
            "image_url": "/seeds/seed_25.jpeg",
            "available_stock_kg": 460.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "55 - 60 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Vibrant orange tight-petaled marigold blooms with strong disease resistance.",
            "package_sizes": "10g, 25g, 50g",
        },
        {
            "sku": "YHS-TOM-ARD",
            "name": "Arudhra F1 Hybrid Tomato",
            "variety_type": "F1 Hybrid Tomato",
            "category": "Vegetables",
            "image_url": "/seeds/seed_26.jpeg",
            "available_stock_kg": 820.0,
            "germination_rate": "90% Min",
            "purity": "99% Min",
            "maturity_days": "60 - 65 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Determinate prolific red tomato with excellent firmness and long distance shipping ability.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-TOM-VER",
            "name": "Veera F1 Hybrid Tomato",
            "variety_type": "F1 Hybrid Tomato",
            "category": "Vegetables",
            "image_url": "/seeds/seed_28.jpeg",
            "available_stock_kg": 910.0,
            "germination_rate": "90% Min",
            "purity": "99% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Semi-determinate square-round tomato with thick pericarp and TyLCV tolerance.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-WM-KUB",
            "name": "Kubera F1 Hybrid Watermelon",
            "variety_type": "F1 Hybrid Watermelon",
            "category": "Vegetables",
            "image_url": "/seeds/seed_31.jpeg",
            "available_stock_kg": 750.0,
            "germination_rate": "90% Min",
            "purity": "99% Min",
            "maturity_days": "70 - 75 Days",
            "crop_season": "Summer & Spring",
            "availability": "In Stock",
            "description": "Striped oblong hybrid watermelon with sweet crisp ruby red flesh and high yield.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-RGD-SAN",
            "name": "Sandy F1 Hybrid Ridge Gourd",
            "variety_type": "F1 Hybrid Ridge Gourd",
            "category": "Vegetables",
            "image_url": "/seeds/seed_32.jpeg",
            "available_stock_kg": 630.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "45 - 50 Days",
            "crop_season": "Rainy & Summer",
            "availability": "In Stock",
            "description": "Deep green straight ridged tender gourd with prolific flushes and tender edible core.",
            "package_sizes": "50g, 100g, 250g",
        },
        {
            "sku": "YHS-PLS-GAN",
            "name": "Ganga Research Cowpea",
            "variety_type": "Research Cowpea",
            "category": "Pulses",
            "image_url": "/seeds/seed_33.jpeg",
            "available_stock_kg": 1120.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "50 - 55 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Bushy cowpea producing long light green tender pods and bold nutritious grains.",
            "package_sizes": "500g, 1kg, 5kg",
        },
        {
            "sku": "YHS-CHL-R55",
            "name": "Ram-55 F1 Hybrid Chilli",
            "variety_type": "F1 Hybrid Chilli",
            "category": "Chilli",
            "image_url": "/seeds/seed_34.jpeg",
            "available_stock_kg": 1020.0,
            "germination_rate": "88% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 70 Days",
            "crop_season": "Kharif & Rabi",
            "availability": "In Stock",
            "description": "Uniform slender green hybrid chilli with dense fruit set and excellent tolerance to heat.",
            "package_sizes": "10g, 50g, 100g",
        },
        {
            "sku": "YHS-FOD-C41",
            "name": "CSV-41 Fodder Jowar",
            "variety_type": "Fodder Jowar",
            "category": "Field Crops",
            "image_url": "/seeds/seed_35.jpeg",
            "available_stock_kg": 2800.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 75 Days",
            "crop_season": "Kharif & Summer",
            "availability": "In Stock",
            "description": "Single-cut highly palatable juicy sweet fodder sorghum with high dry matter and milk yield booster.",
            "package_sizes": "3kg, 5kg, 25kg",
        },
        {
            "sku": "YHS-FOD-C32",
            "name": "CSV-32 Fodder Jowar",
            "variety_type": "Fodder Jowar",
            "category": "Field Crops",
            "image_url": "/seeds/seed_37.jpeg",
            "available_stock_kg": 2500.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "65 - 75 Days",
            "crop_season": "Kharif & Summer",
            "availability": "In Stock",
            "description": "Multi-cut lush forage sorghum with thin stems, broad leaves, and high protein for dairy cattle.",
            "package_sizes": "3kg, 5kg, 25kg",
        },
        {
            "sku": "YHS-PLS-CHY",
            "name": "Chaya Research Cluster Bean",
            "variety_type": "Research Cluster Bean",
            "category": "Pulses",
            "image_url": "/seeds/seed_38.jpeg",
            "available_stock_kg": 1340.0,
            "germination_rate": "85% Min",
            "purity": "98% Min",
            "maturity_days": "45 - 50 Days",
            "crop_season": "All Seasons",
            "availability": "In Stock",
            "description": "Prolific cluster bean with tender non-fibrous dark green pods and excellent branching.",
            "package_sizes": "500g, 1kg, 5kg",
        },
    ]

    for p_data in genuine_products:
        existing = db.query(Product).filter(Product.sku == p_data["sku"]).first()
        if existing:
            for k, v in p_data.items():
                setattr(existing, k, v)
            existing.is_active = True
        else:
            db.add(Product(**p_data, is_active=True))
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
