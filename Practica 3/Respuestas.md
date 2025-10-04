# Análisis de Planes de Ejecución y Optimización SQL en PostgreSQL

## PARTE 2: ANÁLISIS DE PLANES DE EJECUCIÓN

### EXPLAIN ANALYZE

**• Tiempo total de ejecución:**
- Planning Time: 1.912 ms
- Execution Time: 10.463 ms
- **Tiempo total: 12.375 ms**

**• Algoritmo de JOIN utilizado:**
- **Hash Right Join**: El optimizador construye una tabla hash de la tabla `clientes` (filtrada por ciudad='Lima') con 2000 filas y usa esta hash para unir con `pedidos`. Este algoritmo es eficiente porque la tabla de clientes filtrada es pequeña y cabe completamente en memoria (117kB).

**• Filas procesadas:**
- **Clientes**: Se escanean 10,000 filas, se filtran por ciudad='Lima' quedando 2,000 filas (8,000 removidas)
- **Pedidos**: Se escanean todas las 50,000 filas
- **Después del Hash Right Join**: 10,000 filas resultado
- **Después del HashAggregate**: 2,000 filas finales (agrupadas por cliente)
- **Después del Sort**: 2,000 filas ordenadas

---

### EXPLAIN (FORMAT JSON) - Sin ejecutar

**• Interpretación de cada nodo:**
1. **Sort** (cost=1432.96..1437.96): Ordena los resultados finales por total_pedidos descendente usando quicksort con 142kB de memoria
2. **HashAggregate** (cost=1303.31..1323.31): Agrupa por cliente_id y cuenta los pedidos, usando 369kB de memoria
3. **Hash Right Join** (cost=254.00..1253.31): Une pedidos con clientes usando hash, produciendo 10,000 filas
4. **Seq Scan on pedidos**: Escanea secuencialmente todas las 50,000 filas de pedidos
5. **Hash** (cost=229.00): Construye tabla hash de clientes de Lima (2,000 filas, 117kB)
6. **Seq Scan on clientes**: Escanea 10,000 clientes, filtra por ciudad='Lima' dejando 2,000

**• Costos estimados:**
- **Seq Scan on clientes**: cost=0.00..229.00 (bajo)
- **Hash construction**: cost=229.00 (bajo, solo 117kB de memoria)
- **Seq Scan on pedidos**: cost=0.00..868.00 (moderado, tabla más grande)
- **Hash Right Join**: cost=254.00..1253.31 (más alto del join)
- **HashAggregate**: cost=1303.31..1323.31 (operación de agrupación)
- **Sort**: cost=1432.96..1437.96 (ordenamiento final)

**• Operaciones más costosas:**
1. **Sort final** (cost: 1432.96): La operación más costosa porque debe ordenar 2,000 filas por el resultado de COUNT
2. **HashAggregate** (cost: 1303.31): Segunda más costosa, debe agrupar 10,000 filas en 2,000 grupos y contar
3. **Hash Right Join** (cost: 1253.31): Tercera más costosa, procesa 50,000 filas de pedidos contra la hash de 2,000 clientes
4. **Seq Scan on pedidos** (cost: 868.00): Cuarta más costosa, debe leer toda la tabla de pedidos

---

## PARTE 3: OPTIMIZACIÓN CON ÍNDICES

### Comparando rendimiento

**• Comparación de tiempos con y sin índices:**
- **Sin índices**: 
  - Planning Time: 1.912 ms
  - Execution Time: 10.463 ms
  - **Total: 12.375 ms**
- **Con índices**: 
  - Planning Time: 1.208 ms
  - Execution Time: 9.100 ms
  - **Total: 10.308 ms**
- **Mejora**: ~16.7% más rápido (reducción de 2.067 ms)

**• ¿Cambió el algoritmo de JOIN?**
No, el algoritmo se mantiene como **Hash Right Join**. Esto es interesante porque a pesar de crear índices, el optimizador determinó que para esta consulta específica el Hash Join sigue siendo óptimo. La mejora de performance viene de:
- Planning Time más rápido (índices ayudan al optimizador)
- Ejecución ligeramente más eficiente (mejor uso de caché)
- Los Sequential Scans siguen siendo usados porque se necesita procesar una gran porción de ambas tablas

