/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Петрунин Богдан Сергеевич
 * Дата: 29.04.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS total_users, -- общее количество игроков
	   SUM(payer) AS count_payer_users, -- кол-во платящих игроков
	   ROUND(SUM(payer):: NUMERIC / COUNT(id),2 ) AS share_users -- доля платящих игроков от общего количества пользователей
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH payer_users_race_count AS (
	SELECT DISTINCT r.race,
	       COUNT(*) OVER(PARTITION BY race) AS payer_users -- кол-во платящих игроков в каждой расе
	FROM fantasy.users AS u
	JOIN fantasy.race AS r ON u.race_id = r.race_id
	WHERE payer = 1
),
users_race_count AS (
	SELECT DISTINCT r.race,
	   COUNT(*) OVER(PARTITION BY race) AS total_race_users -- кол-во всех  игроков в каждой расе
	FROM fantasy.users AS u
	JOIN fantasy.race AS r ON u.race_id = r.race_id
)
SELECT pyrc.race AS раса,
	   pyrc.payer_users AS платящие_игроки,
	   urc.total_race_users AS всего_игроков,
	   ROUND((pyrc.payer_users :: numeric / urc.total_race_users),2) AS доля_платящих_игроков 
FROM payer_users_race_count AS pyrc 
JOIN users_race_count AS urc ON urc.race = pyrc.race
ORDER BY раса ASC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS count_amount,
	   SUM(amount) AS sum_amount,
	   MIN(amount) AS min_amount,
	   MAX(amount) AS max_amount,
	   AVG(amount) AS avg_amount,
	   PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
	   STDDEV(amount) AS stend_dev
FROM fantasy.events; 
-- 2.2: Аномальные нулевые покупки:
SELECT (SELECT COUNT(*) FROM fantasy.events WHERE amount = 0) AS zero_amount,
	   (SELECT COUNT(*) FROM fantasy.events WHERE amount = 0) :: numeric / COUNT(*) AS share_zero_amount
FROM fantasy.events; 
-- 2.3: Популярные эпические предметы:
SELECT e.item_code,
	   i.game_items,
	   COUNT(*) AS абсолютное_количество ,
	   COUNT(*) / (SELECT COUNT (*) FROM fantasy.events) :: numeric AS относительное_количество,
	   ROUND(COUNT(DISTINCT e.id) / (SELECT COUNT(DISTINCT id) FROM fantasy.users) :: NUMERIC,2) AS доля_купивших_игроков
FROM fantasy.events AS e
JOIN fantasy.items AS i ON e.item_code = i.item_code 
JOIN fantasy.users AS u ON u.id = e.id
WHERE e.amount <> 0
GROUP BY e.item_code,i.item_code
ORDER BY доля_купивших_игроков DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH race_stats AS (
  SELECT race_id,
         COUNT(id) AS total_registered_users                                                            -- общее количество игроков
  FROM fantasy.users
  GROUP BY race_id
  ),
  paying_users AS (
  SELECT u.race_id, 
  		 COUNT(DISTINCT e.id) AS payer_users_count                                                      -- количество игроков которые совершают покупки 
  FROM fantasy.users AS u
  JOIN fantasy.events AS e ON e.id = u.id
  WHERE e.amount > 0
  GROUP BY u.race_id
  ),
  payer_users AS (
  SELECT u.race_id, 
  		 COUNT(DISTINCT e.id) AS payer_users_count                                                      -- количество платящих игроков которые совершают покупки 
  FROM fantasy.users AS u
  JOIN fantasy.events AS e ON e.id = u.id
  WHERE u.payer = 1 AND e.amount > 0
  GROUP BY u.race_id
  ),
  users_events AS (
  SELECT id,
         COUNT(*) AS total_events,                                                                       -- количество всех заказов по каждому пользователю
         SUM(amount) AS total_sum,                                                                       -- суммарная стоимость всех заказов по каждому пользователю 
         AVG(amount) AS avg_amount       
  FROM fantasy.events  
  WHERE amount > 0
  GROUP BY id
),
avg_users_events AS (
SELECT u.race_id,
	 ROUND(AVG(e.total_events),2) AS avg_total_events,
	 ROUND(AVG(fe.amount)::NUMERIC,2) AS avg_amount_user,
	 ROUND(AVG(e.total_sum) :: numeric,2) AS avg_total_sum
FROM users_events AS e
JOIN fantasy.users AS u ON u.id = e.id
JOIN fantasy.events AS fe ON fe.id = u.id
WHERE fe.amount > 0
GROUP BY u.race_id 
)
SELECT  r.race,                                                                                          -- раса
	    rs.total_registered_users AS count_users,                                                        -- общее_количество_игроков                                               
	    pau.payer_users_count AS count_event_user,                                                       -- количество_игроков_совершающих_покупки
	    ROUND((pau.payer_users_count :: NUMERIC / rs.total_registered_users),2) AS share_event_user,     -- доля_игроков_совершающих_покупки
	    ROUND((pu.payer_users_count :: NUMERIC / pau.payer_users_count),2) AS  share_payer_event_user,   -- доля_платящих_игроков_среди_покупающих,
	    aue.avg_total_events AS avg_count_event ,                                                        -- среднее_количество_покупок_на_игрока,
	    aue.avg_amount_user,                                                                             -- средняя_стоимость_покупки_на_игрока,
	    aue.avg_total_sum                                                                                -- среднняя_сумма_на_игрока
FROM race_stats AS rs
JOIN paying_users AS pau ON rs.race_id = pau.race_id 
JOIN payer_users AS pu ON pu.race_id = pau.race_id 
JOIN avg_users_events AS aue ON aue.race_id =pu.race_id
JOIN fantasy.race AS r ON r.race_id = pu.race_id; 





















