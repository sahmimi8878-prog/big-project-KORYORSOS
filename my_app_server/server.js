const http = require("http");
const path = require("path");
const fs = require("fs");
const multer = require("multer");
const bp = require("body-parser");
const express = require("express");
const cors = require("cors");
const userModel = require("./models/user");
const documentModel = require("./models/document");
const jwt = require("./libs/jwt");
const dateUtil = require("./libs/date_utils");
const app = express();

app.use(
  cors({
    origin: true,
  }),
);
app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

const host = "127.0.0.1";
const port = 3000;

// ---- ตั้งค่าที่เก็บไฟล์อัปโหลด ----
const uploadDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, unique + path.extname(file.originalname));
  },
});
const upload = multer({ storage });

// ให้เข้าถึงไฟล์ที่อัปโหลดผ่าน URL เช่น http://127.0.0.1:3000/uploads/xxxx.pdf
app.use("/uploads", express.static(uploadDir));

// ======================================================
// ตรวจสอบ Access Token
// ======================================================
const checkAccessToken = (req, res, next) => {
  let token = null;

  // Authorization: Bearer token
  if (
    req.headers.authorization &&
    req.headers.authorization.split(" ")[0] === "Bearer"
  ) {
    token = req.headers.authorization.split(" ")[1];
  }

  // ?token=...
  else if (req.query && req.query.token) {
    token = req.query.token;
  }

  // body token
  else if (req.body && req.body.token) {
    token = req.body.token;
  }

  // ไม่มี token
  if (!token) {
    return res.status(401).json({
      isError: true,
      errorMessage: "ยังไม่ได้เข้าสู่ระบบ",
    });
  }

  // ตรวจสอบ token
  jwt
    .verify(token)
    .then((decoded) => {
      req.decoded = decoded;
      next();
    })
    .catch((err) => {
      return res.status(401).json({
        isError: true,
        errorMessage: "Session หมดอายุหรือ Token ไม่ถูกต้อง",
      });
    });
};

// ======================================================
// ตรวจสอบว่าเป็นเจ้าหน้าที่
// role_id = 2
// ======================================================
const checkOfficer = (req, res, next) => {
  if (!req.decoded) {
    return res.status(401).json({
      isError: true,
      errorMessage: "ยังไม่ได้เข้าสู่ระบบ",
    });
  }

  if (req.decoded.role_id !== 2) {
    return res.status(403).json({
      isError: true,
      errorMessage: "ไม่มีสิทธิ์ดำเนินการนี้ เฉพาะเจ้าหน้าที่เท่านั้น",
    });
  }

  next();
};

// ======================================================
// LOGIN
// ======================================================

// Login ขั้นที่ 1
app.post("/api/authen/authen_request", async (req, res) => {
  console.log(req.body.authen_request);

  const authenRequest = req.body.authen_request;

  const result = await userModel.checkAuthenRequest(authenRequest);

  console.log(result);

  let response;

  if (result.isError) {
    response = {
      isError: true,
      data: "",
      errorMessage: result.errorMessage,
    };
  } else {
    const payload = {
      email: result.data[0].email,
    };

    const authenToken = jwt.sign(payload);

    response = {
      isError: false,
      data: authenToken,
      errorMessage: "",
    };
  }

  res.json(response);
});

// Login ขั้นที่ 2
app.post("/api/authen/access_request", async (req, res) => {
  const authenSignature = req.body.authen_signature;
  const authenToken = req.body.authen_token;

  let decoded;

  try {
    decoded = await jwt.verify(authenToken);
  } catch (error) {
    decoded = null;
  }

  let response;

  if (decoded) {
    const result = await userModel.checkAccessRequest(
      authenSignature,
      authenToken,
    );

    console.log(result);

    if (result.isError) {
      response = {
        isError: true,
        data: "",
        errorMessage: result.errorMessage,
      };
    } else {
      const payload = {
        user_id: result.data[0].user_id,
        email: result.data[0].email,
        role_id: result.data[0].role_id,
        date: dateUtil.getCurrentDateForToken(),
      };

      const accessToken = jwt.sign(payload);

      response = {
        isError: false,
        data: {
          access_token: accessToken,
          role_id: result.data[0].role_id,
        },
        errorMessage: "",
      };
    }
  } else {
    response = {
      isError: true,
      data: "",
      errorMessage: "ข้อมูลไม่ถูกต้อง",
    };
  }

  res.json(response);
});

// เจ้าหน้าที่: ดูเอกสารทั้งหมด
app.get(
    '/api/officer/documents',
    checkAccessToken,
    checkOfficer,
    async (req, res) => {
        const result = await documentModel.getAllDocuments();
        res.json(result);
    }
);

