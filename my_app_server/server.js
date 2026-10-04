const http = require('http');
const bp = require('body-parser');
const express = require('express');
const cors = require('cors');
const documentModel = require('./models/document');
const userModel = require('./models/user');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const bookings = require('./models/bookings');
const jwt = require('./libs/jwt');
const dateUtil = require('./libs/date_utils');

const app = express();
const host = '127.0.0.1';
const port = 3000;

app.use(cors({ origin: true }));
app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

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
        return res.status(401).json({
            isError: true,
            errorMessage: 'ยังไม่ได้เข้าสู่ระบบ'
        });
    }

    jwt.verify(token)
        .then(decoded => {
            req.decoded = decoded;
            next();
        })
        .catch(err => {
            return res.status(401).json({
                isError: true,
                errorMessage: 'Session หมดอายุหรือ Token ไม่ถูกต้อง'
            });
        });
};

const checkOfficer = (req, res, next) => {
    if (!req.decoded) {
        return res.status(401).json({
            isError: true,
            errorMessage: 'ยังไม่ได้เข้าสู่ระบบ'
        });
    }

    if (req.decoded.role_id !== 2) {
        return res.status(403).json({
            isError: true,
            errorMessage: 'ไม่มีสิทธิ์ดำเนินการนี้ เฉพาะเจ้าหน้าที่เท่านั้น'
        });
    }

    next();
};

app.post('/api/authen/authen_request', async (req, res) => {
    console.log(req.body.authen_request);

    const result = await userModel.checkAuthenRequest(req.body.authen_request);
    console.log(result);

    let response;

    if (result.isError) {
        response = {
            isError: true,
            data: '',
            errorMessage: result.errorMessage
        };
    } else {
        const authenToken = jwt.sign({ email: result.data[0].email });

        response = {
            isError: false,
            data: authenToken,
            errorMessage: ''
        };
    }

    res.json(response);
});

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
        const result = await userModel.checkAccessRequest(authenSignature, authenToken);
        console.log(result);

        if (result.isError) {
            response = {
                isError: true,
                data: '',
                errorMessage: result.errorMessage
            };
        } else {
            const data = result.data[0];
            const accessToken = jwt.sign({
                user_id: data.user_id,
                email: data.email,
                role_id: data.role_id,
                date: dateUtil.getCurrentDateForToken()
            });

            response = {
                isError: false,
                data: {
                    access_token: accessToken,
                    role_id: data.role_id
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

app.get('/api/profile', checkAccessToken, async (req, res) => {
    console.log(req.decoded);
    const result = await userModel.getUserById(req.decoded.user_id);
    res.json(result);
});

app.put('/api/profile', checkAccessToken, async (req, res) => {
    try {
        const currentUser = await userModel.getUserById(req.decoded.user_id);

        if (currentUser.isError || !currentUser.data || currentUser.data.length === 0) {
            return res.status(404).json({
                isError: true,
                errorMessage: 'ไม่พบข้อมูลผู้ใช้'
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
            ...req.body
        };

        userData.email = oldData.email;
        userData.role_id = req.decoded.role_id;

        const result = await userModel.updateUser(req.decoded.user_id, userData);
        res.json(result);
    } catch (error) {
        console.error(error);
        res.status(500).json({
            isError: true,
            errorMessage: 'ไม่สามารถแก้ไขข้อมูลส่วนตัวได้'
        });
    }
});

app.post('/api/profile/image', checkAccessToken, upload.single('profile_image'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                isError: true,
                errorMessage: 'กรุณาเลือกรูปภาพ'
            });
        }

        const imageUrl = `/uploads/${req.file.filename}`;
        const result = await userModel.updateProfileImage(req.decoded.user_id, imageUrl);

        res.json({ ...result, image_url: imageUrl });
    } catch (error) {
        console.error(error);
        res.status(500).json({
            isError: true,
            errorMessage: 'ไม่สามารถอัปโหลดรูปโปรไฟล์ได้'
        });
    }
});

app.post('/api/register', async (req, res) => {
    const userData = { ...req.body, role_id: 1 };
    const result = await userModel.createUser(userData);
    res.json(result);
});

// ===== เอกสาร =====

app.get('/api/documents', checkAccessToken, async (req, res) => {
    const result = await documentModel.getDocumentsByUserId(req.decoded.user_id);
    res.json(result);
});

// เจ้าหน้าที่: ดูเอกสารของทุกคน (ต้องอยู่ก่อน /:id)
app.get('/api/admin/documents', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await documentModel.getAllDocuments());
});

