const pool = require('../libs/db_pool');

// จำนวนคิวสูงสุดต่อ 1 ช่วงเวลา (ต้องตรงกับ _slotCapacity ใน booking_screen.dart)
const SLOT_CAPACITY = 5;

// ช่วงเวลา 09:00 - 16:00 ช่วงละ 30 นาที พักเที่ยง 12:00 - 13:00 (ตรงกับ _buildTimeSlots ใน Flutter)
const VALID_SLOTS = (() => {
  const fmt = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  const slots = [];

  for (let start = 9 * 60; start < 16 * 60; start += 30) {
    if (start >= 12 * 60 && start < 13 * 60) continue;
    slots.push(`${fmt(start)} - ${fmt(start + 30)}`);
  }

  return slots;
})();

const validateInput = (serviceType, bookingDate, timeSlot) => {
  if (!serviceType) throw new Error('กรุณาเลือกประเภทบริการ');
  if (!/^\d{2}-\d{2}-\d{4}$/.test(bookingDate || '')) throw new Error('รูปแบบวันที่ไม่ถูกต้อง');
  if (!VALID_SLOTS.includes(timeSlot)) throw new Error('ช่วงเวลาที่เลือกไม่ถูกต้อง');
};

// รายการจองทั้งหมดของวันที่ระบุ (ล็อกแถวไว้ใน transaction กันสองคนจองคิวสุดท้ายพร้อมกัน)
const lockBookingsOfDate = (conn, bookingDate) => {
  return conn.query(
    "SELECT booking_id, time_slot, queue_no FROM bookings "
    + "WHERE booking_date = STR_TO_DATE(?, '%d-%m-%Y') FOR UPDATE",
    [bookingDate]
  );
};

const okResult = (data = "") => ({ isError: false, data, errorMessage: "" });
const errorResult = (error) => ({ isError: true, data: "", errorMessage: error.message });

const SELECT_BOOKING = "SELECT booking_id, service_type, "
  + "DATE_FORMAT(booking_date, '%d-%m-%Y') AS booking_date, time_slot, queue_no "
  + "FROM bookings ";

module.exports = {
  // รายการจองของผู้ใช้
  getBookings: async (userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = SELECT_BOOKING
        + "WHERE user_id = ? ORDER BY bookings.booking_date DESC, time_slot";

      const rows = await conn.query(sql, [userId]);

      result = okResult(rows);
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  // ข้อมูลการจองเดิมสำหรับหน้าแก้ไข (เฉพาะของผู้ใช้เอง)
  getBookingById: async (bookingId, userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = SELECT_BOOKING + "WHERE booking_id = ? AND user_id = ?";

      const rows = await conn.query(sql, [bookingId, userId]);

      result = okResult(rows);
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  // จำนวนที่จองแล้วต่อ time slot ของวันที่ระบุ (bookingDate รูปแบบ dd-MM-yyyy)
  getSlotCounts: async (bookingDate) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = "SELECT time_slot, COUNT(*) AS booked "
        + "FROM bookings "
        + "WHERE booking_date = STR_TO_DATE(?, '%d-%m-%Y') "
        + "GROUP BY time_slot";

      const rows = await conn.query(sql, [bookingDate]);

      // COUNT(*) เป็น BigInt ต้องแปลงเป็น Number ก่อนส่งเป็น JSON
      result = okResult(rows.map(r => ({ time_slot: r.time_slot, booked: Number(r.booked) })));
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  createBooking: async (userId, serviceType, bookingDate, timeSlot) => {
    let conn;
    let result;

    try {
      validateInput(serviceType, bookingDate, timeSlot);

      conn = await pool.getConnection();
      await conn.beginTransaction();

      const rows = await lockBookingsOfDate(conn, bookingDate);

      const used = rows.filter(r => r.time_slot === timeSlot).length;
      if (used >= SLOT_CAPACITY) throw new Error('ช่วงเวลานี้เต็มแล้ว');

      // เลขคิวรันต่อเนื่องในแต่ละวัน เช่น Q001, Q002
      const lastNo = rows.reduce((max, r) => Math.max(max, parseInt(String(r.queue_no).slice(1), 10) || 0), 0);
      const queueNo = `Q${String(lastNo + 1).padStart(3, '0')}`;

      const sql = "INSERT INTO bookings (user_id, service_type, booking_date, time_slot, queue_no) "
        + "VALUES (?, ?, STR_TO_DATE(?, '%d-%m-%Y'), ?, ?)";

      await conn.query(sql, [userId, serviceType, bookingDate, timeSlot, queueNo]);
      await conn.commit();

      result = okResult({ queue_no: queueNo });
    } catch (error) {
      if (conn) await conn.rollback();
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  updateBooking: async (userId, bookingId, serviceType, bookingDate, timeSlot) => {
    let conn;
    let result;

    try {
      validateInput(serviceType, bookingDate, timeSlot);

      conn = await pool.getConnection();
      await conn.beginTransaction();

      const own = await conn.query(
        "SELECT booking_id FROM bookings WHERE booking_id = ? AND user_id = ? FOR UPDATE",
        [bookingId, userId]
      );
      if (own.length === 0) throw new Error('ไม่พบข้อมูลการจอง');

      const rows = await lockBookingsOfDate(conn, bookingDate);

      // ไม่นับคิวของการจองนี้เอง เพื่อให้แก้ไขแล้วเลือกช่วงเวลาเดิมได้
      const used = rows.filter(r => r.time_slot === timeSlot && Number(r.booking_id) !== Number(bookingId)).length;
      if (used >= SLOT_CAPACITY) throw new Error('ช่วงเวลานี้เต็มแล้ว');

      const sql = "UPDATE bookings SET "
        + "service_type = ?, "
        + "booking_date = STR_TO_DATE(?, '%d-%m-%Y'), "
        + "time_slot = ? "
        + "WHERE booking_id = ? AND user_id = ?";

      await conn.query(sql, [serviceType, bookingDate, timeSlot, bookingId, userId]);
      await conn.commit();

      result = okResult();
    } catch (error) {
      if (conn) await conn.rollback();
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  deleteBooking: async (bookingId, userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = "DELETE FROM bookings WHERE booking_id = ? AND user_id = ?";

      const deleted = await conn.query(sql, [bookingId, userId]);
      if (Number(deleted.affectedRows) === 0) throw new Error('ไม่พบข้อมูลการจอง');

      result = okResult();
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },
};
