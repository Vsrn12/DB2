-------------------------------------
--Crear
--CREATE DATABASE ecommerce_lab;
-------------------------------------
-------------------------------------
-- TABLA: PRODUCTOS
-------------------------------------
CREATE TABLE productos (
    codigo_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
	estado VARCHAR(10) DEFAULT 'activo' CHECK (estado IN ('activo','inactivo')),
    stock_disponible INT NOT NULL CHECK (stock_disponible >= 0),
    stock_minimo_alerta INT DEFAULT 5 CHECK (stock_minimo_alerta >= 0),
    fecha_ultima_actualizacion TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_productos_nombre ON productos(nombre);
CREATE INDEX idx_productos_estado ON productos(estado);
CREATE INDEX idx_productos_precio ON productos(precio_unitario);
-------------------------------------
-- TABLA: CLIENTES
-------------------------------------
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    correo_electronico VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(15),
    direccion_envio TEXT,
    fecha_registro TIMESTAMP DEFAULT NOW()
);

-- Índice
CREATE INDEX idx_clientes_nombre ON clientes(nombre_completo);

-------------------------------------
-- TABLA: PEDIDOS
-------------------------------------
CREATE TABLE pedidos (
    id_pedido SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    fecha_pedido TIMESTAMP DEFAULT NOW(),
    estado_pedido VARCHAR(15) DEFAULT 'pendiente' CHECK (estado_pedido IN ('pendiente','confirmado','enviado','cancelado')),
    monto_total NUMERIC(10,2) DEFAULT 0 CHECK (monto_total >= 0),
    fecha_ultima_actualizacion TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);
CREATE INDEX idx_pedidos_estado ON pedidos(estado_pedido);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido);

