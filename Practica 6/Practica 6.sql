-- PARTE A

-- PASO 1: PREPARACIÓN DEL ENTORNO

-- 1.1 Crear las bases de datos
CREATE DATABASE banco_lima;
CREATE DATABASE banco_cusco;
CREATE DATABASE banco_arequipa;

CREATE USER estudiante WITH PASSWORD 'lab2024';
GRANT ALL PRIVILEGES ON DATABASE banco_lima TO estudiante;
GRANT ALL PRIVILEGES ON DATABASE banco_cusco TO estudiante;
GRANT ALL PRIVILEGES ON DATABASE banco_arequipa TO estudiante;

-- 1.2 Estructura de tablas para BANCO_LIMA
-- Conectar a banco_lima:
CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0),
    sucursal VARCHAR(50) DEFAULT 'Lima',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1
);

CREATE TABLE transacciones_log (
    id SERIAL PRIMARY KEY,
    transaccion_id VARCHAR(50) NOT NULL,
    cuenta_id INTEGER REFERENCES cuentas(id),
    tipo_operacion VARCHAR(20),
    monto NUMERIC(15,2),
    estado VARCHAR(20),
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_prepare TIMESTAMP,
    timestamp_final TIMESTAMP,
    descripcion TEXT
);

CREATE TABLE control_2pc (
    transaccion_id VARCHAR(58) PRIMARY KEY,
    estado_global VARCHAR(28),
    participantes TEXT[],
    votos_commit INTEGER DEFAULT 0,
    votos_abort INTEGER DEFAULT 0,
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_decision TIMESTAMP,
    coordinador VARCHAR(50)
);

INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES
('LIMA-001', 'Juan Pérez Rodríguez', 5000.00),
('LIMA-002', 'María García Flores', 3000.00),
('LIMA-003', 'Carlos López Mendoza', 7500.00),
('LIMA-004', 'Ana Torres Vargas', 2800.00),
('LIMA-005', 'Pedro Ramírez Castro', 6200.00);


-- 1.3 Estructura para BANCO_CUSCO
CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0),
    sucursal VARCHAR(50) DEFAULT 'Cusco',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1
);

CREATE TABLE transacciones_log (
    id SERIAL PRIMARY KEY,
    transaccion_id VARCHAR(50) NOT NULL,
    cuenta_id INTEGER REFERENCES cuentas(id),
    tipo_operacion VARCHAR(20),
    monto NUMERIC(15,2),
    estado VARCHAR(20),
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_prepare TIMESTAMP,
    timestamp_final TIMESTAMP,
    descripcion TEXT
);

CREATE TABLE control_2pc (
    transaccion_id VARCHAR(58) PRIMARY KEY,
    estado_global VARCHAR(28),
    participantes TEXT[],
    votos_commit INTEGER DEFAULT 0,
    votos_abort INTEGER DEFAULT 0,
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_decision TIMESTAMP,
    coordinador VARCHAR(50)
);

INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES
('CUSCO-001', 'Rosa Quispe Huamán', 2000.00),
('CUSCO-002', 'Pedro Mamani Condori', 4500.00),
('CUSCO-003', 'Carmen Ccoa Flores', 1800.00),
('CUSCO-004', 'Luis Apaza Choque', 5300.00),
('CUSCO-005', 'Elena Puma Quispe', 3700.00);


-- 1.4 Estructura para BANCO_AREQUIPA
CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0),
    sucursal VARCHAR(50) DEFAULT 'Arequipa',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1
);

CREATE TABLE transacciones_log (
    id SERIAL PRIMARY KEY,
    transaccion_id VARCHAR(50) NOT NULL,
    cuenta_id INTEGER REFERENCES cuentas(id),
    tipo_operacion VARCHAR(20),
    monto NUMERIC(15,2),
    estado VARCHAR(20),
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_prepare TIMESTAMP,
    timestamp_final TIMESTAMP,
    descripcion TEXT
);

CREATE TABLE control_2pc (
    transaccion_id VARCHAR(58) PRIMARY KEY,
    estado_global VARCHAR(28),
    participantes TEXT[],
    votos_commit INTEGER DEFAULT 0,
    votos_abort INTEGER DEFAULT 0,
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_decision TIMESTAMP,
    coordinador VARCHAR(50)
);

INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES
('AQP-001', 'Luis Vargas Bellido', 6000.00),
('AQP-002', 'Carmen Silva Medina', 2800.00),
('AQP-003', 'Roberto Mendoza Pinto', 9200.00),
('AQP-004', 'Isabel Díaz Salazar', 4100.00),
('AQP-005', 'Jorge Paredes Ramos', 7000.00);


-- EJERCICIO 1: TWO-PHASE COMMIT MANUAL PASO A PASO
-- Escenario: Transferir $1,000 de LIMA-001 (Lima) a CUSCO-001 (Cusco)

-- Generar ID de transacción único:
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id;


-- FASE 0: INICIAR TRANSACCIÓN EN TODOS LOS NODOS

-- Terminal 1 (Lima):
BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251107-232913', 'INICIADA', 'LIMA');
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251107-232913';

-- Terminal 2 (Cusco):
BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251107-232913', 'INICIADA', 'LIMA');

-- FASE 1: PREPARE (Preparación)

-- Terminal 1 (Lima) - Participante ORIGEN:
SELECT numero_cuenta, titular, saldo
FROM cuentas
WHERE numero_cuenta = 'LIMA-001' FOR UPDATE;

INSERT INTO transacciones_log
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion)
SELECT 'TXN-20251107-232913', id, 'DEBITO', 1000.00, 'PENDING',
'Transferencia a CUSCO-001'
FROM cuentas WHERE numero_cuenta = 'LIMA-001';

UPDATE transacciones_log
SET estado = 'PREPARED', timestamp_prepare = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913' AND tipo_operacion = 'DEBITO';

UPDATE control_2pc
SET votos_commit = votos_commit + 1, estado_global = 'PREPARANDO'
WHERE transaccion_id = 'TXN-20251107-232913';

SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251107-232913';
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251107-232913';


-- Terminal 2 (Cusco) - Participante DESTINO:
SELECT numero_cuenta, titular, saldo
FROM cuentas
WHERE numero_cuenta = 'CUSCO-001' FOR UPDATE;

INSERT INTO transacciones_log
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion)
SELECT 'TXN-20251107-232913', id, 'CREDITO', 1000.00, 'PENDING',
'Transferencia desde LIMA-001'
FROM cuentas WHERE numero_cuenta = 'CUSCO-001';

UPDATE transacciones_log
SET estado = 'PREPARED', timestamp_prepare = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913' AND tipo_operacion = 'CREDITO';

UPDATE control_2pc
SET votos_commit = votos_commit + 1
WHERE transaccion_id = 'TXN-20251107-232913';

SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251107-232913';
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251107-232913';

-- FASE 2: DECISIÓN (Commit o Abort)

-- Terminal 4 (Monitor/Coordinador):
SELECT transaccion_id, estado_global, votos_commit, votos_abort,
CASE
  WHEN votos_commit = 2 THEN 'TODOS VOTARON COMMIT - PROCEDER A COMMIT'
  WHEN votos_abort > 0 THEN 'HAY VOTOS ABORT - PROCEDER A ABORT'
  ELSE 'ESPERANDO VOTOS'
END AS decision
FROM control_2pc
WHERE transaccion_id = 'TXN-20251107-232913';

-- Si todos votaron COMMIT (votos_commit = 2):

-- Terminal 1 (Lima):
UPDATE cuentas
SET saldo = saldo - 1000.00,
    ultima_modificacion = CURRENT_TIMESTAMP,
    version = version + 1
WHERE numero_cuenta = 'LIMA-001';

UPDATE transacciones_log
SET estado = 'COMMITTED', timestamp_final = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913' AND tipo_operacion = 'DEBITO';

UPDATE control_2pc
SET estado_global = 'CONFIRMADA', timestamp_decision = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913';

COMMIT;

SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-001';

-- Terminal 2 (Cusco):
UPDATE cuentas
SET saldo = saldo + 1000.00,
    ultima_modificacion = CURRENT_TIMESTAMP,
    version = version + 1
