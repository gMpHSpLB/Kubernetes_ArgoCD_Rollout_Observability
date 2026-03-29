import os
import psycopg2

conn = psycopg2.connect(
    host=os.getenv("DB_HOST", "localhost"),
    database="mydb",
    user="myuser",
    password="mypassword",
    port=5432
)

print("Connected!")

conn.close()