-------------------------------------
-- TABLA: DETALLE_PEDIDO
-------------------------------------
CREATE TABLE detalle_pedido (
    id_detalle SERIAL PRIMARY KEY,
    id_pedido INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    codigo_producto INT NOT NULL REFERENCES productos(codigo_producto) ON DELETE RESTRICT,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal NUMERIC(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

-- Índices
CREATE INDEX idx_detalle_pedido ON detalle_pedido(id_pedido);
CREATE INDEX idx_detalle_producto ON detalle_pedido(codigo_producto);

-------------------------------------
-- TABLA: PAGOS
-------------------------------------
CREATE TABLE pagos (
    id_pago SERIAL PRIMARY KEY,
    id_pedido INT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    metodo_pago VARCHAR(30) NOT NULL,
    monto_pagado NUMERIC(10,2) NOT NULL CHECK (monto_pagado >= 0),
    fecha_pago TIMESTAMP DEFAULT NOW(),
    estado_pago VARCHAR(15) DEFAULT 'procesando' CHECK (estado_pago IN ('procesando','aprobado','rechazado')),
    referencia_transaccion VARCHAR(50)
);

-- Índices
CREATE INDEX idx_pagos_pedido ON pagos(id_pedido);
CREATE INDEX idx_pagos_estado ON pagos(estado_pago);
CREATE INDEX idx_pagos_fecha ON pagos(fecha_pago);

-------------------------------------
-- TABLA: HISTORIAL_STOCK
-------------------------------------
CREATE TABLE historial_stock (
    id_registro SERIAL PRIMARY KEY,
    codigo_producto INT NOT NULL REFERENCES productos(codigo_producto) ON DELETE CASCADE,
    tipo_movimiento VARCHAR(10) NOT NULL CHECK (tipo_movimiento IN ('entrada','salida','ajuste')),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    stock_anterior INT NOT NULL CHECK (stock_anterior >= 0),
    stock_nuevo INT NOT NULL CHECK (stock_nuevo >= 0),
    id_pedido_relacionado INT REFERENCES pedidos(id_pedido) ON DELETE SET NULL,
    fecha_movimiento TIMESTAMP DEFAULT NOW(),
    usuario_movimiento VARCHAR(100) DEFAULT CURRENT_USER
);

-- Índices recomendados
CREATE INDEX idx_historial_producto ON historial_stock(codigo_producto);
CREATE INDEX idx_historial_tipo ON historial_stock(tipo_movimiento);
CREATE INDEX idx_historial_fecha ON historial_stock(fecha_movimiento);

--ADition
ALTER TABLE productos 
    ADD CONSTRAINT chk_estado_producto CHECK (estado IN ('activo', 'inactivo'));

ALTER TABLE pedidos 
    ADD CONSTRAINT chk_estado_pedido CHECK (estado_pedido IN ('pendiente','confirmado','enviado','cancelado'));

ALTER TABLE pagos 
    ADD CONSTRAINT chk_estado_pago CHECK (estado_pago IN ('procesando','aprobado','rechazado'));

ALTER TABLE historial_stock 
    ADD CONSTRAINT chk_tipo_movimiento CHECK (tipo_movimiento IN ('entrada','salida','ajuste'));


-- CLIENTES
INSERT INTO clientes (id_cliente, nombre_completo, correo_electronico, telefono, direccion_envio, fecha_registro)
VALUES
(1, 'Pedro Salazar', 'pedrosalazar@example.com', '987321654', 'Av. Primavera 102 - Lima', NOW()),
(2, 'Rosa Martínez', 'rosamartinez@example.com', '991234567', 'Jr. Las Gardenias 202 - Cusco', NOW()),
(3, 'Miguel Vargas', 'miguelvargas@example.com', '998811223', 'Av. La Cultura 501 - Arequipa', NOW()),
(4, 'Sofía Castro', 'sofiacastro@example.com', '976123456', 'Calle Los Tulipanes 303 - Trujillo', NOW()),
(5, 'Daniela Ramos', 'danielaramos@example.com', '954789123', 'Mz C Lt 7 Urb. San Borja - Lima', NOW());

-- PRODUCTOS con stocks variados (incluye stocks bajos)
INSERT INTO productos (codigo_producto, nombre, descripcion, precio_unitario, stock_disponible, stock_minimo_alerta, estado, fecha_ultima_actualizacion)
VALUES
(1, 'Tablet Samsung Galaxy Tab A8', 'Tablet 10.5" con 4GB RAM y 64GB almacenamiento', 1200.00, 6, 2, 'activo', NOW()),
(2, 'Mouse Razer DeathAdder', 'Mouse gamer ergonómico RGB', 250.00, 12, 3, 'activo', NOW()),
(3, 'Teclado Logitech MX Keys', 'Teclado inalámbrico retroiluminado', 500.00, 4, 2, 'activo', NOW()),
(4, 'Monitor LG UltraGear 27"', 'Monitor QHD 165Hz para gaming', 1850.00, 2, 1, 'activo', NOW()),
(5, 'Auriculares Sony WH-CH720N', 'Auriculares inalámbricos con cancelación de ruido', 780.00, 1, 1, 'activo', NOW()),
(6, 'SSD Kingston 1TB NVMe', 'Unidad SSD M.2 NVMe alta velocidad', 420.00, 8, 2, 'activo', NOW()),
(7, 'Impresora Epson EcoTank L3250', 'Impresora multifuncional Wi-Fi', 950.00, 5, 1, 'activo', NOW()),
(8, 'Silla Ergonomica T-Dagger', 'Silla para oficina y juegos', 890.00, 3, 1, 'activo', NOW()),
(9, 'Memoria MicroSD SanDisk 128GB', 'Memoria clase 10 con adaptador', 110.00, 25, 5, 'activo', NOW()),
(10, 'Webcam Razer Kiyo', 'Cámara Full HD con luz anular', 460.00, 2, 1, 'activo', NOW());

-- AJUSTAR LAS SECUENCIAS

-- Clientes
SELECT setval(pg_get_serial_sequence('clientes','id_cliente'), COALESCE((SELECT MAX(id_cliente) FROM clientes), 1));

-- Productos
SELECT setval(pg_get_serial_sequence('productos','codigo_producto'), COALESCE((SELECT MAX(codigo_producto) FROM productos), 1));

-- Secuencias para otras tablas (por si ya insertaste cosas manualmente antes)
SELECT setval(pg_get_serial_sequence('pedidos','id_pedido'), COALESCE((SELECT MAX(id_pedido) FROM pedidos), 1));
SELECT setval(pg_get_serial_sequence('detalle_pedido','id_detalle'), COALESCE((SELECT MAX(id_detalle) FROM detalle_pedido), 1));
SELECT setval(pg_get_serial_sequence('pagos','id_pago'), COALESCE((SELECT MAX(id_pago) FROM pagos), 1));
SELECT setval(pg_get_serial_sequence('historial_stock','id_registro'), COALESCE((SELECT MAX(id_registro) FROM historial_stock), 1));

-------------------------------------
-- VERIFICACIÓN
-------------------------------------
SELECT id_cliente, nombre_completo, correo_electronico FROM clientes ORDER BY id_cliente;
SELECT codigo_producto, nombre, stock_disponible FROM productos ORDER BY codigo_producto;

-------------------------------------
-- FUNCIÓN: crear_pedido
-------------------------------------
-- 1) Asegurar nombres de columnas y tipo correcto en detalle_pedido
-- Usamos bloques condicionales para renombrar / reemplazar columnas según sea necesario.

DO $$
BEGIN
    -- Renombrar columna 'cantidad' a 'cantidad_solicitada' 
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'detalle_pedido' AND column_name = 'cantidad'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'detalle_pedido' AND column_name = 'cantidad_solicitada'
    ) THEN
        EXECUTE 'ALTER TABLE detalle_pedido RENAME COLUMN cantidad TO cantidad_solicitada';
    END IF;
