const pool = require('../libs/db_pool');

// จำนวนคิวเริ่มต้นต่อ 1 รอบเวลา (เจ้าหน้าที่ปรับรายวัน/รายรอบได้ผ่านตาราง slot_settings)
const DEFAULT_CAPACITY = 5;
const MAX_CAPACITY = 100;
const MAX_DAYS = 366;
const DATE_FORMAT = /^\d{2}-\d{2}-\d{4}$/;

// รอบเวลามาตรฐาน 09:00 - 16:00 ช่วงละ 30 นาที พักเที่ยง 12:00 - 13:00
// ใช้แสดงเป็น "รอบที่ปิด" ของวันที่เจ้าหน้าที่ยังไม่เปิดรับ
const DEFAULT_SLOTS = (() => {
  const fmt = (m) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  const slots = [];

  for (let start = 9 * 60; start < 16 * 60; start += 30) {
    if (start >= 12 * 60 && start < 13 * 60) continue;
    slots.push(`${fmt(start)} - ${fmt(start + 30)}`);
  }

  return slots;
})();

const SLOT_FORMAT = /^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$/;

// แปลง '09:00 - 09:30' เป็นนาที [เริ่ม, จบ] ถ้ารูปแบบไม่ถูกต้องคืน null
const parseSlot = (timeSlot) => {
  const m = SLOT_FORMAT.exec(timeSlot || '');
  if (!m) return null;

  const start = Number(m[1]) * 60 + Number(m[2]);
  const end = Number(m[3]) * 60 + Number(m[4]);
  const valid = Number(m[1]) < 24 && Number(m[3]) < 24 && Number(m[2]) < 60 && Number(m[4]) < 60;

  return valid && start < end ? [start, end] : null;
};

const validateInput = (serviceType, bookingDate, timeSlot) => {
  if (!serviceType) throw new Error('กรุณาเลือกประเภทบริการ');
  if (!DATE_FORMAT.test(bookingDate || '')) throw new Error('รูปแบบวันที่ไม่ถูกต้อง');
  if (!parseSlot(timeSlot)) throw new Error('ช่วงเวลาที่เลือกไม่ถูกต้อง');
};

// ข้อมูลการเปิดรับของวันที่ระบุ: เปิดรับไหม + รอบเวลาที่เจ้าหน้าที่กำหนด { 'HH:MM - HH:MM': { capacity, isOpen } }
// วันที่เจ้าหน้าที่ยังไม่เคยเปิด = ปิดรับ
const loadDay = async (conn, bookingDate) => {
  const days = await conn.query(
    "SELECT is_open FROM booking_days WHERE day_date = STR_TO_DATE(?, '%d-%m-%Y')",
    [bookingDate]
  );

  const rows = await conn.query(
    "SELECT time_slot, capacity, is_open FROM slot_settings "
    + "WHERE slot_date = STR_TO_DATE(?, '%d-%m-%Y')",
    [bookingDate]
  );

  const settings = {};
  for (const r of rows) {
    settings[r.time_slot] = { capacity: Number(r.capacity), isOpen: Number(r.is_open) === 1 };
  }

  return { dayOpen: days.length > 0 && Number(days[0].is_open) === 1, settings };
};

// รอบเวลานี้ของวันนั้นมีไหม + รับกี่คน + เปิดรับอยู่ไหม (ปิดทั้งวันถือว่าทุกรอบปิด)
const resolveSlot = (day, timeSlot) => {
  const slot = day.settings[timeSlot];
  if (!slot) return { exists: false, capacity: 0, isOpen: false };

  return { exists: true, capacity: slot.capacity, isOpen: day.dayOpen && slot.isOpen };
};

