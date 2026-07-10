const pool = require('../libs/db_pool');
const dateUtil = require('../libs/date_utils');

module.exports = {
  getUserById: async (userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `SELECT user_id, username, firstname, lastname, role_id FROM users WHERE user_id = ?`;

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
      if (conn)
        conn.release();
    }

    return result;
  },

  checkAuthenRequest: async (authenRequest) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `
        SELECT username
        FROM users
        WHERE SHA2(CONCAT(username, '&', ?), 256) = ?`;

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
        SELECT user_id, username, firstname, lastname, role_id FROM users
        WHERE SHA2(CONCAT(username, '&', password, '&', ?), 256) = ?`;

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
};