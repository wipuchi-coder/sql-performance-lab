# SQL Performance Lab

Laboratorio de PostgreSQL de [Holger Andrés Meneses Jaramillo](https://github.com/wipuchi-coder). Reúne tres modelos relacionales, dos rutas de carga masiva y seis experimentos reproducibles de rendimiento con `EXPLAIN (ANALYZE, BUFFERS)`.

## Arquitectura

| Ruta | Responsabilidad |
|---|---|
| [01_modeling](01_modeling/) | Esquemas independientes `fintech`, `shop` y `clinic`, diagramas ER y justificación de 3FN. |
| [02_seeding](02_seeding/) | 200.000 órdenes y 200.000 líneas reproducibles, más 1.000 clientes y 500 productos. SQL con `generate_series` o Python con `COPY FROM STDIN` por bloques. |
| [03_plpgsql](03_plpgsql/) | Auditoría JSONB por fila, transferencia atómica y pruebas funcionales con rollback. |
| [04_benchmarks](04_benchmarks/) | SQL de preparación, consulta base, cambio físico o lógico y consulta optimizada. |
| [scripts](scripts/) | Runner Python que comprueba equivalencia y genera el informe de planes y mediciones. |

Ver [diagramas y dependencias funcionales](01_modeling/ER_DIAGRAMS.md) y [mediciones reproducibles](BENCHMARK_RESULTS.md).

## Ejecución local

Requiere Docker Compose y Python 3.10 o posterior. El servicio escucha solo en `127.0.0.1` y crea una base dedicada de laboratorio. La configuración por defecto usa PostgreSQL 16 Alpine. Para PostgreSQL 17, fija `POSTGRES_VERSION=17` en una copia de `.env.example` y arranca con otro nombre de proyecto y puerto para usar un volumen independiente. Si personalizas los valores del contenedor, usa los correspondientes parámetros `PG*` en el cliente.

```powershell
docker compose up -d --wait
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install "psycopg[binary]>=3.3,<4" tzdata
$env:PGHOST = "127.0.0.1"
$env:PGPORT = "55432"
$env:PGUSER = "lab"
$env:PGDATABASE = "performance_lab"
$env:PGPASSWORD = "lab-local"
.\.venv\Scripts\python.exe scripts/run_benchmarks.py --setup sql
```

En Linux y macOS, usa `.venv/bin/python` y exporta las mismas variables con `export`. Para probar la carga alternativa sobre una base vacía, ejecuta `scripts/run_benchmarks.py --setup copy` con el mismo intérprete. Ambos caminos omiten identificadores de semilla existentes. Para repetir solo las mediciones, ejecuta el runner sin `--setup`. Configura `--runs` con un número impar y `--output` para emitir otro informe.

## Integridad transaccional

`fintech.post_transfer` bloquea las dos cuentas por identificador ascendente con `FOR NO KEY UPDATE`, valida existencia, moneda y fondos, y persiste los saldos y el registro en la transacción del llamador. El orden común evita ciclos entre llamadas individuales con direcciones opuestas. Si se agrupan varias llamadas o se toman otros bloqueos dentro de una transacción, el llamador debe coordinar el orden global.

`audit.capture_diff` acepta una o más columnas de identidad y guarda solamente campos cambiados, con sus valores `old` y `new`. En inserciones y borrados conserva la imagen disponible como pares de valores. Una actualización sin cambios no genera eventos. La auditoría comparte la transacción del cambio; un rollback revierte ambos.

Las pruebas SQL revisan saldos, rechazos, registro de transferencia, eventos de inserción, actualización y borrado, y solapamientos por paciente y profesional. El rollback deja sin filas de prueba las tablas permanentes. Las secuencias de identidad pueden avanzar.

### Prueba de transferencias concurrentes

Tras ejecutar el runner con `--setup`, usa las mismas variables de conexión `PG*` y ejecuta:

```powershell
.\.venv\Scripts\python.exe scripts/test_concurrency_transfers.py
```

El script usa dos cuentas sintéticas con USD 5.000,00 cada una. Una sesión coordinadora retiene el bloqueo de la cuenta con el ID menor hasta observar las 20 sesiones de transferencia esperando por bloqueos. Después libera la cuenta y verifica los commits, el conteo e importe exacto por sentido y el saldo de cada cuenta. Cada corrida deja sus cuentas y movimientos sintéticos en la base dedicada para poder inspeccionarlos.

En PostgreSQL 16.15 y 17.12 se confirmaron 20 de 20 transferencias por versión, diez por sentido, con cero eventos `40P01` y saldo combinado exacto de USD 10.000,00 en cada corrida.

## Experimentos

| Caso | Diseño de la comparación | Lectura del plan |
|---|---|---|
| B-tree compuesto | Misma consulta sobre la copia de 200.000 órdenes antes y después del índice. Igualdades primero, seguidas de la clave de ordenación. | Comprueba la desaparición del escaneo completo y del sort explícito. |
| Cobertura | Sustituye un índice de búsqueda por la misma clave con `INCLUDE (status)`. Ejecuta `VACUUM` antes de medir ambas fases. | Comprueba `Index Only Scan` y `Heap Fetches`. El mapa de visibilidad determina si se visita el heap. |
| Índice parcial | Compara un índice completo con uno para la cola `PENDING`, aproximadamente el 1 % de las órdenes. | Evalúa sobre todo los bytes con `pg_relation_size`. La menor huella beneficia esta cola concreta. |
| JSONB y GIN | Aplica el mismo predicado de contención `@>` con y sin `jsonb_path_ops`. | Observa el bitmap del índice y las páginas de heap visitadas. |
| Función de ventana | Cuenta órdenes por cliente para cada fila de una muestra de 5.000 órdenes. | El plan correlacionado sin índice escanea la muestra por fila, con coste de orden O(N²). La ventana ordena una vez y recorre los grupos, con coste de orden O(N log N) para este plan. |
| Particionamiento | Compara tablas sin índices con las mismas filas y consulta de un mes. La variante optimizada distribuye los datos en 12 particiones. | Verifica que se escanea solo junio. La poda depende de los límites de la consulta sobre la clave de partición. |

Cada caso abre una conexión propia y crea tablas temporales. Se descarta una ejecución inicial por fase y se reporta la mediana de cinco ejecuciones por defecto. El informe conserva 12 planes completos en JSON y distingue los buffers locales y compartidos. Las mediciones corresponden a una carga sintética local con calentamiento. Los tiempos dependen del hardware, la memoria, las estadísticas y la distribución de los datos. El informe no mide el coste de escritura, la construcción de índices ni la latencia de cliente.

## Hallazgos de la ejecución incluida

- El B-tree compuesto eliminó el ordenamiento explícito y bajó de 28,379 a 0,108 ms para las 25 órdenes solicitadas.
- La cobertura redujo los accesos a buffers locales de 53 a 5 y obtuvo cero `Heap Fetches`. En esta muestra la mediana quedó prácticamente igual, de 0,121 a 0,123 ms.
- El índice parcial ocupó el 0,99 % del espacio del índice completo. En la cola de pendientes, ambas variantes ya usaban índice.
- El filtro JSONB pasó de un escaneo secuencial a un bitmap GIN. La ventana sustituyó 5.000 ejecuciones del subplan correlacionado por un solo ordenamiento. La consulta por fechas leyó solo la partición de junio.

Los valores corresponden al [informe incluido](BENCHMARK_RESULTS.md).

## Referencias

- [PostgreSQL 16 · Index-only scans y mapa de visibilidad](https://www.postgresql.org/docs/16/indexes-index-only-scans.html)
- [PostgreSQL 16 · Particionamiento declarativo](https://www.postgresql.org/docs/16/ddl-partitioning.html)
- [Psycopg 3 · Protocolo COPY](https://www.psycopg.org/psycopg3/docs/basic/copy.html)
