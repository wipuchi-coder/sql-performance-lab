"""Carga el mismo conjunto que seed_200k.sql por COPY FROM STDIN."""
import csv
import hashlib
import io
import json
from datetime import datetime, timedelta
from pathlib import Path
from time import perf_counter

import psycopg

ROW_COUNT = 200_000
BATCH_SIZE = 4096
START = datetime(2024, 1, 1)


def order_rows():
    for order_id in range(1, ROW_COUNT + 1):
        status = "SHIPPED"
        if order_id % 101 == 0:
            status = "PENDING"
        elif order_id % 17 == 0:
            status = "CANCELLED"
        metadata = {
            "channel": "partner" if order_id % 211 == 0 else "web",
            "batch": order_id % 367,
            "reference": hashlib.md5(str(order_id).encode(), usedforsecurity=False).hexdigest(),
        }
        yield (
            order_id,
            1 + order_id * 7919 % 1000,
            START + timedelta(seconds=order_id * 104729 % 31622400),
            status,
            json.dumps(metadata),
        )


def main():
    seed = Path(__file__).with_name("seed_200k.sql").read_text(encoding="utf-8")
    parents, rest = seed.split("-- COPY ORDERS BEGIN", 1)
    _, lines = rest.split("-- COPY ORDERS END", 1)
    parents = parents.removeprefix("BEGIN;")
    lines, maintenance = lines.split("COMMIT;", 1)

    started = perf_counter()
    with psycopg.connect("", autocommit=True) as connection:
        with connection.transaction(), connection.cursor() as cursor:
            cursor.execute(parents)
            cursor.execute("""
                CREATE TEMP TABLE order_stage (LIKE shop.orders) ON COMMIT DROP
            """)
            buffer = io.StringIO()
            writer = csv.writer(buffer, lineterminator="\n")
            with cursor.copy("COPY order_stage FROM STDIN WITH (FORMAT CSV)") as copy:
                for count, row in enumerate(order_rows(), 1):
                    writer.writerow(row)
                    if count % BATCH_SIZE == 0:
                        copy.write(buffer.getvalue())
                        buffer.seek(0)
                        buffer.truncate()
                if buffer.tell():
                    copy.write(buffer.getvalue())
            cursor.execute("""
                INSERT INTO shop.orders (order_id, customer_id, ordered_at, status, metadata)
                SELECT order_id, customer_id, ordered_at, status, metadata FROM order_stage
                ON CONFLICT (order_id) DO NOTHING
            """)
            inserted = cursor.rowcount
            cursor.execute(lines)
        connection.execute(maintenance)
    elapsed = perf_counter() - started
    print(f"{ROW_COUNT:,} filas por COPY, {inserted:,} órdenes nuevas en {elapsed:.2f} s")


if __name__ == "__main__":
    main()
