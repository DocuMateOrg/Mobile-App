require('dotenv').config();
const express = require('express');
const axios = require('axios');
const PDFDocument = require('pdfkit');

const ORG = process.env.ORG || "himanshaorg";
const BACKEND_CLIENT_ID = process.env.BACKEND_CLIENT_ID || "L43pAamybFKtklKq7Fb0S20uzgca";
const BACKEND_CLIENT_SECRET = process.env.BACKEND_CLIENT_SECRET || "";
const { Document, Packer, Paragraph, TextRun } = require('docx');
const multer = require('multer');
const path = require('path');
const cors = require('cors');
const { Pool } = require('pg'); 

// Configure Multer for image storage
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static('uploads'));

// --- 1. CONNECT TO POSTGRESQL ---
// These credentials come from the .env file
const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
});

const fs = require('fs');
const logFile = 'server.log';
const log = (msg) => {
    const entry = `[${new Date().toISOString()}] ${msg}\n`;
    fs.appendFileSync(logFile, entry);
    console.log(msg);
};

// Request Logger for debugging (Moved here to ensure 'log' is defined)
app.use((req, res, next) => {
    log(`DEBUG: ${req.method} request to ${req.url}`);
    next();
});

// Prevent Node.js from crashing if the database connection drops unexpectedly
pool.on('error', (err, client) => {
    log(`Unexpected error on idle client: ${err.message}`);
});


