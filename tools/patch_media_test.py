with open('backend/test_media_storage.py', 'r', encoding='utf-8') as f:
    content = f.read()

old_methods = '''    def test_product_upload_rejects_non_image(self):
        import asyncio
        from fastapi import UploadFile
        from app.api.products import upload_product_image
        from app.models.all_models import User, Role

        admin_user = User(id=1, full_name="Admin", phone="9999999999")
        admin_user.role = Role(id=1, name="administrator")

        bad_file = UploadFile(filename="test.txt", file=io.BytesIO(b"Not an image at all!"))
        with pytest.raises(HTTPException) as exc_info:
            asyncio.run(upload_product_image(file=bad_file, current_user=admin_user))
        assert exc_info.value.status_code == 400
        assert "Invalid image format" in exc_info.value.detail

    def test_product_upload_accepts_valid_image(self):
        import asyncio
        from fastapi import UploadFile
        from app.api.products import upload_product_image
        from app.models.all_models import User, Role

        admin_user = User(id=1, full_name="Admin", phone="9999999999")
        admin_user.role = Role(id=1, name="administrator")

        with tempfile.TemporaryDirectory() as tmp_dir:
            reset_media_storage_for_testing(LocalStorageBackend(base_dir=tmp_dir))
            valid_png = UploadFile(filename="sample.png", file=io.BytesIO(b"\\x89PNG\\r\\n\\x1a\\n" + b"\\x00" * 32))
            res = asyncio.run(upload_product_image(file=valid_png, current_user=admin_user))'''

new_methods = '''    @pytest.mark.anyio
    async def test_product_upload_rejects_non_image(self):
        from fastapi import UploadFile
        from app.api.products import upload_product_image
        from app.models.all_models import User, Role

        admin_user = User(id=1, full_name="Admin", phone="9999999999")
        admin_user.role = Role(id=1, name="administrator")

        bad_file = UploadFile(filename="test.txt", file=io.BytesIO(b"Not an image at all!"))
        with pytest.raises(HTTPException) as exc_info:
            await upload_product_image(file=bad_file, current_user=admin_user)
        assert exc_info.value.status_code == 400
        assert "Invalid image format" in exc_info.value.detail

    @pytest.mark.anyio
    async def test_product_upload_accepts_valid_image(self):
        from fastapi import UploadFile
        from app.api.products import upload_product_image
        from app.models.all_models import User, Role

        admin_user = User(id=1, full_name="Admin", phone="9999999999")
        admin_user.role = Role(id=1, name="administrator")

        with tempfile.TemporaryDirectory() as tmp_dir:
            reset_media_storage_for_testing(LocalStorageBackend(base_dir=tmp_dir))
            valid_png = UploadFile(filename="sample.png", file=io.BytesIO(b"\\x89PNG\\r\\n\\x1a\\n" + b"\\x00" * 32))
            res = await upload_product_image(file=valid_png, current_user=admin_user)'''

assert old_methods in content, "old_methods not found"
content = content.replace(old_methods, new_methods)

with open('backend/test_media_storage.py', 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print("Updated test_media_storage.py to use async anyio")
