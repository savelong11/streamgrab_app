import os
import subprocess
import sys
import webbrowser
import time
from pathlib import Path

def run_command(cmd):
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
    return True

def setup():
    print("🚀 Starting StreamGrab One-Click Setup...")
    
    # 1. Install dependencies
    print("📦 Installing Python dependencies...")
    if not run_command([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn", "jinja2", "python-multipart", "pyyaml", "python-dotenv"]):
        print("❌ Failed to install dependencies.")
        return

    # 2. Check for FFmpeg
    print("🎬 Checking for FFmpeg...")
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True)
        print("✅ FFmpeg is already installed.")
    except FileNotFoundError:
        print("📥 FFmpeg not found. Downloading...")
        # Reusing existing dl_ffmpeg.py logic if available
        dl_script = Path(__file__).parent.parent.parent / "dl_ffmpeg.py"
        if dl_script.exists():
            run_command([sys.executable, str(dl_script)])
        else:
            print("⚠️ Please install FFmpeg manually.")

    # 3. Start Backend in background
    print("🌐 Starting Backend server...")
    backend_script = Path(__file__).parent / "backend" / "main.py"
    
    # We'll use a separate process for the backend
    proc = subprocess.Popen([sys.executable, str(backend_script)])
    
    # 4. Wait and Open Browser
    print("🖥 Opening Setup UI in browser...")
    time.sleep(2)  # Wait for server to start
    webbrowser.open("http://localhost:8000/setup")
    
    print("\n✅ Setup is running! Please configure your keys in the browser window.")
    print("Press Ctrl+C to stop the backend once you are finished.")
    
    try:
        proc.wait()
    except KeyboardInterrupt:
        print("\nStopping backend...")
        proc.terminate()

if __name__ == "__main__":
    setup()
