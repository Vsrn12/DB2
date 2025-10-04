----------------------------------------------
--PARTE 1: PREPARACIÓN DEL ENTORNO  
----------------------------------------------
CREATE DATABASE laboratorio_optimizacion;

--Creando tabla clientes
CREATE TABLE clientes (
  cliente_id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  email VARCHAR(100),
  ciudad VARCHAR(50),
  fecha_registro DATE,
  activo BOOLEAN DEFAULT TRUE
);

--Creando tabla productos
CREATE TABLE productos (
  producto_id SERIAL PRIMARY KEY,
  nombre_producto VARCHAR(100),
  categoria VARCHAR(50),
  precio DECIMAL(10,2),
  stock INTEGER
);

--Creando tabla pedidos
CREATE TABLE pedidos (
  pedido_id SERIAL PRIMARY KEY,
  cliente_id INTEGER REFERENCES clientes(cliente_id),
  fecha_pedido DATE,
  total DECIMAL(10,2),
  estado VARCHAR(20)
);

--Creando tabla detalle_pedidos
CREATE TABLE detalle_pedidos (
  detalle_id SERIAL PRIMARY KEY,
  pedido_id INTEGER REFERENCES pedidos(pedido_id),
  producto_id INTEGER REFERENCES productos(producto_id),
  cantidad INTEGER,
  precio_unitario DECIMAL(10,2)
);

--INSERTAMOS DATOS DE PRUEBA
--Clientes
INSERT INTO clientes (nombre, email, ciudad, fecha_registro, activo)
SELECT 
  'Cliente ' || generate_series,
  'cliente' || generate_series || '@email.com',
  CASE 
    WHEN generate_series % 5 = 0 THEN 'Lima'
    WHEN generate_series % 5 = 1 THEN 'Arequipa'
    WHEN generate_series % 5 = 2 THEN 'Trujillo'
    WHEN generate_series % 5 = 3 THEN 'Cusco'
    ELSE 'Piura'
  END,
  CURRENT_DATE - (generate_series % 365),
  generate_series % 10 != 0
FROM generate_series(1, 10000);

--Productos
INSERT INTO productos (nombre_producto, categoria, precio, stock)
SELECT 
  'Producto ' || generate_series,
  CASE 
    WHEN generate_series % 4 = 0 THEN 'Electrónicos'
    WHEN generate_series % 4 = 1 THEN 'Ropa'
    WHEN generate_series % 4 = 2 THEN 'Hogar'
    ELSE 'Deportes'
  END,
  (generate_series % 500) + 10.99,
  generate_series % 100 + 1
FROM generate_series(1, 1000);

--Pedidos
INSERT INTO pedidos (cliente_id, fecha_pedido, total, estado)
SELECT 
  (generate_series % 10000) + 1,
  CURRENT_DATE - (generate_series % 180),
  ((generate_series % 500) + 50) * 1.19,
  CASE 
    WHEN generate_series % 4 = 0 THEN 'Completado'
    WHEN generate_series % 4 = 1 THEN 'Pendiente'
    WHEN generate_series % 4 = 2 THEN 'Enviado'
    ELSE 'Cancelado'
  END
FROM generate_series(1, 50000);

--Detalle_pedidos
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario)
SELECT 
  (generate_series % 50000) + 1,
  (generate_series % 1000) + 1,
  (generate_series % 5) + 1,
  ((generate_series % 200) + 10) * 0.99
FROM generate_series(1, 150000);

----------------------------------------------
--PARTE 2: ANÁLISIS DE PLANES DE EJECUCIÓN 
----------------------------------------------
EXPLAIN ANALYZE
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;

----------------------------------------------
--PARTE 3: OPTIMIZACIÓN CON ÍNDICES
----------------------------------------------

CREATE INDEX idx_clientes_ciudad ON clientes(ciudad);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido);
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(cliente_id, fecha_pedido);
-- Índice compuesto
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(cliente_id, fecha_pedido);

--Comparando rendimiento
EXPLAIN ANALYZE
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY total_pedidos DESC;

--Índices Parciales
CREATE INDEX idx_parcial_clientes_lima_activos ON clientes(cliente_id)
WHERE ciudad = 'Lima' AND activo = true;