END
$$;

DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Si existe la columna subtotal y es GENERATED (columna computada), la reemplazamos.
    SELECT * INTO rec
    FROM information_schema.columns
    WHERE table_name = 'detalle_pedido' AND column_name = 'subtotal';

    IF FOUND THEN
        IF rec.is_generated = 'ALWAYS' THEN
            -- eliminar la columna generada y crear una nueva columna normal
            EXECUTE 'ALTER TABLE detalle_pedido DROP COLUMN subtotal';
            EXECUTE 'ALTER TABLE detalle_pedido ADD COLUMN subtotal NUMERIC(10,2) NOT NULL DEFAULT 0';
        ELSE
            -- si existe y no es generada, aseguramos su tipo y nullability (si es necesario)
            -- intentamos cambiar tipo a numeric(10,2)
            BEGIN
                EXECUTE 'ALTER TABLE detalle_pedido ALTER COLUMN subtotal TYPE NUMERIC(10,2) USING subtotal::numeric';
            EXCEPTION WHEN OTHERS THEN
                -- si falla conversión, dejamos como está (evita bloquear)
                RAISE NOTICE 'No se cambió el tipo de subtotal (posible datos no convertibles).';
            END;
            -- asegurar NOT NULL por si el diseño lo exige (opcional, aquí dejamos NOT NULL)
            BEGIN
                EXECUTE 'ALTER TABLE detalle_pedido ALTER COLUMN subtotal SET NOT NULL';
            EXCEPTION WHEN OTHERS THEN
                -- si hay NULLs, no forzamos; avisamos
                RAISE NOTICE 'No se pudo forzar NOT NULL en subtotal (existen valores NULL).';
            END;
        END IF;
    ELSE
        -- si no existe subtotal, la añadimos
        EXECUTE 'ALTER TABLE detalle_pedido ADD COLUMN subtotal NUMERIC(10,2) NOT NULL DEFAULT 0';
    END IF;
END
$$;

-- 2) Asegurar que las columnas esperadas existen; si alguna falta, la creamos con los tipos esperados.
-- id_pedido y codigo_producto deberían existir; si no, esto fallará y debe corregirse manualmente.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'detalle_pedido' AND column_name = 'cantidad_solicitada'
    ) THEN
        EXECUTE 'ALTER TABLE detalle_pedido ADD COLUMN cantidad_solicitada INT NOT NULL DEFAULT 1';
        RAISE NOTICE 'Columna % creada temporalmente con DEFAULT 1; revisa datos.', 'cantidad_solicitada';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'detalle_pedido' AND column_name = 'precio_unitario'
    ) THEN
        EXECUTE 'ALTER TABLE detalle_pedido ADD COLUMN precio_unitario NUMERIC(10,2) NOT NULL DEFAULT 0';
        RAISE NOTICE 'Columna % creada temporalmente con DEFAULT 0; revisa datos.', 'precio_unitario';
    END IF;
END
$$;

-- 3) Reemplazar/crear la función crear_pedido adaptada a los nombres correctos
CREATE OR REPLACE FUNCTION crear_pedido(
    p_id_cliente INT,
    p_productos JSON
)
RETURNS INT AS $$
DECLARE
    v_id_pedido INT;
    v_total NUMERIC := 0;
    v_producto RECORD;
    v_stock_actual INT;
    v_precio NUMERIC;
