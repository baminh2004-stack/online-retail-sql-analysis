-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 5. PHÂN TÍCH KHÁCH HÀNG
-- Chỉ dùng các dòng CÓ customer_id (chiếm 86% doanh thu thuần).
-- "Lần mua" = 1 hóa đơn bán (không tính hóa đơn hủy).
-- Ngày tham chiếu để tính Recency: 2011-12-10 (ngày sau giao dịch cuối cùng).
-- =====================================================================

-- 5.1 Bảng tạm: mỗi hóa đơn bán của khách (1 dòng = 1 lần mua)
DROP TABLE IF EXISTS cust_orders;

CREATE TABLE cust_orders AS
SELECT customer_id,
       invoice_no,
       MIN(invoice_date)                                  AS order_date,
       MIN(ym)                                            AS ym,
       YEAR(MIN(invoice_date)) * 12 + MONTH(MIN(invoice_date)) AS month_idx,
       SUM(revenue)                                       AS order_value,
       SUM(quantity)                                      AS items
FROM sales_clean
WHERE customer_id IS NOT NULL AND is_cancel = 0
GROUP BY customer_id, invoice_no;

CREATE INDEX idx_co_cust ON cust_orders (customer_id);

-- 5.2 Khách có quay lại không? Phân bố số lần mua
SELECT CASE WHEN n = 1 THEN '1 lần'
            WHEN n = 2 THEN '2 lần'
            WHEN n BETWEEN 3 AND 4 THEN '3-4 lần'
            WHEN n BETWEEN 5 AND 9 THEN '5-9 lần'
            ELSE '10+ lần' END                                  AS so_lan_mua,
       COUNT(*)                                                 AS so_khach,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)       AS pct_khach,
       ROUND(SUM(dt), 0)                                        AS dt_ban,
       ROUND(100.0 * SUM(dt) / SUM(SUM(dt)) OVER (), 1)         AS pct_dt
FROM (SELECT customer_id, COUNT(*) AS n, SUM(order_value) AS dt
      FROM cust_orders GROUP BY customer_id) t
GROUP BY CASE WHEN n = 1 THEN '1 lần'
              WHEN n = 2 THEN '2 lần'
              WHEN n BETWEEN 3 AND 4 THEN '3-4 lần'
              WHEN n BETWEEN 5 AND 9 THEN '5-9 lần'
              ELSE '10+ lần' END
ORDER BY MIN(n);

-- 5.3 Tỷ lệ mua lặp lại tổng thể
SELECT COUNT(*)                                      AS so_khach,
       SUM(n >= 2)                                   AS khach_mua_lai,
       ROUND(100.0 * SUM(n >= 2) / COUNT(*), 1)      AS pct_mua_lai
FROM (SELECT customer_id, COUNT(*) AS n FROM cust_orders GROUP BY customer_id) t;

-- 5.4 Giữ chân giữa 2 kỳ: khách mua ở Kỳ 1 có quay lại Kỳ 2 không?
--     và Kỳ 2 phụ thuộc bao nhiêu vào khách mới?
WITH k AS (
  SELECT customer_id,
         MAX(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN 1 ELSE 0 END) AS mua_ky1,
         MAX(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN 1 ELSE 0 END) AS mua_ky2,
         SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN order_value ELSE 0 END) AS dt_ky2
  FROM cust_orders
  GROUP BY customer_id
)
SELECT SUM(mua_ky1)                                               AS khach_ky1,
       SUM(mua_ky1 = 1 AND mua_ky2 = 1)                           AS khach_ky1_quay_lai_ky2,
       ROUND(100.0 * SUM(mua_ky1 = 1 AND mua_ky2 = 1) / SUM(mua_ky1), 1) AS pct_giu_chan,
       SUM(mua_ky2)                                               AS khach_ky2,
       SUM(mua_ky1 = 0 AND mua_ky2 = 1)                           AS khach_moi_ky2,
       ROUND(100.0 * SUM(CASE WHEN mua_ky1 = 1 AND mua_ky2 = 1 THEN dt_ky2 ELSE 0 END)
                   / SUM(dt_ky2), 1)                              AS pct_dt_ky2_tu_khach_cu
FROM k;

-- 5.5 Khách mới theo tháng (tháng mua đầu tiên)
SELECT first_ym                AS thang,
       COUNT(*)                AS khach_moi
FROM (SELECT customer_id, MIN(ym) AS first_ym FROM cust_orders GROUP BY customer_id) f
GROUP BY first_ym
ORDER BY first_ym;