WHERE numero_cuenta = 'CUSCO-001';

UPDATE transacciones_log
SET estado = 'COMMITTED', timestamp_final = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913' AND tipo_operacion = 'CREDITO';

UPDATE control_2pc
SET estado_global = 'CONFIRMADA', timestamp_decision = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-232913';

COMMIT;

SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-001';

-- VERIFICACIÓN FINAL

-- Terminal 4 (Monitor):
-- En Lima
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-001';
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251107-232913';
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20251107-232913';

-- En Cusco (conectar a banco_cusco)
SELECT * FROM cuentas WHERE numero_cuenta = 'CUSCO-001';
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251107-232913';

-- Consistencia global
SELECT 'LIMA' AS sucursal,
       COALESCE(SUM(CASE WHEN tipo_operacion = 'DEBITO' THEN -monto ELSE monto END), 0) AS neto
FROM transacciones_log 
WHERE transaccion_id = 'TXN-20251107-232913'

UNION ALL

SELECT 'CUSCO' AS sucursal,
       COALESCE(resultado.neto, 0) AS neto
FROM dblink('conn_cusco',
    'SELECT SUM(CASE WHEN tipo_operacion = ''CREDITO'' THEN monto ELSE -monto END) AS neto
     FROM transacciones_log 
     WHERE transaccion_id = ''TXN-20251107-232913''')
    AS resultado(neto NUMERIC);
	
-- EJERCICIO 2: SIMULACIÓN DE ABORT (Saldo Insuficiente)
-- Generar nuevo ID
-- paso abort id foto
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id;

-- Terminal 1 (Lima):
BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251107-235013', 'INICIADA', 'LIMA');

SELECT numero_cuenta, titular, saldo
FROM cuentas WHERE numero_cuenta = 'LIMA-002' FOR UPDATE;

INSERT INTO transacciones_log
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion)
SELECT 'TXN-20251107-235013', id, 'DEBITO', 10000.00, 'PENDING',
'Transferencia a AQP-001 - SALDO INSUFICIENTE'
FROM cuentas WHERE numero_cuenta = 'LIMA-002';

UPDATE control_2pc
SET votos_abort = votos_abort + 1, estado_global = 'ABORTADA'
WHERE transaccion_id = 'TXN-20251107-235013';

UPDATE transacciones_log
SET estado = 'ABORTED', timestamp_final = CURRENT_TIMESTAMP
WHERE transaccion_id = 'TXN-20251107-235013';

ROLLBACK;

SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251107-235013';

-- Terminal 3 (Arequipa):
BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251107-235013', 'ABORTADA', 'LIMA');
ROLLBACK;

-- EJERCICIO 3: SIMULACIÓN DE DEADLOCK DISTRIBUIDO

-- Instalación de dblink para deadlock distribuido
-- Terminal 1 (Lima):
CREATE EXTENSION IF NOT EXISTS dblink;
SELECT dblink_connect('conn_cusco',
'host=localhost dbname=banco_cusco user=estudiante password=lab2024');

-- Terminal 2 (Cusco):
CREATE EXTENSION IF NOT EXISTS dblink;
SELECT dblink_connect('conn_lima',
'host=localhost dbname=banco_lima user=estudiante password=lab2024');

-- Ahora ejecutar deadlock real:

-- Terminal 1:
BEGIN;
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE;
SELECT pg_sleep(5);
SELECT * FROM dblink('conn_cusco',
'SELECT * FROM cuentas WHERE numero_cuenta = ''CUSCO-002'' FOR UPDATE')
AS t(id int, numero_cuenta varchar, titular varchar, saldo numeric);
-- SE BLOQUEA

-- Terminal 2 (Cusco):
BEGIN;
SELECT * FROM cuentas WHERE numero_cuenta = 'CUSCO-002' FOR UPDATE;
SELECT pg_sleep(2);
SELECT * FROM dblink('conn_lima',
'SELECT * FROM cuentas WHERE numero_cuenta = ''LIMA-003'' FOR UPDATE')
AS t(id int, numero_cuenta varchar, titular varchar, saldo numeric);
-- DEADLOCK → ERROR

-- Limpieza:

ROLLBACK;

-- PARTE B

-- PASO 4: CREAR FUNCIONES ALMACENADAS

-- 4.1 Función de preparación (PREPARE)
-- Terminal 1 (Lima):
CREATE OR REPLACE FUNCTION preparar_debito(
    p_transaccion_id VARCHAR,
    p_numero_cuenta VARCHAR,
    p_monto NUMERIC
) RETURNS BOOLEAN AS $$  
DECLARE
    v_cuenta_id INTEGER;
    v_saldo_actual NUMERIC;
BEGIN
    SELECT id, saldo INTO v_cuenta_id, v_saldo_actual
    FROM cuentas WHERE numero_cuenta = p_numero_cuenta FOR UPDATE;
    IF NOT FOUND THEN RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; RETURN FALSE; END IF;
    IF v_saldo_actual < p_monto THEN RAISE NOTICE 'Saldo insuficiente'; RETURN FALSE; END IF;
    INSERT INTO transacciones_log (transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion)
    VALUES (p_transaccion_id, v_cuenta_id, 'DEBITO', p_monto, 'PREPARED', 'Preparado para débito');
    RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta;
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Error: %', SQLERRM; RETURN FALSE;
END;
  $$ LANGUAGE plpgsql;

-- Probar la función:
BEGIN;
SELECT preparar_debito('TXN-TEST-001', 'LIMA-001', 500.00);  -- TRUE
SELECT preparar_debito('TXN-TEST-002', 'LIMA-001', 50000.00); -- FALSE
ROLLBACK;


-- 4.2 Función de preparación crédito
-- Terminal 2 (Cusco):
CREATE OR REPLACE FUNCTION preparar_credito(
    p_transaccion_id VARCHAR,
    p_numero_cuenta VARCHAR,
    p_monto NUMERIC
) RETURNS BOOLEAN AS $$  
DECLARE v_cuenta_id INTEGER;
BEGIN
    SELECT id INTO v_cuenta_id FROM cuentas WHERE numero_cuenta = p_numero_cuenta FOR UPDATE;
    IF NOT FOUND THEN RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; RETURN FALSE; END IF;
    INSERT INTO transacciones_log (transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion)
    VALUES (p_transaccion_id, v_cuenta_id, 'CREDITO', p_monto, 'PREPARED', 'Preparado para crédito');
    RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta;
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'Error: %', SQLERRM; RETURN FALSE;
END;
  $$ LANGUAGE plpgsql;

-- 4.3 Función de commit
-- Terminal 1 (Lima):

CREATE OR REPLACE FUNCTION confirmar_transaccion(p_transaccion_id VARCHAR) RETURNS VOID AS $$  
DECLARE v_registro RECORD;
BEGIN
    FOR v_registro IN SELECT cuenta_id, tipo_operacion, monto FROM transacciones_log
                      WHERE transaccion_id = p_transaccion_id AND estado = 'PREPARED' LOOP
        IF v_registro.tipo_operacion = 'DEBITO' THEN
            UPDATE cuentas SET saldo = saldo - v_registro.monto,
                              ultima_modificacion = CURRENT_TIMESTAMP,
                              version = version + 1 WHERE id = v_registro.cuenta_id;
        ELSIF v_registro.tipo_operacion = 'CREDITO' THEN
            UPDATE cuentas SET saldo = saldo + v_registro.monto,
                              ultima_modificacion = CURRENT_TIMESTAMP,
                              version = version + 1 WHERE id = v_registro.cuenta_id;
        END IF;
        UPDATE transacciones_log SET estado = 'COMMITTED', timestamp_final = CURRENT_TIMESTAMP
        WHERE transaccion_id = p_transaccion_id AND cuenta_id = v_registro.cuenta_id;
        RAISE NOTICE 'Operación % confirmada', v_registro.tipo_operacion;
    END LOOP;
    UPDATE control_2pc SET estado_global = 'CONFIRMADA', timestamp_decision = CURRENT_TIMESTAMP
    WHERE transaccion_id = p_transaccion_id;
END;
  $$ LANGUAGE plpgsql;

-- 4.4 Función de abort
-- Terminal 1 (Lima) y Terminal 2 (Cusco):
CREATE OR REPLACE FUNCTION abortar_transaccion(p_transaccion_id VARCHAR) RETURNS VOID AS $$  
BEGIN
    UPDATE transacciones_log SET estado = 'ABORTED', timestamp_final = CURRENT_TIMESTAMP
    WHERE transaccion_id = p_transaccion_id;
    UPDATE control_2pc SET estado_global = 'ABORTADA', timestamp_decision = CURRENT_TIMESTAMP
    WHERE transaccion_id = p_transaccion_id;
    RAISE NOTICE 'Transacción % abortada', p_transaccion_id;
END;
  $$ LANGUAGE plpgsql;

-- EJERCICIO 4: USAR FUNCIONES PARA 2PC AUTOMATIZADO
-- Escenario: Transferir $800 de LIMA-004 a CUSCO-003

-- Terminal 1 (Lima):
-- paso 2pc auto lima foto
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id;

BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251108-001540', 'PREPARANDO', 'LIMA');
SELECT preparar_debito('TXN-20251108-001540', 'LIMA-004', 800.00);

-- Terminal 2 (Cusco):
-- paso 2pc auto cusco foto
BEGIN;
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador)
VALUES ('TXN-20251108-001540', 'PREPARANDO', 'LIMA');
SELECT preparar_credito('TXN-20251108-001540', 'CUSCO-003', 800.00);

-- Terminal 4 (Monitor):
-- paso monitor 2pc auto foto
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20251108-001540';


-- Si ambos votaron COMMIT:

-- Terminal 1 (Lima):
SELECT confirmar_transaccion('TXN-20251108-001540');
COMMIT;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'LIMA-004';

-- Terminal 2 (Cusco):
SELECT confirmar_transaccion('TXN-20251108-001540');
COMMIT;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-003';


-- PASO 5: FUNCIÓN COORDINADORA COMPLETA

-- 5.1 Crear función coordinadora avanzada
-- Terminal 1 (Lima):
CREATE OR REPLACE FUNCTION transferencia_distribuida_coordinador(
    p_cuenta_origen VARCHAR,
    p_cuenta_destino VARCHAR,
    p_monto NUMERIC,
    p_db_destino VARCHAR
) RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    transaccion_id VARCHAR
) AS $$  
DECLARE
    v_transaccion_id VARCHAR;
    v_prepare_origen BOOLEAN;
    v_prepare_destino BOOLEAN;
    v_dblink_name VARCHAR;
    v_dblink_conn VARCHAR;
BEGIN
    v_transaccion_id := 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MI') || '-' ||
                        floor(random() * 10000)::TEXT;
    v_dblink_name := 'conn_' || p_db_destino;
    v_dblink_conn := 'host=localhost dbname=banco_' || p_db_destino ||
                     ' user=estudiante password=lab2024';
    PERFORM dblink_connect(v_dblink_name, v_dblink_conn);
    INSERT INTO control_2pc (transaccion_id, estado_global, coordinador, participantes)
    VALUES (v_transaccion_id, 'PREPARANDO', 'LIMA', ARRAY['LIMA', UPPER(p_db_destino)]);
    RAISE NOTICE '--- FASE 1: PREPARE --- ';
    v_prepare_origen := preparar_debito(v_transaccion_id, p_cuenta_origen, p_monto);
    RAISE NOTICE 'Prepare ORIGEN: %', CASE WHEN v_prepare_origen THEN 'COMMIT' ELSE 'ABORT' END;
    SELECT resultado INTO v_prepare_destino
    FROM dblink(v_dblink_name,
        format('SELECT preparar_credito(%L, %L, %s)',
               v_transaccion_id, p_cuenta_destino, p_monto)
    ) AS t1(resultado BOOLEAN);
    RAISE NOTICE 'Prepare DESTINO: %', CASE WHEN v_prepare_destino THEN 'COMMIT' ELSE 'ABORT' END;
    RAISE NOTICE '--- FASE 2: DECISIÓN --- ';
    IF v_prepare_origen AND v_prepare_destino THEN
        RAISE NOTICE 'Decisión: GLOBAL-COMMIT';
        PERFORM confirmar_transaccion(v_transaccion_id);
        PERFORM dblink_exec(v_dblink_name,
            format('SELECT confirmar_transaccion(%L)', v_transaccion_id)
        );
        PERFORM dblink_disconnect(v_dblink_name);
        RETURN QUERY SELECT TRUE, 'Transferencia exitosa', v_transaccion_id;
    ELSE
        RAISE NOTICE 'Decisión: GLOBAL-ABORT';
        PERFORM abortar_transaccion(v_transaccion_id);
        PERFORM dblink_exec(v_dblink_name,
            format('SELECT abortar_transaccion(%L)', v_transaccion_id)
        );
        PERFORM dblink_disconnect(v_dblink_name);
        RETURN QUERY SELECT FALSE, 'Transferencia abortada - Verificar logs', v_transaccion_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
        BEGIN
            PERFORM abortar_transaccion(v_transaccion_id);
            PERFORM dblink_disconnect(v_dblink_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        RETURN QUERY SELECT FALSE, 'Error: ' || SQLERRM, v_transaccion_id;
END;
  $$ LANGUAGE plpgsql;


-- 5.2 Usar la función coordinadora
-- Terminal 1 (Lima):
CREATE EXTENSION IF NOT EXISTS dblink;
BEGIN;
SELECT * FROM transferencia_distribuida_coordinador (
    'LIMA-005', 'CUSCO-004', 1200.00, 'cusco'
);
COMMIT;
SELECT saldo FROM cuentas WHERE numero_cuenta = 'LIMA-005';

-- Terminal 2 (Cusco):
SELECT saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-004';
SELECT * FROM transacciones_log ORDER BY timestamp_inicio DESC LIMIT 5;


-- PARTE C

-- PASO 6: IMPLEMENTAR SAGA CON COMPENSACIONES

-- 6.1 Crear tablas para SAGA
-- Terminal 1 (Lima):
CREATE TABLE saga_ordenes (
    orden_id VARCHAR(50) PRIMARY KEY,
    tipo VARCHAR(50),
    estado VARCHAR(20),
    datos JSONB,
    paso_actual INTEGER DEFAULT 0,
    timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_final TIMESTAMP
);
CREATE TABLE saga_pasos (
    id SERIAL PRIMARY KEY,
    orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id),
    numero_paso INTEGER,
    nombre_paso VARCHAR(100),
    estado VARCHAR(20),
    accion_ejecutada TEXT,
    compensacion_ejecutada TEXT,
    timestamp_ejecucion TIMESTAMP,
    timestamp_compensacion TIMESTAMP,
    error_mensaje TEXT
);
CREATE TABLE saga_eventos (
    id SERIAL PRIMARY KEY,
    orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id),
    tipo_evento VARCHAR(50),
    descripcion TEXT,
    timestamp_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Copiado en los otros bancos

-- 6.2 Crear función para ejecutar SAGA
-- Terminal 1 (Lima):
CREATE OR REPLACE FUNCTION ejecutar_saga_transferencia(
    p_cuenta_origen VARCHAR,
    p_cuenta_destino VARCHAR,
    p_monto NUMERIC,
    p_db_destino VARCHAR
) RETURNS TABLE (
    exito BOOLEAN,
    orden_id VARCHAR,
    mensaje TEXT
) AS $$
DECLARE
    v_orden_id VARCHAR;
    v_cuenta_origen_id INTEGER;
    v_saldo_origen NUMERIC;
BEGIN
    v_orden_id := 'SAGA-' || to_char(now(), 'YYYYMMDD-HH24MISS');
  
    INSERT INTO saga_ordenes (orden_id, tipo, estado, datos)
    VALUES (
        v_orden_id,
        'TRANSFERENCIA',
        'INICIADA',
        jsonb_build_object(
            'cuenta_origen', p_cuenta_origen,
            'cuenta_destino', p_cuenta_destino,
            'monto', p_monto,
            'db_destino', p_db_destino
        )
    );

    INSERT INTO saga_pasos (orden_id, numero_paso, nombre_paso, estado)
    VALUES
        (v_orden_id, 1, 'Bloquear Fondos Origen', 'PENDIENTE'),
        (v_orden_id, 2, 'Transferir a Destino', 'PENDIENTE'),
        (v_orden_id, 3, 'Confirmar Débito Origen', 'PENDIENTE');

    UPDATE saga_ordenes
    SET estado = 'EN PROGRESO', paso_actual = 1
    WHERE saga_ordenes.orden_id = v_orden_id;

    RAISE NOTICE '--- PASO 1: Bloquear Fondos Origen ---';
      
    BEGIN
        SELECT id, saldo INTO v_cuenta_origen_id, v_saldo_origen
        FROM cuentas
        WHERE numero_cuenta = p_cuenta_origen
        FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cuenta origen % no encontrada', p_cuenta_origen;
        END IF;
      
        IF v_saldo_origen < p_monto THEN
            RAISE EXCEPTION 'Saldo insuficiente. Disponible: %, Requerido: %',
            v_saldo_origen, p_monto;
        END IF;
  
        UPDATE cuentas
        SET version = version + 1
        WHERE id = v_cuenta_origen_id;
      
        UPDATE saga_pasos
        SET estado = 'EJECUTADO',
            timestamp_ejecucion = CURRENT_TIMESTAMP,
            accion_ejecutada = format('Bloqueados $%s en cuenta %s', p_monto, p_cuenta_origen)
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1;

        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 1: Fondos bloqueados');
      
    EXCEPTION
        WHEN OTHERS THEN
            UPDATE saga_pasos
            SET estado = 'FALLIDO',
                timestamp_ejecucion = CURRENT_TIMESTAMP,
                error_mensaje = SQLERRM
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1;
          
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
            VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 1: ' || SQLERRM);
          
            UPDATE saga_ordenes
            SET estado = 'FALLIDA', timestamp_final = CURRENT_TIMESTAMP
            WHERE saga_ordenes.orden_id = v_orden_id;
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 1: ' || SQLERRM;
            RETURN;
    END;

    RAISE NOTICE '--- PASO 2: Transferir a Destino ---';
  
    UPDATE saga_ordenes
    SET paso_actual = 2
    WHERE saga_ordenes.orden_id = v_orden_id;
  
    BEGIN
        PERFORM dblink_connect('conn_destino',
            format('host=localhost dbname=banco_%s user=estudiante password=lab2024', p_db_destino)
        );
        PERFORM dblink_exec('conn_destino',
            format('UPDATE cuentas SET saldo = saldo + %s WHERE numero_cuenta = %L',
            p_monto, p_cuenta_destino)
        );
      
        PERFORM dblink_disconnect('conn_destino');
      
        UPDATE saga_pasos
        SET estado = 'EJECUTADO',
            timestamp_ejecucion = CURRENT_TIMESTAMP,
            accion_ejecutada = format('Acreditados $%s en cuenta %s', p_monto, p_cuenta_destino)
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2;

        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 2: Fondos acreditados en destino');
      
    EXCEPTION
        WHEN OTHERS THEN
            UPDATE saga_pasos
            SET estado = 'FALLIDO',
                timestamp_ejecucion = CURRENT_TIMESTAMP,
                error_mensaje = SQLERRM
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2;
          
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
            VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 2: ' || SQLERRM);
          
            RAISE NOTICE 'Iniciando compensaciones...';
            UPDATE saga_ordenes
            SET estado = 'COMPENSANDO'
            WHERE saga_ordenes.orden_id = v_orden_id;
  
            UPDATE cuentas
            SET version = version - 1
            WHERE id = v_cuenta_origen_id;
          
            UPDATE saga_pasos
            SET estado = 'COMPENSADO',
                timestamp_compensacion = CURRENT_TIMESTAMP,
                compensacion_ejecutada = 'Fondos desbloqueados'
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1;
          
            INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
            VALUES (v_orden_id, 'COMPENSACION_EJECUTADA', 'Compensación Paso 1: Fondos desbloqueados');
  
            UPDATE saga_ordenes
            SET estado = 'COMPENSADA', timestamp_final = CURRENT_TIMESTAMP
            WHERE saga_ordenes.orden_id = v_orden_id;
          
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 2 (compensado): ' || SQLERRM;
            RETURN;
    END;

    RAISE NOTICE '--- PASO 3: Confirmar Débito Origen ---';
  
    UPDATE saga_ordenes
    SET paso_actual = 3
    WHERE saga_ordenes.orden_id = v_orden_id;
  
    BEGIN
        UPDATE cuentas
        SET saldo = saldo - p_monto,
            ultima_modificacion = CURRENT_TIMESTAMP
        WHERE id = v_cuenta_origen_id;
  
        UPDATE saga_pasos
        SET estado = 'EJECUTADO',
            timestamp_ejecucion = CURRENT_TIMESTAMP,
            accion_ejecutada = format('Debitados $%s de cuenta %s', p_monto, p_cuenta_origen)
        WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 3;
      
        INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion)
        VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 3: Débito confirmado');
  
        UPDATE saga_ordenes
        SET estado = 'COMPLETADA', timestamp_final = CURRENT_TIMESTAMP
        WHERE saga_ordenes.orden_id = v_orden_id;
  
        RETURN QUERY SELECT TRUE, v_orden_id, 'Transferencia SAGA completada';
      
    EXCEPTION
        WHEN OTHERS THEN
            UPDATE saga_pasos
            SET estado = 'FALLIDO',
                timestamp_ejecucion = CURRENT_TIMESTAMP,
                error_mensaje = SQLERRM
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 3;
          
            RAISE NOTICE 'Iniciando compensaciones completas...';
            UPDATE saga_ordenes
            SET estado = 'COMPENSANDO'
            WHERE saga_ordenes.orden_id = v_orden_id;

            BEGIN
                PERFORM dblink_connect('conn_destino',
                    format('host=localhost dbname=banco_%s user=estudiante password=lab2024', p_db_destino)
                );
                PERFORM dblink_exec('conn_destino',
                    format('UPDATE cuentas SET saldo = saldo - %s WHERE numero_cuenta = %L',
                        p_monto, p_cuenta_destino)
                );
                PERFORM dblink_disconnect('conn_destino');
                UPDATE saga_pasos
                SET estado = 'COMPENSADO',
                    timestamp_compensacion = CURRENT_TIMESTAMP,
                    compensacion_ejecutada = 'Crédito revertido en destino'
                WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 2;
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'Error en compensación paso 2: %', SQLERRM;
            END;
      
            UPDATE cuentas
            SET version = version - 1
            WHERE id = v_cuenta_origen_id;
          
            UPDATE saga_pasos
            SET estado = 'COMPENSADO',
                timestamp_compensacion = CURRENT_TIMESTAMP,
                compensacion_ejecutada = 'Fondos desbloqueados'
            WHERE saga_pasos.orden_id = v_orden_id AND numero_paso = 1;
          
            UPDATE saga_ordenes
            SET estado = 'COMPENSADA', timestamp_final = CURRENT_TIMESTAMP
            WHERE saga_ordenes.orden_id = v_orden_id;
          
            RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 3 (compensado): ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- 6.3 Probar SAGA exitosa
-- Terminal 1 (Lima):
BEGIN;
SELECT * FROM ejecutar_saga_transferencia(
    'LIMA-001', 'CUSCO-005', 300.00, 'cusco'
);
COMMIT;
SELECT * FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1;
SELECT * FROM saga_pasos WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1) ORDER BY numero_paso;
SELECT * FROM saga_eventos WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1) ORDER BY timestamp_evento;

-- 6.4 Probar SAGA con fallo y compensación
-- Terminal 1 (Lima):
BEGIN;
SELECT * FROM ejecutar_saga_transferencia(
    'LIMA-002', 'CUSCO-999', 500.00, 'cusco'
);
COMMIT;
SELECT numero_paso, nombre_paso, estado, accion_ejecutada, compensacion_ejecutada, error_mensaje
FROM saga_pasos
WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1)
ORDER BY numero_paso;
SELECT * FROM saga_eventos
WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1)
ORDER BY timestamp_evento;