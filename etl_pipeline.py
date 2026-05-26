import pandas as pd
import mysql.connector 
import os
import json
from datetime import datetime

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "Jungkook*1",
    "database": "fashion_db",
}

CSV_PATH = "data/fashion_retail_sales.csv" 

def extract():
    print("EXTRACT: Reading CSV file...")
    df = pd.read_csv(CSV_PATH)
    print(f"EXTRACT: {len(df)} rows loaded")
    return df

def transform(df):
    print("TRANSFORM: Cleaning data...")
    df.columns = [c.strip().lower().replace(" ","_") for c in df.columns]

    df = df.rename(columns={
        "customer_reference_id": "customer_id",
        "purchase_amount_(usd)": "purchase_amount",
        "date_purchase":         "date_purchase",
        "review_rating":         "review_rating",
        "payment_method":        "payment_method",
        "item_purchased":        "item_purchased",
    })
    
    before = len(df)
    df = df.drop_duplicates()
    print(f"TRANSFORM: Removed {before-len(df)} duplicates")

    df["purchase_amount"] = pd.to_numeric(df["purchase_amount"], errors="coerce")
    df["review_rating"] = pd.to_numeric(df["review_rating"], errors="coerce")

    df = df.dropna(subset=["purchase_amount"])
    
    print(f"Transform: {len(df)} clean rows ready")

    return df

def load(df):
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("""
                CREATE TABLE IF NOT EXISTS fashion_sales(
                    id              INT AUTO_INCREMENT PRIMARY KEY,
                    customer_id     VARCHAR(100),
                    item_purchased  VARCHAR(200),
                    purchase_amount DECIMAL(10,2),
                    date_purchase   VARCHAR(50),
                    review_rating   DECIMAL(3,1),
                    payment_method  VARCHAR(50)
                    )
                """)

    cursor.execute("TRUNCATE TABLE fashion_sales")

    insert_sql = """
            INSERT INTO fashion_sales
            (customer_id, item_purchased, purchase_amount,
            date_purchase, review_rating, payment_method)
            VALUES (%s, %s, %s, %s, %s, %s)
        """

    rows = []
    for _, row in df.iterrows():
        rows.append((
            str(row["customer_id"]),
            str(row["item_purchased"]),
            float(row["purchase_amount"]),
            str(row["date_purchase"]),
            float(row["review_rating"]) if pd.notna(row["review_rating"]) else None,
            str(row["payment_method"]),
        ))

    cursor.executemany(insert_sql, rows)

    conn.commit()
    print(f"Load: {cursor.rowcount} rows inserted into MySQL")

    cursor.close()
    conn.close()

# ── EXPORT JSON ──────────────────────────────────────────
# This creates a summary file that the dashboard reads
# Instead of the dashboard connecting to MySQL directly
# we export a simple JSON file - easier and faster

def export_json(df):
    print("EXPORT: Creating dashboard data...")

    # os.makedirs creates the folder if it doesn't exist
    # exist_ok=True means don't crash if folder already exists
    os.makedirs("dashboard", exist_ok=True)

    # build the summary dictionary
    summary = {

        # when was this data generated
        "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M"),

        # top level numbers - KPI cards
        "total_records":   int(len(df)),
        "total_revenue":   round(float(df["purchase_amount"].sum()), 2),
        "avg_purchase":    round(float(df["purchase_amount"].mean()), 2),
        "avg_rating":      round(float(df["review_rating"].mean()), 1),

        # top 10 items by purchase count
        "top_items": (
            df.groupby("item_purchased")
            .size()
            .sort_values(ascending=False)
            .head(10)
            .reset_index()
            .rename(columns={0: "count"})
            .to_dict(orient="records")
        ),

        # revenue by payment method
        "payment_methods": (
            df.groupby("payment_method")["purchase_amount"]
            .sum()
            .round(2)
            .reset_index()
            .rename(columns={"purchase_amount": "revenue"})
            .to_dict(orient="records")
        ),

        # monthly revenue trend
        "monthly_trend": (
            df.groupby("date_purchase")["purchase_amount"]
            .sum()
            .round(2)
            .reset_index()
            .rename(columns={"purchase_amount": "revenue"})
            .sort_values("date_purchase")
            .to_dict(orient="records")
        ),

        # rating distribution
        "rating_distribution": (
            df["review_rating"]
            .dropna()
            .apply(lambda x: round(x))
            .value_counts()
            .sort_index()
            .reset_index()
            .rename(columns={"review_rating": "rating", "count": "total"})
            .to_dict(orient="records")
        ),
    }

    # save as JSON file
    with open("dashboard/data.json", "w") as f:
        json.dump(summary, f, indent=2)

    print("EXPORT: dashboard/data.json created")

if __name__ == "__main__":
    print("=" * 40)
    print(" Fashion ETL Pipeline starting")
    print("=" * 40)
    df_raw = extract() 
    df_clean = transform(df_raw)
    load(df_clean)
    export_json(df_clean)
