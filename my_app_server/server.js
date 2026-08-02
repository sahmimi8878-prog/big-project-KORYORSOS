const http = require('http');
const bp = require('body-parser');
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const userModel = require('./models/user');
const jwt = require('./libs/jwt');
const dateUtil = require('./libs/date_utils');
const documentModel = require('./models/document');

const app = express();

app.use(cors());
app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

const host = '127.0.0.1';
const port = 3000;

// ---- ตั้งค่าที่เก็บไฟล์อัปโหลด ----
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
        cb(null, unique + path.extname(file.originalname));
    }
});
const upload = multer({ storage });

// ให้เข้าถึงไฟล์ที่อัปโหลดผ่าน URL เช่น http://127.0.0.1:3000/uploads/xxxx.pdf
app.use('/uploads', express.static(uploadDir));

const checkAccessToken = (req, res, next) => {
    let token = null;

    if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
        token = req.headers.authorization.split(' ')[1];
    } else if (req.query && req.query.token) {
        token = req.query.token;
    } else if (req.body && req.body.token) {
        token = req.body.token;
    }

    if (!token) {
        return res.json({
            isError: true,
            errorMessage: 'ยังไม่ได้เข้าสู่ระบบ',
        });
    }

    jwt.verify(token)
        .then(decoded => {
            req.decoded = decoded;
            next();
        }, (err) => {
            res.json({
                isError: true,
                errorMessage: 'ยังไม่ได้เข้าสู่ระบบ',
            });
        });
}

app.get('/api/users/:userId', async (req, res) => {
    var userId = req.params.userId;
    var result = await userModel.getUserById(userId);
    res.send(JSON.stringify(result));
});

app.post("/api/authen/authen_request", async (req, res) => {
    console.log(req.body.authen_request);
    const authenRequest = req.body.authen_request;
    const result = await userModel.checkAuthenRequest(authenRequest);
    console.log(result);

    let response;

    if (result.isError) {
        response = { isError: true, data: "", errorMessage: result.errorMessage };
    } else {
        const payload = {
            email: result.data[0].email
        };
        const authenToken = jwt.sign(payload);
        response = {
            isError: false,
            data: authenToken,
            errorMessage: ""
        };
    }
    res.send(JSON.stringify(response));
});

app.post("/api/authen/access_request", async (req, res) => {
    const authenSignature = req.body.authen_signature;
    const authenToken = req.body.authen_token;

    var decoded = jwt.verify(authenToken);

    let response;

    if (decoded) {
        const result = await userModel.checkAccessRequest(authenSignature, authenToken);
        console.log(result);

        if (result.isError) {
            response = { isError: true, data: "", errorMessage: result.errorMessage };
        } else {
            var payload = {
                user_id: result.data[0].user_id,
                email: result.data[0].email,
                role_id: result.data[0].role_id,
                date: dateUtil.getCurrentDateForToken()
            };

            const accessToken = jwt.sign(payload);
            response = {
                isError: false,
                data: {
                    access_token: accessToken
                },
                errorMessage: ""
            }
        }
    } else {
        response = {
            isError: true,
            data: "",
            errorMessage: "ข้อมูลไม่ถูกต้อง"
        };
    }

    res.send(JSON.stringify(response));
});

app.get("/api/profile", checkAccessToken, async (req, res) => {
    console.log(req.decoded);
    const result = await userModel.getUserById(req.decoded.user_id);
    res.json(result);
});

// ---- Documents CRUD ----

app.get("/api/documents", checkAccessToken, async (req, res) => {
    const result = await documentModel.getDocumentsByUserId(req.decoded.user_id);
    res.json(result);
});

// หมายเหตุ: ฝั่ง Flutter ยิงเป็น POST ทั้งตอนเพิ่มและแก้ไข (ไม่ใช่ PUT จริง)
// เพราะ MultipartRequest ถูกสร้างด้วย method 'POST' ตรงๆ ในทั้งสองฟังก์ชัน
app.post("/api/documents", checkAccessToken, upload.single('file'), async (req, res) => {
    const { doc_type, doc_name, note } = req.body;
    const filePath = req.file ? `/uploads/${req.file.filename}` : null;

    const result = await documentModel.addDocument({
        userId: req.decoded.user_id,
        docType: doc_type,
        docName: doc_name,
        filePath,
        note: note || null
    });
    res.json(result);
});

app.post("/api/documents/:id", checkAccessToken, upload.single('file'), async (req, res) => {
    const { doc_type, doc_name, note } = req.body;
    const filePath = req.file ? `/uploads/${req.file.filename}` : null;

    const result = await documentModel.updateDocument({
        documentId: req.params.id,
        userId: req.decoded.user_id,
        docType: doc_type,
        docName: doc_name,
        filePath,
        note: note || null
    });
    res.json(result);
});

app.delete("/api/documents/:id", checkAccessToken, async (req, res) => {
    const result = await documentModel.deleteDocument({
        documentId: req.params.id,
        userId: req.decoded.user_id
    });
    res.json(result);
});

app.listen(port, host, () => {
    console.log(`Server running at http://${host}:${port}/`);
});