// ======================================================
// PROFILE
// ผู้ใช้ทุก Role ดูข้อมูลตัวเองได้
// ======================================================

app.get("/api/profile", checkAccessToken, async (req, res) => {
  console.log(req.decoded);

  const result = await userModel.getUserById(req.decoded.user_id);

  res.json(result);
});

app.post("/api/register", async (req, res) => {
  const userData = {
    ...req.body,

    // สมัครสมาชิกทั่วไป = นักศึกษาเท่านั้น
    role_id: 1,
  };

  const result = await userModel.createUser(userData);

  res.json(result);
});

// ======================================================
// DOCUMENTS
// ======================================================

// ดูเอกสารของตัวเอง
app.get("/api/documents", checkAccessToken, async (req, res) => {
  const result = await documentModel.getDocumentsByUserId(req.decoded.user_id);

  res.json(result);
});

// เพิ่มเอกสาร
app.post(
  "/api/documents",
  checkAccessToken,
  upload.single("file"),
  async (req, res) => {
    try {
      console.log("========== ADD DOCUMENT ==========");
      console.log("User:", req.decoded);
      console.log("Body:", req.body);
      console.log("File:", req.file);

      if (!req.file) {
        return res.status(400).json({
          isError: true,
          data: null,
          errorMessage: "กรุณาแนบไฟล์เอกสาร",
        });
      }

      const result = await documentModel.addDocument({
        userId: req.decoded.user_id,
        docType: req.body.doc_type,
        docName: req.body.doc_name,
        filePath: `/uploads/${req.file.filename}`,
        note: req.body.note || null,
      });

      if (result.isError) {
        return res.status(400).json(result);
      }

      return res.status(201).json(result);
    } catch (error) {
      console.error("ADD DOCUMENT ERROR:", error);

      return res.status(500).json({
        isError: true,
        data: null,
        errorMessage: error.message,
      });
    }
  },
);

// แก้ไขเอกสาร
app.put(
    '/api/documents/:id',
    checkAccessToken,
    upload.single('file'),
    async (req, res) => {
        try {
            const documentId = parseInt(req.params.id);
            if (isNaN(documentId)) {
                return res.status(400).json({
                    isError: true,
                    errorMessage: 'document_id ไม่ถูกต้อง'
                });
            }

            const result = await documentModel.updateDocument({
                documentId: documentId,
                userId: req.decoded.user_id,
                docType: req.body.doc_type,
                docName: req.body.doc_name,
                filePath: req.file ? `/uploads/${req.file.filename}` : null,
                note: req.body.note || null
            });

            if (result.isError || !result.data) {
                return res.status(404).json({
                    isError: true,
                    errorMessage: result.errorMessage || 'ไม่พบเอกสาร หรือไม่มีสิทธิ์แก้ไข'
                });
            }
            return res.status(200).json(result);
        } catch (error) {
            console.error('UPDATE DOCUMENT ERROR:', error);
            return res.status(500).json({ isError: true, errorMessage: error.message });
        }
    }
);

// ======================================================
// ลบเอกสาร
// ผู้ใช้ลบเอกสารของตัวเองได้
// ======================================================

app.delete("/api/documents/:id", checkAccessToken, async (req, res) => {
  try {
    const documentId = parseInt(req.params.id);

    if (isNaN(documentId)) {
      return res.status(400).json({
        isError: true,
        errorMessage: "document_id ไม่ถูกต้อง",
      });
    }

    const result = await documentModel.deleteDocument({
      documentId: documentId,
      userId: req.decoded.user_id,
    });

    if (result.isError) {
      return res.status(404).json(result);
    }

    return res.status(200).json({
      isError: false,
      errorMessage: "",
    });
  } catch (error) {
    console.error("DELETE DOCUMENT ERROR:", error);

    return res.status(500).json({
      isError: true,
      errorMessage: error.message,
    });
  }
});

// เจ้าหน้าที่: อนุมัติ / ปฏิเสธ
app.put(
    '/api/officer/documents/:id/status',
    checkAccessToken,
    checkOfficer,
    async (req, res) => {
        const documentId = parseInt(req.params.id);
        const { status, note } = req.body;

        if (isNaN(documentId) || !['approved', 'rejected', 'pending'].includes(status)) {
            return res.status(400).json({ isError: true, errorMessage: 'ข้อมูลไม่ถูกต้อง' });
        }

        const result = await documentModel.updateStatus({
            documentId, status, note: note || null
        });
        return res.status(result.isError ? 404 : 200).json(result);
    }
);

app.listen(port, host, () => {
  console.log(`Server running at http://${host}:${port}/`);
});