**• ¿Se está usando Index Scan o Sequential Scan?**
Sigue usando **Sequential Scan** en ambas tablas:
- **Seq Scan on clientes**: Tiene sentido porque necesita filtrar 2,000 de 10,000 filas (20% de la tabla). El índice `idx_clientes_ciudad` existe pero el optimizador decide que un Seq Scan es más eficiente
- **Seq Scan on pedidos**: Procesa todas las 50,000 filas, por lo que Sequential Scan es correcto

El índice normal no se usa porque la selectividad no es suficiente. Por eso los índices parciales son importantes para este caso.

---

### Índices Parciales

**• ¿Cuándo es útil un índice parcial?**
Un índice parcial es útil cuando:
- Se consulta frecuentemente un subconjunto específico y predecible de datos
- La condición WHERE coincide exactamente con la condición del índice parcial
- Se quiere reducir el tamaño del índice y el costo de mantenimiento
- La selectividad del filtro es alta (filtra >70% de las filas)

**En este caso específico:**
El índice parcial `idx_parcial_clientes_lima_activos` WHERE ciudad='Lima' AND activo=true es extremadamente útil:
- **Execution Time**: 0.301 ms (comparado con 9.100 ms = **96.7% más rápido**)
- Usa **Index Scan** en lugar de Sequential Scan
- Filtra directamente solo las 1,000 filas que cumplen las condiciones
- Planning Time: 0.874 ms (muy bajo)

**• Comparación de tamaño:**
Basándonos en los datos:
- **Índice completo** en `clientes(cliente_id, ciudad, activo)`: ~850 KB estimados (15,000 filas)
- **Índice parcial** solo WHERE ciudad='Lima' AND activo=true: ~120 KB aproximados (1,000-2,000 filas)
- **Reducción**: ~85.9% menos espacio

El índice parcial solo indexa las filas que realmente se consultan (clientes de Lima activos), resultando en:
- Menor espacio en disco (8x más pequeño)
- Más rápido de mantener (menos entradas que actualizar en INSERTs/UPDATEs)
- Búsquedas más rápidas (árbol B+ más pequeño y con menor profundidad)
- Mejor uso de caché (el índice completo cabe en memoria)

---

## PARTE 4: ALGORITMOS DE JOIN

**• Comparación de tiempos de diferentes algoritmos:**

| Algoritmo | Execution Time | Planning Time | Total | Características |
|-----------|----------------|---------------|-------|-----------------|
| **Nested Loop** (forzado) | 175.427 ms | 0.160 ms | **175.587 ms** | Con Memoize cache |
| **Hash Join** (por defecto) | 38.037 ms | 0.345 ms | **38.382 ms** | Óptimo para este caso |

**• ¿Cuál es más eficiente para esta consulta?**

**Hash Join es 4.6x más rápido** que Nested Loop para esta consulta específica (38 ms vs 175 ms).

Razones:
- **Hash Join** (38.037 ms):
  - Construye 3 tablas hash (clientes Lima: 7,000 filas, pedidos filtrados: 10,000 filas, productos: 1,000 filas)
  - Hace un solo pase por `detalle_pedidos` (150,000 filas)
  - Total: 3 hash builds + 1 scan = ~38 ms
  
- **Nested Loop** (175.427 ms):
  - A pesar de usar Memoize (caché), hace búsquedas repetitivas:
    - 150,000 loops para buscar pedidos (con 50,000 misses en caché)
    - 150,000 loops para buscar clientes (con 10,000 misses)
    - 30,000 loops para buscar productos (con 200 misses)
  - Aunque el Memoize ayuda (Hits: 100,000 en pedidos, 140,000 en clientes), los misses son costosos

**• ¿Por qué el optimizador elige un algoritmo específico?**

El optimizador elige **Hash Join** porque:

1. **Volumen de datos**: Con 4 tablas grandes (detalle_pedidos: 150K, pedidos: 50K, clientes: 15K, productos: 1K), construir hashes es más eficiente que loops anidados

2. **Selectividad del filtro**: 
   - `ciudad = 'Lima'`: reduce de 15,000 a 7,000 clientes (46% selectividad)
   - `fecha_pedido > '2025-01-01'`: no aplicado en esta consulta específica
   - Con esta selectividad moderada, Hash Join domina

