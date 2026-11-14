import subprocess, mysql.connector

cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

cur.execute('''
    SELECT u.id, u.username, u.phone, u.full_name, r.name as role,
           fe.id as fe_id, so.id as so_id
    FROM users u
    JOIN roles r ON u.role_id = r.id
    LEFT JOIN field_executives fe ON fe.user_id = u.id
    LEFT JOIN shop_owners so ON so.user_id = u.id
    WHERE u.id NOT IN (1, 26)
    ORDER BY u.id
''')
non_preserved = cur.fetchall()
print(f"Total non-preserved users to clean up: {len(non_preserved)}")
for u in non_preserved:
    print(f"User ID {u['id']:2d}: {u['role']:15s} | username={u['username']:15s} | fe_id={str(u['fe_id']):5s} | so_id={str(u['so_id']):5s}")

cur.execute("DESCRIBE notifications")
print("\nNotifications columns:")
for col in cur.fetchall():
    print(col['Field'], col['Type'])

conn.close()

