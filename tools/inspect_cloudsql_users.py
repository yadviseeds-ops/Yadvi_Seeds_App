import subprocess
import mysql.connector

cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

print('=== USERS IN CLOUD SQL ===')
cur.execute('''
    SELECT u.id, u.username, u.phone, u.full_name, r.name as role_name, u.is_active
    FROM users u
    JOIN roles r ON u.role_id = r.id
    ORDER BY u.id
''')
users = cur.fetchall()
for u in users:
    print(f"User id={u['id']}, username={u['username']}, phone={u['phone']}, role={u['role_name']}, name={u['full_name']}")

print('\n=== SHOP OWNERS IN CLOUD SQL ===')
cur.execute('''
    SELECT s.id, s.user_id, s.shop_name, s.market_location, s.assigned_executive_id, u.phone, u.username
    FROM shop_owners s
    LEFT JOIN users u ON s.user_id = u.id
    ORDER BY s.id
''')
shops = cur.fetchall()
for s in shops:
    print(f"Shop id={s['id']}, user_id={s['user_id']}, shop_name={s['shop_name']}, phone={s['phone']}, username={s['username']}")

conn.close()

