const http = require("http");
const bp = require("body-parser");
const express = require("express");
const cors = require("cors");

const documentModel = require("./models/document");
const userModel = require("./models/user");
const bookings = require("./models/bookings");

const path = require("path");
const fs = require("fs");
const multer = require("multer");

const jwt = require("./libs/jwt");
const dateUtil = require("./libs/date_utils");

const app = express();

// ======================================================
// CORS
// ======================================================

app.use(
  cors({
    origin: true,
  }),
);

app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

// ======================================================
// SERVER
// ======================================================

const host = "127.0.0.1";
const port = 3000;

// ======================================================
// UPLOAD
// ======================================================

const uploadDir = path.join(__dirname, "uploads");

if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },

  filename: (req, file, cb) => {
    const unique =
      Date.now() + "-" + Math.round(Math.random() * 1e9);

    cb(null, unique + path.extname(file.originalname));
  },
});

const upload = multer({
  storage,
});

// เปิดไฟล์จาก /uploads/ชื่อไฟล์
app.use("/uploads", express.static(uploadDir));

// ======================================================
// CHECK ACCESS TOKEN
// ======================================================

const checkAccessToken = (req, res, next) => {
  let token = null;

  // ------------------------------------------
  // Authorization: Bearer token
  // ------------------------------------------

  if (
    req.headers.authorization &&
    req.headers.authorization.split(" ")[0] === "Bearer"
  ) {
    token = req.headers.authorization.split(" ")[1];
  }

  // ------------------------------------------
  // ?token=...
  // ------------------------------------------
  else if (req.query && req.query.token) {
    token = req.query.token;
  }

  // ------------------------------------------
  // body token
  // ------------------------------------------
  else if (req.body && req.body.token) {
    token = req.body.token;
  }

  // ------------------------------------------
  // ไม่มี token
  // ------------------------------------------

  if (!token) {
    return res.status(401).json({
      isError: true,

      errorMessage: "ยังไม่ได้เข้าสู่ระบบ",
    });
  }

  // ------------------------------------------
  // ตรวจสอบ token
  // ------------------------------------------

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
// CHECK OFFICER
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
// AUTHEN
// ======================================================

// ------------------------------------------------------
// Login ขั้นที่ 1
// ------------------------------------------------------

app.post("/api/authen/authen_request", async (req, res) => {
  try {
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
  } catch (error) {
    console.error("AUTHEN REQUEST ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: error.message,
    });
  }
});

// ------------------------------------------------------
// Login ขั้นที่ 2
// ------------------------------------------------------

app.post("/api/authen/access_request", async (req, res) => {
  try {
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
  } catch (error) {
    console.error("ACCESS REQUEST ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: error.message,
    });
  }
});

// ======================================================
// PROFILE
// ======================================================

// ------------------------------------------------------
// ดู Profile
// ------------------------------------------------------

app.get("/api/profile", checkAccessToken, async (req, res) => {
  try {
    console.log(req.decoded);

    const result = await userModel.getUserById(req.decoded.user_id);

    res.json(result);
  } catch (error) {
    console.error("GET PROFILE ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: error.message,
    });
  }
});

// ------------------------------------------------------
// แก้ไข Profile
// ------------------------------------------------------

app.put("/api/profile", checkAccessToken, async (req, res) => {
  try {
    const currentUser = await userModel.getUserById(req.decoded.user_id);

    if (
      currentUser.isError ||
      !currentUser.data ||
      currentUser.data.length === 0
    ) {
      return res.status(404).json({
        isError: true,

        errorMessage: "ไม่พบข้อมูลผู้ใช้",
      });
    }

    const oldData = currentUser.data[0];

    const userData = {
      email: oldData.email,

      student_code: oldData.student_code,

      citizen_id: oldData.citizen_id,

      prefix: oldData.prefix,

      first_name: oldData.first_name,

      last_name: oldData.last_name,

      birth_date: oldData.birth_date,

      phone: oldData.phone,

      faculty: oldData.faculty,

      major: oldData.major,

      year: oldData.year,

      gpa: oldData.GPA,

      role_id: req.decoded.role_id,

      ...req.body,
    };

    // ห้ามเปลี่ยน email
    userData.email = oldData.email;

    // ห้ามเปลี่ยน role
    userData.role_id = req.decoded.role_id;

    const result = await userModel.updateUser(req.decoded.user_id, userData);

    res.json(result);
  } catch (error) {
    console.error("UPDATE PROFILE ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: "ไม่สามารถแก้ไขข้อมูลส่วนตัวได้",
    });
  }
});

// ------------------------------------------------------
// อัปโหลดรูป Profile
// ------------------------------------------------------

app.post(
  "/api/profile/image",

  checkAccessToken,

  upload.single("profile_image"),

  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          isError: true,

          errorMessage: "กรุณาเลือกรูปภาพ",
        });
      }

      const imageUrl = `/uploads/${req.file.filename}`;

      const result = await userModel.updateProfileImage(
        req.decoded.user_id,
        imageUrl,
      );

      res.json({
        ...result,

        image_url: imageUrl,
      });
    } catch (error) {
      console.error("PROFILE IMAGE ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: "ไม่สามารถอัปโหลดรูปโปรไฟล์ได้",
      });
    }
  },
);

// ======================================================
// REGISTER
// ======================================================

app.post("/api/register", async (req, res) => {
  try {
    const userData = {
      ...req.body,

      // สมัครสมาชิกทั่วไป
      // = นักศึกษา
      role_id: 1,
    };

    const result = await userModel.createUser(userData);

    res.json(result);
  } catch (error) {
    console.error("REGISTER ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: error.message,
    });
  }
});

