-- ตั้งค่าช่วงเวลาเปิดรับการจองรายวัน (เจ้าหน้าที่แก้ไขได้)
-- ถ้าวันไหน/ช่วงไหนไม่มีแถวในตารางนี้ จะใช้ค่าเริ่มต้น (ช่วงละ 30 นาที 09:00-16:00 พักเที่ยง 12:00-13:00 รับ 5 คน)
-- แถวของช่วงเวลามาตรฐาน = ปรับจำนวนรับ/ปิดช่วงนั้น, แถวของช่วงเวลานอกมาตรฐาน = ช่วงเวลาที่เพิ่มเอง
CREATE TABLE IF NOT EXISTS slot_settings (
  setting_id INT AUTO_INCREMENT PRIMARY KEY,
  slot_date  DATE NOT NULL,
  time_slot  VARCHAR(20) NOT NULL,            -- เช่น '09:00 - 09:30'
  capacity   INT NOT NULL DEFAULT 5,          -- จำนวนคนที่รับ
  is_open    TINYINT(1) NOT NULL DEFAULT 1,   -- 0 = ปิดรับ
  UNIQUE KEY uq_slot_settings (slot_date, time_slot)
);