EXPLAIN ANALYZE
SELECT c.nombre, c.email
FROM clientes c
WHERE c.ciudad = 'Lima' AND c.activo = true
AND c.fecha_registro > '2024-01-01';

----------------------------------------------
--PARTE 4: ALGORITMOS DE JOIN 
----------------------------------------------

SET enable_hashjoin = off;
SET enable_mergejoin = off;
SET enable_nestloop = off;

EXPLAIN ANALYZE
SELECT c.nombre, p.total, pr.nombre_producto
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
WHERE c.ciudad = 'Lima'
AND p.fecha_pedido > '2025-01-01';

RESET ALL

----------------------------------------------
--PARTE 5: OPTIMIZACIÓN BASADA EN ESTADÍSTICAS
----------------------------------------------

SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del, last_vacuum, last_analyze
FROM pg_stat_user_tables;

ANALYZE clientes;
ANALYZE pedidos;
ANALYZE productos;
ANALYZE detalle_pedidos;

--5.2: Impacto de las Estadísticas
INSERT INTO clientes (nombre, email, ciudad, fecha_registro, activo)
SELECT 'NuevoCliente ' || generate_series, 'nuevo' || generate_series || '@email.com', 'Lima', CURRENT_DATE, true
FROM generate_series(1, 5000);

EXPLAIN ANALYZE
SELECT c.nombre, p.total, pr.nombre_producto
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
JOIN detalle_pedidos dp ON p.pedido_id = dp.pedido_id
JOIN productos pr ON dp.producto_id = pr.producto_id
WHERE c.ciudad = 'Lima'
AND p.fecha_pedido > '2025-01-01';

----------------------------------------------
--PARTE 6: REESCRITURA DE CONSULTAS 
----------------------------------------------

EXPLAIN ANALYZE
SELECT c.nombre
FROM clientes c
WHERE c.cliente_id IN (
  SELECT p.cliente_id
  FROM pedidos p
  WHERE p.total > 500
);

EXPLAIN ANALYZE
SELECT c.nombre
FROM clientes c
WHERE EXISTS (
  SELECT 1
  FROM pedidos p
  WHERE p.cliente_id = c.cliente_id
  AND p.total > 500
);

--Paso 6.2: Subconsultas vs JOINs
EXPLAIN ANALYZE
SELECT c.nombre, 
  (SELECT COUNT(*) FROM pedidos p WHERE p.cliente_id = c.cliente_id) as total_pedidos
FROM clientes c
WHERE c.ciudad = 'Lima';

EXPLAIN ANALYZE
SELECT c.nombre, COUNT(p.pedido_id) as total_pedidos
FROM clientes c
LEFT JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre;

EXPLAIN ANALYZE
SELECT c.nombre,
  SUM(p.total) as total_compras,
  RANK() OVER (ORDER BY SUM(p.total) DESC) as ranking
FROM clientes c
JOIN pedidos p ON c.cliente_id = p.cliente_id
WHERE c.ciudad = 'Lima'
GROUP BY c.cliente_id, c.nombre
ORDER BY ranking;

----------------------------------------------
--PARTE 7: REESCRITURA DE CONSULTAS 
----------------------------------------------

EXPLAIN ANALYZE
WITH ventas_mensuales AS (
  SELECT 
    pr.nombre_producto,
    DATE_TRUNC('month', p.fecha_pedido) as mes,
    SUM(dp.cantidad * dp.precio_unitario) as total_ventas,
    COUNT(DISTINCT p.cliente_id) as clientes_unicos
  FROM productos pr
  JOIN detalle_pedidos dp ON pr.producto_id = dp.producto_id
  JOIN pedidos p ON dp.pedido_id = p.pedido_id
  JOIN clientes c ON p.cliente_id = c.cliente_id
  WHERE p.estado = 'Completado'
  AND p.fecha_pedido > '2020-01-01'
  AND c.ciudad = 'Lima'
  GROUP BY pr.nombre_producto, mes
),
ranking_productos AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY mes
      ORDER BY total_ventas DESC
    ) as rank
  FROM ventas_mensuales
)
SELECT *
FROM ranking_productos
WHERE rank <= 3
ORDER BY mes, rank;

CREATE INDEX idx_pedidos_fecha_estado ON pedidos(fecha_pedido, estado);
CREATE INDEX idx_detalle_pedidos_pedido_producto ON detalle_pedidos(pedido_id, producto_id);