BEGIN
    -- Verificar que el cliente exista
    PERFORM 1 FROM clientes WHERE id_cliente = p_id_cliente;
    IF NOT FOUND THEN
        RAISE NOTICE 'Cliente no existe: %', p_id_cliente;
        RETURN NULL;
    END IF;

    -- Crear pedido en estado 'pendiente'
    INSERT INTO pedidos (id_cliente, fecha_pedido, estado_pedido, monto_total, fecha_ultima_actualizacion)
    VALUES (p_id_cliente, NOW(), 'pendiente', 0, NOW())
    RETURNING id_pedido INTO v_id_pedido;

    -- Procesar cada producto del JSON
    FOR v_producto IN
        SELECT * FROM json_to_recordset(p_productos) AS (codigo_producto INT, cantidad INT)
    LOOP
        -- Verificar existencia y stock del producto
        SELECT stock_disponible, precio_unitario
        INTO v_stock_actual, v_precio
        FROM productos
        WHERE codigo_producto = v_producto.codigo_producto
          AND estado = 'activo'
        FOR UPDATE; -- opcional: bloquea la fila para evitar race conditions en concurrencia

        IF NOT FOUND THEN
            RAISE NOTICE 'Producto no encontrado o inactivo: %', v_producto.codigo_producto;
            -- revertir creando un flag para eliminar pedido o retornar NULL
            -- eliminamos el pedido creado para no dejar pendientes sin detalles
            DELETE FROM pedidos WHERE id_pedido = v_id_pedido;
            RETURN NULL;
        END IF;

        IF v_stock_actual < v_producto.cantidad THEN
            RAISE NOTICE 'Stock insuficiente para producto % (Stock: %, Solicitado: %)',
                v_producto.codigo_producto, v_stock_actual, v_producto.cantidad;
            DELETE FROM pedidos WHERE id_pedido = v_id_pedido;
            RETURN NULL;
        END IF;

        -- Descontar stock
        UPDATE productos
        SET stock_disponible = stock_disponible - v_producto.cantidad,
            fecha_ultima_actualizacion = NOW()
        WHERE codigo_producto = v_producto.codigo_producto;

        -- Insertar detalle de pedido guardando subtotal explícitamente
        INSERT INTO detalle_pedido (id_pedido, codigo_producto, cantidad_solicitada, precio_unitario, subtotal)
        VALUES (v_id_pedido, v_producto.codigo_producto, v_producto.cantidad, v_precio, (v_precio * v_producto.cantidad));

        -- Registrar movimiento en historial_stock
        INSERT INTO historial_stock (
            codigo_producto, tipo_movimiento, cantidad,
            stock_anterior, stock_nuevo, id_pedido_relacionado,
            fecha_movimiento, usuario_movimiento
        )
        VALUES (
            v_producto.codigo_producto,
            'salida',
            v_producto.cantidad,
            v_stock_actual,
            v_stock_actual - v_producto.cantidad,
            v_id_pedido,
            NOW(),
            CURRENT_USER
        );

        -- Acumular total
        v_total := v_total + (v_precio * v_producto.cantidad);
    END LOOP;

    -- Actualizar el monto total del pedido
    UPDATE pedidos
    SET monto_total = v_total,
        fecha_ultima_actualizacion = NOW()
    WHERE id_pedido = v_id_pedido;

    RAISE NOTICE 'Pedido % creado exitosamente con total %', v_id_pedido, v_total;
    RETURN v_id_pedido;

EXCEPTION
    WHEN OTHERS THEN
        -- Intentamos dejar la BD consistente: borrar pedido si fue creado
        RAISE NOTICE 'Error al crear pedido: %', SQLERRM;
        BEGIN
            DELETE FROM detalle_pedido WHERE id_pedido = v_id_pedido;
            DELETE FROM historial_stock WHERE id_pedido_relacionado = v_id_pedido;
            DELETE FROM pedidos WHERE id_pedido = v_id_pedido;
        EXCEPTION WHEN OTHERS THEN
            -- si falla limpieza, al menos lo notificamos
            RAISE NOTICE 'No fue posible limpiar totalmente el pedido % tras error.', v_id_pedido;
        END;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM pedidos;
