import asyncio
import httpx
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, ShopOwner, FieldExecutive
from app.core.security import create_access_token

async def run_fe_shop_picker_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING FE SHOP PICKER BACKEND TESTS ===\n")

        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        so_user = db.query(User).filter(User.role.has(name="shop_owner")).first()

        assert fe_user is not None, "FE user required"
        assert admin_user is not None, "Admin user required"

        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})
        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_headers = {"Authorization": f"Bearer {fe_token}"}
        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        # 1. Unauthenticated request to /api/v1/shops rejected with 401
        res_unauth = await client.get("/api/v1/shops")
        assert res_unauth.status_code == 401, f"Expected 401, got {res_unauth.status_code}"
        print("[PASS] 1. Unauthenticated request to /api/v1/shops rejected with 401")

        # 2. Shop Owner cannot list all shops (403)
        if so_user:
            so_token = create_access_token(data={"sub": str(so_user.id), "role": "shop_owner", "name": so_user.full_name})
            res_so = await client.get("/api/v1/shops", headers={"Authorization": f"Bearer {so_token}"})
            assert res_so.status_code == 403, f"Expected 403 for SO, got {res_so.status_code}"
            print("[PASS] 2. Shop Owner forbidden from listing all shops (403)")

        # 3. FE GET /api/v1/shops returns all active registered shops by default
        res_fe_default = await client.get("/api/v1/shops", headers=fe_headers)
        assert res_fe_default.status_code == 200, f"Expected 200, got {res_fe_default.status_code}"
        shops_default = res_fe_default.json()
        active_db_shops = db.query(ShopOwner).filter(ShopOwner.status == "Active").count()
        assert len(shops_default) == active_db_shops, f"Expected {active_db_shops} active shops, got {len(shops_default)}"
        print(f"[PASS] 3. FE GET /api/v1/shops returns all {len(shops_default)} active registered shops by default")

        # 4. FE GET /api/v1/shops?all_shops=true also returns all active registered shops
        res_fe_all = await client.get("/api/v1/shops?all_shops=true", headers=fe_headers)
        assert res_fe_all.status_code == 200
        shops_all = res_fe_all.json()
        assert len(shops_all) == active_db_shops
        print(f"[PASS] 4. FE GET /api/v1/shops?all_shops=true returns all {len(shops_all)} active registered shops")

        # 5. Inactive shops are strictly excluded
        for s in shops_default:
            assert s["status"] == "Active", f"Inactive shop {s['id']} found in output!"
        print("[PASS] 5. Inactive shops are strictly excluded from results")

        # 6. Admin created shop is immediately visible to FE
        res_admin = await client.get("/api/v1/shops", headers=admin_headers)
        assert res_admin.status_code == 200
        admin_shops = res_admin.json()
        assert len(admin_shops) == len(shops_default), "Admin and FE should both see active registered shops for planning"
        print(f"[PASS] 6. Admin and FE shop views consistent for active registered shops ({len(admin_shops)} shops)")

        print("\n=== ALL FE SHOP PICKER BACKEND TESTS PASSED ===\n")

if __name__ == "__main__":
    asyncio.run(run_fe_shop_picker_tests())
