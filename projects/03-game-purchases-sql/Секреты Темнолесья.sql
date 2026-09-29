/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей
 * на покупку внутриигровой валюты «райские лепестки», а также оценить
 * активность игроков при совершении внутриигровых покупок
 *
 * Автор: Петрунин Богдан Сергеевич
 * Дата: 30.04.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS total_users, -- общее количество игроков
	   SUM(payer) AS count_payer_users, -- кол-во платящих игроков
	   ROUND(SUM(payer) * 100.0 / COUNT(id), 1) AS share_users_pct -- доля платящих игроков от общего количества игроков, %
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race AS раса,
	   SUM(u.payer) AS платящие_игроки, -- кол-во платящих игроков в каждой расе
	   COUNT(u.id) AS всего_игроков, -- кол-во всех игроков в каждой расе
	   ROUND(SUM(u.payer) * 100.0 / COUNT(u.id), 1) AS доля_платящих_игроков_pct -- доля платящих игроков в расе, %
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY r.race ASC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS count_amount, -- общее количество покупок
	   ROUND(SUM(amount)::NUMERIC, 2) AS sum_amount, -- суммарная стоимость всех покупок
	   MIN(amount) AS min_amount, -- минимальная стоимость покупки
	   MAX(amount) AS max_amount, -- максимальная стоимость покупки
	   ROUND(AVG(amount)::NUMERIC, 2) AS avg_amount, -- среднее значение
	   ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount))::NUMERIC, 2) AS median_amount, -- медиана
	   ROUND(STDDEV(amount)::NUMERIC, 2) AS std_dev -- стандартное отклонение
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(amount) AS total_orders, -- общее количество покупок
	   COUNT(CASE WHEN amount = 0 THEN 1 END) AS zero_orders, -- количество нулевых покупок
	   ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END) * 100.0 / COUNT(amount), 3) AS percent_zero_orders -- доля нулевых покупок, %
FROM fantasy.events;

-- 2.3: Популярные эпические предметы (покупки с нулевой стоимостью исключены):
WITH totals AS (
	SELECT COUNT(*) AS total_purchases, -- общее количество покупок с ненулевой стоимостью
		   COUNT(DISTINCT id) AS total_buyers -- общее количество игроков, совершивших покупки
	FROM fantasy.events
	WHERE amount > 0
)
SELECT i.game_items AS предмет,
	   COUNT(*) AS абсолютное_количество, -- количество покупок предмета
	   ROUND(COUNT(*) * 100.0 / t.total_purchases, 2) AS доля_покупок_pct, -- доля предмета от всех покупок, %
	   ROUND(COUNT(DISTINCT e.id) * 100.0 / t.total_buyers, 2) AS доля_купивших_игроков_pct -- доля покупателей, купивших предмет хотя бы раз, %
FROM fantasy.events AS e
JOIN fantasy.items AS i ON e.item_code = i.item_code
CROSS JOIN totals AS t
WHERE e.amount > 0
GROUP BY i.item_code, i.game_items, t.total_purchases, t.total_buyers
ORDER BY доля_купивших_игроков_pct DESC, абсолютное_количество DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH race_stats AS (
	SELECT race_id,
		   COUNT(id) AS total_registered_users -- общее количество игроков в расе
	FROM fantasy.users
	GROUP BY race_id
),
buyers AS (
	SELECT u.race_id,
		   COUNT(DISTINCT e.id) AS buyers_count -- количество игроков, которые совершают покупки
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON e.id = u.id
	WHERE e.amount > 0
	GROUP BY u.race_id
),
payer_buyers AS (
	SELECT u.race_id,
		   COUNT(DISTINCT e.id) AS payer_buyers_count -- количество платящих игроков, которые совершают покупки
	FROM fantasy.users AS u
	JOIN fantasy.events AS e ON e.id = u.id
	WHERE u.payer = 1 AND e.amount > 0
	GROUP BY u.race_id
),
users_events AS (
	SELECT u.race_id,
		   ROUND(AVG(user_stats.event_count), 2) AS avg_total_events, -- среднее количество покупок на игрока
		   ROUND(AVG(user_stats.avg_amount)::NUMERIC, 2) AS avg_amount_user, -- средняя стоимость одной покупки на игрока
		   ROUND(AVG(user_stats.total_sum)::NUMERIC, 2) AS avg_total_sum -- средняя суммарная стоимость покупок на игрока
	FROM (
		SELECT id,
			   COUNT(*) AS event_count,
			   SUM(amount) AS total_sum,
			   AVG(amount) AS avg_amount
		FROM fantasy.events
		WHERE amount > 0
		GROUP BY id
	) AS user_stats
	JOIN fantasy.users AS u ON u.id = user_stats.id
	GROUP BY u.race_id
)
SELECT r.race, -- раса
	   rs.total_registered_users AS count_users, -- общее количество игроков
	   b.buyers_count AS count_event_user, -- количество игроков, совершающих покупки
	   ROUND(b.buyers_count * 100.0 / rs.total_registered_users, 1) AS share_event_user_pct, -- доля игроков, совершающих покупки, %
	   ROUND(pb.payer_buyers_count * 100.0 / b.buyers_count, 1) AS share_payer_event_user_pct, -- доля платящих игроков среди покупающих, %
	   ue.avg_total_events AS avg_count_event, -- среднее количество покупок на игрока
	   ue.avg_amount_user, -- средняя стоимость одной покупки на игрока
	   ue.avg_total_sum -- средняя суммарная стоимость покупок на игрока
FROM race_stats AS rs
JOIN buyers AS b ON rs.race_id = b.race_id
JOIN payer_buyers AS pb ON pb.race_id = b.race_id
JOIN users_events AS ue ON ue.race_id = b.race_id
JOIN fantasy.race AS r ON r.race_id = rs.race_id
ORDER BY r.race;
