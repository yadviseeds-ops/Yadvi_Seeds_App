import subprocess, mysql.connector
cmd = ['gcloud.cmd', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

cur.execute("SELECT id, username, phone, full_name, role_id FROM users WHERE LOWER(TRIM(username)) = 'shri'")
print('Exact match shri:', cur.fetchall())

cur.execute("SELECT id, username, phone, full_name, role_id FROM users WHERE LOWER(TRIM(username)) = 'shree'")
print('Exact match shree:', cur.fetchall())

cur.execute("SELECT id, user_id, shop_name, address FROM shop_owners WHERE user_id IN (SELECT id FROM users WHERE LOWER(TRIM(username)) IN ('shri', 'shree'))")
print('Shop owner record for shri/shree:', cur.fetchall())
conn.close()

