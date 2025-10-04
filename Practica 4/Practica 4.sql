----------------------------------------------
--PARTE 1: CONFIGURACIÓN DEL ENTORNO 
----------------------------------------------
CREATE DATABASE lab_particionamiento;

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER SYSTEM SET log_min_duration_statement = 1000; -- 1 segundo
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();

----------------------------------------------
--PARTE 2: CREACIÓN DE DATOS DE PRUEBA
----------------------------------------------

-- Tabla de ventas sin particiones
CREATE TABLE ventas_sin_particion (
    id SERIAL PRIMARY KEY,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices básicos
CREATE INDEX idx_ventas_fecha ON ventas_sin_particion(fecha_venta);
CREATE INDEX idx_ventas_cliente ON ventas_sin_particion(cliente_id);


-- Función para generar datos aleatorios
CREATE OR REPLACE FUNCTION generar_ventas_masivas(num_registros INTEGER)
RETURNS VOID AS $$
DECLARE
    i INTEGER;
    fecha_aleatoria DATE;
    precio DECIMAL(10,2);
BEGIN
    FOR i IN 1..num_registros LOOP
        -- Fecha entre 2020 y 2024
        fecha_aleatoria := '2020-01-01'::DATE + (RANDOM() * ('2024-12-31'::DATE - '2020-01-01'::DATE))::INTEGER;
        precio := ROUND((RANDOM() * 1000 + 10)::NUMERIC, 2);
        INSERT INTO ventas_sin_particion (
            fecha_venta, cliente_id, producto_id, cantidad,
            precio_unitario, total, sucursal_id, vendedor_id
        ) VALUES (
            fecha_aleatoria,
            (RANDOM() * 10000 + 1)::INTEGER,
            (RANDOM() * 5000 + 1)::INTEGER,
            (RANDOM() * 10 + 1)::INTEGER,
            precio,
            precio * (RANDOM() * 10 + 1),
            (RANDOM() * 50 + 1)::INTEGER,
            (RANDOM() * 200 + 1)::INTEGER
        );
        -- Mostrar progreso cada 100,000 registros
        IF i % 100000 = 0 THEN
            RAISE NOTICE 'Insertados % registros', i;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Ejecutar inserción de 2 millones de registros
SELECT generar_ventas_masivas(2000000);

-- Estadísticas de la tabla
SELECT
    schemaname,
    relname AS tablename,
    n_tup_ins AS inserciones,
    n_tup_del AS eliminaciones,
    n_tup_upd AS actualizaciones,
    seq_scan AS escaneos_secuencial,
    seq_tup_read AS tuplas_leidas_secuencial,
    idx_scan AS escaneos_index,
    idx_tup_fetch AS tuplas_fetch_index
FROM pg_stat_user_tables
WHERE relname = 'ventas_sin_particion';


-- Tamaño de la tabla
SELECT
    pg_size_pretty(pg_total_relation_size('ventas_sin_particion')) AS tamano_total,
    pg_size_pretty(pg_relation_size('ventas_sin_particion')) AS tamano_tabla,
    pg_size_pretty(pg_total_relation_size('ventas_sin_particion') - pg_relation_size('ventas_sin_particion')) AS tamano_indices;


----------------------------------------------
--PARTE 3: IMPLEMENTACIÓN DE PARTICIONAMIENTO POR RANGO
----------------------------------------------

-- Tabla principal con particionamiento por rango de fechas
CREATE TABLE ventas_particionada (
    id SERIAL,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (fecha_venta);

-- Crear particiones por año
CREATE TABLE ventas_2020 PARTITION OF ventas_particionada FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE ventas_2021 PARTITION OF ventas_particionada FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE ventas_2022 PARTITION OF ventas_particionada FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE ventas_2023 PARTITION OF ventas_particionada FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE ventas_2024 PARTITION OF ventas_particionada FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
-- Agrego para 2025 (ya que la fecha actual es 2025)
CREATE TABLE ventas_2025 PARTITION OF ventas_particionada FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Índices automáticos en todas las particiones
CREATE INDEX idx_ventas_part_cliente ON ventas_particionada(cliente_id);
CREATE INDEX idx_ventas_part_producto ON ventas_particionada(producto_id);
CREATE INDEX idx_ventas_part_sucursal ON ventas_particionada(sucursal_id);

-- Verificar que los índices se crearon en cada partición
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE tablename LIKE 'ventas_%'
ORDER BY tablename, indexname;


-- Insertar datos desde tabla sin particiones
INSERT INTO ventas_particionada (
    fecha_venta, cliente_id, producto_id,
    precio_unitario, total, sucursal_id, vendedor_id, created_at
)
SELECT fecha_venta, cliente_id, producto_id,
       precio_unitario, total, sucursal_id, vendedor_id, created_at
FROM ventas_sin_particion;

ANALYZE ventas_particionada;

-- Verificar distribución de datos por partición
SELECT
    tableoid::regclass AS particion,
    COUNT(*) AS registros
FROM ventas_particionada
GROUP BY particion
ORDER BY particion;

----------------------------------------------
--PARTE 4: PARTICIONAMIENTO HÍBRIDO 
----------------------------------------------

-- Tabla con particionamiento por fecha y subparticionamiento por hash
CREATE TABLE ventas_hibrida (
    id SERIAL,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (fecha_venta);

-- Partición principal 2024 con subparticiones por hash en cliente_id
CREATE TABLE ventas_2024_base PARTITION OF ventas_hibrida
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01')
PARTITION BY HASH (cliente_id);

-- Crear 4 subparticiones hash para 2024
CREATE TABLE ventas_2024_h0 PARTITION OF ventas_2024_base FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE ventas_2024_h1 PARTITION OF ventas_2024_base FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE ventas_2024_h2 PARTITION OF ventas_2024_base FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE ventas_2024_h3 PARTITION OF ventas_2024_base FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Agrego para 2025 (opcional)
CREATE TABLE ventas_2025_base PARTITION OF ventas_hibrida
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01')
PARTITION BY HASH (cliente_id);
CREATE TABLE ventas_2025_h0 PARTITION OF ventas_2025_base FOR VALUES WITH (MODULUS 4, REMAINDER 0);

-- Insertar datos específicos para 2024
INSERT INTO ventas_hibrida (
    fecha_venta,
    cliente_id,
    producto_id,
    precio_unitario,
    total,
    sucursal_id,
    vendedor_id
)
SELECT 
    fecha_venta,
    cliente_id,
    producto_id,
    precio_unitario,
    total,
    sucursal_id,
    vendedor_id
FROM ventas_sin_particion
WHERE fecha_venta >= '2024-01-01' AND fecha_venta < '2025-01-01';


-- Verificar distribución en subparticiones (corregido para contar registros reales)
SELECT
    t.tablename,
    pg_size_pretty(pg_total_relation_size(t.tablename::regclass)) AS tamano,
    c.reltuples::bigint AS registros_estimados
FROM (VALUES 
    ('ventas_2024_h0'),
    ('ventas_2024_h1'),
    ('ventas_2024_h2'),
    ('ventas_2024_h3')
) t(tablename)
JOIN pg_class c ON c.oid = t.tablename::regclass;



----------------------------------------------
--PARTE 5: ANÁLISIS COMPARATIVO DE RENDIMIENTO 
----------------------------------------------

-- Limpiar estadísticas
SELECT pg_stat_reset();

-- Consulta en tabla sin particionamiento
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_sin_particion
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';

-- Misma consulta en tabla particionada
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_particionada
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';

-- Consulta por cliente específico - tabla sin particiones
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_sin_particion
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;

-- Misma consulta - tabla con subparticiones hash
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT * FROM ventas_hibrida
WHERE cliente_id = 5000
AND fecha_venta >= '2024-01-01'
ORDER BY fecha_venta DESC
LIMIT 100;

-- Verificar eliminación de particiones
SET enable_partition_pruning = on;
SET constraint_exclusion = partition;

EXPLAIN (ANALYZE, BUFFERS)
SELECT sucursal_id, SUM(total) AS ventas_totales
FROM ventas_particionada
WHERE fecha_venta = '2023-12-25'
GROUP BY sucursal_id
ORDER BY ventas_totales DESC;

-- Tabla para almacenar resultados de pruebas (corregida para incluir más campos)
CREATE TABLE metricas_rendimiento (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(50),  -- ej. 'sin_particion'
    tabla VARCHAR(50),
    tipo_consulta VARCHAR(100),  -- ej. 'rango_fechas'
    tiempo_ejecucion_ms DECIMAL(18,2),
    buffers_hit INTEGER,
    buffers_read INTEGER,
    fecha_prueba TIMESTAMP DEFAULT NOW()
);

-- Función para ejecutar y medir consultas (corregida: solo mide tiempo; buffers se agregan manualmente después de EXPLAIN)
CREATE OR REPLACE FUNCTION medir_consulta(
    nombre_prueba TEXT,
    consulta TEXT
) RETURNS VOID AS $$
DECLARE
    inicio TIMESTAMP;
    duracion DECIMAL(18,2);
BEGIN
    inicio := clock_timestamp();
    EXECUTE consulta;
    duracion := EXTRACT(MILLISECOND FROM (clock_timestamp() - inicio));
    RAISE NOTICE 'Prueba: %, Duración: % ms', nombre_prueba, duracion;
    INSERT INTO metricas_rendimiento (tipo, tiempo_ejecucion_ms)
    VALUES (nombre_prueba, duracion);
END;
$$ LANGUAGE plpgsql;

-- Ejemplo de uso (ajusta con tus consultas)
SELECT medir_consulta('rango_sin_particion', 'SELECT COUNT(*) FROM ventas_sin_particion WHERE fecha_venta BETWEEN ''2023-06-01'' AND ''2023-08-31'';');

-- Consulta 1: Rango de fechas - tabla sin partición
SELECT medir_consulta(
    'rango_sin_particion',
    'SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
     FROM ventas_sin_particion
     WHERE fecha_venta BETWEEN ''2023-06-01'' AND ''2023-08-31'';'
);

-- Consulta 2: Rango de fechas - tabla particionada
SELECT medir_consulta(
    'rango_particionada',
    'SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
     FROM ventas_particionada
     WHERE fecha_venta BETWEEN ''2023-06-01'' AND ''2023-08-31'';'
);

-- Consulta 3: Cliente específico - sin partición
SELECT medir_consulta(
    'cliente_sin_particion',
    'SELECT * FROM ventas_sin_particion
     WHERE cliente_id = 5000
     AND fecha_venta >= ''2024-01-01''
     ORDER BY fecha_venta DESC
     LIMIT 100;'
);

-- Consulta 4: Cliente específico - tabla híbrida (subparticiones)
SELECT medir_consulta(
    'cliente_particionada_hibrida',
    'SELECT * FROM ventas_hibrida
     WHERE cliente_id = 5000
     AND fecha_venta >= ''2024-01-01''
     ORDER BY fecha_venta DESC
     LIMIT 100;'
);

-- Consulta 5: Agregación por día y sucursal (verifica pruning)
SELECT medir_consulta(
    'agregacion_particionada',
    'SELECT sucursal_id, SUM(total) AS ventas_totales
     FROM ventas_particionada
     WHERE fecha_venta = ''2023-12-25''
     GROUP BY sucursal_id
     ORDER BY ventas_totales DESC;'
);

-- Ejecuta con EXPLAIN para ver buffers
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), AVG(total), MIN(fecha_venta), MAX(fecha_venta)
FROM ventas_sin_particion
WHERE fecha_venta BETWEEN '2023-06-01' AND '2023-08-31';

-- Supongamos que obtienes:
-- Buffers: shared hit=10240 read=120

-- Actualizas en metricas_rendimiento
UPDATE metricas_rendimiento
SET buffers_hit = 10240, buffers_read = 120
WHERE tipo = 'rango_sin_particion';

-- Ver todas las métricas
SELECT * FROM metricas_rendimiento ORDER BY fecha_prueba DESC;

-- Comparar tiempos promedio
SELECT tipo, AVG(tiempo_ejecucion_ms) AS tiempo_promedio
FROM metricas_rendimiento
GROUP BY tipo;


----------------------------------------------
--PARTE 6: MANTENIMIENTO AUTOMATIZADO 
----------------------------------------------

DROP TABLE IF EXISTS ventas_particionada CASCADE;

CREATE TABLE ventas_particionada (
    id SERIAL,
    fecha_venta DATE NOT NULL,
    cliente_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    sucursal_id INTEGER NOT NULL,
    vendedor_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) PARTITION BY RANGE (fecha_venta);

CREATE OR REPLACE FUNCTION crear_particion_anual(
    tabla_principal TEXT,
    ano INTEGER
) RETURNS TEXT AS $$
DECLARE
    fecha_inicio DATE := make_date(ano, 1, 1);
    fecha_fin DATE := make_date(ano + 1, 1, 1);
    nombre_particion TEXT := tabla_principal || '_' || ano;
    comando_sql TEXT;
BEGIN
    comando_sql := format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L) PARTITION BY RANGE (fecha_venta);',
        nombre_particion, tabla_principal, fecha_inicio, fecha_fin
    );
    EXECUTE comando_sql;
    RETURN 'Partición anual creada: ' || nombre_particion;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION crear_particion_mensual(
    tabla_principal TEXT,
    ano INTEGER,
    mes INTEGER
) RETURNS TEXT AS $$
DECLARE
    fecha_inicio DATE;
    fecha_fin DATE;
    nombre_anual TEXT;
    nombre_mensual TEXT;
    comando_sql TEXT;
