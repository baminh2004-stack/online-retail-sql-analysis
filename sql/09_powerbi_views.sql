-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- 5 view làm nguồn dữ liệu cho dashboard Power BI (mô hình hình sao).
-- Chạy SAU khi đã chạy 00 -> 08 (cần các bảng sales_clean, customer_features, line_audit).

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

DROP VIEW IF EXISTS bi_fact_sales;
DROP VIEW IF EXISTS bi_dim_product;
DROP VIEW IF EXISTS bi_dim_country;
DROP VIEW IF EXISTS bi_dim_customer;
DROP VIEW IF EXISTS bi_audit;

-- Bảng sự kiện: 1 dòng = 1 dòng hóa đơn đã làm sạch
-- TRIM: Power BI bỏ qua dấu cách cuối khi so khóa ('47503J' và '47503J ' bị coi là trùng)
CREATE VIEW bi_fact_sales AS
SELECT line_id, invoice_no, DATE(invoice_date) AS order_date, invoice_date,
       customer_id, country_name, TRIM(product_key) AS product_key,
       quantity, unit_price, revenue, is_cancel
FROM sales_clean;

-- Dim sản phẩm: 1 dòng = 1 mã hàng
CREATE VIEW bi_dim_product AS
SELECT TRIM(product_key) AS product_key, MAX(description) AS description
FROM sales_clean
GROUP BY TRIM(product_key);

-- Dim quốc gia
CREATE VIEW bi_dim_country AS
SELECT DISTINCT country_name,
       CASE WHEN country_name = 'United Kingdom' THEN 'Anh' ELSE 'Quốc tế' END AS market
FROM sales_clean;

-- Dim khách hàng: mọi khách có mã trong dữ liệu sạch + đặc trưng RFM
-- (23 khách chỉ có hóa đơn hủy được xếp nhóm riêng)
CREATE VIEW bi_dim_customer AS
SELECT c.customer_id, f.country, f.first_purchase, f.last_purchase,
       f.recency_days, f.frequency, f.monetary, f.avg_order_value,
       f.r_score, f.f_score, f.m_score,
       COALESCE(f.segment, '7 Chỉ có hóa đơn hủy') AS segment
FROM (SELECT DISTINCT customer_id FROM sales_clean WHERE customer_id IS NOT NULL) c
LEFT JOIN customer_features f ON f.customer_id = c.customer_id;

-- Kết quả làm sạch (trang Chất lượng dữ liệu)
CREATE VIEW bi_audit AS
SELECT ly_do, COUNT(*) AS so_dong, SUM(revenue) AS tong_tien
FROM line_audit
GROUP BY ly_do;

-- Kiểm tra số dòng
SELECT 'bi_fact_sales'   AS view_name, COUNT(*) AS so_dong FROM bi_fact_sales
UNION ALL SELECT 'bi_dim_product',  COUNT(*) FROM bi_dim_product
UNION ALL SELECT 'bi_dim_country',  COUNT(*) FROM bi_dim_country
UNION ALL SELECT 'bi_dim_customer', COUNT(*) FROM bi_dim_customer
UNION ALL SELECT 'bi_audit',        COUNT(*) FROM bi_audit;
