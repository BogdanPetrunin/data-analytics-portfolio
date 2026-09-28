/*
 * Анализ платящей аудитории мобильной игры «Секреты Тёмнолесья»
 *
 * Цель: понять, как характеристики игроков и их персонажей влияют на покупку
 * внутриигровой валюты «райские лепестки», и оценить активность игроков
 * во внутриигровых покупках.
 *
 * СУБД: PostgreSQL, схема fantasy
 *   users  — игроки (id, payer, race_id, ...)
 *   race   — справочник рас персонажей
 *   events — внутриигровые покупки (id игрока, item_code, amount)
 *   items  — справочник эпических предметов
 *
 * Автор: Богдан Петрунин
 */


-- =============================================================================
-- 1. Доля платящих игроков
-- =============================================================================

-- 1.1. Доля платящих по всей игре
SELECT COUNT(id)                                  AS total_users,
       SUM(payer)                                 AS payer_users,
       ROUND(SUM(payer)::NUMERIC / COUNT(id), 3)  AS payer_share
FROM fantasy.users;
-- Итог: ~17,7% игроков платящие.


-- 1.2. Доля платящих в разрезе расы персонажа
SELECT r.race,
       SUM(u.payer)                                 AS payer_users,
       COUNT(u.id)                                  AS total_users,
       ROUND(SUM(u.payer)::NUMERIC / COUNT(u.id), 3) AS payer_share
FROM fantasy.users AS u
JOIN fantasy.race  AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY payer_share DESC;
-- Итог: разброс небольшой — от ~17% (Angel, Elf) до ~19% (Demon).
-- Раса почти не влияет на то, станет ли игрок платящим.


-- =============================================================================
-- 2. Внутриигровые покупки
-- =============================================================================

-- 2.1. Статистика стоимости покупок
SELECT COUNT(*)                                            AS purchases,
       SUM(amount)                                         AS total_amount,
       MIN(amount)                                         AS min_amount,
       MAX(amount)                                         AS max_amount,
       ROUND(AVG(amount)::NUMERIC, 2)                      AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
       ROUND(STDDEV(amount)::NUMERIC, 2)                   AS stddev_amount
FROM fantasy.events;
-- Итог: 1 307 678 покупок; среднее ≈ 525.69, медиана ≈ 74.86,
-- стандартное отклонение ≈ 2 517. Распределение сильно скошено вправо:
-- большинство покупок дешёвые, среднее тянут вверх редкие крупные траты.


-- 2.2. Покупки с нулевой стоимостью (аномалия)
SELECT COUNT(*) FILTER (WHERE amount = 0)              AS zero_purchases,
       ROUND(AVG((amount = 0)::INT)::NUMERIC * 100, 2) AS zero_share_pct
FROM fantasy.events;
-- Итог: 907 покупок (~0,69%) с нулевой стоимостью. Это может быть баг,
-- тестовые транзакции или бесплатные начисления — стоит уточнить у команды игры.
-- В дальнейших расчётах такие покупки исключаю.


-- 2.3. Популярность эпических предметов
WITH paid_events AS (
    SELECT *
    FROM fantasy.events
    WHERE amount > 0
)
SELECT i.game_items,
       COUNT(*)                                                                   AS purchases,
       ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM paid_events), 4)           AS purchases_share,
       ROUND(COUNT(DISTINCT e.id)::NUMERIC /
             (SELECT COUNT(id) FROM fantasy.users), 2)                             AS buyers_share
FROM paid_events   AS e
JOIN fantasy.items AS i ON e.item_code = i.item_code
GROUP BY i.game_items
ORDER BY buyers_share DESC;
-- Итог: реально популярны только два предмета — Book of Legends и
-- Bag of Holding (их покупали ~55% и ~54% игроков). Остальные эпические
-- предметы берут крайне редко.


-- =============================================================================
-- 3. Ad hoc: зависит ли покупательская активность от расы персонажа
-- =============================================================================

WITH race_users AS (          -- все игроки по расам
    SELECT race_id,
           COUNT(id) AS total_users
    FROM fantasy.users
    GROUP BY race_id
),
user_purchases AS (           -- метрики каждого покупателя
    SELECT id,
           COUNT(*)    AS purchases,
           SUM(amount) AS total_amount,
           AVG(amount) AS avg_amount
    FROM fantasy.events
    WHERE amount > 0
    GROUP BY id
),
race_buyers AS (              -- покупатели по расам
    SELECT u.race_id,
           COUNT(*)                                      AS buyers,
           SUM(u.payer)                                  AS payer_buyers,
           ROUND(AVG(p.purchases), 2)                    AS avg_purchases_per_buyer,
           ROUND(AVG(p.avg_amount)::NUMERIC, 2)          AS avg_purchase_amount,
           ROUND(AVG(p.total_amount)::NUMERIC, 2)        AS avg_total_amount_per_buyer
    FROM user_purchases AS p
    JOIN fantasy.users  AS u ON u.id = p.id
    GROUP BY u.race_id
)
SELECT r.race,
       ru.total_users,
       rb.buyers,
       ROUND(rb.buyers::NUMERIC / ru.total_users, 3)  AS buyers_share,
       ROUND(rb.payer_buyers::NUMERIC / rb.buyers, 3) AS payer_share_among_buyers,
       rb.avg_purchases_per_buyer,
       rb.avg_purchase_amount,
       rb.avg_total_amount_per_buyer
FROM race_users   AS ru
JOIN race_buyers  AS rb ON rb.race_id = ru.race_id
JOIN fantasy.race AS r  ON r.race_id  = ru.race_id
ORDER BY rb.avg_purchases_per_buyer DESC;
-- Итог: доля покупателей и доля платящих среди них почти одинаковы для всех рас.
-- Различия есть в числе покупок на одного игрока — раса влияет на активность
-- слабо, но заметно.
