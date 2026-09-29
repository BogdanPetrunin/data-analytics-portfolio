/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Петрунин Богдан Сергеевич
 * Дата: 18.05.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 ),
category_flat AS (                                                                                      -- Создаем подзапрос с категоризацией объявлений 
    SELECT fi.id,
    	   ad.first_day_exposition,
    	   (ad.first_day_exposition + ad.days_exposition :: int) AS last_day_exposition, -- Дата снятия публикации
    	   ad.days_exposition,
    	   ad.last_price,
    	   CASE 
    	   		WHEN ad.days_exposition BETWEEN 1 AND 30 THEN 'До месяца'
    	   		WHEN ad.days_exposition BETWEEN 31 AND 90 THEN 'До трех месяцев'
    	   		WHEN ad.days_exposition BETWEEN 91 AND 180 THEN 'До полугода'
    	   		WHEN ad.days_exposition >= 180 THEN 'Более полугода'
    	   		ELSE 'non category'
    	   END AS category
    FROM filtered_id AS fi
    JOIN real_estate.advertisement AS ad ON ad.id = fi.id
 ),
full_information AS (                                                                                 --Создаем подзапрос с подробной информацией о квартирах и фильтруем данные за 2015-2018 г
    SELECT *
    FROM category_flat AS cf
    JOIN real_estate.flats AS f ON cf.id = f.id
    JOIN real_estate.city AS c ON c.city_id = f.city_id
    WHERE cf.first_day_exposition >= '2015-01-01' AND cf.last_day_exposition  <= '2018-12-31'
 ),
category_city AS (                                                                                    --Раставляем нужные стобцы и добавляем категории городов 
SELECT first_day_exposition,
	   days_exposition,
	   category,
	   city,
	   CASE 
	   		WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
	   		ELSE 'ЛенОбл'
	   END AS city_category,
	   last_price,
	   total_area,
	   rooms,
	   ceiling_height,
	   floors_total,
	   living_area,
	   floor,
	   open_plan,
	   balcony
FROM full_information
)                                                                                                   -- Считаем интересующие нас параметры и групперуем таблицу по категориям
SELECT city_category,
	   category,
	   ROUND(AVG(last_price :: NUMERIC / total_area) :: numeric, 2) AS avg_price_area_metr,         -- Средняя стоимость кв.метра 
	   ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_total_area,                                      -- Средняя стоимость квартиры  
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_count_room,                     -- Медиана количества комнат 
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_count_balcony,                -- Медиана количества балконов 
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_count_floors,            -- Медиана этажности 
	   COUNT(*) AS total_count,                                                                     -- Количество объявлений
	   ROUND((COUNT(*)::numeric / SUM(COUNT(*)) OVER ()) * 100, 2) AS share_of_total                -- Доля от всех объявдений
FROM category_city 
GROUP BY city_category, category;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
full_info AS (                                                                                             -- Выгружаем все нужные столбцы схемы 
SELECT fi.id,
       c.city,
	   t.type,
	   a.first_day_exposition,
	   (a.first_day_exposition + a.days_exposition :: int) AS last_day_exposition,
	   a.days_exposition,
	   a.last_price,
	   f.total_area,
	   f.rooms,
	   f.ceiling_height,
	   f.floors_total,
	   f.living_area,
	   f.balcony
FROM filtered_id AS fi
JOIN real_estate.advertisement AS a ON a.id = fi.id 
JOIN real_estate.flats AS f ON f.id = a.id 
JOIN real_estate.city AS c ON c.city_id = f.city_id 
JOIN real_estate.type AS t ON t.type_id = f.type_id
),
filter_full_info AS (                                                                                       --Фильтруем данные по временному периоду и типу населенного пункта 
SELECT *
FROM full_info 
WHERE first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
AND type = 'город' 
),
data_month_info AS (                                                                                        -- Выделяем год и месяц из каждого объявления и оставляем только интересующую нас информацию  
SELECT
    EXTRACT(YEAR FROM first_day_exposition) AS year_first_day_exposition,
    EXTRACT(MONTH FROM first_day_exposition) AS month_first_day_exposition,
    EXTRACT(YEAR FROM last_day_exposition) AS year_last_day_exposition,
    EXTRACT(MONTH FROM last_day_exposition) AS month_last_day_exposition,
    last_price,
    total_area,
    city
  FROM filter_full_info 
 ),
 first_exposition_info AS (                                                                               -- Выводим год и месяц публикации и выполняем нужные расчеты
 SELECT                                               -- Год
 	    month_first_day_exposition,                                                 -- Месяц
 	    COUNT(*) AS count_first_exposition,                                         -- Количество публикаций
 	    ROUND(AVG(last_price / total_area)::NUMERIC,2) AS avg_price_metr_first,     -- Средняя стоимость кв.метра 
        ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_first                  -- Средняя стоимость помещения
FROM data_month_info
GROUP BY 
 	     month_first_day_exposition
ORDER BY 
 	     month_first_day_exposition
),
last_exposition_info AS (                                                                                 -- Выводим год и месяц снятия публикации и выполняем нужные расчеты
SELECT                                                   -- Год
 	    month_last_day_exposition,												   -- Месяц
 	    COUNT(*) AS count_last_exposition,								           -- Количество публикаций
 	    ROUND(AVG(last_price / total_area)::numeric, 2) AS avg_price_metr_last,    -- Средняя стоимость кв.метра
        ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_last                  -- Средняя стоимость помещения
FROM data_month_info
GROUP BY 
 	     month_last_day_exposition
ORDER BY 
 	     month_last_day_exposition
)
SELECT *                                                                                                   -- Объединяем таблицы 
FROM first_exposition_info AS fei
FULL JOIN last_exposition_info AS lei ON fei.month_first_day_exposition = lei.month_last_day_exposition;



