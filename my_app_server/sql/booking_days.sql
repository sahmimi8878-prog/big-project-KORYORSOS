-- วันที่เจ้าหน้าที่เปิดรับการจอง (วันที่ไม่มีแถวในตารางนี้ = ยังไม่เปิดรับ)
-- รอบเวลาของแต่ละวันเก็บในตาราง slot_settings (sql/slot_settings.sql) ทีละแถวตามที่เจ้าหน้าที่กำหนด
CREATE TABLE IF NOT EXISTS booking_days (
  day_date  DATE PRIMARY KEY,
  is_open   TINYINT(1) NOT NULL DEFAULT 1,   -- 0 = ปิดรับวันนี้
  location  VARCHAR(200) NOT NULL DEFAULT '', -- สถานที่ยื่นเอกสาร
  note      VARCHAR(300) NOT NULL DEFAULT ''  -- รายละเอียดเพิ่มเติม (ไม่บังคับ)
);
