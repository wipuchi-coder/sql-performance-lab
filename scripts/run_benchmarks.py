"""Ejecuta experimentos aislados y publica un informe Markdown reproducible."""
import argparse
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path
from statistics import median
from zoneinfo import ZoneInfo

import psycopg

ROOT = Path(__file__).resolve().parents[1]
BUFFER_KEYS = ("Local Hit Blocks", "Local Read Blocks", "Shared Hit Blocks", "Shared Read Blocks")
CASE_NAMES = (
    "B-tree compuesto", "B-tree con INCLUDE", "Índice parcial",
    "GIN sobre JSONB", "Ventana vs. correlación", "Particionamiento mensual",
)


def execute_file(connection, path):
    connection.execute(path.read_text(encoding="utf-8"))


def measure(connection, query, runs):
    plans = [
        connection.execute(
            "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query
        ).fetchone()[0][0]
        for _ in range(runs + 1)
    ][1:]
    return {
        "ms": median(plan["Execution Time"] for plan in plans),
        "buffers": [median(plan["Plan"][key] for plan in plans) for key in BUFFER_KEYS],
        "sample": sorted(plans, key=lambda plan: plan["Execution Time"])[runs // 2],
    }


def run_case(path, runs):
    parts = re.split(r"^-- (setup|vacuum|before|optimize|after|size)$",
                     path.read_text(encoding="utf-8"), flags=re.MULTILINE)
    sections = dict(zip(parts[1::2], parts[2::2], strict=True))
    with psycopg.connect("", autocommit=True) as connection:
        connection.execute("SET jit = off")
        connection.execute(sections["setup"])
        if "vacuum" in sections:
            connection.execute(sections["vacuum"])
        before = measure(connection, sections["before"], runs)
        expected = Counter(connection.execute(sections["before"]).fetchall())
        size_before = connection.execute(sections["size"]).fetchone()[0] if "size" in sections else None
        if "optimize" in sections:
            connection.execute(sections["optimize"])
        after = measure(connection, sections["after"], runs)
        actual = Counter(connection.execute(sections["after"]).fetchall())
        if expected != actual or not actual:
            raise RuntimeError(f"Resultados distintos o vacíos en {path.name}")
        size_after = connection.execute(sections["size"]).fetchone()[0] if "size" in sections else None
        return before, after, size_before, size_after


def buffer_summary(phase):
    local_hits, local_reads, shared_hits, shared_reads = phase["buffers"]
    return f"{local_hits:g}/{local_reads:g} · {shared_hits:g}/{shared_reads:g}"


def render_report(results, version, counts, runs):
    executed = datetime.now(ZoneInfo("America/Bogota")).isoformat(timespec="seconds")
    orders, pending, lines = counts
    report = [
        "# Resultados de rendimiento", "",
        f"Medición local en `{executed}` (Bogotá), con `{version}`.",
        f"Datos de entrada con {orders:,} órdenes, {pending:,} pendientes y {lines:,} líneas.", "",
        f"Una ejecución de calentamiento y {runs} mediciones por fase. Se reporta la mediana de "
        "`Execution Time` y de cada contador en el nodo raíz. Los buffers se muestran como "
        "**local hit/read · shared hit/read**. Las tablas temporales usan buffers locales. "
        "Un bloque leído puede provenir de la caché del sistema operativo.", "",
        "| Caso | Antes (ms) | Después (ms) | Factor antes/después | Buffers antes | Buffers después |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, (before, after, _, _) in zip(CASE_NAMES, results, strict=True):
        factor = f'{before["ms"] / after["ms"]:.2f}×' if after["ms"] else "—"
        report.append(f'| {name} | {before["ms"]:.3f} | {after["ms"]:.3f} | {factor} | '
                      f'{buffer_summary(before)} | {buffer_summary(after)} |')

    _, _, full, partial = results[2]
    report.extend([
        "", f"El índice parcial ocupó {partial:,} bytes frente a {full:,} bytes del índice completo "
        f"(`pg_relation_size`), una reducción del **{100 * (1 - partial / full):.2f} %**.",
        "", "Se verificó la equivalencia como multiconjunto para cada par de consultas. "
        "El caso de ventana usa 5.000 órdenes. La preparación, creación de índices, "
        "carga de particiones y planificación quedan fuera de la columna de ejecución. "
        "JIT se desactivó para los seis casos.", "",
        "## Planes de las ejecuciones medianas", "",
    ])
    for index, (name, (before, after, _, _)) in enumerate(zip(CASE_NAMES, results, strict=True), 1):
        report.extend([f"### {index}. {name}", ""])
        for label, phase in (("Antes", before), ("Después", after)):
            report.extend([f"<details><summary>{label}</summary>", "", "```json",
                           json.dumps(phase["sample"], ensure_ascii=False, indent=2),
                           "```", "", "</details>", ""])
    return "\n".join(report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", choices=("sql", "copy"),
                        help="instala los modelos, carga los datos y ejecuta las pruebas")
    parser.add_argument("--runs", type=int, default=5, help="mediciones por fase (impar)")
    parser.add_argument("--output", type=Path, default=ROOT / "BENCHMARK_RESULTS.md")
    args = parser.parse_args()
    if args.runs < 1 or args.runs % 2 == 0:
        parser.error("--runs debe ser un entero impar positivo")

    if args.setup == "copy":
        import subprocess
        import sys

    with psycopg.connect("", autocommit=True) as connection:
        if args.setup:
            for path in sorted((ROOT / "01_modeling").glob("*.sql")):
                execute_file(connection, path)
            if args.setup == "sql":
                execute_file(connection, ROOT / "02_seeding/seed_200k.sql")
            else:
                subprocess.run([sys.executable, str(ROOT / "02_seeding/bulk_loader.py")], check=True)
            for filename in ("audit_triggers.sql", "stored_procedures.sql", "test_plpgsql.sql"):
                execute_file(connection, ROOT / "03_plpgsql" / filename)
            print("Modelos cargados y pruebas funcionales superadas.", flush=True)
        version = connection.execute("SHOW server_version").fetchone()[0]
        counts = connection.execute("""
            SELECT count(*), count(*) FILTER (WHERE status = 'PENDING'),
                   (SELECT count(*) FROM shop.order_line)
            FROM shop.orders
        """).fetchone()
        if counts[0] != 200_000 or counts[2] != 200_000:
            parser.error("Se requiere una base dedicada con 200.000 órdenes y sus 200.000 líneas.")

    results = []
    for path in sorted((ROOT / "04_benchmarks").glob("case_*.sql")):
        print(f"Ejecutando {path.stem}", flush=True)
        results.append(run_case(path, args.runs))
    report = render_report(results, version, counts, args.runs)
    args.output.write_text(report, encoding="utf-8")
    print(f"Informe generado en {args.output.resolve()}")


if __name__ == "__main__":
    main()
