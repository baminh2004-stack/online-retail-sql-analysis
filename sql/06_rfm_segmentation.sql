-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 6. BẢNG ĐẶC TRƯNG KHÁCH HÀNG & PHÂN NHÓM RFM
-- 1 dòng = 1 khách có ít nhất 1 hóa đơn bán.
--   R (Recency)   = số ngày từ lần mua cuối đến 2011-12-10
--   F (Frequency) = số hóa đơn bán
--   M (Monetary)  = doanh thu thuần (đã trừ hủy/trả) của khách
-- Chấm điểm 1-5:
--   R, F theo NGƯỠNG CỐ ĐỊNH (dễ giải thích cho ban giám đốc, không bị lệch vì nhiều khách bằng điểm)
--     R: <=30 ngày=5 | <=90=4 | <=180=3 | <=365=2 | >365=1
--     F: 10+ đơn=5 | 5-9=4 | 3-4=3 | 2=2 | 1=1
--   M theo NTILE(5) (chia đều 5 nhóm theo doanh thu)
-- =====================================================================

DROP TABLE IF EXISTS customer_features;

CREATE TABLE customer_features AS
SELECT s.*,
       -- Gắn nhóm khách theo lưới R x F (6 nhóm, bao phủ mọi tổ hợp R, F)
       CASE
         WHEN s.r_score >= 4 AND s.f_score >= 4 THEN '1 Champions'
         WHEN (s.r_score = 3 AND s.f_score >= 3)
           OR (s.r_score >= 4 AND s.f_score = 3) THEN '2 Loyal'
         WHEN s.r_score >= 4 AND s.f_score <= 2 THEN '3 New / Promising'
         WHEN s.r_score = 3 AND s.f_score <= 2  THEN '4 Need Attention'
         WHEN s.r_score <= 2 AND s.f_score >= 3 THEN '5 At Risk'
         ELSE                                        '6 Lost / Hibernating'
       END AS segment
FROM (
SELECT b.*,
       CASE WHEN b.recency_days <= 30  THEN 5
            WHEN b.recency_days <= 90  THEN 4
            WHEN b.recency_days <= 180 THEN 3
            WHEN b.recency_days <= 365 THEN 2
            ELSE 1 END                                                AS r_score,
       CASE WHEN b.frequency >= 10 THEN 5
            WHEN b.frequency >= 5  THEN 4
            WHEN b.frequency >= 3  THEN 3
            WHEN b.frequency = 2   THEN 2
            ELSE 1 END                                                AS f_score,
       NTILE(5) OVER (ORDER BY b.monetary, b.customer_id)             AS m_score
FROM (
  SELECT o.customer_id,
         cn.country_name                                              AS country,
         DATE(MIN(o.order_date))                                      AS first_purchase,
         DATE(MAX(o.order_date))                                      AS last_purchase,
         DATEDIFF('2011-12-10', MAX(o.order_date))                    AS recency_days,
         DATEDIFF(MAX(o.order_date), MIN(o.order_date))               AS tenure_days,
         COUNT(*)                                                     AS frequency,
         ROUND(SUM(o.order_value), 2)                                 AS gross_sales,
         ROUND(SUM(o.order_value) + COALESCE(MAX(cx.cancel_value), 0), 2) AS monetary,
         ROUND(SUM(o.order_value) / COUNT(*), 2)                      AS avg_order_value,
         ROUND(1.0 * SUM(o.items) / COUNT(*), 1)                      AS avg_items_per_order,
         COALESCE(MAX(cx.n_cancel_invoices), 0)                       AS n_cancel_invoices,
         ROUND(-100.0 * COALESCE(MAX(cx.cancel_value), 0) / SUM(o.order_value), 2) AS cancel_rate_pct,
         CASE WHEN COUNT(*) > 1
              THEN ROUND(1.0 * DATEDIFF(MAX(o.order_date), MIN(o.order_date)) / (COUNT(*) - 1), 1)
         END                                                          AS avg_days_between_orders,
         MAX(pr.n_products)                                           AS n_distinct_products
  FROM cust_orders o
  JOIN customers  cu ON cu.customer_id = o.customer_id
  JOIN countries  cn ON cn.country_id  = cu.country_id
  LEFT JOIN (SELECT customer_id,
                    SUM(revenue)               AS cancel_value,
                    COUNT(DISTINCT invoice_no) AS n_cancel_invoices
             FROM sales_clean
             WHERE is_cancel = 1 AND customer_id IS NOT NULL
             GROUP BY customer_id) cx ON cx.customer_id = o.customer_id
  LEFT JOIN (SELECT customer_id, COUNT(DISTINCT product_key) AS n_products
             FROM sales_clean
             WHERE is_cancel = 0 AND customer_id IS NOT NULL
             GROUP BY customer_id) pr ON pr.customer_id = o.customer_id
  GROUP BY o.customer_id, cn.country_name
) b
) s;

