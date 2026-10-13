/* Проект: дашборд продаж компании «Лёлики и Болики» за I квартал 2024
 * Часть 1. Витрина данных для дашборда в Yandex DataLens
 *
 * Автор: Петрунин Богдан Сергеевич
 *
 * Гранулярность витрины: месяц × регион × категория товара × поставщик.
 * Декабрь 2023 берётся только для расчёта изменения выручки к предыдущему месяцу
 * и в итоговую выборку не попадает.
*/


-- Агрегируем продажи по месяцам в разрезе региона, категории и поставщика:
WITH monthly_data AS (
    SELECT DATE_TRUNC('month', s.date_of_sale)::date AS month,
           r.id AS region_id,
           r.region_name,
           r.type AS region_type,
           c.latitude,
           c.longitude,
           p.category,
           sup.id AS supplier_id,
           sup.supplier_name,
           SUM(s.total_sale_amount) AS revenue,
           COUNT(*) AS sales_count,
           ROUND(AVG(s.total_sale_amount), 2) AS avg_check
    FROM medtube_sales s
    JOIN medtube_products p ON p.id = s.product_id
    JOIN medtube_suppliers sup ON sup.id = s.supplier_id
    JOIN geobi_region_name r ON r.id = s.region_id
    JOIN geobi_region_coord c ON c.id = r.id
    WHERE s.date_of_sale >= '2023-12-01'
      AND s.date_of_sale < '2024-04-01'
    GROUP BY DATE_TRUNC('month', s.date_of_sale)::date,
             r.id,
             r.region_name,
             r.type,
             c.latitude,
             c.longitude,
             p.category,
             sup.id,
             sup.supplier_name
)
-- Присоединяем выручку предыдущего месяца и считаем изменение (для каскадной диаграммы):
SELECT m.month,
       m.region_id,
       m.region_name,
       m.region_type,
       m.latitude,
       m.longitude,
       m.category,
       m.supplier_id,
       m.supplier_name,
       m.revenue,
       m.sales_count,
       m.avg_check,
       COALESCE(prev.revenue, 0) AS revenue_prev_month,
       m.revenue - COALESCE(prev.revenue, 0) AS revenue_delta
FROM monthly_data m
LEFT JOIN monthly_data prev
       ON prev.region_id = m.region_id
      AND prev.category = m.category
      AND prev.supplier_id = m.supplier_id
      AND prev.month = (m.month - INTERVAL '1 month')::date
WHERE m.month >= '2024-01-01'
ORDER BY m.month,
         m.region_name,
         m.category,
         m.supplier_name;