-- 5.5b Khách mới cùng giai đoạn 7-11 của 2 năm.
-- Vì dữ liệu bắt đầu 12/2009, khách "mới" đầu 2010 có thể là khách cũ chưa quan sát được.
-- So sánh tháng 7-11 (đã có >= 7 tháng lịch sử) giúp giảm sai lệch này.
SELECT SUBSTRING(first_ym, 1, 4) AS nam,
       COUNT(*)                  AS khach_moi_thang_7_11
FROM (SELECT customer_id, MIN(ym) AS first_ym FROM cust_orders GROUP BY customer_id) f
WHERE SUBSTRING(first_ym, 6, 2) IN ('07','08','09','10','11')
GROUP BY SUBSTRING(first_ym, 1, 4)
ORDER BY nam;

-- 5.6 Cohort retention: trong số khách mua lần đầu ở tháng X,
--     bao nhiêu % còn mua ở tháng X+1, X+3, X+6, X+12
WITH f AS (
  SELECT customer_id, MIN(month_idx) AS cohort_idx, MIN(ym) AS cohort
  FROM cust_orders GROUP BY customer_id
), act AS (
  SELECT DISTINCT o.customer_id, f.cohort, f.cohort_idx, o.month_idx - f.cohort_idx AS m
  FROM cust_orders o JOIN f ON f.customer_id = o.customer_id
)
-- Ô nào chưa đủ thời gian theo dõi (vượt quá 11/2011) để NULL thay vì 0.
-- 2011*12+11 = chỉ số tháng của 11/2011 (tháng đủ cuối cùng).
SELECT cohort,
       SUM(m = 0)                                                                         AS co_so,
       CASE WHEN MIN(cohort_idx) + 1  <= 2011*12+11 THEN ROUND(100.0 * SUM(m = 1)  / SUM(m = 0), 1) END AS t1,
       CASE WHEN MIN(cohort_idx) + 2  <= 2011*12+11 THEN ROUND(100.0 * SUM(m = 2)  / SUM(m = 0), 1) END AS t2,
       CASE WHEN MIN(cohort_idx) + 3  <= 2011*12+11 THEN ROUND(100.0 * SUM(m = 3)  / SUM(m = 0), 1) END AS t3,
       CASE WHEN MIN(cohort_idx) + 6  <= 2011*12+11 THEN ROUND(100.0 * SUM(m = 6)  / SUM(m = 0), 1) END AS t6,
       CASE WHEN MIN(cohort_idx) + 12 <= 2011*12+11 THEN ROUND(100.0 * SUM(m = 12) / SUM(m = 0), 1) END AS t12
FROM act
WHERE cohort <= '2011-11'
GROUP BY cohort
ORDER BY cohort;

-- 5.7 Retention trung bình có trọng số: so sánh nhóm khách đến trong mùa cao điểm
--     (9-11) với khách đến ngoài mùa (chỉ các cohort có đủ 12 tháng theo dõi)
WITH f AS (
  SELECT customer_id, MIN(month_idx) AS cohort_idx, MIN(ym) AS cohort
  FROM cust_orders GROUP BY customer_id
), act AS (
  SELECT DISTINCT o.customer_id, f.cohort, o.month_idx - f.cohort_idx AS m
  FROM cust_orders o JOIN f ON f.customer_id = o.customer_id
)
SELECT CASE WHEN cohort = '2009-12'                  THEN 'a) 12/2009 (khách cũ dồn lại)'
            WHEN SUBSTRING(cohort, 6, 2) IN ('09','10','11') THEN 'b) Đến mùa cao điểm 9-11'
            ELSE 'c) Đến ngoài mùa' END              AS nhom_cohort,
       SUM(m = 0)                                    AS so_khach,
       ROUND(100.0 * SUM(m = 1)  / SUM(m = 0), 1)    AS t1,
       ROUND(100.0 * SUM(m = 3)  / SUM(m = 0), 1)    AS t3,
       ROUND(100.0 * SUM(m = 12) / SUM(m = 0), 1)    AS t12
FROM act
WHERE cohort <= '2010-11'
GROUP BY CASE WHEN cohort = '2009-12'                  THEN 'a) 12/2009 (khách cũ dồn lại)'
              WHEN SUBSTRING(cohort, 6, 2) IN ('09','10','11') THEN 'b) Đến mùa cao điểm 9-11'
              ELSE 'c) Đến ngoài mùa' END
ORDER BY nhom_cohort;
