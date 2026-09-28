const pool = require('../libs/db_pool');
const dateUtil = require('../libs/date_utils');

module.exports = {

  // แสดงข้อมูลผู้ใช้ทั้งหมด
  getUsers: async () => {
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
          sp.last_name,
          sp.citizen_id,
          sp.birth_date,
          sp.phone,
          sp.faculty,
          sp.major,
          sp.year,
          sp.GPA
        FROM users u
        JOIN student_profiles sp
          ON u.user_id = sp.user_id
        ORDER BY u.user_id
      `;

      const rows = await conn.query(sql);

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

  // แสดงข้อมูลผู้ใช้ตาม user_id
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
        WHERE u.user_id = ?
      `;

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

  // ตรวจสอบ Login ขั้นที่ 1
  checkAuthenRequest: async (authenRequest) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `
        SELECT email
        FROM users
        WHERE SHA2(CONCAT(email,'&',?),256)=?
      `;

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

  // ตรวจสอบ Login ขั้นที่ 2
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
          256
        )=?
      `;

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

  // เพิ่มผู้ใช้
  createUser: async (userData) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      await conn.beginTransaction();

      const insertUserSql = `
        INSERT INTO users
          (email, password_hash, role_id, is_active, created_at, updated_at)
        VALUES
          (?, SHA2(?, 256), ?, 1, NOW(), NOW())
      `;

      const userResult = await conn.query(insertUserSql, [
        userData.email,
        userData.password,
        userData.role_id || 1
      ]);

      const newUserId = Number(userResult.insertId);

      // เพิ่มข้อมูลลงตาราง student_profiles
      const insertProfileSql = `
        INSERT INTO student_profiles
          (
            user_id,
            student_code,
            citizen_id,
            prefix,
            first_name,
            last_name,
            birth_date,
            phone,
            faculty,
            major,
            year,
            GPA
          )
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
        data: {
          user_id: newUserId
        }
      };

    } catch (error) {

      if (conn) await conn.rollback();

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
  // แก้ไขข้อมูลผู้ใช้
updateUser: async (userId, userData) => {
  let conn;
  let result;

  try {
    conn = await pool.getConnection();

    await conn.beginTransaction();

    // แก้ข้อมูลในตาราง users
    const updateUserSql = `
      UPDATE users
      SET
        email = ?,
        role_id = ?,
        updated_at = NOW()
      WHERE user_id = ?
    `;

    await conn.query(updateUserSql, [
      userData.email,
      userData.role_id || 1,
      userId
    ]);

    // แก้ข้อมูลในตาราง student_profiles
    const updateProfileSql = `
      UPDATE student_profiles
      SET
        student_code = ?,
        citizen_id = ?,
        prefix = ?,
        first_name = ?,
        last_name = ?,
        birth_date = ?,
        phone = ?,
        faculty = ?,
        major = ?,
        year = ?,
        GPA = ?
      WHERE user_id = ?
    `;

    await conn.query(updateProfileSql, [
      userData.student_code,
      userData.citizen_id,
      userData.prefix,
      userData.first_name,
      userData.last_name,
      userData.birth_date,
      userData.phone,
      userData.faculty,
      userData.major,
      userData.year,
      userData.gpa,
      userId
    ]);

    await conn.commit();

    result = {
      isError: false,
      data: {
        user_id: userId
      }
    };

  } catch (error) {

    if (conn) {
      await conn.rollback();
    }

    let errorMessage = error.message;

    if (error.code === 'ER_DUP_ENTRY') {
      errorMessage = 'อีเมล / รหัสนักศึกษา / เลขบัตรประชาชนนี้ถูกใช้งานแล้ว';
    }

    result = {
      isError: true,
      errorMessage
    };

  } finally {

    if (conn) {
      conn.release();
    }

  }

  return result;
},
};