BEGIN
    -- Primero aseguramos que exista la partición anual
    PERFORM crear_particion_anual(tabla_principal, ano);

    fecha_inicio := make_date(ano, mes, 1);
    fecha_fin := fecha_inicio + INTERVAL '1 month';
    nombre_anual := tabla_principal || '_' || ano;
    nombre_mensual := nombre_anual || '_' || LPAD(mes::TEXT, 2, '0');

    comando_sql := format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L);',
        nombre_mensual, nombre_anual, fecha_inicio, fecha_fin
    );

    EXECUTE comando_sql;
    RETURN 'Partición mensual creada: ' || nombre_mensual;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION limpiar_particiones_antiguas(
    tabla_principal TEXT,
    meses_retener INTEGER DEFAULT 24
) RETURNS TEXT AS $$
DECLARE
    rec RECORD;
    fecha_limite DATE;
    fecha_particion DATE;
    resultado TEXT := '';
BEGIN
    fecha_limite := date_trunc('month', CURRENT_DATE) - (meses_retener || ' months')::INTERVAL;

    FOR rec IN
        SELECT tablename
        FROM pg_tables
        WHERE tablename LIKE tabla_principal || '_%%%%_%%' -- detecta formato YYYY_MM
          AND schemaname = 'public'
    LOOP
        BEGIN
            fecha_particion := to_date(
                substring(rec.tablename from '([0-9]{4}_[0-9]{2})'),
                'YYYY_MM'
            );

            IF fecha_particion < fecha_limite THEN
                EXECUTE format('DROP TABLE IF EXISTS %I CASCADE;', rec.tablename);
                resultado := resultado || 'Eliminada: ' || rec.tablename || E'\n';
            END IF;
        EXCEPTION
            WHEN others THEN
                CONTINUE;
        END;
    END LOOP;

    RETURN COALESCE(NULLIF(resultado, ''), 'No se eliminaron particiones');
END;
$$ LANGUAGE plpgsql;

-- Crear particiones de prueba
SELECT crear_particion_mensual('ventas_particionada', 2025, 1);
SELECT crear_particion_mensual('ventas_particionada', 2025, 2);
SELECT crear_particion_mensual('ventas_particionada', 2024, 12);

-- Limpiar particiones con más de 12 meses de antigüedad
SELECT limpiar_particiones_antiguas('ventas_particionada', 12);


