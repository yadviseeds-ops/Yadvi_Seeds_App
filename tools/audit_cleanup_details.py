import subprocess, mysql.connector

cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

# Admin ID: 1
# Preserved SO User ID: 26, ShopOwner ID: 6

print("=== AUDIT OF RECORDS TO DELETE ===")
# 1. Field Executives
cur.execute("SELECT id, user_id, employee_code FROM field_executives")
all_fe = cur.fetchall()
fe_ids = [r['id'] for r in all_fe]
fe_user_ids = [r['user_id'] for r in all_fe]
print(f"FEs ({len(fe_ids)}): {fe_ids}")
print(f"FE User IDs ({len(fe_user_ids)}): {fe_user_ids}")

# 2. Shop Owners to delete (all except ID 6)
cur.execute("SELECT id, user_id, shop_name FROM shop_owners WHERE id != 6")
del_so = cur.fetchall()
del_so_ids = [r['id'] for r in del_so]
del_so_user_ids = [r['user_id'] for r in del_so]
print(f"Shop Owners to delete ({len(del_so_ids)}): {del_so_ids}")
print(f"Shop Owner User IDs to delete ({len(del_so_user_ids)}): {del_so_user_ids}")

# 3. Visits
cur.execute("SELECT COUNT(*) as c FROM visits")
print(f"Total visits: {cur.fetchone()['c']}")

# 4. Attendance
cur.execute("SELECT COUNT(*) as c FROM attendance")
print(f"Total attendance: {cur.fetchone()['c']}")

# 5. EOD Reports
cur.execute("SELECT COUNT(*) as c FROM eod_reports")
print(f"Total EOD reports: {cur.fetchone()['c']}")

# 6. FE Locations
cur.execute("SELECT COUNT(*) as c FROM fe_locations")
print(f"Total FE locations: {cur.fetchone()['c']}")

# 7. Orders & Order Items
cur.execute("SELECT id FROM orders WHERE shop_id != 6")
del_orders = [r['id'] for r in cur.fetchall()]
print(f"Orders to delete ({len(del_orders)}): {del_orders}")
if del_orders:
    format_strings = ','.join(['%s'] * len(del_orders))
    cur.execute(f"SELECT COUNT(*) as c FROM order_items WHERE order_id IN ({format_strings})", tuple(del_orders))
    print(f"Order items to delete: {cur.fetchone()['c']}")

# 8. Check if shri (shop_id=6) has any orders
cur.execute("SELECT COUNT(*) as c FROM orders WHERE shop_id = 6")
print(f"Orders belonging to preserved shri (shop_id=6): {cur.fetchone()['c']}")

# 9. FCM Device Tokens
cur.execute("SELECT COUNT(*) as c FROM fcm_device_tokens WHERE user_id NOT IN (1, 26)")
print(f"FCM tokens to delete: {cur.fetchone()['c']}")

# 10. Notifications
cur.execute("SELECT COUNT(*) as c FROM notifications WHERE user_id NOT IN (1, 26)")
print(f"Notifications to delete: {cur.fetchone()['c']}")

# 11. Shipments
cur.execute("SELECT COUNT(*) as c FROM shipments WHERE order_id IN (SELECT id FROM orders WHERE shop_id != 6)")
print(f"Shipments tied to deleted orders: {cur.fetchone()['c']}")

# 12. Check products table (must be untouched)
cur.execute("SELECT COUNT(*) as c FROM products")
print(f"Products in catalogue (must be preserved): {cur.fetchone()['c']}")

conn.close()