SELECT * FROM pedidos ORDER BY id_pedido DESC LIMIT 5;
SELECT * FROM detalle_pedido WHERE id_pedido = 2;
SELECT * FROM historial_stock WHERE id_pedido_relacionado = 2;


-- Ver los últimos pedidos
SELECT * FROM pedidos ORDER BY id_pedido DESC LIMIT 5;

-- Ver el detalle del pedido recién creado
SELECT * FROM detalle_pedido WHERE id_pedido = 3;

-- Ver el historial de stock relacionado
SELECT * FROM historial_stock WHERE id_pedido_relacionado = 3;

--Tarea 2.2: Crear una función procesar_pago que:

CREATE OR REPLACE FUNCTION procesar_pago(
    p_id_pedido INT,
    p_metodo_pago VARCHAR,
    p_referencia VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_estado_pedido VARCHAR(15);
    v_monto_total NUMERIC(10,2);
    v_id_pago INT;
    v_aprobado BOOLEAN;
BEGIN
    -- 1) Validar que el pedido exista y esté pendiente
    SELECT estado_pedido, monto_total INTO v_estado_pedido, v_monto_total
    FROM pedidos
    WHERE id_pedido = p_id_pedido;

    IF NOT FOUND THEN
        RAISE NOTICE ' Pedido % no existe', p_id_pedido;
        RETURN FALSE;
    ELSIF v_estado_pedido <> 'pendiente' THEN
        RAISE NOTICE ' Pedido % no está pendiente (estado actual: %)', p_id_pedido, v_estado_pedido;
        RETURN FALSE;
    END IF;

    -- 2) Registrar el intento de pago con estado "procesando"
    INSERT INTO pagos (id_pedido, metodo_pago, monto_pagado, estado_pago, referencia_transaccion, fecha_pago)
    VALUES (p_id_pedido, p_metodo_pago, v_monto_total, 'procesando', p_referencia, NOW())
    RETURNING id_pago INTO v_id_pago;

    -- 3) Simular aprobación y rechazo (50% probabilidad)
    v_aprobado := (RANDOM() < 0.5);

    -- 4) Si el pago fue aprobado
    IF v_aprobado THEN
        UPDATE pedidos
        SET estado_pedido = 'confirmado',
            fecha_ultima_actualizacion = NOW()
        WHERE id_pedido = p_id_pedido;

        UPDATE pagos
        SET estado_pago = 'aprobado',
            fecha_pago = NOW()
        WHERE id_pago = v_id_pago;

        RAISE NOTICE ' Pago aprobado para el pedido %, total: %', p_id_pedido, v_monto_total;
        RETURN TRUE;

    -- 5) Si el pago fue rechazado
    ELSE
        -- Restaurar stock
        UPDATE productos
        SET stock_disponible = stock_disponible + dp.cantidad,
            fecha_ultima_actualizacion = NOW()
        FROM detalle_pedido dp
        WHERE dp.id_pedido = p_id_pedido
          AND productos.codigo_producto = dp.codigo_producto;

        -- Actualizar estado del pedido y pago
        UPDATE pedidos
        SET estado_pedido = 'cancelado',
            fecha_ultima_actualizacion = NOW()
        WHERE id_pedido = p_id_pedido;

        UPDATE pagos
        SET estado_pago = 'rechazado',
            fecha_pago = NOW()
        WHERE id_pago = v_id_pago;

        -- Registrar movimientos en historial_stock
        INSERT INTO historial_stock (
            codigo_producto, tipo_movimiento, cantidad,
            stock_anterior, stock_nuevo, id_pedido_relacionado
        )
        SELECT 
            dp.codigo_producto,
            'entrada' AS tipo_movimiento,
            dp.cantidad,
            p.stock_disponible - dp.cantidad AS stock_anterior,
            p.stock_disponible AS stock_nuevo,
            p_id_pedido
        FROM detalle_pedido dp
        JOIN productos p ON p.codigo_producto = dp.codigo_producto
        WHERE dp.id_pedido = p_id_pedido;

        RAISE NOTICE ' Pago rechazado para pedido %, stock restaurado.', p_id_pedido;
        RETURN FALSE;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al procesar pago: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

