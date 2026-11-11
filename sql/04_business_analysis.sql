-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 4. PHÂN TÍCH KINH DOANH
-- Chỉ số chính: DOANH THU THUẦN (£) = bán - hủy/trả, trên bảng sales_clean.
-- "Đơn hàng" = hóa đơn bán (không tính hóa đơn hủy).
-- So sánh năm dùng 2 kỳ 12 THÁNG ĐỦ để công bằng:
--   Kỳ 1 = 12/2009 - 11/2010,  Kỳ 2 = 12/2010 - 11/2011
--   (bỏ 12/2011 vì chỉ có dữ liệu đến ngày 09/12)
-- =====================================================================

-- 4.1 Doanh thu theo tháng
SELECT ym                                                        AS thang,
       ROUND(SUM(revenue), 0)                                    AS dt_thuan,
       COUNT(DISTINCT CASE WHEN is_cancel = 0 THEN invoice_no END) AS so_don,
       COUNT(DISTINCT customer_id)                               AS so_khach,
       ROUND(SUM(CASE WHEN is_cancel = 0 THEN revenue END)
             / COUNT(DISTINCT CASE WHEN is_cancel = 0 THEN invoice_no END), 1) AS gia_tri_don_tb,
       CASE WHEN ym = '2011-12' THEN 'Chưa đủ tháng (1-9/12)' ELSE '' END AS ghi_chu
FROM sales_clean
GROUP BY ym
ORDER BY ym;

-- 4.2 So sánh 2 kỳ 12 tháng
WITH ky AS (
  SELECT s.*,
         CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN 'Ky1 12/09-11/10'
              WHEN ym BETWEEN '2010-12' AND '2011-11' THEN 'Ky2 12/10-11/11' END AS ky
  FROM sales_clean s
)
SELECT ky,
       ROUND(SUM(revenue), 0)                                                   AS dt_thuan,
       COUNT(DISTINCT CASE WHEN is_cancel = 0 THEN invoice_no END)              AS so_don,
       COUNT(DISTINCT customer_id)                                              AS so_khach_co_ma,
       ROUND(SUM(CASE WHEN is_cancel = 0 THEN revenue END)
             / COUNT(DISTINCT CASE WHEN is_cancel = 0 THEN invoice_no END), 1)  AS gia_tri_don_tb,
       ROUND(-100.0 * SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END)
                    / SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 2)  AS pct_huy
FROM ky
WHERE ky IS NOT NULL
GROUP BY ky
ORDER BY ky;

-- 4.3 Cùng tháng, khác năm: 2010 vs 2011 (tháng 1-11)
SELECT MONTH(invoice_date)                                                      AS thang,
       ROUND(SUM(CASE WHEN YEAR(invoice_date) = 2010 THEN revenue ELSE 0 END), 0) AS dt_2010,
       ROUND(SUM(CASE WHEN YEAR(invoice_date) = 2011 THEN revenue ELSE 0 END), 0) AS dt_2011,
       ROUND(100.0 * (SUM(CASE WHEN YEAR(invoice_date) = 2011 THEN revenue ELSE 0 END)
                    - SUM(CASE WHEN YEAR(invoice_date) = 2010 THEN revenue ELSE 0 END))
                   / SUM(CASE WHEN YEAR(invoice_date) = 2010 THEN revenue ELSE 0 END), 1) AS tang_truong_pct
FROM sales_clean
WHERE YEAR(invoice_date) IN (2010, 2011) AND MONTH(invoice_date) <= 11
GROUP BY MONTH(invoice_date)
ORDER BY thang;

-- 4.4 Tính mùa vụ: tỷ trọng doanh thu theo quý trong Kỳ 2
SELECT CASE WHEN MONTH(invoice_date) IN (12,1,2) THEN 'Q-Đông (12-2)'
            WHEN MONTH(invoice_date) IN (3,4,5)  THEN 'Q-Xuân (3-5)'
            WHEN MONTH(invoice_date) IN (6,7,8)  THEN 'Q-Hè (6-8)'
            ELSE 'Q-Thu (9-11)' END                              AS mua,
       ROUND(SUM(revenue), 0)                                     AS dt_thuan,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct
FROM sales_clean
WHERE ym BETWEEN '2010-12' AND '2011-11'
GROUP BY CASE WHEN MONTH(invoice_date) IN (12,1,2) THEN 'Q-Đông (12-2)'
              WHEN MONTH(invoice_date) IN (3,4,5)  THEN 'Q-Xuân (3-5)'
              WHEN MONTH(invoice_date) IN (6,7,8)  THEN 'Q-Hè (6-8)'
              ELSE 'Q-Thu (9-11)' END
ORDER BY pct DESC;

-- 4.5 Doanh thu theo thị trường (toàn bộ 2 năm)
SELECT country_name,
       ROUND(SUM(revenue), 0)                                       AS dt_thuan,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2)   AS pct_dt,
       COUNT(DISTINCT customer_id)                                  AS so_khach,
       ROUND(SUM(revenue) / COUNT(DISTINCT customer_id), 0)         AS dt_moi_khach
FROM sales_clean
GROUP BY country_name
ORDER BY dt_thuan DESC
LIMIT 12;

