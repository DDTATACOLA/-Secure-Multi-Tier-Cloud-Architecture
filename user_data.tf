#!/bin/bash
dnf update -y
dnf install -y python3-pip
pip3 install flask pymysql boto3 watchtower

mkdir -p /opt/rdsapp
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
from watchtower import CloudWatchLogHandler
from flask import Flask, request

# Setup default region, keep other region for code logic and redundancy
os.environ["AWS_DEFAULT_REGION"] = "us-east-2"

# Setup CloudWatch Logging
# This sends any log.error() directly to the Log Group we made in Terraform
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.addHandler(CloudWatchLogHandler(log_group="/aws/ec2/lab-rds-app", stream_name="flask-app"))

REGION = os.environ.get("AWS_REGION", "us-east-2")
SECRET_ID = "lab/rds/mysql"
PARAM_ENDPOINT = "/lab/db/endpoint"
PARAM_DBNAME = "/lab/db/dbname"

ssm = boto3.client("ssm", region_name=REGION)
secrets = boto3.client("secretsmanager", region_name=REGION)

def get_config():
    # Fetch Non-Sensitive Info from Parameter Store
    try:
        host = ssm.get_parameter(Name=PARAM_ENDPOINT)["Parameter"]["Value"]
        dbname = ssm.get_parameter(Name=PARAM_DBNAME)["Parameter"]["Value"]
        return host, dbname
    except Exception as e:
        logger.error(f"Failed to fetch SSM Parameters: {str(e)}")
        raise e

def get_creds():
    # Fetch Sensitive Info from Secrets Manager
    try:
        resp = secrets.get_secret_value(SecretId=SECRET_ID)
        s = json.loads(resp["SecretString"])
        return s["username"], s["password"]
    except Exception as e:
        logger.error(f"Failed to fetch Secrets: {str(e)}")
        raise e

def get_conn():
    try:
        host, dbname = get_config()
        user, password = get_creds()
        
        # Connect
        conn = pymysql.connect(host=host, user=user, password=password, database=dbname, cursorclass=pymysql.cursors.DictCursor, autocommit=True)
        logger.info("Database connection successful")
        return conn
    except Exception as e:
        # !!! CRITICAL: This specific phrase triggers the CloudWatch Alarm !!!
        logger.error(f"CRITICAL: Database connection failed: {str(e)}")
        return None

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>Private EC2 App with CloudWatch Logging</h2>
    <h2>EC2 → RDS Notes App</h2>
    <p>POST /add?note=hello</p>
    <p>GET /list</p>
    <p>TEST /test-db</p>
    """

@app.route("/test-db")
def test_db():
    conn = get_conn()
    if conn:
        conn.close()
        return "Database Connected!"
    else:
        return "Database Connection Failed! (Check CloudWatch Logs)", 500

@app.route("/init")
def init_db():
    try:
        # FIXED: Use the correct functions for config AND creds
        host, dbname = get_config()     # Get host from SSM
        user, password = get_creds()    # Get user/pass from Secrets Manager
        
        # Connect
        conn = pymysql.connect(host=host, user=user, password=password, port=3306, autocommit=True)
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {dbname};")
        cur.execute(f"USE {dbname};")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                note VARCHAR(255) NOT NULL
            );
        """)
        cur.close()
        conn.close()
        return "Initialized labdb + notes table."
    except Exception as e:
        return f"Init failed: {str(e)}", 500

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note param. Try: /add?note=hello", 400
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Inserted note: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    out = "<h3>Notes</h3><ul>"
    for r in rows:
        out += f"<li>{r['id']}: {r['note']}</li>"
    out += "</ul>"
    return out

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)
PY

cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=lab/rds/mysql
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp
