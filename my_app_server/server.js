const http = require('http');
const bp = require('body-parser');
const express = require('express');
const cors = require('cors');
const userModel = require('./models/users');
const jwt = require('./libs/jwt');
const dateUtil = require('./libs/date_utils');

const app = express();

app.use(cors());
app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

const host = '127.0.0.1';
const port = 3000;

const checkAccessToken = async (req, res, next) => {
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
            errorMessage: "ยังไม่ได้เข้าสู่ระบบ"
        });
    }

    try {
        const decoded = await jwt.verify(token);
        req.decoded = decoded;
        next();
    } catch (err) {
        return res.json({
            isError: true,
            errorMessage: "Access Token ไม่ถูกต้อง"
        });
    }
};

app.get('/api/users/:userId', async (req, res) => {
    const userId = req.params.userId;

    const result = await userModel.getUserById(userId);

    res.json(result);
});

app.post("/api/authen/authen_request", async (req, res) => {

    const authenRequest = req.body.authen_request;

    const result = await userModel.checkAuthenRequest(authenRequest);

    let response;

    if (result.isError) {

        response = {
            isError: true,
            data: "",
            errorMessage: result.errorMessage
        };

    } else {

        const payload = {
            username: result.data[0].username
        };

        const authenToken = jwt.sign(payload);

        response = {
            isError: false,
            data: authenToken,
            errorMessage: ""
        };
    }

    res.json(response);
});

app.post("/api/authen/access_request", async (req, res) => {

    const authenSignature = req.body.authen_signature;
    const authenToken = req.body.authen_token;

    let decoded = null;

    try {
        decoded = await jwt.verify(authenToken);
    } catch (err) {
        decoded = null;
    }

    let response;

    if (decoded) {

        const result = await userModel.checkAccessRequest(
            authenSignature,
            authenToken
        );

        if (result.isError) {

            response = {
                isError: true,
                data: "",
                errorMessage: result.errorMessage
            };

        } else {

            const payload = {
                user_id: result.data[0].user_id,
                username: result.data[0].username,
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
            };
        }

    } else {

        response = {
            isError: true,
            data: "",
            errorMessage: "ข้อมูลไม่ถูกต้อง"
        };
    }

    res.json(response);

});
app.get("/api/profile", checkAccessToken, async (req, res) => {

    const result = await userModel.getUserById(req.decoded.user_id);

    res.json(result);

});

app.listen(port, host, () => {
    console.log(`Server running at http://${host}:${port}/`);
});