import sqlite3

def migrate():
    conn = sqlite3.connect('yadvi_seeds.db')
    cur = conn.cursor()
    
    # Check if column exists
    cur.execute("PRAGMA table_info(shop_owners)")
    columns = [info[1] for info in cur.fetchall()]
    
    if 'assigned_executive_id' not in columns:
        print("Adding assigned_executive_id to shop_owners...")
        cur.execute("ALTER TABLE shop_owners ADD COLUMN assigned_executive_id INTEGER REFERENCES field_executives(id) ON DELETE SET NULL")
        conn.commit()
        print("Column added successfully.")
    else:
        print("Column already exists.")
        
    conn.close()

if __name__ == "__main__":
    migrate()