// เจ้าหน้าที่: เปลี่ยนสถานะเอกสาร + หมายเหตุ
app.put('/api/admin/documents/:id/status', checkAccessToken, checkOfficer, async (req, res) => {
    const { status, note } = req.body;

    if (!status) {
        return res.json({ isError: true, errorMessage: 'กรุณาระบุสถานะ' });
    }

    res.json(await documentModel.updateStatus({
        documentId: req.params.id,
        status,
        note: note || ''
    }));
});

// ดึงเอกสารรายตัวตาม id (เฉพาะเอกสารของผู้ใช้ที่ล็อกอิน)
app.get('/api/documents/:id', checkAccessToken, async (req, res) => {
    const result = await documentModel.getDocumentsByUserId(req.decoded.user_id);

    if (result.isError) return res.json(result);

    const doc = (result.data || []).find(
        d => String(d.document_id) === String(req.params.id)
    );

    res.json(
        doc
            ? { isError: false, data: [doc], errorMessage: '' }
            : { isError: true, data: '', errorMessage: 'ไม่พบเอกสาร' }
    );
});

// ยื่นเอกสารใหม่ (multipart/form-data: ไฟล์ชื่อ field "file" + doc_type, doc_name, note)
app.post('/api/documents', checkAccessToken, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                isError: true,
                errorMessage: 'กรุณาเลือกไฟล์เอกสาร'
            });
        }

        const { doc_type, doc_name, note } = req.body;

        res.json(await documentModel.addDocument({
            userId: req.decoded.user_id,
            docType: doc_type,
            docName: doc_name || req.file.originalname,
            filePath: `/uploads/${req.file.filename}`,
            note: note || ''
        }));
    } catch (error) {
        console.error(error);
        res.status(500).json({
            isError: true,
            errorMessage: 'ไม่สามารถยื่นเอกสารได้'
        });
    }
});

// แก้ไขเอกสาร (ไม่แนบไฟล์ใหม่ = ใช้ไฟล์เดิม)
app.put('/api/documents/:id', checkAccessToken, upload.single('file'), async (req, res) => {
    try {
        const { doc_type, doc_name, note } = req.body;

        res.json(await documentModel.updateDocument({
            documentId: req.params.id,
            userId: req.decoded.user_id,
            docType: doc_type,
            docName: doc_name,
            filePath: req.file ? `/uploads/${req.file.filename}` : null,
            note: note || ''
        }));
    } catch (error) {
        console.error(error);
        res.status(500).json({
            isError: true,
            errorMessage: 'ไม่สามารถแก้ไขเอกสารได้'
        });
    }
});

// ลบเอกสาร (ลบทั้งแถวและไฟล์จริง)
app.delete('/api/documents/:id', checkAccessToken, async (req, res) => {
    res.json(await documentModel.deleteDocument({
        documentId: req.params.id,
        userId: req.decoded.user_id
    }));
});

// ===== ผู้ใช้ (เฉพาะเจ้าหน้าที่) =====

app.get('/api/users', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await userModel.getUsers());
});

app.get('/api/users/count_by_role', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await userModel.countUsersByRole());
});

app.get('/api/users/:userId', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await userModel.getUserById(req.params.userId));
});

app.post('/api/users', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await userModel.createUser(req.body));
});