-- 4.6 Anh vs Quốc tế: quy mô và tăng trưởng giữa 2 kỳ
SELECT CASE WHEN country_name = 'United Kingdom' THEN 'Anh' ELSE 'Quốc tế' END AS thi_truong,
       ROUND(SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END), 0) AS dt_ky1,
       ROUND(SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN revenue ELSE 0 END), 0) AS dt_ky2,
       ROUND(100.0 * (SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN revenue ELSE 0 END)
                    - SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END))
                   / SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END), 1) AS tang_truong_pct,
       ROUND(SUM(revenue) / COUNT(DISTINCT CASE WHEN is_cancel = 0 THEN invoice_no END), 0) AS gia_tri_don_tb
FROM sales_clean
GROUP BY CASE WHEN country_name = 'United Kingdom' THEN 'Anh' ELSE 'Quốc tế' END;

-- 4.7 Tăng trưởng các thị trường quốc tế lớn (Kỳ 1 -> Kỳ 2)
SELECT country_name,
       ROUND(SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END), 0) AS dt_ky1,
       ROUND(SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN revenue ELSE 0 END), 0) AS dt_ky2,
       ROUND(100.0 * (SUM(CASE WHEN ym BETWEEN '2010-12' AND '2011-11' THEN revenue ELSE 0 END)
                    - SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END))
                   / SUM(CASE WHEN ym BETWEEN '2009-12' AND '2010-11' THEN revenue ELSE 0 END), 1) AS tang_truong_pct
FROM sales_clean
WHERE country_name <> 'United Kingdom'
GROUP BY country_name
HAVING SUM(revenue) > 150000
ORDER BY dt_ky2 DESC;

-- 4.8 Top 10 sản phẩm theo doanh thu thuần
SELECT product_key,
       MAX(description)                                            AS mo_ta,
       ROUND(SUM(revenue), 0)                                      AS dt_thuan,
       SUM(quantity)                                               AS sl_thuan,
       COUNT(DISTINCT customer_id)                                 AS so_khach_mua,
       ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM sales_clean), 2) AS pct_dt
FROM sales_clean
GROUP BY product_key
ORDER BY dt_thuan DESC
LIMIT 10;

-- 4.9 Mức độ tập trung sản phẩm (Pareto): bao nhiêu % mã hàng tạo ra 80% doanh thu?
WITH sp AS (
  SELECT product_key, SUM(revenue) AS dt
  FROM sales_clean
  GROUP BY product_key
  HAVING SUM(revenue) > 0
), luy_ke AS (
  SELECT product_key, dt,
         SUM(dt) OVER (ORDER BY dt DESC, product_key) / SUM(dt) OVER () AS pct_luy_ke,
         ROW_NUMBER() OVER (ORDER BY dt DESC, product_key)             AS hang,
         COUNT(*) OVER ()                                              AS tong_sp
  FROM sp
)
SELECT MAX(tong_sp)                                       AS tong_so_ma_hang,
       MIN(CASE WHEN pct_luy_ke >= 0.8 THEN hang END)     AS so_ma_tao_80pct_dt,
       ROUND(100.0 * MIN(CASE WHEN pct_luy_ke >= 0.8 THEN hang END) / MAX(tong_sp), 1) AS pct_ma_hang,
       ROUND(100.0 * SUM(CASE WHEN hang <= 10 THEN dt ELSE 0 END) / SUM(dt), 1)        AS pct_dt_top10
FROM luy_ke;

-- 4.10 Hủy / trả hàng: những sản phẩm bị trả nhiều tiền nhất (đáng lo ngại?)
SELECT product_key,
       MAX(description)                                                AS mo_ta,
       ROUND(-SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END), 0) AS tien_bi_huy,
       ROUND(SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 0)  AS tien_ban,
       ROUND(-100.0 * SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END)
                    / SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 1) AS pct_huy
FROM sales_clean
GROUP BY product_key
HAVING SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END) > 20000
ORDER BY pct_huy DESC
LIMIT 10;

-- 4.11 Mức độ phụ thuộc vào khách lớn: top 1% / 10% khách (có mã) chiếm bao nhiêu doanh thu?
WITH kh AS (
  SELECT customer_id, SUM(revenue) AS dt
  FROM sales_clean
  WHERE customer_id IS NOT NULL
  GROUP BY customer_id
), xh AS (
  SELECT customer_id, dt,
         ROW_NUMBER() OVER (ORDER BY dt DESC, customer_id) AS hang,
         COUNT(*) OVER ()                                  AS n
  FROM kh
)
SELECT MAX(n)                                                                 AS so_khach,
       ROUND(100.0 * SUM(CASE WHEN hang <= 0.01 * n THEN dt ELSE 0 END) / SUM(dt), 1) AS pct_dt_top1pct,
       ROUND(100.0 * SUM(CASE WHEN hang <= 0.10 * n THEN dt ELSE 0 END) / SUM(dt), 1) AS pct_dt_top10pct,
       ROUND(100.0 * SUM(CASE WHEN hang <= 0.50 * n THEN dt ELSE 0 END) / SUM(dt), 1) AS pct_dt_top50pct
FROM xh;
