-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- =====================================================================
-- PHẦN 2. LÀM SẠCH DỮ LIỆU
-- Cách làm: gắn cho MỖI dòng hóa đơn một "lý do loại" (hoặc 'Giữ lại') theo
-- thứ tự ưu tiên -> bảng line_audit. Nhờ vậy:
--   (a) biết chính xác mỗi quy tắc loại bao nhiêu dòng / bao nhiêu tiền,
--   (b) tổng các nhóm luôn bằng dữ liệu gốc (kiểm chứng được).
--
-- Quy tắc (theo thứ tự):
--   R1  Hóa đơn 'A' (điều chỉnh nợ xấu)           -> loại: bút toán kế toán, không phải bán hàng
--   R2  Mã không phải sản phẩm (POST, M, AMAZONFEE..) -> loại: phí/điều chỉnh, làm méo doanh thu sản phẩm
--   R3  Đơn giá <= 0                              -> loại: hàng tặng / điều chỉnh kho
--   R4  Hóa đơn bán nhưng số lượng <= 0           -> loại: ghi chú kho (damages, lost...)
--   R5  Dòng trùng lặp hoàn toàn (giữ dòng đầu)  -> loại: nhập trùng
-- GIỮ LẠI:
--   * Hóa đơn hủy 'C' (số lượng âm) -> tính là doanh thu âm, để có DOANH THU THUẦN
--   * Dòng thiếu customer_id -> vẫn là doanh thu thật; chỉ loại khi phân tích khách hàng
--   * Quốc gia 'Unspecified'  -> giữ, chiếm rất nhỏ
-- =====================================================================

DROP TABLE IF EXISTS line_audit;

CREATE TABLE line_audit AS
SELECT x.line_id,
       x.invoice_no,
       x.invoice_date,
       x.customer_id,
       x.country_id,
       x.stock_code,
       x.quantity,
       x.unit_price,
       x.quantity * x.unit_price AS revenue,
       CASE
         WHEN SUBSTRING(x.invoice_no, 1, 1) = 'A'                     THEN 'R1 Điều chỉnh nợ xấu'
         WHEN x.stock_code IN ('POST','DOT','M','m','C2','C3','D','S','B','BANK CHARGES',
                               'AMAZONFEE','CRUK','PADS','ADJUST','ADJUST2','TEST001','TEST002')
              OR x.stock_code LIKE 'gift!_%' ESCAPE '!'               THEN 'R2 Mã không phải sản phẩm'
         WHEN x.unit_price <= 0                                       THEN 'R3 Đơn giá <= 0'
         WHEN SUBSTRING(x.invoice_no, 1, 1) <> 'C' AND x.quantity <= 0 THEN 'R4 SL âm không phải hủy'
         WHEN x.rn > 1                                                THEN 'R5 Dòng trùng lặp'
         ELSE 'Giữ lại'
       END AS ly_do
FROM (SELECT l.line_id, l.invoice_no, i.invoice_date, i.customer_id, i.country_id,
             l.stock_code, l.quantity, l.unit_price,
             ROW_NUMBER() OVER (PARTITION BY l.invoice_no, l.stock_code, l.quantity, l.unit_price
                                ORDER BY l.line_id) AS rn
      FROM invoice_lines l
      JOIN invoices i ON i.invoice_no = l.invoice_no) x;

-- 2.1 "Thác nước" làm sạch: mỗi quy tắc loại bao nhiêu
SELECT ly_do,
       COUNT(*)                                                         AS so_dong,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_dong,
       ROUND(SUM(revenue), 2)                                           AS tong_tien
FROM line_audit
GROUP BY ly_do
ORDER BY ly_do;

-- 2.2 Bảng dữ liệu sạch dùng cho mọi phân tích phía sau
--   product_key = UPPER(stock_code): gộp các mã chỉ khác hoa/thường (161/173 cặp cùng mô tả)
--   is_cancel   = 1 nếu là dòng hủy/trả hàng
DROP TABLE IF EXISTS sales_clean;

CREATE TABLE sales_clean AS
SELECT a.line_id,
       a.invoice_no,
       a.invoice_date,
       DATE_FORMAT(a.invoice_date, '%Y-%m')                  AS ym,
       a.customer_id,
       c.country_name,
       a.stock_code,
       UPPER(a.stock_code)                                   AS product_key,
       p.description,
       a.quantity,
       a.unit_price,
       a.revenue,
       CASE WHEN SUBSTRING(a.invoice_no, 1, 1) = 'C' THEN 1 ELSE 0 END AS is_cancel
FROM line_audit a
JOIN countries c ON c.country_id = a.country_id
JOIN products  p ON p.stock_code = a.stock_code
WHERE a.ly_do = 'Giữ lại';

CREATE INDEX idx_sc_cust ON sales_clean (customer_id);
CREATE INDEX idx_sc_date ON sales_clean (invoice_date);
CREATE INDEX idx_sc_prod ON sales_clean (product_key);

-- 2.3 Ảnh hưởng của làm sạch lên con số doanh thu
--   Doanh thu gộp  = các dòng bán (không hủy)
--   Hủy / trả hàng = các dòng 'C' (âm)
--   Doanh thu thuần = gộp + hủy   <- CHỈ SỐ CHÍNH của báo cáo
SELECT ROUND(SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 2) AS doanh_thu_gop,
       ROUND(SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END), 2) AS huy_tra_hang,
       ROUND(SUM(revenue), 2)                                         AS doanh_thu_thuan,
       ROUND(-100.0 * SUM(CASE WHEN is_cancel = 1 THEN revenue ELSE 0 END)
                    / SUM(CASE WHEN is_cancel = 0 THEN revenue ELSE 0 END), 2) AS pct_huy_tren_gop,
       ROUND(100.0 * SUM(CASE WHEN customer_id IS NULL THEN revenue ELSE 0 END)
                   / SUM(revenue), 2)                                 AS pct_dt_khong_ma_khach
FROM sales_clean;
