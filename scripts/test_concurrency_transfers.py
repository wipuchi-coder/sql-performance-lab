"""Prueba transferencias cruzadas en una base local dedicada de laboratorio."""
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from threading import Barrier
from time import monotonic, sleep
from uuid import uuid4

import psycopg

TRANSFER_COUNT = 20
INITIAL_BALANCE = Decimal("5000.00")
AMOUNT = Decimal("100.00")


def create_accounts(connection, run_id):
    with connection.transaction():
        connection.execute("INSERT INTO fintech.currency VALUES ('USD') ON CONFLICT DO NOTHING")
        (customer_id,) = connection.execute(
            "INSERT INTO fintech.customer (email, full_name) VALUES (%s, %s) RETURNING customer_id",
            (f"concurrency-{run_id}@example.test", "Prueba de concurrencia"),
        ).fetchone()
        accounts = connection.execute(
            """
            INSERT INTO fintech.account (customer_id, currency_code, balance)
            VALUES (%s, 'USD', %s), (%s, 'USD', %s) RETURNING account_id
            """,
            (customer_id, INITIAL_BALANCE, customer_id, INITIAL_BALANCE),
        ).fetchall()
    return tuple(sorted(account_id for (account_id,) in accounts))


def transfer(source, destination, start, application_name):
    try:
        with psycopg.connect("", application_name=application_name, connect_timeout=5) as connection:
            connection.execute("SET LOCAL statement_timeout = '30s'")
            start.wait(timeout=15)
            connection.execute("CALL fintech.post_transfer(%s, %s, %s)", (source, destination, AMOUNT))
    except psycopg.Error as error:
        start.abort()
        return error.sqlstate or "sin SQLSTATE"
    return None


def wait_for_contention(connection, application_name):
    deadline = monotonic() + 15
    while monotonic() < deadline:
        connection.execute("SELECT pg_stat_clear_snapshot()")
        (blocked,) = connection.execute(
            """
            SELECT count(*) FROM pg_stat_activity
            WHERE application_name = %s AND wait_event_type = 'Lock'
            """,
            (application_name,),
        ).fetchone()
        if blocked == TRANSFER_COUNT:
            return
        sleep(0.05)
    raise RuntimeError(f"Solo se observaron {blocked}/{TRANSFER_COUNT} sesiones bloqueadas")


def main():
    run_id = uuid4().hex
    application_name = f"lab-transfer-{run_id}"
    with psycopg.connect("", autocommit=True, connect_timeout=5) as coordinator:
        a, b = create_accounts(coordinator, run_id)
        directions = [(a, b), (b, a)] * (TRANSFER_COUNT // 2)
        start = Barrier(TRANSFER_COUNT + 1)

        with ThreadPoolExecutor(max_workers=TRANSFER_COUNT) as executor:
            with coordinator.transaction():
                coordinator.execute(
                    "SELECT account_id FROM fintech.account WHERE account_id = %s FOR NO KEY UPDATE",
                    (a,),
                ).fetchall()
                futures = [
                    executor.submit(transfer, source, destination, start, application_name)
                    for source, destination in directions
                ]
                start.wait(timeout=15)
                wait_for_contention(coordinator, application_name)
            errors = Counter(code for future in futures if (code := future.result()) is not None)

        balances = coordinator.execute(
            "SELECT balance FROM fintech.account WHERE account_id IN (%s, %s) ORDER BY account_id",
            (a, b),
        ).fetchall()
        records = coordinator.execute(
            """
            SELECT source_id, destination_id, amount FROM fintech.transfer
            WHERE source_id IN (%s, %s) OR destination_id IN (%s, %s)
            """,
            (a, b, a, b),
        ).fetchall()
        version = coordinator.execute("SHOW server_version").fetchone()[0]

    expected = Counter((source, destination, AMOUNT) for source, destination in directions)
    total = sum(balance for (balance,) in balances)
    print(f"PostgreSQL {version} | cuentas sintéticas {a}, {b} | {TRANSFER_COUNT} sesiones en espera")
    print(f"Transferencias confirmadas: {TRANSFER_COUNT - sum(errors.values())}/{TRANSFER_COUNT}")
    print(f"Deadlocks (40P01): {errors['40P01']} | saldo combinado: USD {total:.2f}")
    if errors or balances != [(INITIAL_BALANCE,), (INITIAL_BALANCE,)] or Counter(records) != expected:
        raise SystemExit(f"Falló la verificación. SQLSTATE: {dict(errors)}. Saldos: {balances}")
    print("Verificado: 10 transferencias por sentido, importes exactos y saldos individuales intactos.")


if __name__ == "__main__":
    main()
