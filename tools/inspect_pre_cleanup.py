import subprocess
import mysql.connector

# Fetch DB password from Secret Manager
cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()

conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

print("=" * 60)
print("1. USERS & ROLES IN CLOUD SQL")
print("=" * 60)
cur.execute('''
    SELECT u.id, u.username, u.phone, u.full_name, r.name as role_name, u.is_active, u.created_at
    FROM users u
    JOIN roles r ON u.role_id = r.id
    ORDER BY u.id
''')
users = cur.fetchall()
admin_users = []
shri_users = []
fe_users = []
other_so_users = []

for u in users:
    role = u['role_name']
    username = (u['username'] or '').strip().lower()
    masked_phone = u['phone'][:2] + '******' + u['phone'][-2:] if u['phone'] and len(u['phone']) >= 4 else '****'
    print(f"User ID: {u['id']:2d} | Role: {role:15s} | Username: {u['username']:15s} | Phone: {masked_phone} | Name: {u['full_name']}")
    if role == 'administrator':
        admin_users.append(u)
    elif role == 'shop_owner':
        if username == 'shri':
            shri_users.append(u)
        else:
            other_so_users.append(u)
    elif role == 'field_executive':
        fe_users.append(u)

print("\n" + "=" * 60)
print("2. PRESERVED ACCOUNTS CHECK")
print("=" * 60)
print(f"Admin accounts found: {len(admin_users)}")
for a in admin_users:
    print(f"  -> Admin ID: {a['id']}, Username: {a['username']}")

print(f"\n'shri' Shop Owner accounts found: {len(shri_users)}")
for s in shri_users:
    print(f"  -> shri User ID: {s['id']}, Username: {s['username']}")

assert len(admin_users) >= 1, "Error: No Admin account found!"
assert len(shri_users) == 1, f"Error: Expected exactly 1 'shri' account, found {len(shri_users)}!"

shri_user_id = shri_users[0]['id']

# Check shop_owners table for shri
cur.execute("SELECT * FROM shop_owners WHERE user_id = %s", (shri_user_id,))
shri_shop = cur.fetchone()
print(f"  -> shri ShopOwner ID: {shri_shop['id'] if shri_shop else 'None'}, Shop Name: {shri_shop['shop_name'] if shri_shop else 'None'}")
assert shri_shop is not None, "Error: No ShopOwner profile for 'shri'!"
shri_shop_id = shri_shop['id']

print("\n" + "=" * 60)
print("3. TABLE COUNTS PRE-CLEANUP")
print("=" * 60)
tables = [
    'users', 'roles', 'admin_phones', 'field_executives', 'shop_owners',
    'visits', 'attendance', 'eod_reports', 'fe_locations',
    'orders', 'order_items', 'fcm_device_tokens', 'products', 'shipments', 'notifications'
]
counts = {}
for t in tables:
    cur.execute(f"SELECT COUNT(*) as cnt FROM {t}")
    counts[t] = cur.fetchone()['cnt']
    print(f"{t:20s}: {counts[t]:4d}")

print("\n" + "=" * 60)
print("4. DELETION CANDIDATES BREAKDOWN")
print("=" * 60)
# FEs to delete
cur.execute("SELECT id, user_id, employee_code FROM field_executives")
all_fes = cur.fetchall()
fe_ids = [fe['id'] for fe in all_fes]
fe_user_ids = [fe['user_id'] for fe in all_fes]
print(f"Field Executives to delete: {len(fe_ids)} (IDs: {fe_ids})")

# SOs to delete (excluding shri)
cur.execute("SELECT id, user_id, shop_name FROM shop_owners WHERE id != %s", (shri_shop_id,))
del_sos = cur.fetchall()
del_so_ids = [s['id'] for s in del_sos]
del_so_user_ids = [s['user_id'] for s in del_sos]
print(f"Shop Owners to delete: {len(del_so_ids)} (IDs: {del_so_ids})")

# Dependent visits
cur.execute("SELECT COUNT(*) as cnt FROM visits")
total_visits = cur.fetchone()['cnt']
print(f"Visits to delete: {total_visits}")

# Dependent EOD
cur.execute("SELECT COUNT(*) as cnt FROM eod_reports")
total_eod = cur.fetchone()['cnt']
print(f"EOD reports to delete: {total_eod}")

# Dependent attendance
cur.execute("SELECT COUNT(*) as cnt FROM attendance")
total_att = cur.fetchone()['cnt']
print(f"Attendance records to delete: {total_att}")

# Dependent FE locations
cur.execute("SELECT COUNT(*) as cnt FROM fe_locations")
total_locs = cur.fetchone()['cnt']
print(f"FE location points to delete: {total_locs}")

# Orders to delete (belonging to deleted SOs)
cur.execute("SELECT COUNT(*) as cnt FROM orders WHERE shop_id != %s", (shri_shop_id,))
del_orders_cnt = cur.fetchone()['cnt']
cur.execute("SELECT COUNT(*) as cnt FROM orders WHERE shop_id = %s", (shri_shop_id,))
shri_orders_cnt = cur.fetchone()['cnt']
print(f"Orders belonging to deleted SOs: {del_orders_cnt}")
print(f"Orders belonging to preserved 'shri': {shri_orders_cnt}")

# Foreign key constraints check
print("\n" + "=" * 60)
print("5. FOREIGN KEY CONSTRAINTS ON OPERATIONAL TABLES")
print("=" * 60)
cur.execute('''
    SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = 'yadvi_seeds_db' AND REFERENCED_TABLE_NAME IS NOT NULL
    ORDER BY TABLE_NAME
''')
fks = cur.fetchall()
for fk in fks:
    print(f"{fk['TABLE_NAME']}.{fk['COLUMN_NAME']} -> {fk['REFERENCED_TABLE_NAME']}.{fk['REFERENCED_COLUMN_NAME']} ({fk['CONSTRAINT_NAME']})")

conn.close()
print("\nPre-cleanup inspection complete.")

