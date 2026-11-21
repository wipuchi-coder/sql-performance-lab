# Resultados de rendimiento

Medición local en `2026-11-18T07:55:05-05:00` (Bogotá), con `16.15`.
Datos de entrada con 200,000 órdenes, 1,980 pendientes y 200,000 líneas.

Una ejecución de calentamiento y 5 mediciones por fase. Se reporta la mediana de `Execution Time` y de cada contador en el nodo raíz. Los buffers se muestran como **local hit/read · shared hit/read**. Las tablas temporales usan buffers locales. Un bloque leído puede provenir de la caché del sistema operativo.

| Caso | Antes (ms) | Después (ms) | Factor antes/después | Buffers antes | Buffers después |
|---|---:|---:|---:|---:|---:|
| B-tree compuesto | 28.379 | 0.108 | 262.77× | 0/3904 · 0/0 | 29/0 · 0/0 |
| B-tree con INCLUDE | 0.121 | 0.123 | 0.98× | 53/0 · 0/0 | 5/0 · 0/0 |
| Índice parcial | 0.189 | 0.173 | 1.09× | 103/0 · 0/0 | 102/0 · 0/0 |
| GIN sobre JSONB | 75.834 | 3.397 | 22.32× | 0/3904 · 0/0 | 951/0 · 0/0 |
| Ventana vs. correlación | 1988.389 | 5.614 | 354.18× | 160032/0 · 0/0 | 32/0 · 0/0 |
| Particionamiento mensual | 28.551 | 3.456 | 8.26× | 0/3904 · 0/0 | 316/0 · 0/0 |

El índice parcial ocupó 81,920 bytes frente a 8,249,344 bytes del índice completo (`pg_relation_size`), una reducción del **99.01 %**.

Se verificó la equivalencia como multiconjunto para cada par de consultas. El caso de ventana usa 5.000 órdenes. La preparación, creación de índices, carga de particiones y planificación quedan fuera de la columna de ejecución. JIT se desactivó para los seis casos.

## Planes de las ejecuciones medianas

### 1. B-tree compuesto

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 6909.22,
    "Total Cost": 6909.28,
    "Plan Rows": 25,
    "Plan Width": 16,
    "Actual Startup Time": 28.326,
    "Actual Total Time": 28.331,
    "Actual Rows": 25,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 3904,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Sort",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Startup Cost": 6909.22,
        "Total Cost": 6909.68,
        "Plan Rows": 185,
        "Plan Width": 16,
        "Actual Startup Time": 28.324,
        "Actual Total Time": 28.327,
        "Actual Rows": 25,
        "Actual Loops": 1,
        "Sort Key": [
          "ordered_at DESC",
          "order_id DESC"
        ],
        "Sort Method": "top-N heapsort",
        "Sort Space Used": 26,
        "Sort Space Type": "Memory",
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 0,
        "Local Read Blocks": 3904,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0,
        "Plans": [
          {
            "Node Type": "Seq Scan",
            "Parent Relationship": "Outer",
            "Parallel Aware": false,
            "Async Capable": false,
            "Relation Name": "bench_orders",
            "Alias": "bench_orders",
            "Startup Cost": 0.0,
            "Total Cost": 6904.0,
            "Plan Rows": 185,
            "Plan Width": 16,
            "Actual Startup Time": 0.124,
            "Actual Total Time": 28.209,
            "Actual Rows": 186,
            "Actual Loops": 1,
            "Filter": "((customer_id = 42) AND (status = 'SHIPPED'::text))",
            "Rows Removed by Filter": 199814,
            "Shared Hit Blocks": 0,
            "Shared Read Blocks": 0,
            "Shared Dirtied Blocks": 0,
            "Shared Written Blocks": 0,
            "Local Hit Blocks": 0,
            "Local Read Blocks": 3904,
            "Local Dirtied Blocks": 0,
            "Local Written Blocks": 0,
            "Temp Read Blocks": 0,
            "Temp Written Blocks": 0
          }
        ]
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.06,
  "Triggers": [],
  "Execution Time": 28.379
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 0.42,
    "Total Cost": 99.84,
    "Plan Rows": 25,
    "Plan Width": 16,
    "Actual Startup Time": 0.043,
    "Actual Total Time": 0.076,
    "Actual Rows": 25,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 29,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Index Only Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Scan Direction": "Forward",
        "Index Name": "bench_orders_customer_id_status_ordered_at_order_id_idx",
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.42,
        "Total Cost": 736.12,
        "Plan Rows": 185,
        "Plan Width": 16,
        "Actual Startup Time": 0.042,
        "Actual Total Time": 0.072,
        "Actual Rows": 25,
        "Actual Loops": 1,
        "Index Cond": "((customer_id = 42) AND (status = 'SHIPPED'::text))",
        "Rows Removed by Index Recheck": 0,
        "Heap Fetches": 25,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 29,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.058,
  "Triggers": [],
  "Execution Time": 0.108
}
```

</details>

### 2. B-tree con INCLUDE

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 0.42,
    "Total Cost": 198.28,
    "Plan Rows": 50,
    "Plan Width": 24,
    "Actual Startup Time": 0.045,
    "Actual Total Time": 0.087,
    "Actual Rows": 50,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 53,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Index Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Scan Direction": "Forward",
        "Index Name": "bench_cover",
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.42,
        "Total Cost": 787.89,
        "Plan Rows": 199,
        "Plan Width": 24,
        "Actual Startup Time": 0.044,
        "Actual Total Time": 0.083,
        "Actual Rows": 50,
        "Actual Loops": 1,
        "Index Cond": "(customer_id = 42)",
        "Rows Removed by Index Recheck": 0,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 53,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.068,
  "Triggers": [],
  "Execution Time": 0.121
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 0.42,
    "Total Cost": 6.32,
    "Plan Rows": 50,
    "Plan Width": 24,
    "Actual Startup Time": 0.052,
    "Actual Total Time": 0.073,
    "Actual Rows": 50,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 5,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Index Only Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Scan Direction": "Forward",
        "Index Name": "bench_cover",
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.42,
        "Total Cost": 23.9,
        "Plan Rows": 199,
        "Plan Width": 24,
        "Actual Startup Time": 0.051,
        "Actual Total Time": 0.068,
        "Actual Rows": 50,
        "Actual Loops": 1,
        "Index Cond": "(customer_id = 42)",
        "Rows Removed by Index Recheck": 0,
        "Heap Fetches": 0,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 5,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.065,
  "Triggers": [],
  "Execution Time": 0.123
}
```