// Auto-create the tables if they don't exist yet
const initDB = async () => {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                email VARCHAR(255) UNIQUE NOT NULL,
                username VARCHAR(255) NOT NULL,
                auth_provider VARCHAR(50) DEFAULT 'email',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        // Auto-create folders & documents tables if they don't exist yet
        await pool.query(`
            CREATE TABLE IF NOT EXISTS folders (
                id SERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        await pool.query(`
            CREATE TABLE IF NOT EXISTS documents (
                id SERIAL PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                title VARCHAR(255) NOT NULL,
                content TEXT,
                local_image_path TEXT,
                server_image_path TEXT,
                folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        // Update schema safely
        await pool.query(`
            ALTER TABLE documents 
            ADD COLUMN IF NOT EXISTS folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL;
        `);
        await pool.query(`
            ALTER TABLE documents 
            ADD COLUMN IF NOT EXISTS server_image_path TEXT;
        `);

        log("✅ Database tables ready.");
    } catch (err) {
        log(`Database Init Error: ${err.message || 'Connection failed'}`);
        if (err.code === 'ECONNREFUSED') {
            log(`ERROR: Could not connect to PostgreSQL at ${process.env.DB_HOST}:${process.env.DB_PORT}. Is the database running?`);
        } else {
            log(`Details: ${err.stack || err}`);
        }
    }
};
initDB();

// --- USER MANAGEMENT ENDPOINTS ---
// Check if user exists by email
app.get('/api/users/check', async (req, res) => {
    try {
        const email = req.query.email?.trim().toLowerCase();
        if (!email) return res.status(400).json({ error: "Email is required" });

        const result = await pool.query(`SELECT * FROM users WHERE LOWER(email) = $1`, [email]);
        if (result.rows.length > 0) {
            return res.status(200).json({ exists: true, user: result.rows[0] });
        } else {
            return res.status(200).json({ exists: false, user: null });
        }
    } catch (err) {
        log(`Error checking user: ${err.message}`);
        res.status(500).json({ error: "Server error checking user" });
    }
});

// Register or update user details
app.post('/api/users/register', async (req, res) => {
    try {
        const { email, username, authProvider } = req.body;
        if (!email || !username) {
            return res.status(400).json({ error: "Email and Username are required" });
        }

        const cleanedEmail = email.trim().toLowerCase();
        const cleanedUsername = username.trim();
        const provider = authProvider || 'email';

        const result = await pool.query(
            `INSERT INTO users (email, username, auth_provider)
             VALUES ($1, $2, $3)
             ON CONFLICT (email) 
             DO UPDATE SET username = EXCLUDED.username, auth_provider = EXCLUDED.auth_provider
             RETURNING *`,
            [cleanedEmail, cleanedUsername, provider]
        );

        log(`👤 User registered/updated: ${cleanedEmail} (${cleanedUsername})`);
        res.status(200).json({ message: "User registered successfully", user: result.rows[0] });
    } catch (err) {
        log(`Error registering user: ${err.message}`);
        res.status(500).json({ error: "Server error registering user" });
    }
});

/// Update user profile (username)
app.put('/api/users/profile', async (req, res) => {
    try {
        const { email, username } = req.body;
        if (!email || !username) {
            return res.status(400).json({ error: "Email and Username required" });
        }

        const cleanedEmail = email.trim().toLowerCase();
        const cleanedUsername = username.trim();

        await pool.query(`UPDATE users SET username = $1 WHERE LOWER(email) = $2`, [cleanedUsername, cleanedEmail]);
        log(`✏️ Profile updated for ${cleanedEmail}: new username "${cleanedUsername}"`);
        res.status(200).json({ message: "Profile updated successfully" });
    } catch (err) {
        log(`Error updating profile: ${err.message}`);
        res.status(500).json({ error: "Server error updating profile" });
    }
});

// --- ASGARDEO BACKEND PROXY AUTH ENDPOINTS ---

// 1. NATIVE MANUAL LOGIN (Asgardeo Native Authentication - STRICT PASSWORD MATCHING)
app.post('/api/auth/login', async (req, res) => {
  try {
    const rawIdentifier = req.body.email || req.body.username;
    const { password } = req.body;
    
    if (!rawIdentifier || !password) {
      return res.status(400).json({ success: false, message: "Email/Username and password required" });
    }

    const email = rawIdentifier.trim().toLowerCase();
    const orgName = process.env.ORG || ORG;
    const clientId = process.env.BACKEND_CLIENT_ID || BACKEND_CLIENT_ID;
    const clientSecret = process.env.BACKEND_CLIENT_SECRET || BACKEND_CLIENT_SECRET;
    const redirectUris = [
      'http://localhost:8080/oidc-sample-app/oauth2client',
      'http://localhost:3000',
      'http://localhost:3000/',
      'http://localhost:3000/callback',
      'com.documate.app://callback',
      'com.example.documate://callback',
      'https://localhost:3000',
      'https://localhost:3000/callback',
      'http://10.0.2.2:3000',
      'http://10.0.2.2:3000/callback'
    ];

    // Native Auth strictly expects raw email (no DEFAULT/ domain prefix)
    const usernamesToTest = [email];

    const authHeader = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    // 0. Resource Owner Password Credentials Grant (Direct OAuth2 Password Authentication)
    for (const uname of [email, `DEFAULT/${email}`]) {
      try {
        const pwdTokenRes = await axios.post(
          `https://api.asgardeo.io/t/${orgName}/oauth2/token`,
          new URLSearchParams({
            grant_type: 'password',
            username: uname,
            password: password,
            client_id: clientId,
            client_secret: clientSecret,
            scope: 'openid profile email'
          }).toString(),
          {
            headers: {
              'Authorization': `Basic ${authHeader}`,
              'Content-Type': 'application/x-www-form-urlencoded'
            }
          }
        );

        if (pwdTokenRes.data?.access_token) {
          log(`🔓 Asgardeo Password Grant authentication successful: ${email}`);

          await pool.query(
            `INSERT INTO users (email, username, auth_provider)
             VALUES ($1, $2, $3)
             ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username`,
            [email, email.split('@')[0], 'email']
          ).catch(() => {});

          return res.json({
            success: true,
            message: "Login successful",
            data: pwdTokenRes.data,
            user: { email: email, username: email }
          });
        }
      } catch (pwdErr) {
        log(`Note: Password grant attempt (${uname}) note: ${pwdErr.response ? JSON.stringify(pwdErr.response.data) : pwdErr.message}`);
      }
    }

    // A. Native 3-Step Authorization Code Exchange (Password Authentication)
    for (const redirectUri of redirectUris) {
      for (const uname of usernamesToTest) {
        try {
          // 1. Initiate authorization with response_mode=direct
          const initRes = await axios.post(
            `https://api.asgardeo.io/t/${orgName}/oauth2/authorize`,
            new URLSearchParams({
              client_id: clientId,
              response_type: 'code',
              response_mode: 'direct',
              scope: 'openid profile email',
              redirect_uri: redirectUri
            }).toString(),
            {
              headers: {
                'Authorization': `Basic ${authHeader}`,
                'Content-Type': 'application/x-www-form-urlencoded'
              }
            }
          );

          log(`Initiating Native Login for ${email} with redirectUri=${redirectUri}...`);
          const flowId = initRes.data.flowId || initRes.data.authCode || initRes.data.sessionDataKey;
          log(`initRes response for ${redirectUri}: ${JSON.stringify(initRes.data)}`);

          if (flowId) {
            // Dynamically extract the exact authenticatorId required by Asgardeo
            const authenticators = initRes.data.nextStep?.authenticators || [];
            const primaryAuthId = authenticators.find(a => a.authenticator === "Username & Password" || a.idp === "LOCAL")?.authenticatorId || authenticators[0]?.authenticatorId;
            const authenticatorIdsToTry = Array.from(new Set(["QmFzaWNBdXRoZW50aWNhdG9yOkxPQ0FM", primaryAuthId, "BasicAuthenticator"])).filter(Boolean);

            const authEndpoints = [
              `https://api.asgardeo.io/t/${orgName}/oauth2/authn`,
              `https://api.asgardeo.io/t/${orgName}/api/identity/auth/v1.1/authenticate`
            ];

            for (const endpoint of authEndpoints) {
              for (const targetAuthId of authenticatorIdsToTry) {
                try {
                  log(`Submitting credentials to ${endpoint} with authenticatorId="${targetAuthId}"...`);
                  const authRes = await axios.post(
                    endpoint,
                    {
                      flowId: flowId,
                      selectedAuthenticator: {
                        authenticatorId: targetAuthId,
                        params: {
                          username: uname,
                          password: password
                        }
                      }
                    },
                    { headers: { 'Authorization': `Basic ${authHeader}`, 'Content-Type': 'application/json' } }
                  );

                  log(`authRes response data from ${endpoint}: ${JSON.stringify(authRes.data)}`);
                  const authCode = authRes.data.code || authRes.data.authData?.code || authRes.data.authCode || authRes.data.authData?.authCode;

                  if (authCode) {
                    // 3. Exchange authorization code for tokens
                    const tokenRes = await axios.post(
                      `https://api.asgardeo.io/t/${orgName}/oauth2/token`,
                      new URLSearchParams({
                        grant_type: 'authorization_code',
                        client_id: clientId,
                        client_secret: clientSecret,
                        code: authCode,
                        redirect_uri: redirectUri
                      }).toString(),
                      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
                    );

                    log(`🔓 Asgardeo password authentication successful: ${email}`);

                    await pool.query(
                      `INSERT INTO users (email, username, auth_provider)
                       VALUES ($1, $2, $3)
                       ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username`,
                      [email, email.split('@')[0], 'email']
                    ).catch(() => {});

                    return res.json({
                      success: true,
                      message: "Login successful",
                      data: tokenRes.data,
                      user: { email: email, username: email }
                    });
                  }
                } catch (authErr) {
                  log(`❌ authRes ERROR (${endpoint}, ${targetAuthId}): ${authErr.response ? JSON.stringify(authErr.response.data) : authErr.message}`);
                }
              }
            }
          }
        } catch (err) {
          log(`Note: Native login auth attempt (${uname}, ${redirectUri}) note: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
        }
      }
    }

    // B. Direct /oauth2/authn Authenticator API Fallback (Password Authentication)
    for (const uname of usernamesToTest) {
      try {
        const authnRes = await axios.post(
          `https://api.asgardeo.io/t/${orgName}/oauth2/authn`,
          {
            selectedAuthenticator: {
              authenticatorId: "BasicAuthenticator",
              params: {
                username: uname,
                password: password
              }
            }
          },
          { headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' } }
        );

        if (authnRes.status === 200 && (authnRes.data?.status === 'SUCCESS' || authnRes.data?.authData)) {
          log(`🔓 Asgardeo /oauth2/authn password authentication successful: ${email}`);

          await pool.query(
            `INSERT INTO users (email, username, auth_provider)
             VALUES ($1, $2, $3)
             ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username`,
            [email, email.split('@')[0], 'email']
          ).catch(() => {});

          return res.json({
            success: true,
            message: "Login successful",
            data: authnRes.data,
            user: { email: email, username: email }
          });
        }
      } catch (authnErr) {
        log(`Note: Direct authn attempt (${uname}) note: ${authnErr.response ? JSON.stringify(authnErr.response.data) : authnErr.message}`);
      }
    }

    // If all password authenticators reject the credentials:
    log(`❌ Invalid login credentials for ${email}`);
    return res.status(401).json({
      success: false,
      message: "Invalid email/username or password in Asgardeo."
    });

  } catch (error) {
    console.error("Native Login Error:", error.response?.data || error.message);
    log(`❌ Native Login Error: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
    res.status(401).json({
      success: false,
      message: error.response?.data?.description || error.response?.data?.message || "Authentication failed",
      error: error.response?.data || error.message
    });
  }
});

// Helper to acquire Asgardeo Management Admin Token
async function getAsgardeoAdminToken() {
  const authHeader = Buffer.from(`${BACKEND_CLIENT_ID}:${BACKEND_CLIENT_SECRET}`).toString('base64');
  
  // Attempt 1: Client Secret Basic (Standard Header) with full Management and Recovery scopes
  try {
    const res = await axios.post(
      `https://api.asgardeo.io/t/${ORG}/oauth2/token`,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: BACKEND_CLIENT_ID,
        client_secret: BACKEND_CLIENT_SECRET,
        scope: 'internal_user_mgt_create internal_user_mgt_update internal_user_mgt_view internal_user_recovery_create'
      }).toString(),
      {
        headers: {
          'Authorization': `Basic ${authHeader}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      }
    );
    return res.data.access_token;
  } catch (err1) {
    // Attempt 2: Client Secret Post (Body Parameters)
    try {
      const res = await axios.post(
        `https://api.asgardeo.io/t/${ORG}/oauth2/token`,
        new URLSearchParams({
          grant_type: 'client_credentials',
          client_id: BACKEND_CLIENT_ID,
          client_secret: BACKEND_CLIENT_SECRET,
          scope: 'internal_user_mgt_create internal_user_mgt_update internal_user_mgt_view internal_user_recovery_create'
        }).toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          }
        }
      );
      return res.data.access_token;
    } catch (err2) {
      throw err1;
    }
  }
}

// 2. NATIVE MANUAL SIGN UP (Admin Token + Asgardeo SCIM 2.0 User API - STRICT ASGARDEO, NO LOCAL DB FALLBACK)
app.post('/api/auth/register', async (req, res) => {
  try {
    const { username, email, password, firstName, lastName } = req.body;
    if (!username || !email || !password) {
      return res.status(400).json({ success: false, message: "Username, email, and password required" });
    }

    const cleanedEmail = email.trim().toLowerCase();
    const cleanedUsername = username.trim();

    if (!BACKEND_CLIENT_ID || !BACKEND_CLIENT_SECRET) {
      log(`❌ Missing BACKEND_CLIENT_ID or BACKEND_CLIENT_SECRET in .env`);
      return res.status(500).json({ success: false, message: "Backend credentials not configured in .env" });
    }

    // A. Request Admin Access Token via Client Credentials Grant
    let adminToken;
    try {
      adminToken = await getAsgardeoAdminToken();
      log(`🔑 Admin access token obtained from Asgardeo.`);
    } catch (tokenErr) {
      const errorDetail = tokenErr.response?.data?.error_description || tokenErr.response?.data?.error || tokenErr.message;
      log(`❌ Asgardeo Admin Token Request Failed: ${tokenErr.response ? JSON.stringify(tokenErr.response.data) : tokenErr.message}`);
      return res.status(tokenErr.response?.status || 401).json({
        success: false,
        message: `Asgardeo Admin Token Error: "${errorDetail}". Ensure BACKEND_CLIENT_ID is created as a Management / Standard-Based Application in Asgardeo with Client Credentials enabled.`,
        error: tokenErr.response?.data
      });
    }

    // B. Create the User in Asgardeo SCIM 2.0 Endpoint
    let asgardeoRes;
    try {
      const scimUserName = cleanedEmail.startsWith('DEFAULT/') ? cleanedEmail : `DEFAULT/${cleanedEmail}`;
      asgardeoRes = await axios.post(
        `https://api.asgardeo.io/t/${ORG}/scim2/Users`,
        {
          schemas: ["urn:ietf:params:scim:schemas:core:2.0:User"],
          userName: scimUserName,
          password: password,
          name: {
            givenName: firstName || cleanedUsername || "User",
            familyName: lastName || "User"
          },
          emails: [
            {
              primary: true,
              value: cleanedEmail
            }
          ]
        },
        {
          headers: {
            'Authorization': `Bearer ${adminToken}`,
            'Content-Type': 'application/json'
          }
        }
      );
      log(`👤 User successfully created in Asgardeo SCIM 2.0: ${cleanedEmail}`);
    } catch (scimErr) {
      log(`❌ Asgardeo SCIM 2.0 User Creation Rejected: ${scimErr.response ? JSON.stringify(scimErr.response.data) : scimErr.message}`);
      return res.status(scimErr.response?.status || 400).json({
        success: false,
        message: scimErr.response?.data?.detail || scimErr.response?.data?.message || scimErr.response?.data?.scimDetail || "Asgardeo registration rejected.",
        error: scimErr.response?.data
      });
    }

    // C. Synchronize user record to local PostgreSQL DB ONLY IF Asgardeo user creation succeeded
    try {
      await pool.query(
        `INSERT INTO users (email, username, auth_provider)
         VALUES ($1, $2, $3)
         ON CONFLICT (email) DO UPDATE SET username = EXCLUDED.username`,
        [cleanedEmail, cleanedUsername, 'email']
      );
    } catch (dbErr) {
      log(`Note: Local DB sync skipped (${dbErr.message})`);
    }

    res.status(201).json({
      success: true,
      message: "User created successfully in Asgardeo!",
      data: asgardeoRes.data
    });

  } catch (error) {
    log(`Register endpoint error: ${error.message}`);
    res.status(500).json({
      success: false,
      message: "Server error during registration."
    });
  }
});

// --- ASGARDEO FORGOT PASSWORD / ACCOUNT RECOVERY ENDPOINTS (V2 REST API) ---

// Step 1: Initiate Recovery (Looks up user & triggers notification email via Asgardeo V2 recovery endpoint)
app.post('/api/auth/forgot-password/init', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required" });
    }

    const cleanedEmail = email.trim().toLowerCase();
    const formattedUsername = cleanedEmail.startsWith('DEFAULT/') ? cleanedEmail : `DEFAULT/${cleanedEmail}`;

    const adminToken = await getAsgardeoAdminToken();

    // 1. Look up user and get channels
    const initResponse = await axios.post(
      `https://api.asgardeo.io/t/${ORG}/api/users/v2/recovery/password/init`,
      { claims: [{ uri: "http://wso2.org/claims/username", value: formattedUsername }] },
      { headers: { 'Authorization': `Bearer ${adminToken}`, 'Content-Type': 'application/json' } }
    );

    const initDataArray = Array.isArray(initResponse.data) ? initResponse.data : [initResponse.data];
    const notifData = initDataArray.find(d => d.mode === 'recoverWithNotifications') || initDataArray[0];

    if (!notifData) {
      log(`❌ Password recovery notification data not available for ${cleanedEmail}`);
      return res.status(400).json({ success: false, message: "Password recovery with notifications is not enabled for this user." });
    }

    const channelInfo = notifData.channelInfo || notifData;
    const emailChannel = channelInfo.channels?.find(c => c.type === 'EMAIL') || channelInfo.channels?.[0];
    const recoveryCode = channelInfo.recoveryCode || notifData.recoveryCode;
    
    // IMPORTANT FIX: Save the flow code from the initial response here
    const correctFlowCode = notifData.flowConfirmationCode || notifData.confirmationCode;

    // 2. Trigger the SendGrid Email via Asgardeo /recover endpoint
    if (recoveryCode && emailChannel && emailChannel.id) {
      await axios.post(
        `https://api.asgardeo.io/t/${ORG}/api/users/v2/recovery/password/recover`,
        {
          recoveryCode: recoveryCode,
          channelId: emailChannel.id.toString()
        },
        { headers: { 'Authorization': `Bearer ${adminToken}`, 'Content-Type': 'application/json' } }
      );
    }
    
    log(`📧 Password recovery notification email dispatched to ${cleanedEmail} (Flow Code: ${correctFlowCode})`);
    
    // 3. Return the saved flow code to Flutter
    res.json({
      success: true,
      message: "Password recovery OTP sent to email.",
      flowConfirmationCode: correctFlowCode
    });
  } catch (error) {
    console.error("Asgardeo Error:", error.response?.data || error.message);
    log(`❌ Forgot Password Init Error: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
    res.status(error.response?.status || 500).json({
      success: false,
      message: error.response?.data?.description || error.response?.data?.message || "Failed to initiate password recovery.",
      error: error.response?.data || error.message
    });
  }
});

// Step 2: Confirm OTP Code
app.post('/api/auth/forgot-password/confirm', async (req, res) => {
  try {
    const { confirmationCode, otp } = req.body;
    if (!confirmationCode || !otp) {
      return res.status(400).json({ success: false, message: "Confirmation code and OTP are required" });
    }

    const adminToken = await getAsgardeoAdminToken();

    const response = await axios.post(
      `https://api.asgardeo.io/t/${ORG}/api/users/v2/recovery/password/confirm`,
      {
        confirmationCode: confirmationCode,
        otp: otp.trim()
      },
      {
        headers: { 
          'Authorization': `Bearer ${adminToken}`,
          'Content-Type': 'application/json' 
        }
      }
    );

    const resetCode = response.data.resetCode || response.data.flowConfirmationCode || response.data.confirmationCode || confirmationCode;
    const newFlowCode = response.data.flowConfirmationCode || response.data.resetCode || confirmationCode;
    log(`✅ OTP confirmed successfully.`);
    res.json({
      success: true,
      message: "OTP verified successfully.",
      resetCode: resetCode,
      flowConfirmationCode: newFlowCode,
      data: response.data
    });

  } catch (error) {
    log(`❌ Forgot Password Confirm Error: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
    res.status(error.response?.status || 400).json({
      success: false,
      message: error.response?.data?.description || error.response?.data?.message || "Invalid OTP code.",
      error: error.response?.data
    });
  }
});

// Step 3: Reset Password (supports both /reset and /recover routes)
const handleResetPassword = async (req, res) => {
  try {
    const { resetCode, flowConfirmationCode, password } = req.body;
    
    // Safety check as requested:
    if (!resetCode || !flowConfirmationCode || !password) {
      return res.status(400).json({ 
        error: "Flutter is missing data!", 
        received: { resetCode, flowConfirmationCode, passwordHasValue: !!password } 
      });
    }

    const adminToken = await getAsgardeoAdminToken();

    const response = await axios.post(
      `https://api.asgardeo.io/t/${ORG}/api/users/v2/recovery/password/reset`,
      {
        password: password,
        resetCode: resetCode,
        flowConfirmationCode: flowConfirmationCode
      },
      {
        headers: { 
          'Authorization': `Bearer ${adminToken}`,
          'Content-Type': 'application/json' 
        }
      }
    );

    log(`🔑 Password updated successfully via recovery.`);
    res.json({
      success: true,
      message: "Password reset successfully. You can now log in.",
      data: response.data
    });

  } catch (error) {
    console.error("Asgardeo Reset Error:", error.response?.data || error.message);
    log(`❌ Forgot Password Reset Error: ${error.response ? JSON.stringify(error.response.data) : error.message}`);
    res.status(error.response?.status || 400).json({
      success: false,
      message: error.response?.data?.description || error.response?.data?.message || "Password reset failed.",
      error: error.response?.data || error.message
    });
  }
};