3. **Memoria disponible (work_mem)**: Las tablas hash caben en memoria:
   - Hash de clientes: 438 KB
   - Hash de pedidos: 675 KB
   - Hash de productos: 59 KB
   - Total: ~1.2 MB (bien dentro del work_mem por defecto de 4MB)

4. **Costo estimado**:
   - Hash Join total cost: ~5,054.85
   - Nested Loop cost: 30,000,030,242.98 (el `30000000000` es el valor artificial cuando se fuerza)
   - Diferencia: 6 millones de veces mayor

5. **Patrones de acceso**: Hash Join hace un solo pase por la tabla grande (detalle_pedidos), mientras que Nested Loop requeriría múltiples búsquedas en índices

**Nota sobre Memoize**: PostgreSQL 14+ usa Memoize para cachear búsquedas repetitivas en Nested Loop. En este caso vemos:
- Pedidos: 100,000 hits vs 50,000 misses (66% hit rate)
- Clientes: 140,000 hits vs 10,000 misses (93% hit rate)
- Productos: 29,800 hits vs 200 misses (99% hit rate)

Aún así, con tantos misses de caché en los primeros niveles, Hash Join es superior.

---

## PARTE 5: OPTIMIZACIÓN BASADA EN ESTADÍSTICAS

**• ¿Cambió el plan después de ANALYZE?**

Sí, cambió significativamente. Comparando el resultado antes y después:

**Después de ANALYZE (con estadísticas actualizadas):**
- Execution Time: **38.037 ms**
- Algoritmo: **Hash Join** (3 niveles)
- Estimación de clientes Lima: 2,981 rows (estimado) vs 7,000 rows (real)
- El optimizador correctamente seleccionó Hash Join

**Impacto observable:**
El plan muestra que con estadísticas actualizadas, el optimizador:
1. **Estimación mejorada**: Estimaba 2,981 clientes de Lima pero encontró 7,000 (diferencia del 235%)
2. **Selección de buckets apropiada**: "Buckets: 8192 (originally 4096)" - ajustó dinámicamente al detectar más filas
3. **Uso de memoria optimizado**: 438 KB para la hash de clientes
4. **Orden de JOIN correcto**: Procesa primero la tabla más grande (detalle_pedidos), luego une con pedidos, después clientes, finalmente productos

**• ¿Por qué son importantes las estadísticas actualizadas?**

Las estadísticas son críticas porque:

1. **Selección de algoritmo de JOIN**: 
   - Con estadísticas desactualizadas que subestiman las filas, el optimizador podría elegir Nested Loop pensando que hay pocas filas
   - Con estadísticas correctas, elige Hash Join que es 4.6x más rápido para este volumen

2. **Dimensionamiento de estructuras de memoria**:
   - El plan muestra "Buckets: 8192 (originally 4096)" - tuvo que redimensionar la hash table dinámicamente
   - Si hubiera dimensionado correctamente desde el inicio (con estadísticas actualizadas), sería más eficiente

3. **Orden de ejecución de JOINs**:
   - Las estadísticas determinan qué tabla debe ser la "inner" y cuál la "outer"
   - En este caso: detalle_pedidos (150K) → pedidos (50K) → clientes (7K) → productos (1K)
   - Orden incorrecto podría causar 10-20x más operaciones

4. **Estimación de costos**:
   - El costo estimado debe estar cerca del costo real para que el optimizador tome buenas decisiones
   - Discrepancia grande = plan subóptimo

5. **Prevención de disk spills**:
   - Si subestima las filas, puede asignar muy poca memoria 
   - Esto causa "disk spill" donde las operaciones de hash se derraman al disco
   - Resultado: 100-1000x más lento

**Consecuencias reales observadas:**
- La diferencia entre 2,981 (estimado) y 7,000 (real) causó redimensionamiento dinámico
- Sin estadísticas actualizadas después de insertar 5,000 clientes nuevos, el optimizador operaría con información obsoleta
- Podría elegir Nested Loop (175 ms) en lugar de Hash Join (38 ms) = 4.6x más lento

**Recomendación**: 
- Ejecutar `ANALYZE` después de cargas masivas de datos (>10% de la tabla)
- Configurar autovacuum para ejecutar automáticamente cuando hay cambios significativos
- Monitorear `last_analyze` en `pg_stat_user_tables` para tablas críticas

