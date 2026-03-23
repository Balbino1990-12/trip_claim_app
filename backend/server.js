const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const bodyParser = require('body-parser');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Serve static files from uploads folder with proper binary handling
app.get('/uploads/:filename', (req, res) => {
  const filename = req.params.filename;
  const filepath = path.join(uploadsDir, filename);
  
  // Security check: prevent directory traversal
  if (!filepath.startsWith(uploadsDir)) {
    return res.status(403).send('Forbidden');
  }
  
  // Check if file exists
  if (!fs.existsSync(filepath)) {
    console.log(`File not found: ${filepath}`);
    return res.status(404).send('File not found');
  }
  
  try {
    // Read file as binary buffer
    const data = fs.readFileSync(filepath);
    
    // Check if it's base64 encoded text (all ASCII-printable characters)
    const isLikelyBase64 = /^[A-Za-z0-9+/=\s]+$/.test(data.toString('utf-8'));
    
    if (isLikelyBase64 && data.length > 100) {
      console.log(`Image ${filename} appears to be base64, decoding...`);
      try {
        // Decode base64 to binary
        const binaryData = Buffer.from(data.toString('utf-8').replace(/\s/g, ''), 'base64');
        res.set('Content-Type', 'image/jpeg');
        res.set('Content-Length', binaryData.length);
        return res.send(binaryData);
      } catch (e) {
        console.log(`Base64 decode failed for ${filename}: ${e.message}, serving as-is`);
      }
    }
    
    // Serve binary data directly
    res.set('Content-Type', 'image/jpeg');
    res.set('Content-Length', data.length);
    res.send(data);
  } catch (err) {
    console.error(`Error serving image ${filename}:`, err);
    res.status(500).send('Error serving image');
  }
});

// Serve static files in backend directory (admin.html)
app.use(express.static(path.join(__dirname)));

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
  transports: ['websocket', 'polling'],
  path: '/socket.io',
});

io.on('connection', (socket) => {
  console.log('Socket connected:', socket.id);
  socket.on('disconnect', (reason) => {
    console.log('Socket disconnected:', socket.id, reason);
  });

  socket.on('claim:reopened', (payload) => {
    console.log('Socket admin emit received:', payload);
    io.emit('claim:reopened', payload);
  });
});

// Debug broadcast endpoint
app.post('/debug/broadcast', (req, res) => {
  try {
    const payload = req.body || {};
    const claimId = payload.claimId || (payload.claim && (payload.claim.id || payload.claim.claimId));
    const newStatus = payload.newStatus || 'on-progress';
    const oldStatus = payload.oldStatus || 'rejected';
    const emitPayload = { claimId, newStatus, oldStatus, timestamp: new Date().toISOString() };

    console.log('Broadcasting claim:reopened ->', emitPayload);
    io.emit('claim:reopened', emitPayload);
    return res.json({ success: true, message: 'Reopen event sent', payload: emitPayload });
  } catch (err) {
    console.error('Broadcast error', err);
    return res.status(500).json({ success: false, message: 'Broadcast failed', error: String(err) });
  }
});

app.get('/health', (_, res) => res.send('ok'));

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