app.post('/api/auth/forgot-password/reset', handleResetPassword);
app.post('/api/auth/forgot-password/recover', handleResetPassword);

// --- 2. THE SAVE ROUTE (Updated for image upload) ---
app.post('/api/documents', upload.single('image'), async (req, res) => {
    try {
        log(`DEBUG: Save Request - Body keys: ${Object.keys(req.body || {})}, File: ${req.file ? req.file.filename : 'None'}`);
        const body = req.body || {};
        let { userId, title, content, localImagePath, folderId } = body;
        const serverImagePath = req.file ? req.file.path : null;
        
        userId = userId?.trim();
        if (!userId) return res.status(400).json({ error: "User ID required" });

        // Provide defaults to prevent SQL NOT NULL errors
        title = title || "Untitled Document";
        content = content || "";
        localImagePath = localImagePath || "";
        
        // Insert the data into PostgreSQL
        await pool.query(
            `INSERT INTO documents (user_id, title, content, local_image_path, server_image_path, folder_id) 
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [userId, title, content, localImagePath, serverImagePath, folderId || null]
        );
        
        log(`📥 Saved to DB: ${title} for user ${userId} (Image: ${serverImagePath})`);
        res.status(201).json({ message: "Document saved successfully!" });
    } catch (err) {
        log(`Database Save Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});

// --- 3. THE FETCH ROUTE (Hits when you open the Dashboard) ---
app.get('/api/documents/:userId', async (req, res) => {
    try {
        const userId = req.params.userId?.trim();
        const folderId = req.query.folderId;
        const search = req.query.search;
        
        if (!userId) return res.status(400).json({ error: "User ID required" });

        log(`[DEBUG] Fetching docs for UID: "${userId}"`);
        if (folderId) log(`[DEBUG] Filter by Folder: ${folderId}`);
        if (search) log(`[DEBUG] Filter by Search: "${search}"`);

        let queryStr = `SELECT * FROM documents WHERE user_id = $1`;
        let values = [userId];
        let paramCount = 2;

        if (folderId) {
            queryStr += ` AND folder_id = $${paramCount}`;
            values.push(folderId);
            paramCount++;
        }

        if (search) {
            
            const searchWords = search.split(/\s+/).filter(word => word.length > 2);
            
            if (searchWords.length > 0) {
                let searchConditions = [];
                searchWords.forEach(word => {
                    searchConditions.push(`(title ILIKE $${paramCount} OR content ILIKE $${paramCount})`);
                    values.push(`%${word}%`);
                    paramCount++;
                });
                // Match ANY of the meaningful words (OR logic)
                queryStr += ` AND (${searchConditions.join(' OR ')})`;
            } else {
                // Fallback to exact match if words are too short
                queryStr += ` AND (title ILIKE $${paramCount} OR content ILIKE $${paramCount})`;
                values.push(`%${search}%`);
                paramCount++;
            }
        }

        queryStr += ` ORDER BY created_at DESC`;

        const result = await pool.query(queryStr, values);
        
        log(`📦 Found ${result.rows.length} documents for UID: "${userId}"`);
        
        res.status(200).json(result.rows);
    } catch (err) {
        log(`Database Fetch Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});

app.post('/api/folders', async (req, res) => {
    try {
        const { userId, name } = req.body;
        
        const result = await pool.query(
            `INSERT INTO folders (user_id, name) VALUES ($1, $2) RETURNING id, name`,
            [userId, name]
        );
        
        console.log("📁 Created folder:", name);
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error("Database Folder Save Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});


app.get('/api/folders/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        
        const result = await pool.query(
            `SELECT * FROM folders WHERE user_id = $1 ORDER BY created_at DESC`,
            [userId]
        );
        
        log(`📂 Sent ${result.rows.length} folders to user ${userId}`);
        res.status(200).json(result.rows);
    } catch (err) {
        log(`Database Folder Fetch Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});


app.delete('/api/folders/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query(`DELETE FROM folders WHERE id = $1`, [id]);
        log(`🗑️ Folder Delete attempt for ID ${id}. Rows affected: ${result.rowCount}`);
        res.status(200).json({ message: "Folder deleted", count: result.rowCount });
    } catch (err) {
        log(`Database Folder Delete Error: ${err.message}`);
        res.status(500).json({ error: "Server error" });
    }
});


app.delete('/api/documents/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query(`DELETE FROM documents WHERE id = $1`, [id]);
        res.status(200).json({ message: "Document deleted" });
    } catch (err) {
        console.error("Database Delete Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

app.put('/api/documents/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { title, folderId } = req.body;
        
        let query = 'UPDATE documents SET ';
        const values = [];
        let count = 1;

        if (title !== undefined) {
            query += `title = $${count} `;
            values.push(title);
            count++;
        }
        if (folderId !== undefined) {
            if (count > 1) query += ', ';
            query += `folder_id = $${count} `;
            values.push(folderId === null ? null : folderId);
            count++;
        }
        
        if (values.length === 0) {
            return res.status(400).json({ error: "No fields to update" });
        }

        query += `WHERE id = $${count}`;
        values.push(id);

        await pool.query(query, values);
        res.status(200).json({ message: "Document updated" });
    } catch (err) {
        console.error("Database Update Error:", err);
        res.status(500).json({ error: "Server error" });
    }
});

app.get('/api/documents/:id/export', async (req, res) => {
    try {
        const { id } = req.params;
        const { format } = req.query; 

        const result = await pool.query('SELECT * FROM documents WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: "Document not found" });
        }

        const docData = result.rows[0];
        const fileName = `${docData.title.replace(/\s+/g, '_')}_${id}`;

        if (format === 'pdf') {
            const doc = new PDFDocument();
            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename=${fileName}.pdf`);

            doc.pipe(res);
            
            // 1. Add Title
            doc.fontSize(20).text(docData.title, { align: 'center' });
            doc.moveDown();

            // 2. Add Image if available
            if (docData.server_image_path && fs.existsSync(docData.server_image_path)) {
                log(`Adding image to PDF: ${docData.server_image_path}`);
                doc.image(docData.server_image_path, {
                    fit: [500, 600],
                    align: 'center',
                    valign: 'center'
                });
            } else {
                log(`No image found for export: ${docData.server_image_path}`);
                doc.fontSize(12).text("[Image not available]", { align: 'center' });
            }

            doc.end();

        } else if (format === 'docx') {
            const doc = new Document({
                sections: [{
                    properties: {},
                    children: [
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: docData.title,
                                    bold: true,
                                    size: 32,
                                }),
                            ],
                        }),
                        new Paragraph({
                            children: [
                                new TextRun({
                                    text: "\n" + docData.content,
                                    size: 24,
                                }),
                            ],
                        }),
                    ],
                }],
            });

            const buffer = await Packer.toBuffer(doc);
            res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            res.setHeader('Content-Disposition', `attachment; filename=${fileName}.docx`);
            res.send(buffer);

        } else {
            res.status(400).json({ error: "Invalid format. Use 'pdf' or 'docx'." });
        }
    } catch (err) {
        log(`Export Error: ${err.message}`);
        res.status(500).json({ error: "Server error during export" });
    }
});

// --- START SERVER ---
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 DocuMate Backend running at http://localhost:${PORT}`);
}).on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        log(`CRITICAL ERROR: Port ${PORT} is already in use. Please close the other process or use a different port.`);
    } else {
        log(`CRITICAL ERROR: Server failed to start: ${err.message}`);
    }
    process.exit(1);
});

// Catch silent crashes
process.on('unhandledRejection', (reason, promise) => {
    log(`CRITICAL ERROR: Unhandled Rejection at: ${promise}, reason: ${reason}`);
});

process.on('uncaughtException', (err) => {
    log(`CRITICAL ERROR: Uncaught Exception: ${err.message}\nStack: ${err.stack}`);
    process.exit(1);
});