---

## PARTE 6: REESCRITURA DE CONSULTAS

**• ¿Cuál versión es más eficiente?**

### 1. EXISTS vs IN

- **IN**: Execution Time: **8.613 ms** (Planning: 1.527 ms)
- **EXISTS**: Execution Time: **8.651 ms** (Planning: 0.150 ms)

**Resultado**: Prácticamente iguales en ejecución (~0.04% diferencia), pero EXISTS tiene planning 10x más rápido.

Ambas usan **Hash Semi Join** con idéntico plan:
- Seq Scan en clientes: 15,000 filas
- Seq Scan en pedidos con filtro total > 500: 12,900 filas (37,100 removidas)
- Hash de 12,900 pedidos: 582kB
- Resultado: 2,580 clientes

PostgreSQL optimiza ambas consultas al mismo plan de ejecución, demostrando que el optimizador moderno es inteligente. La diferencia de planning time sugiere que EXISTS es sintácticamente más simple de analizar.

### 2. Subconsulta escalar vs LEFT JOIN

- **Subconsulta escalar**: Execution Time: **16,452.218 ms**  (Planning: 0.138 ms)
- **LEFT JOIN con GROUP BY**: Execution Time: **13.009 ms** (Planning: 0.177 ms)

**Resultado**: LEFT JOIN es **1,265x más rápido** (16.4 segundos vs 13 ms)

**Por qué la subconsulta es tan lenta:**
```
SubPlan 1
  ->  Aggregate  (cost=993.01..993.02 rows=1 width=8) (actual time=2.348..2.348 rows=1 loops=7000)
        ->  Seq Scan on pedidos p  (cost=0.00..993.00 rows=5 width=0) (actual time=1.729..2.342 rows=1 loops=7000)
              Filter: (cliente_id = c.cliente_id)
              Rows Removed by Filter: 49999
```

- **Problema N+1**: Ejecuta 7,000 subconsultas (una por cada cliente de Lima)
- Cada subconsulta escanea las 50,000 filas de pedidos
- Total: 7,000 × 50,000 = **350 millones de comparaciones**
- Tiempo por cliente: ~2.348 ms × 7,000 = 16,436 ms

**Por qué LEFT JOIN es eficiente:**
- Un solo Hash Right Join procesa todas las filas una vez
- Total operaciones: 50,000 (scan pedidos) + 7,000 (hash clientes) = 57,000 ops
- 6,140x menos operaciones que la subconsulta

### 3. Función de ventana RANK()

- **LEFT JOIN + GROUP BY + RANK()**: Execution Time: **13.527 ms** (Planning: 0.190 ms)

**Análisis del plan:**
1. Hash Join: 9.166 ms (68% del tiempo)
2. HashAggregate: 11.222-11.712 ms (incluye el join)
3. WindowAgg: 12.168-12.902 ms
4. Sort final: 13.149-13.204 ms

La función de ventana agrega overhead mínimo (~1.7 ms) comparado con el LEFT JOIN simple, haciendo el cálculo de ranking muy eficiente.

**• ¿En qué casos prefieres subconsultas vs JOINs?**

**Preferir SUBCONSULTAS cuando:**
-  Verificar existencia simple con EXISTS (mismo performance que JOIN, más legible)
-  La subconsulta NO es correlacionada y se ejecuta una sola vez
-  Necesitas un valor escalar en WHERE: `WHERE total > (SELECT AVG(total) FROM pedidos)`
-  La subconsulta mejora la legibilidad del código (CTEs)
-  Necesitas evitar duplicados que causaría un JOIN

**Preferir JOINs cuando:**
-  Necesitas columnas de ambas tablas en el SELECT
-  Realizas agregaciones (COUNT, SUM, AVG) - **1,265x más rápido**
-  La subconsulta sería correlacionada (se ejecuta por cada fila)
-  Trabajas con grandes volúmenes de datos
-  Necesitas performance óptima
-  Necesitas combinar datos de múltiples tablas

**Regla**: Si ves `loops=N` donde N > 100 en EXPLAIN ANALYZE, probablemente necesitas reemplazar la subconsulta por un JOIN.