// รายการจองทั้งหมดของวันที่ระบุ (ล็อกแถวไว้ใน transaction กันสองคนจองคิวสุดท้ายพร้อมกัน)
const lockBookingsOfDate = (conn, bookingDate) => {
  return conn.query(
    "SELECT booking_id, user_id, time_slot, queue_no FROM bookings "
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

  // รอบเวลาทั้งหมดของวันที่ระบุ (bookingDate รูปแบบ dd-MM-yyyy) พร้อมจำนวนรับ สถานะเปิด/ปิด และจำนวนที่จองแล้ว
  // วันที่ยังไม่เปิดรับ: คืนรอบมาตรฐานทั้งหมดเป็น "ปิด" (day_open = false)
  getSlotCounts: async (bookingDate) => {
    let conn;
    let result;

    try {
      if (!DATE_FORMAT.test(bookingDate || '')) throw new Error('รูปแบบวันที่ไม่ถูกต้อง');

      conn = await pool.getConnection();

      const day = await loadDay(conn, bookingDate);

      const counts = await conn.query(
        "SELECT time_slot, COUNT(*) AS booked FROM bookings "
        + "WHERE booking_date = STR_TO_DATE(?, '%d-%m-%Y') GROUP BY time_slot",
        [bookingDate]
      );

      // COUNT(*) เป็น BigInt ต้องแปลงเป็น Number ก่อนส่งเป็น JSON
      const booked = {};
      for (const r of counts) booked[r.time_slot] = Number(r.booked);

      const configured = Object.keys(day.settings);
      const names = new Set([...(configured.length > 0 ? configured : DEFAULT_SLOTS), ...Object.keys(booked)]);

      const rows = [...names].sort().map((timeSlot) => {
        const slot = resolveSlot(day, timeSlot);

        return {
          time_slot: timeSlot,
          capacity: slot.exists ? slot.capacity : DEFAULT_CAPACITY,
          is_open: slot.isOpen,
          booked: booked[timeSlot] || 0,
          day_open: day.dayOpen,
        };
      });

      result = okResult(rows);
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  // วันที่เปิดรับการจอง (ตั้งแต่วันนี้เป็นต้นไป) พร้อมสถานที่ ให้นักศึกษาเลือกวัน
  getOpenDays: async () => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const rows = await conn.query(
        "SELECT DATE_FORMAT(day_date, '%d-%m-%Y') AS date, location, note FROM booking_days "
        + "WHERE is_open = 1 AND day_date >= CURDATE() ORDER BY day_date"
      );

      result = okResult(rows);
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

      const day = await loadDay(conn, bookingDate);
      if (!day.dayOpen) throw new Error('วันนี้ไม่ได้เปิดรับการจอง');

      const slot = resolveSlot(day, timeSlot);
      if (!slot.exists) throw new Error('ช่วงเวลาที่เลือกไม่ถูกต้อง');
      if (!slot.isOpen) throw new Error('ช่วงเวลานี้ปิดรับการจอง');

      const alreadyBooked = rows.some(r => r.time_slot === timeSlot && Number(r.user_id) === Number(userId));
      if (alreadyBooked) throw new Error('คุณจองช่วงเวลานี้ของวันนี้ไว้แล้ว');

      const used = rows.filter(r => r.time_slot === timeSlot).length;
      if (used >= slot.capacity) throw new Error('ช่วงเวลานี้เต็มแล้ว');

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
        "SELECT booking_id, time_slot, DATE_FORMAT(booking_date, '%d-%m-%Y') AS booking_date "
        + "FROM bookings WHERE booking_id = ? AND user_id = ? FOR UPDATE",
        [bookingId, userId]
      );
      if (own.length === 0) throw new Error('ไม่พบข้อมูลการจอง');

      const rows = await lockBookingsOfDate(conn, bookingDate);

      const day = await loadDay(conn, bookingDate);
      const slot = resolveSlot(day, timeSlot);

      // แก้แค่ประเภทบริการโดยไม่ย้ายวัน/ช่วงเวลา ให้ผ่านได้แม้วัน/รอบนั้นถูกปิดรับทีหลัง
      const moved = own[0].booking_date !== bookingDate || own[0].time_slot !== timeSlot;
      if (moved && !day.dayOpen) throw new Error('วันนี้ไม่ได้เปิดรับการจอง');
      if (moved && !slot.exists) throw new Error('ช่วงเวลาที่เลือกไม่ถูกต้อง');
      if (moved && !slot.isOpen) throw new Error('ช่วงเวลานี้ปิดรับการจอง');

      const alreadyBooked = rows.some(r => r.time_slot === timeSlot
        && Number(r.user_id) === Number(userId)
        && Number(r.booking_id) !== Number(bookingId));
      if (alreadyBooked) throw new Error('คุณจองช่วงเวลานี้ของวันนี้ไว้แล้ว');

      // ไม่นับคิวของการจองนี้เอง เพื่อให้แก้ไขแล้วเลือกช่วงเวลาเดิมได้
      const used = rows.filter(r => r.time_slot === timeSlot && Number(r.booking_id) !== Number(bookingId)).length;
      if (moved && used >= slot.capacity) throw new Error('ช่วงเวลานี้เต็มแล้ว');

      // ย้ายไปวันอื่น: ออกเลขคิวใหม่ตามวันนั้น (เลขคิวเดิมอาจซ้ำกับคิวที่มีอยู่แล้วของวันใหม่)
      const dateChanged = own[0].booking_date !== bookingDate;
      let queueNo = null;

      if (dateChanged) {
        const lastNo = rows.reduce((max, r) => Math.max(max, parseInt(String(r.queue_no).slice(1), 10) || 0), 0);
        queueNo = `Q${String(lastNo + 1).padStart(3, '0')}`;
      }

      const sql = "UPDATE bookings SET "
        + "service_type = ?, "
        + "booking_date = STR_TO_DATE(?, '%d-%m-%Y'), "
        + "time_slot = ?"
        + (dateChanged ? ", queue_no = ? " : " ")
        + "WHERE booking_id = ? AND user_id = ?";

      const params = [serviceType, bookingDate, timeSlot];
      if (dateChanged) params.push(queueNo);
      params.push(bookingId, userId);

      await conn.query(sql, params);
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

  // ===== สำหรับเจ้าหน้าที่ =====

  // รายการจองของทุกคน (ใส่ bookingDate รูปแบบ dd-MM-yyyy เพื่อกรองเฉพาะวัน)
  getAllBookings: async (bookingDate) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      let sql = "SELECT b.booking_id, b.user_id, b.service_type, "
        + "DATE_FORMAT(b.booking_date, '%d-%m-%Y') AS booking_date, b.time_slot, b.queue_no, "
        + "sp.student_code, "
        + "TRIM(CONCAT(COALESCE(sp.prefix, ''), COALESCE(sp.first_name, ''), ' ', COALESCE(sp.last_name, ''))) AS student_name "
        + "FROM bookings b "
        + "LEFT JOIN student_profiles sp ON sp.user_id = b.user_id ";
      const params = [];

      if (bookingDate) {
        sql += "WHERE b.booking_date = STR_TO_DATE(?, '%d-%m-%Y') ";
        params.push(bookingDate);
      }

      sql += "ORDER BY b.booking_date DESC, b.time_slot, b.queue_no";

      const rows = await conn.query(sql, params);

      result = okResult(rows);
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  // เจ้าของการจอง ใช้ให้เจ้าหน้าที่แก้ไข/ลบแทนนักศึกษา
  getBookingOwner: async (bookingId) => {
    let conn;

    try {
      conn = await pool.getConnection();

      const rows = await conn.query("SELECT user_id FROM bookings WHERE booking_id = ?", [bookingId]);

      return rows.length === 0 ? null : rows[0].user_id;
    } finally {
      if (conn) conn.release();
    }
  },

  // การตั้งค่าเปิดรับของวันที่อยู่ในช่วง from-to (dd-MM-yyyy)
  // คืนเฉพาะวันที่เคยตั้งค่าไว้ พร้อมรอบเวลาและจำนวนที่จองแล้วของแต่ละรอบ
  getOpenDaysAdmin: async (from, to) => {
    let conn;
    let result;

    try {
      if (!DATE_FORMAT.test(from || '') || !DATE_FORMAT.test(to || '')) throw new Error('รูปแบบวันที่ไม่ถูกต้อง');

      conn = await pool.getConnection();

      const between = "BETWEEN STR_TO_DATE(?, '%d-%m-%Y') AND STR_TO_DATE(?, '%d-%m-%Y')";

      const days = await conn.query(
        "SELECT DATE_FORMAT(day_date, '%d-%m-%Y') AS date, is_open, location, note "
        + `FROM booking_days WHERE day_date ${between} ORDER BY day_date`,
        [from, to]
      );

      const slots = await conn.query(
        "SELECT DATE_FORMAT(slot_date, '%d-%m-%Y') AS date, time_slot, capacity, is_open "
        + `FROM slot_settings WHERE slot_date ${between} ORDER BY slot_date, time_slot`,
        [from, to]
      );

      const counts = await conn.query(
        "SELECT DATE_FORMAT(booking_date, '%d-%m-%Y') AS date, time_slot, COUNT(*) AS booked "
        + `FROM bookings WHERE booking_date ${between} GROUP BY booking_date, time_slot`,
        [from, to]
      );

      const booked = {};
      for (const r of counts) booked[`${r.date}|${r.time_slot}`] = Number(r.booked);

      const data = days.map((d) => ({
        date: d.date,
        is_open: Number(d.is_open) === 1,
        location: d.location,
        note: d.note,
        slots: slots
          .filter((s) => s.date === d.date)
          .map((s) => ({
            time_slot: s.time_slot,
            capacity: Number(s.capacity),
            is_open: Number(s.is_open) === 1,
            booked: booked[`${d.date}|${s.time_slot}`] || 0,
          })),
      }));

      result = okResult(data);
    } catch (error) {
      result = errorResult(error);
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  // บันทึกการเปิดรับหลายวันพร้อมกัน (สำเร็จทั้งหมดหรือไม่บันทึกเลย)
  // days = [{ date, is_open, location, note, slots: [{ time_slot, capacity, is_open }] }]
  // รอบเวลาของแต่ละวันจะถูกแทนที่ด้วยรายการที่ส่งมา (รอบที่มีคนจองแล้วห้ามหายไป)
  saveOpenDays: async (days) => {
    let conn;
    let result;

    try {
      if (!Array.isArray(days) || days.length === 0) throw new Error('ไม่มีวันที่ให้บันทึก');
      if (days.length > MAX_DAYS) throw new Error(`ตั้งค่าได้ครั้งละไม่เกิน ${MAX_DAYS} วัน`);

      const seenDates = new Set();

      for (const d of days) {
        if (!DATE_FORMAT.test(d.date || '')) throw new Error('รูปแบบวันที่ไม่ถูกต้อง');
        if (seenDates.has(d.date)) throw new Error(`วันที่ ${d.date} ซ้ำกัน`);
        seenDates.add(d.date);

        if (String(d.location || '').length > 200) throw new Error('สถานที่ยาวเกินไป');
        if (String(d.note || '').length > 300) throw new Error('รายละเอียดเพิ่มเติมยาวเกินไป');
        if (!Array.isArray(d.slots)) throw new Error('รอบเวลาไม่ถูกต้อง');

        const ranges = [];

        for (const s of d.slots) {
          const range = parseSlot(s.time_slot);
          if (!range) throw new Error(`รูปแบบรอบเวลาไม่ถูกต้อง (${d.date}: ${s.time_slot})`);

          const cap = Number(s.capacity);
          if (!Number.isInteger(cap) || cap < 0 || cap > MAX_CAPACITY) {
            throw new Error(`จำนวนที่รับต้องเป็นเลข 0 - ${MAX_CAPACITY} (${d.date}: ${s.time_slot})`);
          }

          const overlap = ranges.find((r) => range[0] < r.range[1] && r.range[0] < range[1]);
          if (overlap) throw new Error(`รอบเวลาซ้อนกัน (${d.date}: ${s.time_slot} กับ ${overlap.name})`);

          ranges.push({ name: s.time_slot, range });
        }

        if (d.is_open !== false && d.slots.length === 0) {
          throw new Error(`วันที่ ${d.date} เปิดรับแล้วต้องมีอย่างน้อย 1 รอบเวลา`);
        }
      }

      conn = await pool.getConnection();
      await conn.beginTransaction();

      for (const d of days) {
        const booked = await conn.query(
          "SELECT DISTINCT time_slot FROM bookings WHERE booking_date = STR_TO_DATE(?, '%d-%m-%Y')",
          [d.date]
        );

        const keep = new Set(d.slots.map((s) => s.time_slot));
        const lost = booked.find((b) => !keep.has(b.time_slot));
        if (lost) throw new Error(`มีนักศึกษาจองรอบ ${lost.time_slot} ของวันที่ ${d.date} อยู่ ลบรอบนี้ไม่ได้`);

        await conn.query(
          "INSERT INTO booking_days (day_date, is_open, location, note) "
          + "VALUES (STR_TO_DATE(?, '%d-%m-%Y'), ?, ?, ?) "
          + "ON DUPLICATE KEY UPDATE is_open = VALUES(is_open), location = VALUES(location), note = VALUES(note)",
          [d.date, d.is_open === false ? 0 : 1, String(d.location || ''), String(d.note || '')]
        );

        await conn.query(
          "DELETE FROM slot_settings WHERE slot_date = STR_TO_DATE(?, '%d-%m-%Y')",
          [d.date]
        );

        for (const s of d.slots) {
          await conn.query(
            "INSERT INTO slot_settings (slot_date, time_slot, capacity, is_open) "
            + "VALUES (STR_TO_DATE(?, '%d-%m-%Y'), ?, ?, ?)",
            [d.date, s.time_slot, Number(s.capacity), s.is_open === false ? 0 : 1]
          );
        }
      }

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
};
