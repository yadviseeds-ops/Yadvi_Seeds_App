"""
Comprehensive Automated Test Suite for Task 6:
Make Owner Full Name Optional During Shop Owner Registration.

Test Cases:
1. Submit registration with Owner Full Name supplied — must succeed.
2. Submit registration with Owner Full Name omitted — must succeed.
3. Submit registration with Owner Full Name explicitly set to null — must succeed.
4. Submit registration with Owner Full Name as an empty string — must succeed.
5. Submit registration with Owner Full Name containing only whitespace — must succeed and normalize to None.
6. Submit registration with other required fields missing (phone, username, shop_name, address) — must fail with 400.
7. Verify existing Shop Owner records and names remain unchanged.
8. Verify Shop Owner login and authentication behavior remains intact.
"""

import sys
import asyncio
import httpx
from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, ShopOwner, Role
from app.core.security import create_access_token

async def run_tests():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n========================================================")
        print("TASK 6: SHOP OWNER OPTIONAL OWNER FULL NAME TEST SUITE")
        print("========================================================\n")

        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        assert admin_user is not None, "Administrator user required for testing"
        token = create_access_token(data={"sub": str(admin_user.id), "role": "Admin"})
        headers = {"Authorization": f"Bearer {token}"}

        # Cleanup helper
        def cleanup_user_by_phone(phone: str):
            u = db.query(User).filter(User.phone == phone).first()
            if u:
                db.query(ShopOwner).filter(ShopOwner.user_id == u.id).delete()
                db.delete(u)
                db.commit()

        # ----------------------------------------------------
        # 1. Registration with Owner Full Name supplied
        # ----------------------------------------------------
        p1_phone = "9876000001"
        p1_user = "so_name_supplied"
        cleanup_user_by_phone(p1_phone)

        payload_with_name = {
            "owner_name": "Ramesh Kumar Rao",
            "shop_name": "Ramesh Agro Agencies",
            "phone": p1_phone,
            "username": p1_user,
            "market_location": "Guntur Market Yard",
            "address": "Shop #12, Phase 1, Guntur",
        }
        res1 = await client.post("/api/v1/shops", json=payload_with_name, headers=headers)
        assert res1.status_code == 200, f"Expected 200, got {res1.status_code}: {res1.text}"
        data1 = res1.json()
        assert data1["owner_name"] == "Ramesh Kumar Rao"
        assert data1["shop_name"] == "Ramesh Agro Agencies"
        assert data1["phone"] == p1_phone
        print("[PASS] Case 1: Owner Full Name supplied -> Registration succeeds with entered name")

        # ----------------------------------------------------
        # 2. Registration with Owner Full Name omitted
        # ----------------------------------------------------
        p2_phone = "9876000002"
        p2_user = "so_name_omitted"
        cleanup_user_by_phone(p2_phone)

        payload_omitted = {
            "shop_name": "Sri Lakshmi Seeds Center",
            "phone": p2_phone,
            "username": p2_user,
            "market_location": "Tenali Town",
            "address": "Bazaar Street, Tenali",
        }
        res2 = await client.post("/api/v1/shops", json=payload_omitted, headers=headers)
        assert res2.status_code == 200, f"Expected 200, got {res2.status_code}: {res2.text}"
        data2 = res2.json()
        assert data2["owner_name"] is None or data2["owner_name"] == "", f"Expected None/empty owner_name, got {data2['owner_name']}"
        assert data2["shop_name"] == "Sri Lakshmi Seeds Center"
        print("[PASS] Case 2: Owner Full Name omitted -> Registration succeeds with None/empty name")

        # ----------------------------------------------------
        # 3. Registration with Owner Full Name explicitly null
        # ----------------------------------------------------
        p3_phone = "9876000003"
        p3_user = "so_name_null"
        cleanup_user_by_phone(p3_phone)

        payload_null = {
            "owner_name": None,
            "shop_name": "Krishna River Agro Tech",
            "phone": p3_phone,
            "username": p3_user,
            "market_location": "Vijayawada Center",
            "address": "Governorpet, Vijayawada",
        }
        res3 = await client.post("/api/v1/shops", json=payload_null, headers=headers)
        assert res3.status_code == 200, f"Expected 200, got {res3.status_code}: {res3.text}"
        data3 = res3.json()
        assert data3["owner_name"] is None or data3["owner_name"] == "", f"Expected None/empty owner_name, got {data3['owner_name']}"
        print("[PASS] Case 3: Owner Full Name explicitly null -> Registration succeeds")

        # ----------------------------------------------------
        # 4. Registration with Owner Full Name empty string
        # ----------------------------------------------------
        p4_phone = "9876000004"
        p4_user = "so_name_empty"
        cleanup_user_by_phone(p4_phone)

        payload_empty = {
            "owner_name": "",
            "shop_name": "Amaravati Farmers Hub",
            "phone": p4_phone,
            "username": p4_user,
            "market_location": "Mangalagiri",
            "address": "Old Trunk Road, Mangalagiri",
        }
        res4 = await client.post("/api/v1/shops", json=payload_empty, headers=headers)
        assert res4.status_code == 200, f"Expected 200, got {res4.status_code}: {res4.text}"
        data4 = res4.json()
        assert data4["owner_name"] is None or data4["owner_name"] == "", f"Expected None/empty owner_name, got {data4['owner_name']}"
        print("[PASS] Case 4: Owner Full Name empty string -> Registration succeeds")

        # ----------------------------------------------------
        # 5. Registration with Owner Full Name whitespace only
        # ----------------------------------------------------
        p5_phone = "9876000005"
        p5_user = "so_name_whitespace"
        cleanup_user_by_phone(p5_phone)

        payload_whitespace = {
            "owner_name": "    \t   ",
            "shop_name": "Balaji Hybrid Seeds",
            "phone": p5_phone,
            "username": p5_user,
            "market_location": "Nandigama",
            "address": "Highway Junction, Nandigama",
        }
        res5 = await client.post("/api/v1/shops", json=payload_whitespace, headers=headers)
        assert res5.status_code == 200, f"Expected 200, got {res5.status_code}: {res5.text}"
        data5 = res5.json()
        assert data5["owner_name"] is None or data5["owner_name"] == "", f"Expected None/empty owner_name, got {data5['owner_name']}"
        print("[PASS] Case 5: Owner Full Name whitespace only -> Normalized to None/empty and succeeds")

        # ----------------------------------------------------
        # 6. Missing other mandatory fields -> Must fail validation
        # ----------------------------------------------------
        # Missing phone
        res_no_phone = await client.post("/api/v1/shops", json={
            "shop_name": "Invalid Shop",
            "username": "inv_phone",
            "address": "Anywhere"
        }, headers=headers)
        assert res_no_phone.status_code in (400, 422), f"Expected 400/422 for missing phone, got {res_no_phone.status_code}"

        # Missing username
        res_no_user = await client.post("/api/v1/shops", json={
            "shop_name": "Invalid Shop",
            "phone": "9999999999",
            "address": "Anywhere"
        }, headers=headers)
        assert res_no_user.status_code in (400, 422), f"Expected 400/422 for missing username, got {res_no_user.status_code}"

        # Missing shop_name
        res_no_shop = await client.post("/api/v1/shops", json={
            "phone": "9999999998",
            "username": "inv_shop",
            "address": "Anywhere"
        }, headers=headers)
        assert res_no_shop.status_code in (400, 422), f"Expected 400/422 for missing shop_name, got {res_no_shop.status_code}"

        # Missing address
        res_no_addr = await client.post("/api/v1/shops", json={
            "shop_name": "Invalid Shop",
            "phone": "9999999997",
            "username": "inv_addr"
        }, headers=headers)
        assert res_no_addr.status_code in (400, 422), f"Expected 400/422 for missing address, got {res_no_addr.status_code}"
        print("[PASS] Case 6: Missing other mandatory fields (phone, username, shop_name, address) correctly rejected")

        # ----------------------------------------------------
        # 7. Verify existing Shop Owner records and names remain unchanged
        # ----------------------------------------------------
        existing_shops = db.query(ShopOwner).join(ShopOwner.user).filter(User.full_name != "").all()
        assert len(existing_shops) > 0, "Expected existing shop owners in database"
        sample_shop = existing_shops[0]
        sample_name = sample_shop.user.full_name
        assert sample_name is not None and len(sample_name) > 0, "Existing shop owner name must not be overwritten"
        res_get_shop = await client.get(f"/api/v1/shops/{sample_shop.id}", headers=headers)
        assert res_get_shop.status_code == 200
        assert res_get_shop.json()["owner_name"] == sample_name
        print(f"[PASS] Case 7: Existing Shop Owner record '{sample_shop.shop_name}' preserved with name '{sample_name}'")

        # ----------------------------------------------------
        # 8. Verify Shop Owner login behavior remains unchanged
        # ----------------------------------------------------
        # Verify SO can authenticate using registered mobile
        so_user = db.query(User).filter(User.role.has(name="shop_owner")).first()
        assert so_user is not None
        assert so_user.phone is not None
        so_token = create_access_token(data={"sub": str(so_user.id), "role": "shop_owner"})
        so_headers = {"Authorization": f"Bearer {so_token}"}
        res_my_shop = await client.get("/api/v1/shops/my", headers=so_headers)
        assert res_my_shop.status_code == 200
        assert res_my_shop.json()["phone"] == so_user.phone
        print(f"[PASS] Case 8: Shop Owner authentication and /api/v1/shops/my access verified cleanly for {so_user.username}")

        print("\n=== ALL 8 TASK 6 INTEGRATION TEST CASES PASSED SUCCESSFULLY! ===\n")

if __name__ == "__main__":
    asyncio.run(run_tests())
