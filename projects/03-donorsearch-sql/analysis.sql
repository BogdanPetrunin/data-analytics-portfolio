
--1)Регионы с наибольшим количеством зарегистрированных доноров
WITH task_1 AS (
	SELECT region,
	   COUNT(id) AS count_users_region
	FROM donorsearch.user_anon_data 
	GROUP BY region 
	ORDER BY count_users_region DESC
),
-- 2)Динамика общего количества донаций в месяц за 2022 и 2023 годы
task_2 AS (
	SELECT DATE_TRUNC('month',donation_date) :: date AS month_donation,
	   COUNT(*) AS count_donation
	FROM donorsearch.donation_anon
	WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
	GROUP BY month_donation
	ORDER BY month_donation
),
-- 3)Наиболее активные доноры в системе, учитывая только данные о зарегистрированных и подтвержденных донациях
task_3 AS (
	SELECT id,
	   confirmed_donations 
	FROM donorsearch.user_anon_data
	GROUP BY id
	ORDER BY confirmed_donations DESC
	LIMIT 100
),
--4)Как система бонусов влияет на зарегистрированные в системе донации.
task_4 AS (
	SELECT 
	   CASE 
	   		WHEN user_bonus_count > 0 THEN 'Получали бонус' ELSE 'Не получали бонус'
	   END AS using_user_bonus,
	  ROUND(AVG(confirmed_donations),2) AS Среднее_количество_донаций,
	  COUNT(id) AS Количество_доноров
	FROM (SELECT d.id,
	         d.confirmed_donations,
	         COALESCE(b.user_bonus_count,0) AS user_bonus_count
      FROM donorsearch.user_anon_data AS d
      LEFT JOIN donorsearch.user_anon_bonus AS b ON b.user_id = d.id)
	GROUP BY using_user_bonus
),
--5)Вовлечение новых доноров через социальные сети.Сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
task_5 AS (
SELECT 
	   CASE 
	   	WHEN autho_vk THEN 'ВКонтакте'
	   	WHEN autho_ok THEN 'Одноклассники'
	   	WHEN autho_yandex THEN 'Яндекс'
	   	WHEN autho_tg THEN 'Telegram'
	   	WHEN autho_google THEN 'Google'
	   	ELSE 'Нет_соцсетей'
	   END AS Название_соцсетей,
	   COUNT(id) AS Количество_доноров,
	   ROUND(AVG(confirmed_donations),2) AS Среднее_количество_донаций
FROM donorsearch.user_anon_data
GROUP BY Название_соцсетей
ORDER BY Количество_доноров ASC
),
--6)Сравние активности однократных доноров со средней активностью повторных доноров.
donor_activity AS (
  SELECT user_id,
         COUNT(*) AS total_donations,
         (MAX(donation_date) - MIN(donation_date)) AS activity_duration_days,
         (MAX(donation_date) - MIN(donation_date)) / (COUNT(*) - 1) AS avg_days_between_donations,
         EXTRACT(YEAR FROM MIN(donation_date)) AS first_donation_year,
         EXTRACT(YEAR FROM AGE(CURRENT_DATE, MIN(donation_date))) AS years_since_first_donation
  FROM donorsearch.donation_anon
  GROUP BY user_id
  HAVING COUNT(*) > 1
),
task_6 AS (
SELECT first_donation_year,
       CASE 
           WHEN total_donations BETWEEN 2 AND 3 THEN '2-3 донации'
           WHEN total_donations BETWEEN 4 AND 5 THEN '4-5 донаций'
           ELSE '6 и более донаций'
       END AS donation_frequency_group,
       COUNT(user_id) AS donor_count,
       ROUND(AVG(total_donations),2) AS avg_donations_per_donor,
       ROUND(AVG(activity_duration_days),2) AS avg_activity_duration_days,
       AVG(avg_days_between_donations) AS avg_days_between_donations,
       ROUND(AVG(years_since_first_donation),2) AS avg_years_since_first_donation
FROM donor_activity
GROUP BY first_donation_year, donation_frequency_group
ORDER BY first_donation_year, donation_frequency_group
),
--7)Сравние данных о планируемых донациях с фактическими данным
 planned_donations AS (
  SELECT DISTINCT user_id, donation_date, donation_type
  FROM donorsearch.donation_plan
),
actual_donations AS (
  SELECT DISTINCT user_id, donation_date
  FROM donorsearch.donation_anon
),
planned_vs_actual AS (
  SELECT
    pd.user_id,
    pd.donation_date AS planned_date,
    pd.donation_type,
    CASE WHEN ad.user_id IS NOT NULL THEN 1 ELSE 0 END AS completed
  FROM planned_donations pd
  LEFT JOIN actual_donations ad ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
),
task_7 AS (
SELECT
  donation_type,
  COUNT(*) AS total_planned_donations,
  SUM(completed) AS completed_donations,
  ROUND(SUM(completed) * 100.0 / COUNT(*), 2) AS completion_rate
FROM planned_vs_actual
GROUP BY donation_type
),
task_8 AS 
	SELECT COUNT(*),
		   gender
	FROM FROM donorsearch.user_anon_data
)
--Основной запрос
SELECT *
FROM task_8
