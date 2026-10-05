const fs = require("fs");
const path = require("path");
const pool = require("../libs/db_pool");

module.exports = {
  getDocumentsByUserId: async (userId) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `
      SELECT
        document_id,
        doc_type,
        doc_name,
        file_path,
        status,
        note,
        created_at,
        updated_at
      FROM documents
      WHERE user_id = ?
      ORDER BY created_at DESC`;

      const rows = await conn.query(sql, [userId]);

      result = {
        isError: false,
        data: rows,
      };
    } catch (error) {
      result = {
        isError: true,
        errorMessage: error.message,
      };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

  addDocument: async ({ userId, docType, docName, filePath, note }) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      const sql = `
        INSERT INTO documents (user_id, doc_type, doc_name, file_path, status, note, created_at, updated_at)
        VALUES (?, ?, ?, ?, 'pending', ?, NOW(), NOW())`;

      const insertResult = await conn.query(sql, [
        userId,
        docType,
        docName,
        filePath,
        note,
      ]);

      const rows = await conn.query(
        `SELECT document_id, doc_type, doc_name, file_path, status, note, created_at, updated_at
         FROM documents WHERE document_id = ?`,
        [insertResult.insertId],
      );

      result = { isError: false, data: rows[0] };
    } catch (error) {
      result = { isError: true, errorMessage: error.message };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

    updateDocument: async ({
    documentId,
    userId,
    docType,
    docName,
    filePath,
    note,
  }) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      // เช็กก่อนว่าเอกสารนี้เป็นของผู้ใช้คนนี้จริง
      const owner = await conn.query(
        `SELECT document_id FROM documents
         WHERE document_id = ? AND user_id = ?`,
        [documentId, userId],
      );

      if (owner.length === 0) {
        return {
          isError: true,
          errorMessage: "ไม่พบเอกสาร หรือไม่มีสิทธิ์แก้ไขเอกสารนี้",
        };
      }

      let sql, params;
      if (filePath) {
        sql = `
          UPDATE documents
          SET doc_type = ?, doc_name = ?, file_path = ?, note = ?, updated_at = NOW()
          WHERE document_id = ? AND user_id = ?`;
        params = [docType, docName, filePath, note, documentId, userId];
      } else {
        sql = `
          UPDATE documents
          SET doc_type = ?, doc_name = ?, note = ?, updated_at = NOW()
          WHERE document_id = ? AND user_id = ?`;
        params = [docType, docName, note, documentId, userId];
      }

      await conn.query(sql, params);

      const rows = await conn.query(
        `SELECT document_id, doc_type, doc_name, file_path, status, note, created_at, updated_at
         FROM documents WHERE document_id = ? AND user_id = ?`,
        [documentId, userId],
      );

      result = { isError: false, data: rows[0] };
    } catch (error) {
      result = { isError: true, errorMessage: error.message };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },

    deleteDocument: async ({ documentId, userId }) => {
    let conn;
    let result;

    try {
      conn = await pool.getConnection();

      // ดึง path ไฟล์ก่อนลบแถว (เช็กเจ้าของด้วย user_id)
      const rows = await conn.query(
        `SELECT file_path FROM documents
         WHERE document_id = ? AND user_id = ?`,
        [documentId, userId],
      );

      if (rows.length === 0) {
        return {
          isError: true,
          errorMessage: "ไม่พบเอกสาร หรือไม่มีสิทธิ์ลบเอกสารนี้",
        };
      }

      const filePath = rows[0].file_path;

      await conn.query(
        `DELETE FROM documents
         WHERE document_id = ? AND user_id = ?`,
        [documentId, userId],
      );

      // ลบไฟล์จริงออกจากโฟลเดอร์ uploads
      // ใช้ basename กัน path แปลก ๆ หลุดออกนอกโฟลเดอร์
      if (filePath) {
        const fileName = path.basename(filePath);
        const fullPath = path.join(__dirname, "..", "uploads", fileName);
        fs.unlink(fullPath, (err) => {
          if (err && err.code !== "ENOENT") {
            console.error("DELETE FILE ERROR:", err.message);
          }
        });
      }

      result = { isError: false, errorMessage: "" };
    } catch (error) {
      console.error("DELETE DOCUMENT MODEL ERROR:", error);
      result = { isError: true, errorMessage: error.message };
    } finally {
      if (conn) conn.release();
    }

    return result;
  },
  
    getAllDocuments: async () => {
    let conn;
    let result;
    try {
      conn = await pool.getConnection();
      const rows = await conn.query(`
      SELECT d.document_id, d.user_id, d.doc_type, d.doc_name, d.file_path,
             d.status, d.note, d.created_at, d.updated_at,
             sp.student_code, sp.prefix, sp.first_name, sp.last_name
      FROM documents d
      LEFT JOIN student_profiles sp ON sp.user_id = d.user_id
      ORDER BY d.created_at DESC`);
      result = { isError: false, data: rows };
    } catch (error) {
      result = { isError: true, errorMessage: error.message };
    } finally {
      if (conn) conn.release();
    }
    return result;
  },
  updateStatus: async ({ documentId, status, note }) => {
  let conn;
  let result;
  try {
    conn = await pool.getConnection();
    const r = await conn.query(
      `UPDATE documents SET status = ?, note = ?, updated_at = NOW()
       WHERE document_id = ?`,
      [status, note, documentId]
    );
    if (r.affectedRows === 0) {
      result = { isError: true, errorMessage: 'ไม่พบเอกสาร' };
    } else {
      result = { isError: false, errorMessage: '' };
    }
  } catch (error) {
    result = { isError: true, errorMessage: error.message };
  } finally {
    if (conn) conn.release();
  }
  return result;
},
};
