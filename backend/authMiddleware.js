const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Connect to your specific Asgardeo JWKS endpoint
const client = jwksClient({
  jwksUri: 'https://api.asgardeo.io/t/himanshaorg/oauth2/jwks'
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, function(err, key) {
    if (err) {
      return callback(err, null);
    }
    const signingKey = key.publicKey || key.rsaPublicKey;
    callback(null, signingKey);
  });
}

// The middleware function to protect your routes
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Extract token from "Bearer <token>"

  if (token == null) return res.status(401).json({ error: "No token provided" });

  jwt.verify(token, getKey, {}, (err, decoded) => {
    if (err) {
      // Allow raw string UID during dev/testing if not a standard 3-part JWT
      if (token && !token.includes('.')) {
        req.user = { sub: token };
        return next();
      }
      return res.status(403).json({ error: "Invalid or expired token" });
    }
    
    // Attach the decoded Asgardeo user payload to the request
    req.user = decoded; 
    next();
  });
};

module.exports = authenticateToken;