--Cancelar pedido
CREATE OR REPLACE FUNCTION cancelar_pedido(p_id_pedido INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_estado_actual VARCHAR(15);
    v_codigo_producto INT;
    v_cantidad INT;
    v_stock_anterior INT;
BEGIN
    -- 1)Verificar si el pedido existe
    SELECT estado_pedido INTO v_estado_actual
    FROM pedidos
    WHERE id_pedido = p_id_pedido;

    IF NOT FOUND THEN
        RAISE NOTICE 'Error: El pedido % no existe', p_id_pedido;
        RETURN FALSE;
    END IF;

    -- 2) Validar si se puede cancelar
    IF v_estado_actual NOT IN ('pendiente', 'confirmado') THEN
        RAISE NOTICE 'El pedido % no puede cancelarse (estado: %)', p_id_pedido, v_estado_actual;
        RETURN FALSE;
    END IF;

    -- 3) Restaurar el stock de productos
    FOR v_codigo_producto, v_cantidad IN
        SELECT codigo_producto, cantidad
        FROM detalle_pedido
        WHERE id_pedido = p_id_pedido
    LOOP
        -- Guardar stock anterior
        SELECT stock_disponible INTO v_stock_anterior
        FROM productos
        WHERE codigo_producto = v_codigo_producto;

        -- Actualizar stock (devolución)
        UPDATE productos
        SET stock_disponible = stock_disponible + v_cantidad,
            fecha_ultima_actualizacion = NOW()
        WHERE codigo_producto = v_codigo_producto;

        -- Registrar devolución en historial_stock
        INSERT INTO historial_stock (
            codigo_producto,
            tipo_movimiento,
            cantidad,
            stock_anterior,
            stock_nuevo,
            id_pedido_relacionado
        )
        VALUES (
            v_codigo_producto,
            'entrada',
            v_cantidad,
            v_stock_anterior,
            v_stock_anterior + v_cantidad,
            p_id_pedido
        );
    END LOOP;

    -- 4) Actualizar el pedido a cancelado
    UPDATE pedidos
    SET estado_pedido = 'cancelado',
        fecha_ultima_actualizacion = NOW()
    WHERE id_pedido = p_id_pedido;

    RAISE NOTICE ' Pedido % cancelado exitosamente y stock restaurado.', p_id_pedido;
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error al cancelar pedido %: %', p_id_pedido, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'detalle_pedido';

ALTER TABLE detalle_pedido
ADD COLUMN cantidad INT NOT NULL DEFAULT 1;

SELECT column_name FROM information_schema.columns WHERE table_name = 'detalle_pedido';


-- 3.1.

SELECT codigo_producto, nombre, stock_disponible, estado 
FROM productos 
ORDER BY codigo_producto;

---------
--Conexion A (Query Tool de la base de datos 1):
--BEGIN;
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--SELECT crear_pedido(1, '[{"codigo_producto": 5, "cantidad": 1}]'::json);
--SELECT pg_sleep(10);

--COMMIT;
--Conexion B (Query Tool de la base de datos 2):

--BEGIN;
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--SELECT crear_pedido(2, '[{"codigo_producto": 5, "cantidad": 1}]'::json);
--COMMIT;


---------
SELECT codigo_producto, nombre, stock_disponible
FROM productos
WHERE codigo_producto = 5;

SELECT * FROM pedidos ORDER BY id_pedido DESC LIMIT 5;
SELECT * FROM detalle_pedido ORDER BY id_detalle DESC LIMIT 5;

---3.2.

SELECT * FROM productos WHERE codigo_producto = 4;


--Paso 2: Crear pedido exitosamente

SELECT crear_pedido(2, '[{"codigo_producto": 4, "cantidad": 1}]'::json);

SELECT * FROM pedidos ORDER BY id_pedido DESC LIMIT 1;
SELECT * FROM detalle_pedido WHERE id_pedido = (SELECT MAX(id_pedido) FROM pedidos);
SELECT * FROM productos WHERE codigo_producto = 4;


SELECT procesar_pago(6, 'tarjeta', 'REF-TEST');


--PASO 4
SELECT * FROM productos WHERE codigo_producto = 4;

---Paso 5
SELECT * 
FROM historial_stock 
WHERE codigo_producto = 4 
ORDER BY fecha_movimiento DESC 
LIMIT 5;


--3.3.
SELECT codigo_producto, nombre, stock_disponible
FROM productos
WHERE stock_disponible <= 2;

