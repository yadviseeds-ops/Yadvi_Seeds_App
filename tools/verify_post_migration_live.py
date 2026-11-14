import subprocess
import mysql.connector

def verify():
    cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
    pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
    conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
    cur = conn.cursor(dictionary=True)

    cur.execute("""
        SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_TYPE
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = 'yadvi_seeds_db' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'full_name'
    """)
    col = cur.fetchone()
    print("Column verification:", col)
    assert col['IS_NULLABLE'] == 'YES', "Column must be nullable!"

    cur.execute("SELECT COUNT(*) as cnt FROM users")
    cnt = cur.fetchone()['cnt']
    print(f"Total users: {cnt} (verified intact)")
    assert cnt == 26, f"Expected 26 users, found {cnt}"

    # Test inserting with NULL full_name inside a transaction and rollback
    cur.execute("SELECT id FROM roles WHERE name='shop_owner' LIMIT 1")
    role_id = cur.fetchone()['id']
    cur.execute(
        "INSERT INTO users (username, phone, full_name, role_id, hashed_password, is_active) VALUES (%s, %s, NULL, %s, %s, 1)",
        ("test_null_user_check", "9000000000", role_id, "hash")
    )
    print("Test insert with NULL full_name succeeded! Row ID:", cur.lastrowid)
    conn.rollback()
    print("Transaction rolled back cleanly. Database remains in pristine state!")
    conn.close()

if __name__ == '__main__':
    verify()
