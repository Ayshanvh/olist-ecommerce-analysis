import io
import os
import subprocess
import sys
from pathlib import Path

import pandas as pd
from openpyxl.styles import Font

os.environ.setdefault("PGHOST", "localhost")
os.environ.setdefault("PGPORT", "5432")
os.environ.setdefault("PGUSER", "postgres")
os.environ.setdefault("PGPASSWORD", "postgres")
os.environ.setdefault("PGDATABASE", "postgres")

HERE = Path(__file__).resolve().parent if "__file__" in globals() else Path.cwd()
OUT_FILE = Path(os.environ.get("OUT_FILE", "olist_before_after.xlsx"))
DICT_CSV = Path(os.environ.get("DICT_CSV", HERE.parent / "docs" / "column_dictionary.csv"))

def run_sql(sql: str) -> pd.DataFrame:
    wrapped = f"COPY ({sql.strip().rstrip(';')}) TO STDOUT WITH CSV HEADER"
    r = subprocess.run(
        ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-c", wrapped],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit(f"SQL xətası:\n{r.stderr}\n--- sorğu ---\n{sql[:500]}")
    if not r.stdout.strip():
        return pd.DataFrame()
    return pd.read_csv(io.StringIO(r.stdout), keep_default_na=False)

def columns_of(schema: str) -> dict:
    df = run_sql(
        f"""SELECT table_name, column_name FROM information_schema.columns
            WHERE table_schema = '{schema}' ORDER BY table_name, ordinal_position"""
    )
    out = {}
    for t, c in zip(df["table_name"], df["column_name"]):
        out.setdefault(t, []).append(c)
    return out

def blank_report(schema: str) -> pd.DataFrame:
    parts = []
    for table, cols in columns_of(schema).items():
        if table == "cleaning_log":
            continue
        for c in cols:
            parts.append(
                f"""SELECT '{table}' AS table_name, '{c}' AS column_name,
                           COUNT(*) AS total_rows,
                           COUNT(*) FILTER (WHERE NULLIF(TRIM("{c}"::text), '') IS NULL) AS blank_cells
                    FROM {schema}.{table}"""
            )
    df = run_sql(" UNION ALL ".join(parts))
    df["blank_pct"] = (100 * df["blank_cells"] / df["total_rows"]).round(2)
    return df.sort_values(["blank_cells"], ascending=False).reset_index(drop=True)

KEYS = {
    "customers": "customer_id",
    "orders": "order_id",
    "order_items": "order_id, order_item_id",
    "order_payments": "order_id, payment_sequential",
    "order_reviews": "review_id",
    "products": "product_id",
    "sellers": "seller_id",
    "geolocation": "geolocation_zip_code_prefix, geolocation_lat, geolocation_lng",
    "product_category_name_translation": "product_category_name",
}

def duplicate_report() -> pd.DataFrame:
    parts = []
    for t, key in KEYS.items():
        parts.append(
            f"""SELECT '{t}' AS table_name,
                       '{key}' AS key_columns,
                       (SELECT COUNT(*) FROM raw.{t}) AS total_rows,
                       (SELECT COUNT(*) FROM raw.{t}) - (SELECT COUNT(*) FROM (SELECT DISTINCT {key} FROM raw.{t}) k) AS duplicate_by_key,
                       (SELECT COUNT(*) FROM raw.{t}) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM raw.{t}) d) AS fully_identical_rows"""
        )
    return run_sql(" UNION ALL ".join(parts))

def main():
    print("Sorğular işlənir...")
    before_after = run_sql(
        """
        SELECT t.tbl AS table_name, t.raw_rows, t.clean_rows, t.raw_rows - t.clean_rows AS rows_removed
        FROM (
            SELECT 'customers' AS tbl, (SELECT COUNT(*) FROM raw.customers) AS raw_rows, (SELECT COUNT(*) FROM clean.customers) AS clean_rows
            UNION ALL SELECT 'orders',         (SELECT COUNT(*) FROM raw.orders),         (SELECT COUNT(*) FROM clean.orders)
            UNION ALL SELECT 'order_items',    (SELECT COUNT(*) FROM raw.order_items),    (SELECT COUNT(*) FROM clean.order_items)
            UNION ALL SELECT 'order_payments', (SELECT COUNT(*) FROM raw.order_payments), (SELECT COUNT(*) FROM clean.order_payments)
            UNION ALL SELECT 'order_reviews',  (SELECT COUNT(*) FROM raw.order_reviews),  (SELECT COUNT(*) FROM clean.order_reviews)
            UNION ALL SELECT 'products',       (SELECT COUNT(*) FROM raw.products),       (SELECT COUNT(*) FROM clean.products)
            UNION ALL SELECT 'sellers',        (SELECT COUNT(*) FROM raw.sellers),        (SELECT COUNT(*) FROM clean.sellers)
            UNION ALL SELECT 'geolocation',    (SELECT COUNT(*) FROM raw.geolocation),    (SELECT COUNT(*) FROM clean.geolocation)
        ) t ORDER BY t.tbl
        """
    )
    blanks_raw = blank_report("raw")
    blanks_clean = blank_report("clean")
    dups = duplicate_report()
    log = run_sql("SELECT step_no, table_name, issue, rows_affected, decision FROM clean.cleaning_log ORDER BY step_no")
    dictionary = pd.read_csv(DICT_CSV, keep_default_na=False)
    monthly = run_sql(
        """
        SELECT TO_CHAR(o.purchase_month, 'YYYY-MM') AS month,
               COUNT(DISTINCT o.order_id) AS orders,
               ROUND(SUM(i.price), 2)     AS revenue,
               ROUND(SUM(i.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
        FROM clean.orders o JOIN clean.order_items i ON i.order_id = o.order_id
        WHERE o.order_status NOT IN ('canceled', 'unavailable')
        GROUP BY o.purchase_month ORDER BY o.purchase_month
        """
    )
    pivot_data = run_sql(
        """
        SELECT o.order_id,
               TO_CHAR(o.purchase_month, 'YYYY-MM') AS month,
               EXTRACT(YEAR FROM o.purchase_month)::int AS year,
               o.order_status,
               c.state AS customer_state,
               p.category_en AS category,
               i.price
        FROM clean.order_items i
        JOIN clean.orders    o ON o.order_id    = i.order_id
        JOIN clean.customers c ON c.customer_id = o.customer_id
        JOIN clean.products  p ON p.product_id  = i.product_id
        ORDER BY o.purchase_month, o.order_id
        """
    )

    sheets = {
        "1_Əvvəl_Sonra": before_after,
        "2_Boş_xanalar_raw": blanks_raw,
        "3_Boş_xanalar_clean": blanks_clean,
        "4_Təkrarlar": dups,
        "5_Jurnal": log,
        "6_Sütun_lüğəti": dictionary,
        "7_Aylıq_dinamika": monthly,
        "8_Pivot_data": pivot_data,
    }

    print(f"Excel yazılır: {OUT_FILE}")
    with pd.ExcelWriter(OUT_FILE, engine="openpyxl") as xw:
        for name, df in sheets.items():
            df.to_excel(xw, sheet_name=name, index=False)
            ws = xw.sheets[name]
            ws.freeze_panes = "A2"
            ws.auto_filter.ref = ws.dimensions
            for cell in ws[1]:
                cell.font = Font(bold=True)
            for col in ws.columns:
                width = max(len(str(c.value)) if c.value is not None else 0 for c in list(col)[:200])
                ws.column_dimensions[col[0].column_letter].width = min(max(width + 2, 10), 60)

    print("Hazırdır:", OUT_FILE.resolve())
    try:
        from google.colab import files
        files.download(str(OUT_FILE))
    except ImportError:
        pass

if __name__ == "__main__":
    main()