-- 6.1 Kiểm chứng bảng đặc trưng
--   (a) số khách = số khách có hóa đơn bán, (b) mỗi khách 1 dòng,
--   (c) tổng monetary = doanh thu thuần của khách có mã trong sales_clean
--       (trừ phần hủy của khách KHÔNG có hóa đơn bán nào)
SELECT (SELECT COUNT(*) FROM customer_features)                          AS so_dong,
       (SELECT COUNT(DISTINCT customer_id) FROM customer_features)       AS so_khach_khac_nhau,
       (SELECT COUNT(DISTINCT customer_id) FROM cust_orders)             AS khach_co_don_ban,
       ROUND((SELECT SUM(monetary) FROM customer_features), 2)           AS tong_monetary,
       ROUND((SELECT SUM(revenue) FROM sales_clean
              WHERE customer_id IN (SELECT customer_id FROM cust_orders)), 2) AS dt_thuan_khach_co_ma,
       (SELECT COUNT(*) FROM customer_features WHERE segment IS NULL)    AS chua_phan_nhom;

-- 6.2 Khách chỉ có hóa đơn hủy, không có hóa đơn bán nào (không đưa vào RFM)
SELECT COUNT(DISTINCT customer_id) AS khach_chi_co_huy,
       ROUND(SUM(revenue), 2)      AS tien_huy
FROM sales_clean
WHERE customer_id IS NOT NULL
  AND customer_id NOT IN (SELECT customer_id FROM cust_orders);

-- 6.3 Hồ sơ từng nhóm khách
SELECT segment,
       COUNT(*)                                                  AS so_khach,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)        AS pct_khach,
       ROUND(SUM(monetary), 0)                                   AS doanh_thu,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_dt,
       ROUND(AVG(recency_days), 0)                               AS recency_tb,
       ROUND(AVG(frequency), 1)                                  AS so_don_tb,
       ROUND(AVG(monetary), 0)                                   AS dt_tb_moi_khach,
       ROUND(AVG(avg_order_value), 0)                            AS gia_tri_don_tb
FROM customer_features
GROUP BY segment
ORDER BY segment;

-- 6.4 Nhóm "At Risk" đáng giá bao nhiêu? Top khách có giá trị cao đã lâu không quay lại
SELECT customer_id, country, last_purchase, recency_days, frequency, monetary
FROM customer_features
WHERE segment = '5 At Risk'
ORDER BY monetary DESC
LIMIT 10;

-- 6.5 Xuất CSV bảng đặc trưng khách hàng
-- Cách xuất: trong MySQL Workbench, BỎ giới hạn 1000 dòng (ô "Limit to ..." -> Don't Limit),
-- chạy câu lệnh dưới -> nút "Export" trên lưới kết quả -> CSV,
-- đặt tên M1_Project1_NguyenBaHongMinh_customer_features.csv  (kết quả phải có 5.852 dòng)
SELECT customer_id, country, first_purchase, last_purchase, recency_days, tenure_days,
       frequency, gross_sales, monetary, avg_order_value, avg_items_per_order,
       n_distinct_products, n_cancel_invoices, cancel_rate_pct, avg_days_between_orders,
       r_score, f_score, m_score,
       CONCAT(r_score, f_score, m_score) AS rfm_code,
       segment
FROM customer_features
ORDER BY customer_id;
