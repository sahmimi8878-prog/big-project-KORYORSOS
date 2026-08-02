const pool = require('../libs/db_pool');
const dateUtil = require('../libs/date_utils');

module.exports = {
  getUserById: async (userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `
      SELECT
        u.user_id,
        u.email,
        u.role_id,
        sp.student_code,
        sp.prefix,
        sp.first_name,
        sp.last_name
      FROM users u
      JOIN student_profiles sp
        ON u.user_id = sp.user_id
      WHERE u.user_id = ?`;

      const rows = await conn.query(sql, [userId]);

      result = {
        isError: false,
        data: rows
      };
    } catch (error) {
      result = {
        isError: true,
        errorMessage: error.message
      };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  checkAuthenRequest: async (authenRequest) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `SELECT email FROM users WHERE SHA2(CONCAT(email,'&',?),256)=?`;

      const rows = await conn.query(sql, [
        dateUtil.getCurrentDateForToken(),
        authenRequest
      ]);

      if (rows.length === 0) {
        result = {
          isError: true,
          errorMessage: 'ไม่พบข้อมูลผู้ใช้ในระบบ'
        };
      } else {
        result = {
          isError: false,
          data: rows
        };
      }
    } catch (error) {
      result = {
        isError: true,
        errorMessage: error.message
      };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  checkAccessRequest: async (authenSignature, authenToken) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

const sql = `
SELECT
    u.user_id,
    u.email,
    u.role_id,
    sp.student_code,
    sp.first_name,
    sp.last_name
FROM users u
JOIN student_profiles sp
    ON u.user_id = sp.user_id
WHERE SHA2(
    CONCAT(
        u.email,
        '&',
        u.password_hash,
        '&',
        ?
    ),
256)=?`;

      const rows = await conn.query(sql, [
        authenToken,
        authenSignature
      ]);

      if (rows.length === 0) {
        result = {
          isError: true,
          errorMessage: 'รหัสผ่านไม่ถูกต้อง'
        };
      } else {
        result = {
          isError: false,
          data: rows
        };
      }
    } catch (error) {
      result = {
        isError: true,
        errorMessage: error.message
      };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },
  createUser: async (userData) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();
      await conn.beginTransaction();

      const insertUserSql = `
        INSERT INTO users (email, password_hash, role_id, is_active, created_at, updated_at)
        VALUES (?, SHA2(?, 256), ?, 1, NOW(), NOW())
      `;
      const userResult = await conn.query(insertUserSql, [
        userData.email,
        userData.password,
        userData.role_id || 3
      ]);

      const newUserId = Number(userResult.insertId);

      // เพิ่มข้อมูลลงตาราง student_profiles
      const insertProfileSql = `
        INSERT INTO student_profiles
          (user_id, student_code, citizen_id, prefix, first_name, last_name, birth_date, phone, faculty, major, year, GPA)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;
      await conn.query(insertProfileSql, [
        newUserId,
        userData.student_code,
        userData.citizen_id,
        userData.prefix || null,
        userData.first_name,
        userData.last_name,
        userData.birth_date,
        userData.phone,
        userData.faculty,
        userData.major,
        userData.year,
        userData.gpa
      ]);

      await conn.commit();

      result = {
        isError: false,
        data: { user_id: newUserId }
      };
    } catch (error) {
      if (conn) await conn.rollback();

      // email / student_code / citizen_id ซ้ำ (ต้องตั้ง UNIQUE ที่ column เหล่านี้ในฐานข้อมูลตาม ERD)
      let errorMessage = error.message;
      if (error.code === 'ER_DUP_ENTRY') {
        errorMessage = 'อีเมล / รหัสนักศึกษา / เลขบัตรประชาชนนี้ถูกใช้งานแล้ว';
      }

      result = {
        isError: true,
        errorMessage
      };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },
};