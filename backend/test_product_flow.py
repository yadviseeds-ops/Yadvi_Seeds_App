import requests
import io

BASE_URL = "http://127.0.0.1:8000/api/v1"
STATIC_BASE = "http://127.0.0.1:8000"

def run_tests():
    print("=== STARTING PRODUCT & VARIETY FORM COMPREHENSIVE VERIFICATION ===")

    # 1. Login as Admin
    admin_login = requests.post(f"{BASE_URL}/auth/login", json={"username": "ADMIN", "password": "admin123"}).json()
    assert "access_token" in admin_login, f"Admin login failed: {admin_login}"
    token = admin_login["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("[PASS] 1. Admin authenticated successfully")

    # 2. Create a product with blank SKU (Requirement 1 & 6.1)
    payload_blank_sku = {
        "name": "Super Gold Maize Hybrid",
        "variety_type": "Maize",
        "sku": "",  # Blank SKU
        "category": "Field Crop Seeds",
        "image_url": "",
        "available_stock_kg": 450.5,
        "germination_rate": "90% Min",
        "purity": "98% Min",
        "availability": "In Stock",
        "package_sizes": "1kg, 5kg, 10kg"
    }
    res_blank = requests.post(f"{BASE_URL}/products", json=payload_blank_sku, headers=headers)
    assert res_blank.status_code in [200, 201], f"Blank SKU creation failed: {res_blank.text}"
    prod_blank = res_blank.json()
    print("Created Product (Blank SKU):", prod_blank["name"], "Generated SKU:", prod_blank["sku"], "Stock:", prod_blank["available_stock_kg"])
    assert prod_blank["sku"].startswith("YHS-"), f"SKU was not auto-generated: {prod_blank['sku']}"
    assert prod_blank["available_stock_kg"] == 450.5, f"Stock kg mismatch: {prod_blank['available_stock_kg']}"
    print(f"[PASS] 2. Product created with blank SKU successfully. Auto-generated SKU: {prod_blank['sku']}")

    # 3. Test Product Image Upload (Requirement 3 & 6.3)
    # 1x1 transparent PNG magic bytes
    png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    upload_res = requests.post(
        f"{BASE_URL}/products/upload-image",
        files={"file": ("seed_test.png", io.BytesIO(png_bytes), "image/png")},
        headers=headers
    )
    assert upload_res.status_code in [200, 201], f"Upload image failed: {upload_res.text}"
    upload_data = upload_res.json()
    assert "image_url" in upload_data, f"image_url not in response: {upload_data}"
    image_url = upload_data["image_url"]
    print("Uploaded image URL:", image_url)
    assert image_url.startswith("/public/products/"), f"Unexpected image_url format: {image_url}"
    print("[PASS] 3. Image uploaded successfully via backend media storage")

    # 3b. Verify image is served statically and accessible
    image_fetch_res = requests.get(f"{STATIC_BASE}{image_url}")
    assert image_fetch_res.status_code == 200, f"Cannot fetch uploaded image: {image_fetch_res.status_code}"
    assert image_fetch_res.headers.get("content-type", "").startswith("image/"), f"Wrong content-type: {image_fetch_res.headers.get('content-type')}"
    print(f"[PASS] 3b. Static image serving confirmed: {STATIC_BASE}{image_url} -> 200 OK")

    # 4. Create Product with the uploaded Image (Requirement 3 & 6.4)
    payload_with_image = {
        "name": "Krishna-99 Super Chilli",
        "variety_type": "Chilli",
        "sku": "YHS-CHL-TEST-99",
        "category": "Vegetable Seeds",
        "image_url": image_url,
        "available_stock_kg": 320.0,
        "germination_rate": "88% Min",
        "purity": "99% Min",
        "availability": "In Stock",
        "package_sizes": "100g, 250g, 500g, 1kg"
    }
    res_img_prod = requests.post(f"{BASE_URL}/products", json=payload_with_image, headers=headers)
    assert res_img_prod.status_code in [200, 201], f"Product with image creation failed: {res_img_prod.text}"
    prod_with_img = res_img_prod.json()
    assert prod_with_img["image_url"] == image_url, f"Image URL not preserved: {prod_with_img['image_url']}"
    assert prod_with_img["available_stock_kg"] == 320.0
    print(f"[PASS] 4. Created product with image: ID={prod_with_img['id']}, Image='{prod_with_img['image_url']}', Stock={prod_with_img['available_stock_kg']} kg")

    # 5. Verify product listing reflects image and kg stock (Requirement 6.4 & 6.8)
    list_res = requests.get(f"{BASE_URL}/products", headers=headers)
    assert list_res.status_code == 200
    listed_prod = next(p for p in list_res.json() if p["id"] == prod_with_img["id"])
    assert listed_prod["image_url"] == image_url
    assert listed_prod["available_stock_kg"] == 320.0
    print(f"[PASS] 5. GET /products confirmed product displays correct image and kg stock")

    # 6. Test Edit existing product preserves image unless changed (Requirement 6.6)
    edit_payload = {
        "name": "Krishna-99 Super Chilli (Premium Grade)",
        "available_stock_kg": 750.0,
        "description": "Upgraded high yield variety with pest resistance."
    }
    edit_res = requests.put(f"{BASE_URL}/products/{prod_with_img['id']}", json=edit_payload, headers=headers)
    assert edit_res.status_code == 200, f"Edit product failed: {edit_res.text}"
    edited_prod = edit_res.json()
    assert edited_prod["name"] == "Krishna-99 Super Chilli (Premium Grade)"
    assert edited_prod["available_stock_kg"] == 750.0
    assert edited_prod["image_url"] == image_url, f"Image was overwritten or lost during edit: {edited_prod['image_url']}"
    print(f"[PASS] 6. Product edited successfully: Name='{edited_prod['name']}', Stock={edited_prod['available_stock_kg']} kg, Image preserved='{edited_prod['image_url']}'")

    # 7. Test API validation error handling (Requirement 4 & 6.7)
    # 7a. Missing product name
    missing_name_res = requests.post(f"{BASE_URL}/products", json={"name": "", "variety_type": "Tomato", "category": "Veg"}, headers=headers)
    assert missing_name_res.status_code == 400
    assert "Product Name is mandatory" in missing_name_res.text
    print(f"[PASS] 7a. Missing name returns useful validation error: {missing_name_res.json()['detail']}")

    # 7b. Duplicate SKU error
    dup_sku_res = requests.post(f"{BASE_URL}/products", json={"name": "Dup Variety", "variety_type": "Chilli", "category": "Veg", "sku": "YHS-CHL-TEST-99"}, headers=headers)
    assert dup_sku_res.status_code == 400
    assert "already exists" in dup_sku_res.text
    print(f"[PASS] 7b. Duplicate SKU returns useful validation error: {dup_sku_res.json()['detail']}")

    # 8. Clean up created test products
    requests.delete(f"{BASE_URL}/products/{prod_blank['id']}", headers=headers)
    requests.delete(f"{BASE_URL}/products/{prod_with_img['id']}", headers=headers)
    print("[PASS] 8. Cleaned up temporary test products")

    print("\n*** ALL BACKEND PRODUCT TESTS PASSED 100%! ***")

if __name__ == "__main__":
    run_tests()
