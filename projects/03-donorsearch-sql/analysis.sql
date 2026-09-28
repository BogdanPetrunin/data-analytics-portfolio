/*
 * Активность доноров крови на платформе DonorSearch
 *
 * Цель: оценить регистрацию и активность доноров, динамику донаций,
 * эффект бонусной программы и каналов привлечения, удержание повторных
 * доноров и выполнение запланированных донаций.
 *
 * СУБД: PostgreSQL, схема donorsearch
 *   user_anon_data  — анонимизированные профили доноров
 *   user_anon_bonus — полученные донорами бонусы
 *   donation_anon   — совершённые донации
 *   donation_plan   — запланированные донации
 *
 * Автор: Богдан Петрунин
 */


-- =============================================================================
-- 1. Регионы с наибольшим числом зарегистрированных доноров
-- =============================================================================
SELECT region,
       COUNT(id) AS donors
FROM donorsearch.user_anon_data
GROUP BY region
ORDER BY donors DESC
LIMIT 10;


-- =============================================================================
-- 2. Динамика донаций по месяцам, 2022–2023
-- =============================================================================
SELECT DATE_TRUNC('month', donation_date)::DATE AS month,
       COUNT(*)                                 AS donations
FROM donorsearch.donation_anon
WHERE donation_date >= '2022-01-01'
  AND donation_date <  '2024-01-01'
GROUP BY month
ORDER BY month;


-- =============================================================================
-- 3. Топ-100 самых активных доноров по подтверждённым донациям
-- =============================================================================
SELECT id,
       confirmed_donations
FROM donorsearch.user_anon_data
ORDER BY confirmed_donations DESC
LIMIT 100;


-- =============================================================================
-- 4. Влияние бонусной программы на число донаций
-- =============================================================================
WITH donor_bonus AS (
    SELECT d.id,
           d.confirmed_donations,
           COALESCE(b.user_bonus_count, 0) AS bonus_count
    FROM donorsearch.user_anon_data       AS d
    LEFT JOIN donorsearch.user_anon_bonus AS b ON b.user_id = d.id
)
SELECT CASE WHEN bonus_count > 0 THEN 'получали бонус'
            ELSE 'не получали бонус'
       END                                 AS bonus_group,
       COUNT(id)                           AS donors,
       ROUND(AVG(confirmed_donations), 2)  AS avg_confirmed_donations
FROM donor_bonus
GROUP BY bonus_group;


-- =============================================================================
-- 5. Каналы регистрации (соцсети) и активность доноров
-- =============================================================================
-- Если у донора привязано несколько соцсетей, он попадает в первую по порядку.
SELECT CASE
           WHEN autho_vk     THEN 'ВКонтакте'
           WHEN autho_ok     THEN 'Одноклассники'
           WHEN autho_yandex THEN 'Яндекс'
           WHEN autho_tg     THEN 'Telegram'
           WHEN autho_google THEN 'Google'
           ELSE 'без соцсетей'
       END                                AS channel,
       COUNT(id)                          AS donors,
       ROUND(AVG(confirmed_donations), 2) AS avg_confirmed_donations
FROM donorsearch.user_anon_data
GROUP BY channel
ORDER BY donors DESC;


-- =============================================================================
-- 6. Повторные доноры: когорты по году первой донации
-- =============================================================================
WITH donor_activity AS (
    SELECT user_id,
           COUNT(*)                                                     AS donations,
           MAX(donation_date) - MIN(donation_date)                      AS activity_days,
           (MAX(donation_date) - MIN(donation_date))::NUMERIC
               / (COUNT(*) - 1)                                         AS avg_days_between,
           EXTRACT(YEAR FROM MIN(donation_date))                        AS first_donation_year
    FROM donorsearch.donation_anon
    GROUP BY user_id
    HAVING COUNT(*) > 1          -- только повторные доноры
)
SELECT first_donation_year,
       CASE
           WHEN donations BETWEEN 2 AND 3 THEN '2–3 донации'
           WHEN donations BETWEEN 4 AND 5 THEN '4–5 донаций'
           ELSE '6+ донаций'
       END                              AS frequency_group,
       COUNT(user_id)                   AS donors,
       ROUND(AVG(donations), 2)         AS avg_donations,
       ROUND(AVG(activity_days), 1)     AS avg_activity_days,
       ROUND(AVG(avg_days_between), 1)  AS avg_days_between_donations
FROM donor_activity
GROUP BY first_donation_year, frequency_group
ORDER BY first_donation_year, frequency_group;


-- =============================================================================
-- 7. План vs факт: доля выполненных запланированных донаций
-- =============================================================================
WITH planned AS (
    SELECT DISTINCT user_id, donation_date, donation_type
    FROM donorsearch.donation_plan
),
actual AS (
    SELECT DISTINCT user_id, donation_date
    FROM donorsearch.donation_anon
),
plan_vs_fact AS (
    SELECT p.donation_type,
           (a.user_id IS NOT NULL)::INT AS completed
    FROM planned     AS p
    LEFT JOIN actual AS a
           ON a.user_id       = p.user_id
          AND a.donation_date = p.donation_date
)
SELECT donation_type,
       COUNT(*)                                AS planned_donations,
       SUM(completed)                          AS completed_donations,
       ROUND(AVG(completed) * 100, 2)          AS completion_rate_pct
FROM plan_vs_fact
GROUP BY donation_type
ORDER BY completion_rate_pct DESC;


-- =============================================================================
-- 8. Распределение доноров по полу
-- =============================================================================
SELECT gender,
       COUNT(*)                                            AS donors,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM donorsearch.user_anon_data
GROUP BY gender
ORDER BY donors DESC;