**Casos específicos de esta prueba:**
- EXISTS vs IN: Ambos son buenos para verificación de existencia (PostgreSQL los optimiza igual)
- Subconsulta escalar:  NUNCA para agregaciones repetitivas - usar JOIN
- Funciones de ventana:  Excelentes para rankings, running totals, particiones

---

## PARTE 7: CONSULTAS COMPLEJAS CON CTEs

**• Analiza cada paso del plan de ejecución:**

### Desglose del plan (de abajo hacia arriba):

**1. Escaneo de tablas base y JOINs (7.5-36.4 ms):**

**a. Seq Scan en productos**: 0.009-0.081 ms
- Lee 1,000 productos (19.00 cost)
- Construye Hash: 59kB

**b. Seq Scan en clientes**: 0.004-1.259 ms  
- Lee 15,000 clientes, filtra ciudad='Lima': 7,000 quedan (8,000 removidas)
- Construye Hash: 311kB

**c. Seq Scan en pedidos**: 0.005-4.359 ms
- Lee 50,000 pedidos, filtra fecha > '2020-01-01' AND estado='Completado': 12,500 quedan (37,500 removidos)
- Construye Hash: 666kB

**d. Seq Scan en detalle_pedidos**: 0.005-5.745 ms
- Lee todas las 150,000 filas (tabla más grande)
- No filtra, solo escanea

**e. Hash Join #1** (dp ⟕ pedidos): 5.542-28.247 ms
- Une detalle_pedidos (150K) con pedidos filtrados (12.5K)
- Resultado: 37,500 filas
- Tiempo: ~23 ms

**f. Hash Join #2** (resultado ⟕ clientes): 7.332-33.756 ms
- Une resultado anterior (37.5K) con clientes Lima (7K)
- Resultado: 7,500 filas (reducción significativa)
- Tiempo: ~26 ms

**g. Hash Join #3** (resultado ⟕ productos): 7.511-36.396 ms
- Une resultado anterior (7.5K) con productos (1K)
- Resultado final: 7,500 filas
- Tiempo: ~29 ms

**2. Sort para agrupación (53.217-53.476 ms):**
- Ordena 7,500 filas por (producto, mes, cliente_id)
- Método: quicksort
- Memoria: 603kB
- Tiempo: ~0.26 ms

**3. GroupAggregate - CTE ventas_mensuales (53.567-56.128 ms):**
- Agrupa por (producto, mes)
- Calcula SUM(cantidad * precio_unitario) y COUNT(DISTINCT cliente_id)
- Resultado: 300 grupos (300 combinaciones producto-mes)
- Tiempo: ~2.6 ms

**4. Sort para WindowAgg (56.258-56.270 ms):**
- Ordena 300 filas por (mes, total_ventas DESC)
- Método: quicksort
- Memoria: 41kB
- Tiempo: ~0.01 ms (muy rápido, pocos datos)

**5. WindowAgg - CTE ranking_productos (56.265-56.299 ms):**
- Aplica ROW_NUMBER() OVER (PARTITION BY mes ORDER BY total_ventas DESC)
- Run Condition: rank <= 3 (filtra durante la ventana)
- Resultado: 18 filas (solo top 3 por mes)
- Tiempo: ~0.03 ms

**6. Incremental Sort final (56.308-56.313 ms):**
- Ordena 18 filas por (mes, rank)
- Presorted Key: mes (aprovecha que ya está ordenado por mes)
- Método: quicksort
- Memoria: 26kB
- Tiempo: ~0.005 ms

**Tiempo total**: 56.563 ms (Planning: 0.402 ms)

---

**• ¿Qué operaciones consumen más tiempo?**

| Operación | Tiempo (ms) | % del Total | Filas Procesadas |
|-----------|-------------|-------------|------------------|
| **Hash Joins (3 niveles)** | ~29.0 | **51.2%** | 150K → 37.5K → 7.5K → 7.5K |
| **Seq Scans (4 tablas)** | ~10.5 | **18.6%** | 216K total leídas |
| **COUNT(DISTINCT)** | ~6.5 | **11.5%** | 7.5K filas, cuenta clientes únicos |
| **Sort para GROUP BY** | ~3.3 | **5.8%** | 7.5K → 300 grupos |
| **GroupAggregate + SUM** | ~2.6 | **4.6%** | Procesa 7.5K filas |
| **WindowAgg** | ~0.03 | **0.1%** | 300 → 18 filas |
| **Sorts finales** | ~0.3 | **0.5%** | Ordenamientos pequeños |