</details>

### 3. Índice parcial

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 0.42,
    "Total Cost": 188.28,
    "Plan Rows": 100,
    "Plan Width": 16,
    "Actual Startup Time": 0.073,
    "Actual Total Time": 0.138,
    "Actual Rows": 100,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 103,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Index Only Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Scan Direction": "Forward",
        "Index Name": "bench_queue",
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.42,
        "Total Cost": 3808.28,
        "Plan Rows": 2027,
        "Plan Width": 16,
        "Actual Startup Time": 0.072,
        "Actual Total Time": 0.13,
        "Actual Rows": 100,
        "Actual Loops": 1,
        "Index Cond": "(status = 'PENDING'::text)",
        "Rows Removed by Index Recheck": 0,
        "Heap Fetches": 100,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 103,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.076,
  "Triggers": [],
  "Execution Time": 0.189
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "Limit",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 0.28,
    "Total Cost": 321.45,
    "Plan Rows": 100,
    "Plan Width": 16,
    "Actual Startup Time": 0.066,
    "Actual Total Time": 0.128,
    "Actual Rows": 100,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 102,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Index Only Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Scan Direction": "Forward",
        "Index Name": "bench_queue",
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.28,
        "Total Cost": 6510.41,
        "Plan Rows": 2027,
        "Plan Width": 16,
        "Actual Startup Time": 0.065,
        "Actual Total Time": 0.118,
        "Actual Rows": 100,
        "Actual Loops": 1,
        "Heap Fetches": 100,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 102,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.065,
  "Triggers": [],
  "Execution Time": 0.173
}
```

</details>

### 4. GIN sobre JSONB

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Seq Scan",
    "Parallel Aware": false,
    "Async Capable": false,
    "Relation Name": "bench_orders",
    "Alias": "bench_orders",
    "Startup Cost": 0.0,
    "Total Cost": 6404.0,
    "Plan Rows": 20,
    "Plan Width": 8,
    "Actual Startup Time": 0.087,
    "Actual Total Time": 75.713,
    "Actual Rows": 947,
    "Actual Loops": 1,
    "Filter": "(metadata @> '{\"channel\": \"partner\"}'::jsonb)",
    "Rows Removed by Filter": 199053,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 3904,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.147,
  "Triggers": [],
  "Execution Time": 75.834
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "Bitmap Heap Scan",
    "Parallel Aware": false,
    "Async Capable": false,
    "Relation Name": "bench_orders",
    "Alias": "bench_orders",
    "Startup Cost": 17.2,
    "Total Cost": 93.15,
    "Plan Rows": 20,
    "Plan Width": 8,
    "Actual Startup Time": 1.32,
    "Actual Total Time": 2.598,
    "Actual Rows": 947,
    "Actual Loops": 1,
    "Recheck Cond": "(metadata @> '{\"channel\": \"partner\"}'::jsonb)",
    "Rows Removed by Index Recheck": 0,
    "Exact Heap Blocks": 947,
    "Lossy Heap Blocks": 0,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 951,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Bitmap Index Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Index Name": "bench_orders_metadata_idx",
        "Startup Cost": 0.0,
        "Total Cost": 17.19,
        "Plan Rows": 20,
        "Plan Width": 0,
        "Actual Startup Time": 0.979,
        "Actual Total Time": 0.98,
        "Actual Rows": 947,
        "Actual Loops": 1,
        "Index Cond": "(metadata @> '{\"channel\": \"partner\"}'::jsonb)",
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 4,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 1,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.2,
  "Triggers": [],
  "Execution Time": 3.397
}
```