--Conexion A:
/*BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT crear_pedido(1, '[{"codigo_producto": 8, "cantidad": 1}]'::json);
SELECT pg_sleep(10);

ROLLBACK;

--Conexion B:
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT crear_pedido(2, '[{"codigo_producto": 8, "cantidad": 1}]'::json);
COMMIT;
*/
--ROLLBACK;

--4.1.

-- 1. Listar todos los pedidos con sus detalles, incluyendo información del cliente y productos
SELECT 
    p.id_pedido,
    p.id_cliente,
    c.nombre_completo AS cliente,
    pr.codigo_producto,
    pr.nombre AS producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal,
    p.monto_total,
    p.fecha_ultima_actualizacion AS fecha_pedido
FROM pedidos p
JOIN clientes c ON p.id_cliente = c.id_cliente
JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
JOIN productos pr ON dp.codigo_producto = pr.codigo_producto
ORDER BY p.id_pedido;


-- 2. Mostrar productos con stock por debajo del mínimo de alerta
SELECT 
    codigo_producto,
    nombre,
    stock_disponible,
    stock_minimo_alerta,
    estado
FROM productos
WHERE stock_disponible < stock_minimo_alerta
ORDER BY stock_disponible ASC;


-- 3. Generar reporte de ventas por producto

SELECT 
    pr.codigo_producto,
    pr.nombre,
    SUM(dp.cantidad) AS total_vendido,
    SUM(dp.subtotal) AS monto_total
FROM detalle_pedido dp
JOIN pedidos p ON dp.id_pedido = p.id_pedido
JOIN productos pr ON dp.codigo_producto = pr.codigo_producto
GROUP BY pr.codigo_producto, pr.nombre
ORDER BY monto_total DESC;

-- 4. Listar pedidos cancelados con motivo
SELECT 
    p.id_pedido,
    c.nombre_completo,
    p.fecha_pedido,
    p.estado_pedido,
    h.tipo_movimiento,
    h.cantidad,
    h.fecha_movimiento,
    h.usuario_movimiento
FROM pedidos p
JOIN clientes c ON p.id_cliente = c.id_cliente
JOIN historial_stock h ON p.id_pedido = h.id_pedido_relacionado
WHERE p.estado_pedido = 'cancelado'
ORDER BY p.id_pedido, h.fecha_movimiento;


-- 5. Mostrar historial completo de movimientos de stock

SELECT * FROM historial_stock;

SELECT * FROM productos WHERE codigo_producto = 8;

SELECT 
    h.id_registro,
    h.codigo_producto,
    pr.nombre AS nombre_producto,
    h.tipo_movimiento,
    h.cantidad,
    h.stock_anterior,
    h.stock_nuevo,
    h.id_pedido_relacionado,
    h.fecha_movimiento,
    h.usuario_movimiento
FROM historial_stock h
JOIN productos pr ON h.codigo_producto = pr.codigo_producto
ORDER BY h.fecha_movimiento DESC;

--4.2.
--Explain
EXPLAIN ANALYZE
SELECT 
    p.id_pedido,
    c.nombre_completo AS cliente,
    pr.nombre AS producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal,
    p.monto_total,
    p.fecha_pedido
FROM pedidos p
JOIN clientes c ON p.id_cliente = c.id_cliente
JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
JOIN productos pr ON dp.codigo_producto = pr.codigo_producto
ORDER BY p.id_pedido;

EXPLAIN ANALYZE
SELECT 
    pr.codigo_producto,
    pr.nombre,
    SUM(dp.cantidad) AS total_vendido,
    SUM(dp.subtotal) AS monto_total
FROM detalle_pedido dp
JOIN pedidos p ON dp.id_pedido = p.id_pedido
JOIN productos pr ON dp.codigo_producto = pr.codigo_producto
WHERE p.estado_pedido IN ('confirmado', 'enviado')
GROUP BY pr.codigo_producto, pr.nombre
ORDER BY monto_total DESC;

EXPLAIN ANALYZE
SELECT 
    h.codigo_producto,
    pr.nombre AS producto,
    h.tipo_movimiento,
    h.cantidad,
    h.fecha_movimiento
FROM historial_stock h
JOIN productos pr ON h.codigo_producto = pr.codigo_producto
ORDER BY h.fecha_movimiento DESC;

----Identificar oportunidades de optimización

--No hay índice útil.
--Sort costoso
--Filtros en columnas sin índice 

