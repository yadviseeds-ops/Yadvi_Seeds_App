with open('backend/app/api/visits.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = """    # Generate secure server-side filename and persist through media storage abstraction
    safe_filename = generate_safe_filename(prefix=f"visit_{visit.id}", extension=detected_ext)
    storage = get_media_storage()
    saved_url = storage.save(contents, safe_filename, content_type=detected_mime, folder="visits")"""

replacement = """    # Generate secure server-side filename and persist through media storage abstraction
    safe_filename = generate_safe_filename(prefix=f"visit_{visit.id}", extension=detected_ext)
    storage = get_media_storage()
    try:
        saved_url = storage.save(contents, safe_filename, content_type=detected_mime, folder="visits")
    except Exception as exc:
        logger.error(f"Failed to persist visit photo for visit {visit.id}: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload visit photograph: {str(exc)}"
        )"""

assert target in content, "Target not found in visits.py"
content = content.replace(target, replacement)
with open('backend/app/api/visits.py', 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print("Updated visits.py with robust storage upload error handling")

