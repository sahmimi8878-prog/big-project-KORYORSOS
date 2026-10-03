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
        [documentId],
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

      const deleteResult = await conn.query(
        `DELETE FROM documents
       WHERE document_id = ? AND user_id = ?`,
        [documentId, userId],
      );

      console.log("========== DELETE DOCUMENT ==========");
      console.log("documentId:", documentId);
      console.log("userId:", userId);
      console.log("deleteResult:", deleteResult);

      if (deleteResult.affectedRows === 0) {
        result = {
          isError: true,
          errorMessage: "ไม่พบเอกสาร หรือไม่มีสิทธิ์ลบเอกสารนี้",
        };
      } else {
        result = {
          isError: false,
          errorMessage: "",
        };
      }
    } catch (error) {
      console.error("DELETE DOCUMENT MODEL ERROR:", error);

      result = {
        isError: true,
        errorMessage: error.message,
      };
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
      SELECT document_id, user_id, doc_type, doc_name, file_path,
             status, note, created_at, updated_at
      FROM documents
      ORDER BY created_at DESC`);
      result = { isError: false, data: rows };
    } catch (error) {
      //result = { isError: false === true, errorMessage: error.message };
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