app.put('/api/users/:userId', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await userModel.updateUser(req.params.userId, req.body));
});

app.delete('/api/users/:userId', checkAccessToken, checkOfficer, async (req, res) => {
    if (Number(req.params.userId) === Number(req.decoded.user_id)) {
        return res.json({
            isError: true,
            errorMessage: 'ไม่สามารถลบบัญชีของตัวเองได้'
        });
    }

    res.json(await userModel.deleteUser(req.params.userId));
});

// ===== จองคิว =====
// /list และ /slots ต้องอยู่ก่อน /:bookingId

app.get('/api/bookings/list', checkAccessToken, async (req, res) => {
    res.json(await bookings.getBookings(req.decoded.user_id));
});

app.get('/api/bookings/slots', checkAccessToken, async (req, res) => {
    res.json(await bookings.getSlotCounts(req.query.date));
});

app.get('/api/bookings/open-days', checkAccessToken, async (req, res) => {
    res.json(await bookings.getOpenDays());
});

app.get('/api/bookings/:bookingId', checkAccessToken, async (req, res) => {
    res.json(await bookings.getBookingById(req.params.bookingId, req.decoded.user_id));
});

app.post('/api/bookings/create', checkAccessToken, async (req, res) => {
    const { service_type, booking_date, time_slot } = req.body;

    res.json(await bookings.createBooking(
        req.decoded.user_id, service_type, booking_date, time_slot
    ));
});

app.post('/api/bookings/update', checkAccessToken, async (req, res) => {
    const { booking_id, service_type, booking_date, time_slot } = req.body;

    res.json(await bookings.updateBooking(
        req.decoded.user_id, booking_id, service_type, booking_date, time_slot
    ));
});

app.post('/api/bookings/delete', checkAccessToken, async (req, res) => {
    res.json(await bookings.deleteBooking(req.body.booking_id, req.decoded.user_id));
});

// ===== จัดการการจอง (เฉพาะเจ้าหน้าที่) =====

app.get('/api/admin/bookings', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await bookings.getAllBookings(req.query.date));
});

app.post('/api/admin/bookings/create', checkAccessToken, checkOfficer, async (req, res) => {
    const { user_id, service_type, booking_date, time_slot } = req.body;

    if (!user_id) {
        return res.json({ isError: true, data: '', errorMessage: 'กรุณาเลือกนักศึกษา' });
    }

    res.json(await bookings.createBooking(user_id, service_type, booking_date, time_slot));
});

app.post('/api/admin/bookings/update', checkAccessToken, checkOfficer, async (req, res) => {
    const { booking_id, service_type, booking_date, time_slot } = req.body;

    const ownerId = await bookings.getBookingOwner(booking_id);

    if (ownerId === null) {
        return res.json({ isError: true, data: '', errorMessage: 'ไม่พบข้อมูลการจอง' });
    }

    res.json(await bookings.updateBooking(ownerId, booking_id, service_type, booking_date, time_slot));
});

app.post('/api/admin/bookings/delete', checkAccessToken, checkOfficer, async (req, res) => {
    const ownerId = await bookings.getBookingOwner(req.body.booking_id);

    if (ownerId === null) {
        return res.json({ isError: true, data: '', errorMessage: 'ไม่พบข้อมูลการจอง' });
    }

    res.json(await bookings.deleteBooking(req.body.booking_id, ownerId));
});

// ตั้งค่าการเปิดรับการจองรายวัน (เจ้าหน้าที่)
app.get('/api/admin/open-days', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await bookings.getOpenDaysAdmin(req.query.from, req.query.to));
});

app.post('/api/admin/open-days', checkAccessToken, checkOfficer, async (req, res) => {
    res.json(await bookings.saveOpenDays(req.body.days));
});

=========
>>>>>>>>> Temporary merge branch 2
app.listen(port, host, () => {
    console.log(`Server running at http://${host}:${port}/`);
});