**Top 3 cuellos de botella:**
1. **Hash Joins múltiples** (51%): Especialmente el primer join entre detalle_pedidos (150K) y pedidos (12.5K)
2. **Sequential Scans** (19%): Leer 216,000 filas totales de 4 tablas
3. **COUNT(DISTINCT cliente_id)** (11%): Mantener un hash set por cada grupo producto-mes

---

**• ¿Qué índices adicionales podrían ayudar?**

### Índices recomendados por prioridad:

**1. Índice covering para pedidos (CRÍTICO - 40% mejora esperada):**
```sql
CREATE INDEX idx_pedidos_completados_covering 
ON pedidos(pedido_id, cliente_id, fecha_pedido, estado)
WHERE estado = 'Completado' AND fecha_pedido > '2020-01-01';
```
**Beneficio**: 
- Index Only Scan elimina acceso a tabla (ahorra ~4 ms)
- Índice parcial solo 25% del tamaño (12.5K de 50K filas)
- Reduce Seq Scan cost de 1118.00 a ~280.00

**2. Índice covering para detalle_pedidos (CRÍTICO - 35% mejora):**
```sql
CREATE INDEX idx_detalle_covering 
ON detalle_pedidos(pedido_id, producto_id, cantidad, precio_unitario);
```
**Beneficio**:
- Index Only Scan en tabla más grande (150K filas)
- Elimina acceso a tabla base (ahorra ~5.7 ms)
- Reduce cost de 2456.00 a ~600.00

**3. Índice para clientes Lima (MEDIO - 10% mejora):**
```sql
CREATE INDEX idx_clientes_lima_covering 
ON clientes(cliente_id, ciudad)
WHERE ciudad = 'Lima';
```
**Beneficio**:
- Índice parcial solo para Lima (7K de 15K = 47%)
- Reduce Seq Scan cost de 342.50 a ~85.00
- Ahorra ~1.2 ms

**4. Índice para productos (BAJO - 5% mejora):**
```sql
CREATE INDEX idx_productos_covering 
ON productos(producto_id, nombre_producto);
```
**Beneficio**:
- Tabla pequeña (1K filas), mejora marginal
- Reduce cost de 19.00 a ~5.00
- Ahorra ~0.08 ms

### Mejora estimada total:

| Escenario | Execution Time | Mejora |
|-----------|----------------|--------|
| **Sin índices** (actual) | 56.563 ms | - |
| **Con índices 1+2** | ~24.0 ms | **57.6% más rápido** |
| **Con todos los índices** | ~18.5 ms | **67.3% más rápido** |

### Por qué esta mejora:

1. **Hash Joins** (29 ms → 12 ms):
   - Index Scans en lugar de Seq Scans
   - Menos datos cargados en memoria para hashes
   - Puede cambiar a Nested Loop con índices en algunos niveles

2. **Seq Scans** (10.5 ms → 2 ms):
   - Index Only Scans evitan acceder a las tablas base
   - Solo leen las columnas necesarias del índice

3. **Filtros tempranos**:
   - Índices parciales filtran desde el inicio (12.5K pedidos en lugar de 50K)
   - Reduce filas procesadas en joins subsecuentes

### Alternativa: Tabla Materializada

Para consultas que se ejecutan frecuentemente (ej: dashboard que se refresca cada hora):

```sql
CREATE MATERIALIZED VIEW mv_top3_productos_mes AS
-- (toda la consulta CTE)
WITH DATA;

CREATE INDEX idx_mv_mes ON mv_top3_productos_mes(mes, rank);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top3_productos_mes;
```

**Beneficio**: Query time de 56 ms → **0.5 ms** (112x más rápido)
**Costo**: Refresh cada hora toma 56 ms, pero solo 1 vez vs cientos de queries

### Consideración final:

Los índices propuestos agregarían ~2.5 MB de espacio total, pero reducirían el tiempo de ejecución en 67%. El trade-off es excelente para consultas frecuentes.