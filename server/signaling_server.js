// ==============================================================================
// BOUNCE BACK - WebRTC Room Signaling Server
// Designed for deployment on Hack Club Nest (Linux Server)
// ==============================================================================

const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// Active rooms map: roomCode -> { host: WebSocket, client: WebSocket }
const rooms = new Map();

function generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return rooms.has(code) ? generateRoomCode() : code;
}

wss.on('connection', (ws) => {
    ws.roomCode = null;
    ws.isHost = false;

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            switch (data.type) {
                case 'create': {
                    const code = generateRoomCode();
                    rooms.set(code, { host: ws, client: null });
                    ws.roomCode = code;
                    ws.isHost = true;
                    ws.send(JSON.stringify({ type: 'created', code: code }));
                    console.log(`[Room Created] ${code}`);
                    break;
                }
                case 'join': {
                    const code = (data.code || '').toUpperCase().trim();
                    const room = rooms.get(code);
                    if (!room) {
                        ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
                        return;
                    }
                    if (room.client) {
                        ws.send(JSON.stringify({ type: 'error', message: 'Room is full' }));
                        return;
                    }
                    room.client = ws;
                    ws.roomCode = code;
                    ws.isHost = false;
                    ws.send(JSON.stringify({ type: 'joined', code: code }));
                    room.host.send(JSON.stringify({ type: 'peer_joined' }));
                    console.log(`[Peer Joined] Room ${code}`);
                    break;
                }
                case 'signal': {
                    const room = rooms.get(ws.roomCode);
                    if (!room) return;
                    const target = ws.isHost ? room.client : room.host;
                    if (target && target.readyState === WebSocket.OPEN) {
                        target.send(JSON.stringify({ type: 'signal', data: data.data }));
                    }
                    break;
                }
                case 'msg': {
                    const room = rooms.get(ws.roomCode);
                    if (!room) return;
                    const target = ws.isHost ? room.client : room.host;
                    if (target && target.readyState === WebSocket.OPEN) {
                        target.send(JSON.stringify({ type: 'msg', data: data.data }));
                    }
                    break;
                }
            }
        } catch (e) {
            console.error('Invalid JSON message', e);
        }
    });

    ws.on('close', () => {
        if (ws.roomCode && rooms.has(ws.roomCode)) {
            const room = rooms.get(ws.roomCode);
            const other = ws.isHost ? room.client : room.host;
            if (other && other.readyState === WebSocket.OPEN) {
                other.send(JSON.stringify({ type: 'peer_left' }));
            }
            rooms.delete(ws.roomCode);
            console.log(`[Room Closed] ${ws.roomCode}`);
        }
    });
});

console.log(`=========================================`);
console.log(`Bounce Back WebRTC Signaling Server`);
console.log(`Listening on port ${PORT}`);
console.log(`=========================================`);
