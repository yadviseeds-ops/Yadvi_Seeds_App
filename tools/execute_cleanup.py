import subprocess
import mysql.connector

cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

print("=" * 60)
print("EXECUTING CONTROLLED DUMMY FE/SO DATA CLEANUP")
print("Preserved: Admin (User ID 1), 'shri' Shop Owner (User ID 26, Shop ID 6)")
print("=" * 60)

try:
    # 1. Unassign executive and clear foreign keys on preserved records
    print("1. Unassigning FE from preserved shop (ID 6) and its orders...")
    cur.execute("UPDATE shop_owners SET assigned_executive_id = NULL WHERE id = 6")
    cur.execute("UPDATE orders SET assigned_executive_id = NULL WHERE shop_id = 6")

    # 2. Delete notifications for dummy orders
    print("2. Deleting notifications for dummy orders...")
    cur.execute("DELETE FROM notifications WHERE order_number NOT IN (SELECT order_number FROM (SELECT order_number FROM orders WHERE shop_id = 6) AS t)")
    del_notifs = cur.rowcount
    print(f"   Deleted {del_notifs} notifications.")

    # 3. Delete order items for dummy orders
    print("3. Deleting order items for dummy orders...")
    cur.execute("DELETE FROM order_items WHERE order_id IN (SELECT id FROM (SELECT id FROM orders WHERE shop_id != 6) AS t)")
    del_order_items = cur.rowcount
    print(f"   Deleted {del_order_items} order items.")

    # 4. Delete shipments for dummy orders
    print("4. Deleting shipments for dummy orders...")
    cur.execute("DELETE FROM shipments WHERE order_id IN (SELECT id FROM (SELECT id FROM orders WHERE shop_id != 6) AS t)")
    del_shipments = cur.rowcount
    print(f"   Deleted {del_shipments} shipments.")

    # 5. Delete dummy orders
    print("5. Deleting dummy orders...")
    cur.execute("DELETE FROM orders WHERE shop_id != 6")
    del_orders = cur.rowcount
    print(f"   Deleted {del_orders} orders.")

    # 6. Delete visits
    print("6. Deleting test visits...")
    cur.execute("DELETE FROM visits")
    del_visits = cur.rowcount
    print(f"   Deleted {del_visits} visits.")

    # 7. Delete EOD reports
    print("7. Deleting test EOD reports...")
    cur.execute("DELETE FROM eod_reports")
    del_eod = cur.rowcount
    print(f"   Deleted {del_eod} EOD reports.")

    # 8. Delete attendance
    print("8. Deleting test attendance records...")
    cur.execute("DELETE FROM attendance")
    del_att = cur.rowcount
    print(f"   Deleted {del_att} attendance records.")

    # 9. Delete FE locations
    print("9. Deleting test FE locations...")
    cur.execute("DELETE FROM fe_locations")
    del_locs = cur.rowcount
    print(f"   Deleted {del_locs} FE locations.")

    # 10. Delete dummy shop owners
    print("10. Deleting dummy shop owners...")
    cur.execute("DELETE FROM shop_owners WHERE id != 6")
    del_shops = cur.rowcount
    print(f"   Deleted {del_shops} shop owners.")

    # 11. Delete dummy field executives
    print("11. Deleting dummy field executives...")
    cur.execute("DELETE FROM field_executives")
    del_fes = cur.rowcount
    print(f"   Deleted {del_fes} field executives.")

    # 12. Delete FCM device tokens for dummy users
    print("12. Deleting FCM device tokens for dummy users...")
    cur.execute("DELETE FROM fcm_device_tokens WHERE user_id NOT IN (1, 26)")
    del_tokens = cur.rowcount
    print(f"   Deleted {del_tokens} FCM tokens.")

    # 13. Delete dummy users
    print("13. Deleting dummy users (all except ID 1 and ID 26)...")
    cur.execute("DELETE FROM users WHERE id NOT IN (1, 26)")
    del_users = cur.rowcount
    print(f"   Deleted {del_users} dummy users.")

    conn.commit()
    print("\n" + "=" * 60)
    print("CLEANUP TRANSACTION COMMITTED SUCCESSFULLY!")
    print("=" * 60)

except Exception as e:
    conn.rollback()
    print(f"ERROR: Transaction rolled back due to error: {e}")
    raise

# Verification of post-cleanup counts
print("\n=== POST-CLEANUP VERIFICATION ===")
cur.execute("SELECT id, username, role_id, phone, full_name FROM users ORDER BY id")
remaining_users = cur.fetchall()
print(f"Remaining Users ({len(remaining_users)}):")
for u in remaining_users:
    print(f"  ID {u['id']}: username='{u['username']}', role_id={u['role_id']}, name='{u['full_name']}'")

cur.execute("SELECT id, user_id, shop_name, address FROM shop_owners")
remaining_shops = cur.fetchall()
print(f"\nRemaining Shop Owners ({len(remaining_shops)}):")
for s in remaining_shops:
    print(f"  ID {s['id']}: user_id={s['user_id']}, name='{s['shop_name']}'")

cur.execute("SELECT COUNT(*) as c FROM field_executives")
remaining_fes = cur.fetchone()['c']
print(f"\nRemaining Field Executives: {remaining_fes} (Expected 0)")

cur.execute("SELECT COUNT(*) as c FROM products")
remaining_products = cur.fetchone()['c']
print(f"Remaining Products: {remaining_products} (Expected 35)")

cur.execute("SELECT COUNT(*) as c FROM orders")
remaining_orders = cur.fetchone()['c']
print(f"Remaining Orders: {remaining_orders} (Expected 2, belonging to 'shri')")

cur.execute("SELECT COUNT(*) as c FROM visits")
print(f"Remaining Visits: {cur.fetchone()['c']} (Expected 0)")

cur.execute("SELECT COUNT(*) as c FROM eod_reports")
print(f"Remaining EOD Reports: {cur.fetchone()['c']} (Expected 0)")

cur.execute("SELECT COUNT(*) as c FROM attendance")
print(f"Remaining Attendance: {cur.fetchone()['c']} (Expected 0)")

cur.execute("SELECT COUNT(*) as c FROM fe_locations")
print(f"Remaining FE Locations: {cur.fetchone()['c']} (Expected 0)")

conn.close()
print("\nPost-cleanup database verification finished successfully.")
