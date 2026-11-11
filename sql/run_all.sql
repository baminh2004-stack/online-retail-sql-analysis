-- Chạy toàn bộ project bằng mysql client, đứng ở thư mục gốc của repo:
--   mysql -u root -p --default-character-set=utf8mb4 --table < sql/run_all.sql > output/query_results.txt
source sql/00_setup_check.sql
source sql/01_data_profiling.sql
source sql/02_data_cleaning.sql
source sql/03_validation.sql
source sql/04_business_analysis.sql
source sql/05_customer_retention.sql
source sql/06_rfm_segmentation.sql
source sql/07_extra_questions.sql
source sql/08_key_metrics.sql
