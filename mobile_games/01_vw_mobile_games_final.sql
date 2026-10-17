sql
-- =====================================================================
-- Proyecto: Mobile Games 2025
-- Vista:    vw_mobile_games_final
-- Fuente:   tabla mobile_game_purchases (dataset público de Kaggle, 2025)
-- Granularidad: dispositivo + género + género de juego + segmento de gasto
--               + rango de edad (aprox. 4 usuarios por grupo)
-- Uso:      tabla principal que se carga en Power BI
--
-- Decisiones de diseño:
--  * Se excluyeron country y payment_method a propósito: con tantas
--    dimensiones cada grupo quedaba con ~1 usuario y el GROUP BY no
--    resumía nada. El análisis por país está en vw_mobile_games_country.
--  * age se convierte a entero (CAST) y se agrupa en rangos con CASE.
--    Los nulos se marcan como 'Unknown' en lugar de caer en '45+'.
--  * age_group_order permite ordenar los rangos en Power BI
--    (Ordenar por columna).
--  * pct_of_genre_amount y rank_in_genre son estables (no dependen del
--    orden de filas empatadas, a diferencia de un acumulado).
-- =====================================================================
CREATE OR REPLACE VIEW vw_mobile_games_final AS
WITH users_clean AS (
    -- Paso 1: limpieza a nivel usuario y creación de grupos de edad
    SELECT
        user_id,
        device,
        gender,
        game_genre,
        spending_segment,
        session_count,
        in_app_purchase_amount,
        CASE
            WHEN age IS NULL THEN 'Unknown'
            WHEN CAST(age AS INT) < 18 THEN '<18'
            WHEN CAST(age AS INT) BETWEEN 18 AND 24 THEN '18-24'
            WHEN CAST(age AS INT) BETWEEN 25 AND 34 THEN '25-34'
            WHEN CAST(age AS INT) BETWEEN 35 AND 44 THEN '35-44'
            ELSE '45+'
        END AS age_group,
        CASE
            WHEN age IS NULL THEN 0
            WHEN CAST(age AS INT) < 18 THEN 1
            WHEN CAST(age AS INT) BETWEEN 18 AND 24 THEN 2
            WHEN CAST(age AS INT) BETWEEN 25 AND 34 THEN 3
            WHEN CAST(age AS INT) BETWEEN 35 AND 44 THEN 4
            ELSE 5
        END AS age_group_order
    FROM mobile_game_purchases
),
data_mobile_games_2025 AS (
    -- Paso 2: agregación por dimensiones
    SELECT
        device,
        gender,
        game_genre,
        spending_segment,
        age_group,
        age_group_order,
        COUNT(DISTINCT user_id)     AS total_users,
        SUM(session_count)          AS total_sessions,
        SUM(in_app_purchase_amount) AS total_amount
    FROM users_clean
    GROUP BY device, gender, game_genre, spending_segment, age_group, age_group_order
)
SELECT
    device,
    gender,
    game_genre,
    spending_segment,
    age_group,
    age_group_order,
    total_users,
    total_sessions,
    total_amount,
    ROUND(100.0 * total_amount
          / NULLIF(SUM(total_amount) OVER (PARTITION BY game_genre), 0), 2) AS pct_of_genre_amount,
    RANK() OVER (PARTITION BY game_genre ORDER BY total_amount DESC)       AS rank_in_genre
FROM data_mobile_games_2025;

sql
-- =====================================================================
-- Proyecto: Mobile Games 2025
-- Vista:    vw_mobile_games_country
-- Fuente:   tabla mobile_game_purchases
-- Granularidad: una fila por país + género
-- Uso:      análisis geográfico en Power BI
--
-- Decisiones de diseño:
--  * Vista separada de vw_mobile_games_final porque country tiene muchos
--    valores distintos y fragmentaba los grupos de la vista principal.
--  * Se conecta con la vista principal en Power BI mediante dim_gender.
--  * total_users no debe sumarse entre ambas vistas: cuentan a los
--    mismos usuarios.
-- =====================================================================
CREATE OR REPLACE VIEW vw_mobile_games_country AS
SELECT
    country,
    gender,
    COUNT(DISTINCT user_id)     AS total_users,
    SUM(session_count)          AS total_sessions,
    SUM(in_app_purchase_amount) AS total_amount
FROM mobile_game_purchases
GROUP BY country, gender;

sql
-- =====================================================================
-- Proyecto: Mobile Games 2025
-- Vista:    dim_gender
-- Fuente:   tabla mobile_game_purchases
-- Granularidad: una fila por valor único de género
-- Uso:      dimensión puente en Power BI. Se relaciona (uno a muchos) con
--           la columna gender de vw_mobile_games_final y
--           vw_mobile_games_country, para que un mismo filtro de género
--           afecte a ambas vistas sin crear una relación muchos a muchos.
-- =====================================================================
CREATE OR REPLACE VIEW dim_gender AS
SELECT DISTINCT gender
FROM mobile_game_purchases;
