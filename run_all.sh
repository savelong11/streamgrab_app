#!/bin/bash

# StreamGrab Unified Startup Script
# This script checks for dependencies, installs them if missing, and starts both Backend and Frontend.

echo "🚀 Starting StreamGrab Unified Setup & Run..."

# 1. Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed. Please install it first from https://brew.sh/"
    exit 1
fi

# 2. Check and Install FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "📥 FFmpeg not found. Installing via Homebrew..."
    brew install ffmpeg
else
    echo "✅ FFmpeg is already installed."
fi

# 3. Check and Install Python3
if ! command -v python3 &> /dev/null; then
    echo "📥 Python3 not found. Installing via Homebrew..."
    brew install python
else
    echo "✅ Python3 is already installed."
fi

# 4. Check and Install Flutter
if ! command -v flutter &> /dev/null; then
    echo "📥 Flutter not found. Installing via Homebrew..."
    brew install --cask flutter
    # Add flutter to path for the current session
    export PATH="$PATH:/usr/local/bin"
else
    echo "✅ Flutter is already installed."
fi

# 5. Link to existing Virtual Environment to save space
echo "🔗 Linking to existing Virtual Environment from youtube_auto_video_maker..."
EXISTING_VENV="/Users/mickey/Documents/Claude/Projects/Youtube-video/youtube_auto_video_maker/.venv"

if [ -d "$EXISTING_VENV" ]; then
    echo "✅ Found existing venv at $EXISTING_VENV. Using it."
    VENV_PYTHON="$EXISTING_VENV/bin/python"
    echo "📦 Ensuring minimal backend dependencies are installed..."
    $VENV_PYTHON -m pip install fastapi uvicorn jinja2 python-multipart pyyaml python-dotenv python-telegram-bot yt-dlp
else
    echo "⚠️ Existing venv not found. Creating local one..."
    PYTHON_BIN=$(command -v python3.13 || command -v python3.12 || command -v python3)
    if [ ! -d ".venv" ]; then
        $PYTHON_BIN -m venv .venv
    fi
    VENV_PYTHON=".venv/bin/python"
    echo "📦 Installing minimal dependencies..."
    $VENV_PYTHON -m pip install fastapi uvicorn jinja2 python-multipart pyyaml python-dotenv python-telegram-bot yt-dlp
fi

# 6. Prepare Flutter Frontend
echo "🔧 Preparing Frontend..."
cd frontend
if [ ! -d "macos" ] && [ ! -d "android" ] && [ ! -d "ios" ]; then
    echo "🏗 Platform folders missing. Initializing Flutter project..."
    flutter create .
fi
flutter pub get
cd ..

# 7. Start Backend in background
echo "🌐 Starting Backend server..."
$VENV_PYTHON backend/main.py > backend.log 2>&1 &
BACKEND_PID=$!

# 8. Start Frontend
echo "🖥 Starting Frontend..."
echo "💡 The Backend is running in the background (PID: $BACKEND_PID). Logs: backend.log"
echo "Press Ctrl+C to stop both."

# Function to kill backend on exit
cleanup() {
    echo -e "\n🛑 Stopping Backend (PID: $BACKEND_PID)..."
    kill $BACKEND_PID
    exit
}
trap cleanup SIGINT

cd frontend
flutter run -d macos
