const http = require('http');
const bp = require('body-parser');
const express = require('express');
const cors = require('cors');
const userModel = require('./models/user');
const jwt = require('./libs/jwt');
const dateUtil = require('./libs/date_utils');
const app = express();

app.use(cors({
    origin: true
}));
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

// ======================================================
// ตรวจสอบ Access Token
// ======================================================
const checkAccessToken = (req, res, next) => {
    let token = null;

    // Authorization: Bearer token
    if (
        req.headers.authorization &&
        req.headers.authorization.split(' ')[0] === 'Bearer'
    ) {
        token = req.headers.authorization.split(' ')[1];
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
            errorMessage: 'ยังไม่ได้เข้าสู่ระบบ',
        });
    }

    // ตรวจสอบ token
    jwt.verify(token)
        .then(decoded => {
            req.decoded = decoded;
            next();
        })
        .catch(err => {
            return res.status(401).json({
                isError: true,
                errorMessage: 'Session หมดอายุหรือ Token ไม่ถูกต้อง',
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
            errorMessage: 'ยังไม่ได้เข้าสู่ระบบ',
        });
    }

    if (req.decoded.role_id !== 2) {
        return res.status(403).json({
            isError: true,
            errorMessage: 'ไม่มีสิทธิ์ดำเนินการนี้ เฉพาะเจ้าหน้าที่เท่านั้น',
        });
    }

    next();
};


// ======================================================
// LOGIN
// ======================================================

// Login ขั้นที่ 1
app.post('/api/authen/authen_request', async (req, res) => {

    console.log(req.body.authen_request);

    const authenRequest = req.body.authen_request;

    const result = await userModel.checkAuthenRequest(authenRequest);

    console.log(result);

    let response;

    if (result.isError) {

        response = {
            isError: true,
            data: '',
            errorMessage: result.errorMessage
        };

    } else {

        const payload = {
            email: result.data[0].email
        };

        const authenToken = jwt.sign(payload);

        response = {
            isError: false,
            data: authenToken,
            errorMessage: ''
        };
    }

    res.json(response);
});


// Login ขั้นที่ 2
app.post('/api/authen/access_request', async (req, res) => {

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
            authenToken
        );

        console.log(result);

        if (result.isError) {

            response = {
                isError: true,
                data: '',
                errorMessage: result.errorMessage
            };

        } else {

            const payload = {
                user_id: result.data[0].user_id,
                email: result.data[0].email,
                role_id: result.data[0].role_id,
                date: dateUtil.getCurrentDateForToken()
            };

            const accessToken = jwt.sign(payload);

            response = {
                isError: false,
                data: {
                    access_token: accessToken,
                    role_id: result.data[0].role_id
                },
                errorMessage: ''
            };
        }

    } else {

        response = {
            isError: true,
            data: '',
            errorMessage: 'ข้อมูลไม่ถูกต้อง'
        };
    }

    res.json(response);
});


// ======================================================
// PROFILE
// ผู้ใช้ทุก Role ดูข้อมูลตัวเองได้
// ======================================================

app.get('/api/profile', checkAccessToken, async (req, res) => {

    console.log(req.decoded);

    const result = await userModel.getUserById(
        req.decoded.user_id
    );

    res.json(result);
});

app.post('/api/register', async (req, res) => {

    const userData = {
        ...req.body,

        // สมัครสมาชิกทั่วไป = นักศึกษาเท่านั้น
        role_id: 1
    };

    const result = await userModel.createUser(userData);

    res.json(result);
});


// ======================================================
// START SERVER
// ======================================================

app.listen(port, host, () => {
    console.log(
        `Server running at http://${host}:${port}/`
    );
});