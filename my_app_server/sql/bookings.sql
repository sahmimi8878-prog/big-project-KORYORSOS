-- ตาราง bookings ที่ my_app_server/models/bookings.js ใช้งาน
-- ถ้ามีตารางนี้อยู่แล้วให้เทียบชื่อคอลัมน์ให้ตรงกัน
CREATE TABLE IF NOT EXISTS bookings (
  booking_id   INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT NOT NULL,
  service_type VARCHAR(100) NOT NULL,
  booking_date DATE NOT NULL,
  time_slot    VARCHAR(20) NOT NULL,        -- เช่น '09:00 - 09:30'
  queue_no     VARCHAR(10) NOT NULL,        -- เช่น 'Q001' รันต่อเนื่องในแต่ละวัน
  created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_bookings_user (user_id),
  INDEX idx_bookings_date (booking_date),
  UNIQUE KEY uq_bookings_date_queue (booking_date, queue_no)
);