</details>

### 5. Ventana vs. correlación

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Seq Scan",
    "Parallel Aware": false,
    "Async Capable": false,
    "Relation Name": "bench_orders",
    "Alias": "o",
    "Startup Cost": 0.0,
    "Total Cost": 472694.5,
    "Plan Rows": 5000,
    "Plan Width": 16,
    "Actual Startup Time": 0.376,
    "Actual Total Time": 1987.604,
    "Actual Rows": 5000,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 160032,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Aggregate",
        "Strategy": "Plain",
        "Partial Mode": "Simple",
        "Parent Relationship": "SubPlan",
        "Subplan Name": "SubPlan 1",
        "Parallel Aware": false,
        "Async Capable": false,
        "Startup Cost": 94.51,
        "Total Cost": 94.52,
        "Plan Rows": 1,
        "Plan Width": 8,
        "Actual Startup Time": 0.396,
        "Actual Total Time": 0.396,
        "Actual Rows": 1,
        "Actual Loops": 5000,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 160000,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0,
        "Plans": [
          {
            "Node Type": "Seq Scan",
            "Parent Relationship": "Outer",
            "Parallel Aware": false,
            "Async Capable": false,
            "Relation Name": "bench_orders",
            "Alias": "p",
            "Startup Cost": 0.0,
            "Total Cost": 94.5,
            "Plan Rows": 5,
            "Plan Width": 0,
            "Actual Startup Time": 0.039,
            "Actual Total Time": 0.393,
            "Actual Rows": 5,
            "Actual Loops": 5000,
            "Filter": "(customer_id = o.customer_id)",
            "Rows Removed by Filter": 4995,
            "Shared Hit Blocks": 0,
            "Shared Read Blocks": 0,
            "Shared Dirtied Blocks": 0,
            "Shared Written Blocks": 0,
            "Local Hit Blocks": 160000,
            "Local Read Blocks": 0,
            "Local Dirtied Blocks": 0,
            "Local Written Blocks": 0,
            "Temp Read Blocks": 0,
            "Temp Written Blocks": 0
          }
        ]
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.065,
  "Triggers": [],
  "Execution Time": 1988.389
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "WindowAgg",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 389.19,
    "Total Cost": 476.69,
    "Plan Rows": 5000,
    "Plan Width": 24,
    "Actual Startup Time": 2.106,
    "Actual Total Time": 5.23,
    "Actual Rows": 5000,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 32,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Sort",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Startup Cost": 389.19,
        "Total Cost": 401.69,
        "Plan Rows": 5000,
        "Plan Width": 16,
        "Actual Startup Time": 2.095,
        "Actual Total Time": 2.464,
        "Actual Rows": 5000,
        "Actual Loops": 1,
        "Sort Key": [
          "customer_id"
        ],
        "Sort Method": "quicksort",
        "Sort Space Used": 388,
        "Sort Space Type": "Memory",
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 32,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0,
        "Plans": [
          {
            "Node Type": "Seq Scan",
            "Parent Relationship": "Outer",
            "Parallel Aware": false,
            "Async Capable": false,
            "Relation Name": "bench_orders",
            "Alias": "bench_orders",
            "Startup Cost": 0.0,
            "Total Cost": 82.0,
            "Plan Rows": 5000,
            "Plan Width": 16,
            "Actual Startup Time": 0.012,
            "Actual Total Time": 0.57,
            "Actual Rows": 5000,
            "Actual Loops": 1,
            "Shared Hit Blocks": 0,
            "Shared Read Blocks": 0,
            "Shared Dirtied Blocks": 0,
            "Shared Written Blocks": 0,
            "Local Hit Blocks": 32,
            "Local Read Blocks": 0,
            "Local Dirtied Blocks": 0,
            "Local Written Blocks": 0,
            "Temp Read Blocks": 0,
            "Temp Written Blocks": 0
          }
        ]
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.041,
  "Triggers": [],
  "Execution Time": 5.614
}
```

</details>

### 6. Particionamiento mensual

<details><summary>Antes</summary>

```json
{
  "Plan": {
    "Node Type": "Aggregate",
    "Strategy": "Plain",
    "Partial Mode": "Simple",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 6944.72,
    "Total Cost": 6944.73,
    "Plan Rows": 1,
    "Plan Width": 8,
    "Actual Startup Time": 28.53,
    "Actual Total Time": 28.531,
    "Actual Rows": 1,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 3904,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Seq Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Relation Name": "bench_orders",
        "Alias": "bench_orders",
        "Startup Cost": 0.0,
        "Total Cost": 6904.0,
        "Plan Rows": 16289,
        "Plan Width": 0,
        "Actual Startup Time": 0.033,
        "Actual Total Time": 27.511,
        "Actual Rows": 16383,
        "Actual Loops": 1,
        "Filter": "((ordered_at >= '2024-06-01 00:00:00'::timestamp without time zone) AND (ordered_at < '2024-07-01 00:00:00'::timestamp without time zone))",
        "Rows Removed by Filter": 183617,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 0,
        "Local Read Blocks": 3904,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.081,
  "Triggers": [],
  "Execution Time": 28.551
}
```

</details>

<details><summary>Después</summary>

```json
{
  "Plan": {
    "Node Type": "Aggregate",
    "Strategy": "Plain",
    "Partial Mode": "Simple",
    "Parallel Aware": false,
    "Async Capable": false,
    "Startup Cost": 602.7,
    "Total Cost": 602.71,
    "Plan Rows": 1,
    "Plan Width": 8,
    "Actual Startup Time": 3.439,
    "Actual Total Time": 3.44,
    "Actual Rows": 1,
    "Actual Loops": 1,
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 316,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0,
    "Plans": [
      {
        "Node Type": "Seq Scan",
        "Parent Relationship": "Outer",
        "Parallel Aware": false,
        "Async Capable": false,
        "Relation Name": "bench_2024_06",
        "Alias": "bench_partitioned",
        "Startup Cost": 0.0,
        "Total Cost": 561.75,
        "Plan Rows": 16380,
        "Plan Width": 0,
        "Actual Startup Time": 0.009,
        "Actual Total Time": 2.414,
        "Actual Rows": 16383,
        "Actual Loops": 1,
        "Filter": "((ordered_at >= '2024-06-01 00:00:00'::timestamp without time zone) AND (ordered_at < '2024-07-01 00:00:00'::timestamp without time zone))",
        "Rows Removed by Filter": 0,
        "Shared Hit Blocks": 0,
        "Shared Read Blocks": 0,
        "Shared Dirtied Blocks": 0,
        "Shared Written Blocks": 0,
        "Local Hit Blocks": 316,
        "Local Read Blocks": 0,
        "Local Dirtied Blocks": 0,
        "Local Written Blocks": 0,
        "Temp Read Blocks": 0,
        "Temp Written Blocks": 0
      }
    ]
  },
  "Planning": {
    "Shared Hit Blocks": 0,
    "Shared Read Blocks": 0,
    "Shared Dirtied Blocks": 0,
    "Shared Written Blocks": 0,
    "Local Hit Blocks": 0,
    "Local Read Blocks": 0,
    "Local Dirtied Blocks": 0,
    "Local Written Blocks": 0,
    "Temp Read Blocks": 0,
    "Temp Written Blocks": 0
  },
  "Planning Time": 0.113,
  "Triggers": [],
  "Execution Time": 3.456
}
```

</details>
