import subprocess, mysql.connector

cmd = ['gcloud', 'secrets', 'versions', 'access', 'latest', '--secret=yadvi-db-password', '--project=yadvi-seed-app-5f306']
pwd = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, shell=True).stdout.strip()
conn = mysql.connector.connect(host='127.0.0.1', port=3307, user='root', password=pwd, database='yadvi_seeds_db')
cur = conn.cursor(dictionary=True)

cur.execute("SELECT id, username, phone, full_name, role_id, is_active FROM users")
users = cur.fetchall()
print(f"Total users in DB: {len(users)}")
for u in users:
    print(u)

conn.close()
