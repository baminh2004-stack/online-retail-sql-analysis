-- Online Retail II - SQL analysis (MySQL 8)
-- Author: Nguyen Ba Hong Minh
-- Run the files in order (see sql/run_all.sql). Comments are in Vietnamese.

USE online_retail;

-- Bắt buộc: dùng bảng mã utf8mb4 cho phiên làm việc. Nếu thiếu, cmd trên Windows
-- dùng bảng mã cp850 làm mặc định, khiến các cột chữ tạo bằng CREATE TABLE ... AS
-- (vd ly_do, segment) mang bảng mã cp850, mất dấu tiếng Việt và lỗi khi ghép
-- với dữ liệu utf8mb4 (lỗi 1267 Illegal mix of collations).
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- 0. Kiểm tra dữ liệu đã nạp đủ (đối chiếu với tài liệu: 43 / 5942 / 5305 / 53628 / 1044848)
SELECT 'countries' AS bang, COUNT(*) AS so_dong FROM countries
UNION ALL SELECT 'customers',     COUNT(*) FROM customers
UNION ALL SELECT 'products',      COUNT(*) FROM products
UNION ALL SELECT 'invoices',      COUNT(*) FROM invoices
UNION ALL SELECT 'invoice_lines', COUNT(*) FROM invoice_lines;
