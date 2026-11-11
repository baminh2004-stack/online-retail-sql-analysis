-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 7. CÂU HỎI BỔ SUNG CHO BAN GIÁM ĐỐC
-- =====================================================================

-- 7.1 Doanh thu Kỳ 2 so với Kỳ 1 thay đổi vì đâu? (cầu doanh thu - revenue bridge)
--   Khách duy trì : có giao dịch ở cả 2 kỳ  -> chênh lệch chi tiêu
--   Khách mới     : chỉ có ở Kỳ 2           -> + doanh thu
--   Khách rời bỏ  : chỉ có ở Kỳ 1           -> - doanh thu
--   Không mã khách: phần doanh thu không gắn được với khách
-- Tổng các cấu phần = DT Kỳ 2 - DT Kỳ 1 (kiểm chứng ở dòng TỔNG).
WITH kh AS (
  SELECT customer_id,
         SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END) AS dt1,
         SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN revenue ELSE 0 END) AS dt2,
         MAX(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN 1 ELSE 0 END)       AS co1,
         MAX(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN 1 ELSE 0 END)       AS co2
  FROM sales_clean
  WHERE ym <= '2011-11'
  GROUP BY customer_id
), nhom AS (
  SELECT CASE WHEN customer_id IS NULL THEN '4 Không mã khách'
              WHEN co1 = 1 AND co2 = 1 THEN '1 Khách duy trì'
              WHEN co2 = 1             THEN '2 Khách mới'
              ELSE                          '3 Khách rời bỏ' END AS nhom,
         customer_id, dt1, dt2
  FROM kh
)
SELECT nhom,
       COUNT(customer_id)        AS so_khach,
       ROUND(SUM(dt1), 0)        AS dt_ky1,
       ROUND(SUM(dt2), 0)        AS dt_ky2,
       ROUND(SUM(dt2 - dt1), 0)  AS chenh_lech
FROM nhom
GROUP BY nhom
UNION ALL
SELECT 'TỔNG', COUNT(customer_id), ROUND(SUM(dt1), 0), ROUND(SUM(dt2), 0), ROUND(SUM(dt2 - dt1), 0)
FROM nhom
ORDER BY nhom;

-- 7.2 Khách quay lại lần 2 sau bao lâu? (giúp chọn thời điểm gửi chương trình nhắc mua)
WITH thu_tu AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, invoice_no) AS lan
  FROM cust_orders
), hai_lan AS (
  SELECT a.customer_id, DATEDIFF(b.order_date, a.order_date) AS so_ngay
  FROM thu_tu a
  JOIN thu_tu b ON b.customer_id = a.customer_id AND a.lan = 1 AND b.lan = 2
), nhom AS (
  SELECT CASE WHEN so_ngay <= 30  THEN 'a) <= 30 ngày'
              WHEN so_ngay <= 60  THEN 'b) 31-60 ngày'
              WHEN so_ngay <= 90  THEN 'c) 61-90 ngày'
              WHEN so_ngay <= 180 THEN 'd) 91-180 ngày'
              ELSE                     'e) > 180 ngày' END AS khoang_cach
  FROM hai_lan
)
SELECT khoang_cach,
       COUNT(*)                                                                    AS so_khach,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                          AS pct,
       ROUND(100.0 * SUM(COUNT(*)) OVER (ORDER BY khoang_cach) / SUM(COUNT(*)) OVER (), 1) AS pct_luy_ke
FROM nhom
GROUP BY khoang_cach
ORDER BY khoang_cach;

-- 7.3 Thời điểm khách đặt hàng (ngày trong tuần, giờ) - để lên lịch email / khuyến mãi
--     DAYOFWEEK: 1 = Chủ nhật ... 7 = Thứ bảy
SELECT DAYOFWEEK(order_date)                                AS thu,
       COUNT(*)                                             AS so_don,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct
FROM cust_orders
GROUP BY DAYOFWEEK(order_date)
ORDER BY thu;

SELECT HOUR(order_date)                                     AS gio,
       COUNT(*)                                             AS so_don,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct
FROM cust_orders
GROUP BY HOUR(order_date)
ORDER BY gio;
