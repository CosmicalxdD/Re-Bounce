#!/usr/bin/env bash
# ==============================================================================
# BOUNCE BACK - Signaling Server Deployment Script for Hack Club Nest
# ==============================================================================
set -e

echo "🚀 Setting up Bounce Back Signaling Server on Hack Club Nest..."

# 1. Ensure Node.js & npm are available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found! Please ensure Node is installed on your Nest account."
    exit 1
fi

# 2. Install dependencies
echo "📦 Installing WebSocket dependencies..."
npm install

# 3. Check for PM2 to run in background
if command -v pm2 &> /dev/null; then
    echo "⚡ Starting server with PM2..."
    PORT=${PORT:-8080} pm2 start signaling_server.js --name "bounce-back"
    pm2 save
    echo "✅ Server started with PM2 on port ${PORT:-8080}!"
    echo "   Run 'pm2 logs bounce-back' to view live traffic."
else
    echo "💡 Starting server with nohup in background..."
    PORT=${PORT:-8080} nohup node signaling_server.js > server.log 2>&1 &
    echo "✅ Server started in background! Logs written to server.log"
fi

echo "========================================================================"
echo "🎉 Bounce Back Signaling Server is LIVE!"
echo "If your Nest domain is yourname.hackclub.app, configure Caddy to point"
echo "to localhost:8080. Then in your game on itch.io, connect to:"
echo "   wss://yourname.hackclub.app"
echo "========================================================================"