--Propuestas
---Mejora 1: Índice compuesto para acelerar búsquedas por cliente y pedido
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(id_cliente, fecha_pedido);

---Mejora 2: Índice para consultas de reportes de ventas
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(codigo_producto);

---Mejora 3: Índice para historial de movimientos de stock

CREATE INDEX idx_historial_producto_fecha ON historial_stock(codigo_producto, fecha_movimiento DESC);

--Tarea 4.3: Gestión de transacciones

--  TRANSACCIONES ACTIVAS
SELECT
    pid,
    usename AS usuario,
    datname AS base_datos,
    state AS estado,
    backend_start AS inicio_backend,
    xact_start AS inicio_transaccion,
    query_start AS inicio_query,
    now() - query_start AS duracion_query,
    query
FROM pg_stat_activity
WHERE state IN ('active', 'idle in transaction')
ORDER BY query_start DESC;

-- BLOQUEOS ACTUALES
SELECT
    l.pid,
    a.usename AS usuario,
    a.datname AS base_datos,
    l.relation::regclass AS tabla_afectada,
    l.mode AS tipo_bloqueo,
    l.granted AS concedido,
    a.query AS consulta,
    now() - a.query_start AS duracion
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted
   OR a.state = 'active'
ORDER BY duracion DESC;


-- CONSULTAS ESPERANDO BLOQUEOS

--Conexion A:
--BEGIN;
--SELECT * FROM productos WHERE codigo_producto = 1 FOR UPDATE;
-- No hagas COMMIT ni ROLLBACK todavía

--Conexion B:

--BEGIN;
--UPDATE productos SET precio_unitario = precio_unitario + 10 WHERE codigo_producto = 1;

SELECT
    bl.pid AS pid_bloqueado,
    a_bl.usename AS usuario_bloqueado,
    a_bl.query AS consulta_bloqueada,
    now() - a_bl.query_start AS tiempo_espera,
    kl.pid AS pid_bloqueante,
    a_kl.usename AS usuario_bloqueante,
    a_kl.query AS consulta_bloqueante
FROM pg_locks bl
JOIN pg_stat_activity a_bl ON bl.pid = a_bl.pid
JOIN pg_locks kl ON bl.locktype = kl.locktype
                 AND bl.database IS NOT DISTINCT FROM kl.database
                 AND bl.relation IS NOT DISTINCT FROM kl.relation
                 AND bl.page IS NOT DISTINCT FROM kl.page
                 AND bl.tuple IS NOT DISTINCT FROM kl.tuple
                 AND bl.transactionid IS NOT DISTINCT FROM kl.transactionid
                 AND bl.classid IS NOT DISTINCT FROM kl.classid
                 AND bl.objid IS NOT DISTINCT FROM kl.objid
                 AND bl.objsubid IS NOT DISTINCT FROM kl.objsubid
JOIN pg_stat_activity a_kl ON kl.pid = a_kl.pid
WHERE NOT bl.granted
ORDER BY tiempo_espera DESC;

/*
--Ver tabalas creadas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';

--Estructura de las tablas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'productos';

--Datos insertados
SELECT * FROM productos;
SELECT * FROM clientes;

--Crear pedido
SELECT crear_pedido(1, '[{"codigo_producto": 1, "cantidad": 3}]'::json);
SELECT * FROM pedidos;
SELECT * FROM pedidos ORDER BY id_pedido DESC LIMIT 5;
SELECT * FROM detalle_pedido WHERE id_pedido = 2;
SELECT * FROM historial_stock WHERE id_pedido_relacionado = 2;

--Procesar pago
SELECT procesar_pago(1, 'tarjeta', 'REF-001');

--Cancelar pedido
SELECT cancelar_pedido(2);

--Deadlock
--A
BEGIN;
SELECT * FROM productos WHERE codigo_producto = 8 FOR UPDATE;
SELECT pg_sleep(5);
SELECT * FROM productos WHERE codigo_producto = 10 FOR UPDATE;
--B
BEGIN;
SELECT * FROM productos WHERE codigo_producto = 10 FOR UPDATE;
SELECT pg_sleep(5);
SELECT * FROM productos WHERE codigo_producto = 8 FOR UPDATE;

--M y R
SELECT * FROM pedidos;
SELECT * FROM historial_stock;

--Transaccion y bloqueos
SELECT * FROM pg_stat_activity;
SELECT * FROM pg_locks;
*/