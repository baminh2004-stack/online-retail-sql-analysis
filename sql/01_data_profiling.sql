-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 1. KHÁM PHÁ CHẤT LƯỢNG DỮ LIỆU
-- Mục tiêu: đếm và chứng minh từng vấn đề TRƯỚC khi quyết định cách xử lý.
-- =====================================================================

-- 1.1 Khoảng thời gian dữ liệu
-- -> 01/12/2009 đến 09/12/2011: tháng 12/2011 chỉ có 9 ngày (chưa đủ tháng)
SELECT MIN(invoice_date) AS ngay_dau, MAX(invoice_date) AS ngay_cuoi
FROM invoices;

-- 1.2 Số ngày có hóa đơn trong từng tháng (phát hiện tháng thiếu dữ liệu)
SELECT DATE_FORMAT(invoice_date, '%Y-%m') AS thang,
       COUNT(*)                            AS so_hoa_don,
       MIN(DATE(invoice_date))             AS ngay_dau,
       MAX(DATE(invoice_date))             AS ngay_cuoi
FROM invoices
GROUP BY DATE_FORMAT(invoice_date, '%Y-%m')
ORDER BY thang;

-- 1.3 Loại hóa đơn theo ký tự đầu của mã
-- 'C' = hóa đơn hủy/trả hàng, 'A' = điều chỉnh nợ xấu (Adjust bad debt)
SELECT CASE SUBSTRING(invoice_no, 1, 1)
            WHEN 'C' THEN 'C - Hủy / trả hàng'
            WHEN 'A' THEN 'A - Điều chỉnh nợ xấu'
            ELSE          'Số - Bán hàng' END   AS loai_hoa_don,
       COUNT(*)                                AS so_hoa_don,
       SUM(customer_id IS NULL)                AS thieu_ma_khach
FROM invoices
GROUP BY CASE SUBSTRING(invoice_no, 1, 1)
            WHEN 'C' THEN 'C - Hủy / trả hàng'
            WHEN 'A' THEN 'A - Điều chỉnh nợ xấu'
            ELSE          'Số - Bán hàng' END
ORDER BY loai_hoa_don;

-- 1.4 Tổng hợp các vấn đề ở cấp dòng hóa đơn
SELECT COUNT(*)                                                   AS tong_so_dong,
       SUM(i.customer_id IS NULL)                                 AS dong_thieu_ma_khach,
       ROUND(100.0 * SUM(i.customer_id IS NULL) / COUNT(*), 1)    AS pct_thieu_ma_khach,
       SUM(SUBSTRING(i.invoice_no, 1, 1) = 'C')                   AS dong_huy,
       SUM(SUBSTRING(i.invoice_no, 1, 1) <> 'C' AND l.quantity < 0) AS sl_am_khong_phai_huy,
       SUM(l.unit_price = 0)                                      AS gia_bang_0,
       SUM(l.unit_price < 0)                                      AS gia_am,
       ROUND(SUM(l.quantity * l.unit_price), 2)                   AS tong_tien_tho
FROM invoice_lines l
JOIN invoices i ON i.invoice_no = l.invoice_no;

-- 1.5 Số lượng âm nhưng KHÔNG phải hóa đơn hủy: đều có giá 0, không mã khách
-- -> là ghi chú điều chỉnh kho (damages, lost, given away...), không phải giao dịch
SELECT p.description, COUNT(*) AS so_dong,
       SUM(l.unit_price = 0)     AS gia_0,
       SUM(i.customer_id IS NULL) AS khong_ma_khach
FROM invoice_lines l
JOIN invoices i ON i.invoice_no = l.invoice_no
JOIN products p ON p.stock_code = l.stock_code
WHERE SUBSTRING(i.invoice_no, 1, 1) <> 'C' AND l.quantity < 0
GROUP BY p.description
ORDER BY so_dong DESC, p.description
LIMIT 10;

-- 1.6 Dòng giá = 0: gần như toàn bộ không có mã khách -> điều chỉnh nội bộ
SELECT COUNT(*) AS dong_gia_0, SUM(i.customer_id IS NULL) AS khong_ma_khach,
       SUM(l.quantity > 0) AS sl_duong
FROM invoice_lines l
JOIN invoices i ON i.invoice_no = l.invoice_no
WHERE l.unit_price = 0;

-- 1.7 Mã hàng KHÔNG phải sản phẩm (phí ship, phí ngân hàng, điều chỉnh tay, giảm giá...)
-- Mã sản phẩm thật thường bắt đầu bằng 5 chữ số (vd 85123A) hoặc DCGS... (hàng của web dotcom)
SELECT l.stock_code, p.description,
       COUNT(*)                                 AS so_dong,
       ROUND(SUM(l.quantity * l.unit_price), 2) AS tong_tien
FROM invoice_lines l
JOIN products p ON p.stock_code = l.stock_code
WHERE l.stock_code IN ('POST','DOT','M','m','C2','C3','D','S','B','BANK CHARGES',
                       'AMAZONFEE','CRUK','PADS','ADJUST','ADJUST2','TEST001','TEST002')
   OR l.stock_code LIKE 'gift!_%' ESCAPE '!'
GROUP BY l.stock_code, p.description
ORDER BY so_dong DESC;

-- 1.8 Dòng trùng lặp hoàn toàn (cùng hóa đơn, mã hàng, số lượng, đơn giá)
SELECT COUNT(*)      AS so_nhom_trung,
       SUM(so_lan - 1) AS so_dong_du_thua
FROM (SELECT invoice_no, stock_code, quantity, unit_price, COUNT(*) AS so_lan
      FROM invoice_lines
      GROUP BY invoice_no, stock_code, quantity, unit_price
      HAVING COUNT(*) > 1) t;

-- 1.9 Mã hàng chỉ khác nhau chữ hoa/thường: phần lớn là CÙNG một sản phẩm
-- (vd 15056BL và 15056bl đều là EDWARDIAN PARASOL BLACK)
SELECT COUNT(*)                                  AS so_cap_ma,
       SUM(p1.description = p2.description)      AS cap_cung_mo_ta
FROM products p1
JOIN products p2
  ON UPPER(p1.stock_code) = UPPER(p2.stock_code)
 AND p1.stock_code < p2.stock_code;

-- 1.10 Giao dịch bất thường rất lớn: đặt rồi hủy ngay trong ngày
SELECT l.invoice_no, i.invoice_date, i.customer_id, l.stock_code, p.description,
       l.quantity, l.unit_price, ROUND(l.quantity * l.unit_price, 2) AS thanh_tien
FROM invoice_lines l
JOIN invoices i ON i.invoice_no = l.invoice_no
JOIN products p ON p.stock_code = l.stock_code
WHERE ABS(l.quantity) >= 50000
ORDER BY i.invoice_date;

-- 1.11 Quốc gia không xác định
SELECT c.country_name, COUNT(*) AS so_hoa_don
FROM invoices i
JOIN countries c ON c.country_id = i.country_id
WHERE c.country_name IN ('Unspecified', 'European Community')
GROUP BY c.country_name;

-- 1.12 Sản phẩm thiếu mô tả
SELECT COUNT(*) AS sp_thieu_mo_ta FROM products WHERE description IS NULL;
