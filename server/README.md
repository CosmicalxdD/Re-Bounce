# Bounce Back - Online Co-Op Signaling Server (Hack Club Nest Guide)

This lightweight Node.js signaling & relay server enables 2-player browser-to-browser co-op on itch.io using WebRTC and 4-letter room codes.

---

## 🎮 How Multiplayer Works

1. **Host** clicks `ONLINE CO-OP` on the main menu, then clicks `CREATE ROOM`.
2. A unique **4-letter code** (e.g. `ABCD`) appears on screen.
3. **Friend** clicks `ONLINE CO-OP`, types the 4 letters on their keyboard, and clicks `JOIN ROOM`.
4. The server pairs them up and establishes a direct **WebRTC P2P Data Channel** (backed by automatic WebSocket relay fallback).
5. **Host** clicks `START CO-OP MISSION` and both players enter the wave together with dual health bars, ability synergies, and revive mechanics!

---

## 💻 Step 1: Quick Local Testing (On Your PC)

Before deploying to Nest, you can test multiplayer right on your computer:

1. Open PowerShell or Terminal in this project directory:
   ```bash
   cd server
   npm install
   node signaling_server.js
   ```
2. Run Godot in two separate windows (or run two instances):
   - Instance 1: Click `ONLINE CO-OP` -> `CREATE ROOM`
   - Instance 2: Click `ONLINE CO-OP` -> Type the 4-letter code -> `JOIN ROOM`
   - Instance 1: Click `START CO-OP MISSION`
   - Both instances will sync perfectly over `ws://127.0.0.1:8080`!

---

## 🐧 Step 2: Deploying to Hack Club Nest (Linux Server)

Hack Club Nest gives members a free Linux shell and domain (`your_username.hackclub.app`).

### A. SSH into Nest
Open terminal or PowerShell on your computer and run:
```bash
ssh your_username@nest.hackclub.com
```

### B. Create Directory on Nest
```bash
mkdir -p ~/bounce-back-server
cd ~/bounce-back-server
```

### C. Copy Server Files
From your computer, you can upload the server files using `scp`:
```bash
scp -r server/* your_username@nest.hackclub.com:~/bounce-back-server/
```
*(Or create `signaling_server.js` and `package.json` manually with `nano` if you prefer).*

### D. Install Dependencies & Run
On your Nest server:
```bash
cd ~/bounce-back-server
npm install
```

Now start the server using **PM2** (so it stays running even when you disconnect from SSH):
```bash
PORT=8080 npx pm2 start signaling_server.js --name "bounce-back"
npx pm2 save
```
To check server status and live logs anytime:
```bash
npx pm2 status
npx pm2 logs bounce-back
```

---

## 🔒 Step 3: Setting Up Your Secure WSS Subdomain on Nest

Because **itch.io** runs over **HTTPS**, web browsers will block insecure `ws://` connections. You need secure WebSockets (`wss://`).

Nest uses **Caddy** for automated SSL certificates and reverse proxy.

1. In your home directory on Nest, check or create your `Caddyfile`:
   ```bash
   nano ~/Caddyfile
   ```
2. Add your Nest subdomain routing to port 8080:
   ```caddy
   your_username.hackclub.app {
       reverse_proxy localhost:8080
   }
   ```
   *(Replace `your_username` with your actual Nest username).*

3. Reload or start Caddy:
   ```bash
   caddy reload
   # or if not running:
   caddy start
   ```

Now your signaling server is securely accessible worldwide at:
```
wss://your_username.hackclub.app
```

---

## 🚀 Step 4: Connecting the Game

In `game.gd` (or directly inside the game's Online Lobby modal):
1. Click the bottom bar `SERVER: ws://127.0.0.1:8080 (CLICK TO EDIT)`.
2. Enter your Nest address:
   ```
   wss://your_username.hackclub.app
   ```
3. Press **ENTER**. The indicator dot will turn green: `● Connected to Server`!
4. Export your game to HTML5 in Godot, upload to itch.io, and you and your friends can play together anywhere in the world!
