with open('backend/app/core/database.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''def get_engine():
    # Construct primary database connection URL securely using URL.create'''

replacement = '''def get_engine():
    if os.getenv("USE_SQLITE", "false").lower() in ("true", "1") and settings.ENVIRONMENT.lower() not in ("production", "staging"):
        sqlite_url = f"sqlite:///{settings.SQLITE_DB_PATH}"
        logger.info(f"USE_SQLITE active: utilizing local SQLite engine ({settings.SQLITE_DB_PATH})")
        return create_engine(sqlite_url, connect_args={"check_same_thread": False})

    # Construct primary database connection URL securely using URL.create'''

assert target in content, "target not found"
content = content.replace(target, replacement)

with open('backend/app/core/database.py', 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print("Updated database.py with USE_SQLITE check")

