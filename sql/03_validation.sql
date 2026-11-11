-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 3. KIỂM CHỨNG SỐ LIỆU
-- Mỗi kiểm tra trả về cột ket_qua = 'OK' nếu đúng.
-- =====================================================================

-- 3.1 Không mất dòng nào: tổng các nhóm trong line_audit = số dòng gốc
SELECT (SELECT COUNT(*) FROM line_audit)    AS dong_audit,
       (SELECT COUNT(*) FROM invoice_lines) AS dong_goc,
       CASE WHEN (SELECT COUNT(*) FROM line_audit) = (SELECT COUNT(*) FROM invoice_lines)
            THEN 'OK' ELSE 'SAI' END        AS ket_qua;

-- 3.2 Không mất tiền: tổng tiền line_audit = tổng tiền tính thẳng từ bảng gốc
SELECT ROUND((SELECT SUM(revenue) FROM line_audit), 2)                      AS tien_audit,
       ROUND((SELECT SUM(quantity * unit_price) FROM invoice_lines), 2)     AS tien_goc,
       CASE WHEN ABS((SELECT SUM(revenue) FROM line_audit)
                   - (SELECT SUM(quantity * unit_price) FROM invoice_lines)) < 0.01
            THEN 'OK' ELSE 'SAI' END                                        AS ket_qua;

-- 3.3 sales_clean khớp với nhóm 'Giữ lại' (số dòng và tiền)
SELECT (SELECT COUNT(*) FROM sales_clean)                                   AS dong_clean,
       (SELECT COUNT(*) FROM line_audit WHERE ly_do = 'Giữ lại')            AS dong_giu_lai,
       CASE WHEN (SELECT COUNT(*) FROM sales_clean)
               = (SELECT COUNT(*) FROM line_audit WHERE ly_do = 'Giữ lại')
             AND ABS((SELECT SUM(revenue) FROM sales_clean)
                   - (SELECT SUM(revenue) FROM line_audit WHERE ly_do = 'Giữ lại')) < 0.01
            THEN 'OK' ELSE 'SAI' END                                        AS ket_qua;

-- 3.4 Dữ liệu sạch không còn giá <= 0, không còn dòng bán có SL <= 0,
--     dòng hủy luôn có SL âm, không còn trùng lặp
SELECT SUM(unit_price <= 0)                         AS gia_khong_hop_le,
       SUM(is_cancel = 0 AND quantity <= 0)         AS ban_sl_am,
       SUM(is_cancel = 1 AND quantity >= 0)         AS huy_sl_duong,
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT invoice_no, stock_code, quantity, unit_price
                                         FROM sales_clean) d) AS con_trung,
       CASE WHEN SUM(unit_price <= 0) + SUM(is_cancel = 0 AND quantity <= 0)
               + SUM(is_cancel = 1 AND quantity >= 0) = 0 THEN 'OK' ELSE 'SAI' END AS ket_qua
FROM sales_clean;

-- 3.5 Tính doanh thu thuần theo 2 đường khác nhau phải ra cùng một số:
--     (a) cộng theo tháng, (b) cộng theo quốc gia
SELECT ROUND((SELECT SUM(dt) FROM (SELECT ym, SUM(revenue) AS dt FROM sales_clean GROUP BY ym) a), 2)           AS tong_theo_thang,
       ROUND((SELECT SUM(dt) FROM (SELECT country_name, SUM(revenue) AS dt FROM sales_clean GROUP BY country_name) b), 2) AS tong_theo_quoc_gia,
       ROUND((SELECT SUM(revenue) FROM sales_clean), 2)                                                          AS tong_truc_tiep;
