sql
-- =====================================================================
-- Proyecto: Ecommerce 2025
-- Vista:    vw_ecomm_global_2025
-- Fuente:   tabla ecommerce_2025 (dataset público de Kaggle, datos de 2025)
-- Granularidad: una fila por fecha + país + categoría
-- Uso:      tabla final que se carga en Power BI
--
-- Decisiones de diseño:
--  * Solo se dejan métricas aditivas (órdenes, cantidad, ventas) para que
--    Power BI las pueda sumar a cualquier nivel sin errores.
--  * avg_order_value es referencial; en Power BI se recalcula como medida:
--    DIVIDE(SUM(total_sales), SUM(total_orders)), para no promediar promedios.
--  * El acumulado usa un frame explícito (ROWS) para que sea determinista.
--    En Power BI el acumulado por país se calcula con DAX.
-- =====================================================================
CREATE OR REPLACE VIEW vw_ecomm_global_2025 AS
WITH data_demand_sales_base AS (
    SELECT
        order_date,
        country,
        category,
        COUNT(order_id)   AS total_orders,
        SUM(quantity)     AS total_quantity,
        SUM(total_amount) AS total_sales
    FROM ecommerce_2025
    GROUP BY order_date, country, category
)
SELECT
    order_date,
    country,
    category,
    total_orders,
    total_quantity,
    total_sales,
    ROUND(total_sales / NULLIF(total_orders, 0), 2) AS avg_order_value,
    SUM(total_sales) OVER (
        PARTITION BY country, category
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS historical_cumulative_revenue
FROM data_demand_sales_base;

--Query adicional: Ventas Totales por categoria

WITH data_ecomerce_2025 AS
		(SELECT 
		country,
	   category,
	   SUM(total_amount) AS total_sales_amount
FROM ecommerce_2025
GROUP BY country, category
),
top_category_ecom_2025 AS (
	SELECT
		country,
	   category,
	   total_sales_amount,
	   DENSE_RANK () OVER(PARTITION BY category ORDER BY total_sales_amount DESC) AS ranking
FROM data_ecomerce_2025
)
SELECT country,
	   category,
	   total_sales_amount,
	   ranking
FROM top_category_ecom_2025
WHERE ranking= 1;
	 
