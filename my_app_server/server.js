const http = require('http');
const bp = require('body-parser');
const express = require('express');
const cors = require('cors');
const userModel = require('./models/user');
const jwt = require('./libs/jwt');
const dateUtil = require('./libs/date_utils');

const app = express();

app.use(cors());
app.use(bp.urlencoded({ extended: false }));
app.use(bp.json());

const host = '127.0.0.1';
const port = 3000;

const checkAccessToken = (req, res, next) => {
    let token = null;

    if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
        token = req.headers.authorization.split(' ')[1];
    } else if (req.query && req.query.token) {
        token = req.query.token;
    } else {
        token = req.body.token;
    }

    jwt.verify(token)
        .then(decoded => {
            req.decoded = decoded;
            next();
        }, (err) => {
            res.json({
                isError: false,
                errormessage: 'ยังไม่ได้เข้าสู่ระบบ',
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

app.listen(port, host, () => {
    console.log(`Server running at http://${host}:${port}/`);
});