// ======================================================
// DOCUMENTS
// ======================================================

// ------------------------------------------------------
// นักศึกษา: ดูเอกสารของตัวเอง
// ------------------------------------------------------

app.get("/api/documents", checkAccessToken, async (req, res) => {
  try {
    const result = await documentModel.getDocumentsByUserId(
      req.decoded.user_id,
    );

    res.json(result);
  } catch (error) {
    console.error("GET DOCUMENTS ERROR:", error);

    res.status(500).json({
      isError: true,

      errorMessage: error.message,
    });
  }
});

// ------------------------------------------------------
// นักศึกษา: เพิ่มเอกสาร
// ------------------------------------------------------

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

// ------------------------------------------------------
// นักศึกษา: แก้ไขเอกสาร
// ------------------------------------------------------

app.put(
  "/api/documents/:id",

  checkAccessToken,

  upload.single("file"),

  async (req, res) => {
    try {
      const documentId = parseInt(req.params.id);

      if (isNaN(documentId)) {
        return res.status(400).json({
          isError: true,

          errorMessage: "document_id ไม่ถูกต้อง",
        });
      }

      const result = await documentModel.updateDocument({
        documentId: documentId,

        userId: req.decoded.user_id,

        docType: req.body.doc_type,

        docName: req.body.doc_name,

        filePath: req.file ? `/uploads/${req.file.filename}` : null,

        note: req.body.note || null,
      });

      if (result.isError || !result.data) {
        return res.status(404).json({
          isError: true,

          errorMessage:
            result.errorMessage || "ไม่พบเอกสาร หรือไม่มีสิทธิ์แก้ไข",
        });
      }

      return res.status(200).json(result);
    } catch (error) {
      console.error("UPDATE DOCUMENT ERROR:", error);

      return res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// นักศึกษา: ลบเอกสาร
// ------------------------------------------------------

app.delete(
  "/api/documents/:id",

  checkAccessToken,

  async (req, res) => {
    try {
      const documentId = parseInt(req.params.id);

      if (isNaN(documentId)) {
        return res.status(400).json({
          isError: true,

          errorMessage: "document_id ไม่ถูกต้อง",
        });
      }

      console.log("DELETE DOCUMENT ID:", documentId);

      console.log("USER ID:", req.decoded.user_id);

      const result = await documentModel.deleteDocument({
        documentId: documentId,

        userId: req.decoded.user_id,
      });

      console.log("DELETE RESULT:", result);

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
  },
);

// ------------------------------------------------------
// เจ้าหน้าที่: ดูเอกสารทั้งหมด
// ------------------------------------------------------

app.get(
  "/api/officer/documents",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await documentModel.getAllDocuments();

      res.json(result);
    } catch (error) {
      console.error("GET ALL DOCUMENTS ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// เจ้าหน้าที่: อนุมัติ / ปฏิเสธเอกสาร
// ------------------------------------------------------

app.put(
  "/api/officer/documents/:id/status",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const documentId = parseInt(req.params.id);

      const { status, note } = req.body;

      if (
        isNaN(documentId) ||
        !["approved", "rejected", "pending"].includes(status)
      ) {
        return res.status(400).json({
          isError: true,

          errorMessage: "ข้อมูลไม่ถูกต้อง",
        });
      }

      const result = await documentModel.updateStatus({
        documentId: documentId,

        status: status,

        note: note || null,
      });

      return res.status(result.isError ? 404 : 200).json(result);
    } catch (error) {
      console.error("UPDATE DOCUMENT STATUS ERROR:", error);

      return res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ======================================================
// USERS
// เฉพาะเจ้าหน้าที่
// ======================================================

// ------------------------------------------------------
// ดูผู้ใช้ทั้งหมด
// ------------------------------------------------------

app.get(
  "/api/users",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await userModel.getUsers();

      res.json(result);
    } catch (error) {
      console.error("GET USERS ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// นับจำนวนผู้ใช้ตาม Role
// ------------------------------------------------------

app.get(
  "/api/users/count_by_role",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await userModel.countUsersByRole();

      res.json(result);
    } catch (error) {
      console.error("COUNT USERS ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// ดูผู้ใช้ตาม ID
// ------------------------------------------------------

app.get(
  "/api/users/:userId",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await userModel.getUserById(req.params.userId);

      res.json(result);
    } catch (error) {
      console.error("GET USER ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// เพิ่มผู้ใช้
// ------------------------------------------------------

app.post(
  "/api/users",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await userModel.createUser(req.body);

      res.json(result);
    } catch (error) {
      console.error("CREATE USER ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// แก้ไขผู้ใช้
// ------------------------------------------------------

app.put(
  "/api/users/:userId",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      const result = await userModel.updateUser(req.params.userId, req.body);

      res.json(result);
    } catch (error) {
      console.error("UPDATE USER ERROR:", error);

      res.status(500).json({
        isError: true,

        errorMessage: error.message,
      });
    }
  },
);

// ------------------------------------------------------
// ลบผู้ใช้
// ------------------------------------------------------

app.delete(
  "/api/users/:userId",

  checkAccessToken,

  checkOfficer,

  async (req, res) => {
    try {
      // กันเจ้าหน้าที่ลบตัวเอง
      if (Number(req.params.userId) === req.decoded.user_id) {
        return res.json({
          isError: true,

          errorMessage: "ไม่สามารถลบบัญชีของตัวเองได้",
        });
      }

    res.json(await userModel.deleteUser(req.params.userId));
});
app.listen(port, host, () => {
  console.log(`Server running at http://${host}:${port}/`);
});
