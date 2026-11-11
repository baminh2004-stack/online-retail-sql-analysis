-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 8. BẢNG SỐ LIỆU CHÍNH DÙNG TRÊN SLIDE
-- Một truy vấn duy nhất trả về các con số được trích dẫn trong slide,
-- để giảng viên / người xem kiểm tra nhanh.
-- =====================================================================
SELECT 'DT thuần toàn kỳ (12/2009-09/12/2011), £'   AS chi_so, ROUND(SUM(revenue), 0) AS gia_tri FROM sales_clean
UNION ALL
SELECT 'DT thuần Kỳ 1 (12/2009-11/2010), £', ROUND(SUM(revenue), 0) FROM sales_clean WHERE ym BETWEEN '2009-12' AND '2010-11'
UNION ALL
SELECT 'DT thuần Kỳ 2 (12/2010-11/2011), £', ROUND(SUM(revenue), 0) FROM sales_clean WHERE ym BETWEEN '2010-12' AND '2011-11'
UNION ALL
SELECT 'Tỷ trọng DT tháng 9-11 trong Kỳ 2, %',
       ROUND(100.0 * SUM(CASE WHEN MONTH(invoice_date) IN (9,10,11) THEN revenue ELSE 0 END) / SUM(revenue), 1)
FROM sales_clean WHERE ym BETWEEN '2010-12' AND '2011-11'
UNION ALL
SELECT 'Tỷ trọng DT Anh, %',
       ROUND(100.0 * SUM(CASE WHEN country_name = 'United Kingdom' THEN revenue ELSE 0 END) / SUM(revenue), 1)
FROM sales_clean
UNION ALL
SELECT 'Tỷ lệ hủy/trả trên DT gộp, %',
       ROUND(-100.0 * SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END)
                    / SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 2)
FROM sales_clean
UNION ALL
SELECT 'Tỷ trọng DT không gắn mã khách, %',
       ROUND(100.0 * SUM(CASE WHEN customer_id IS NULL THEN revenue ELSE 0 END) / SUM(revenue), 1)
FROM sales_clean
UNION ALL
SELECT 'Số khách có mua hàng', COUNT(*) FROM customer_features
UNION ALL
SELECT 'Tỷ lệ khách mua từ 2 lần, %', ROUND(100.0 * SUM(frequency >= 2) / COUNT(*), 1) FROM customer_features
UNION ALL
SELECT 'Champions: % doanh thu khách có mã',
       ROUND(100.0 * SUM(CASE WHEN segment = '1 Champions' THEN monetary ELSE 0 END) / SUM(monetary), 1)
FROM customer_features
UNION ALL
SELECT 'At Risk: doanh thu lịch sử, £', ROUND(SUM(monetary), 0) FROM customer_features WHERE segment = '5 At Risk';
