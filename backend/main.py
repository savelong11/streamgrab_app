import sys
import os
from pathlib import Path

# Add parent directory and modules directory to path
sys.path.append(str(Path(__file__).parent.parent.parent))
sys.path.append(str(Path(__file__).parent.parent.parent / "youtube_auto_video_maker"))

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from typing import Optional
import logging
import uuid
import yaml

# Import existing modules
from modules.douyin_downloader import download_douyin_video
from modules.ytdlp_helpers import yt_dlp_bin, base_args, download_safe_args
from modules.config import Config

app = FastAPI(title="StreamGrab API")
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Setup templates
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))

class DownloadRequest(BaseModel):
    url: str
    quality: Optional[str] = "best"
    send_to_telegram: bool = False
    upload_to_drive: bool = False

class DownloadResponse(BaseModel):
    job_id: str
    status: str
    message: str

# In-memory job status
jobs = {}

def process_download(job_id: str, url: str, cfg: Config):
    jobs[job_id] = {"status": "processing", "progress": 0}
    try:
        log.info(f"Starting download for {url}")
        
        # Determine output directory (prioritize user setting if exists)
        base_output_dir = Path(cfg.outputs_dir)
        output_dir = base_output_dir / job_id
        output_dir.mkdir(parents=True, exist_ok=True)

        # Get video info first to get the ID
        import subprocess
        info_cmd = [yt_dlp_bin(), "--get-id", "--get-title", url]
        info_proc = subprocess.run(info_cmd, capture_output=True, text=True)
        video_id = info_proc.stdout.split('\n')[0].strip() if info_proc.returncode == 0 else job_id
        
        # Determine platform prefix
        prefix = "video"
        if "youtube.com" in url or "youtu.be" in url: prefix = "youtube"
        elif "facebook.com" in url: prefix = "facebook"
        elif "tiktok.com" in url: prefix = "tiktok"
        elif "douyin.com" in url: prefix = "douyin"

        filename_template = f"{prefix}_{video_id}_%(ext)s"
        
        # Determine platform
        if "douyin.com" in url or "tiktok.com" in url:
            # For simplicity in this demo, we use yt-dlp logic for both
            # but you can keep douyin_downloader if needed.
            # Using yt-dlp with the new template:
            cmd = [
                yt_dlp_bin(),
                "-f", "bestvideo+bestaudio/best",
                "--merge-output-format", "mp4",
                "-o", str(output_dir / filename_template),
                *download_safe_args(base_args(cfg)),
                url
            ]
        else:
            cmd = [
                yt_dlp_bin(),
                "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
                "--merge-output-format", "mp4",
                "-o", str(output_dir / filename_template),
                *download_safe_args(base_args(cfg)),
                url
            ]
            
        log.info(f"Running command: {' '.join(cmd)}")
        proc = subprocess.run(cmd, capture_output=True, text=True)
        
        # Find the downloaded file
        downloaded_files = list(output_dir.glob(f"{prefix}_{video_id}.*"))
        if not downloaded_files: # fallback to any file in dir
            downloaded_files = list(output_dir.glob("*"))

        if proc.returncode == 0 and downloaded_files:
            result = downloaded_files[0]
            jobs[job_id]["status"] = "completed"
            jobs[job_id]["file_path"] = str(result)
            jobs[job_id]["filename"] = result.name
            log.info(f"Download completed: {result}")
            
            # Optional: Upload to Google Drive
            drive_link = None
            if cfg.drive.get("enabled"):
                from modules.pipeline import _upload_to_drive
                log.info(f"Uploading {result} to Google Drive")
                drive_link = _upload_to_drive(result, cfg)
                jobs[job_id]["drive_link"] = drive_link
                
            # Optional: Notify Telegram
            if cfg.telegram.get("bot_token") and cfg.telegram.get("chat_id"):
                from telegram import Bot
                import asyncio
                bot = Bot(token=cfg.telegram["bot_token"])
                msg = f"✅ Video downloaded: {url}\n"
                if drive_link:
                    msg += f"🎬 Drive: {drive_link}"
                
                # We need to run this in an event loop
                async def send_msg():
                    async with bot:
                        await bot.send_message(chat_id=cfg.telegram["chat_id"], text=msg)
                
                try:
                    # Check if there is already a running loop
                    try:
                        loop = asyncio.get_event_loop()
                        if loop.is_running():
                            loop.create_task(send_msg())
                        else:
                            loop.run_until_complete(send_msg())
                    except Exception:
                        asyncio.run(send_msg())
                except Exception as te:
                    log.error(f"Telegram notification failed: {te}")

        else:
            jobs[job_id]["status"] = "failed"
            jobs[job_id]["message"] = "Download failed"
            
    except Exception as e:
        log.exception(f"Error processing {url}")
        jobs[job_id]["status"] = "failed"
        jobs[job_id]["message"] = str(e)

@app.post("/download", response_model=DownloadResponse)
async def start_download(request: DownloadRequest, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())[:8]
    cfg = Config.load()
    
    background_tasks.add_task(process_download, job_id, request.url, cfg)
    
    return DownloadResponse(
        job_id=job_id,
        status="accepted",
        message="Download started in background"
    )

@app.get("/status/{job_id}")
async def get_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    return jobs[job_id]

@app.get("/open-folder/{job_id}")
async def open_folder(job_id: str):
    if job_id not in jobs or "file_path" not in jobs[job_id]:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    folder_path = Path(jobs[job_id]["file_path"]).parent
    if folder_path.exists():
        import subprocess
        subprocess.run(["open", str(folder_path)])
        return {"status": "ok", "message": "Folder opened"}
    else:
        raise HTTPException(status_code=404, detail="Path does not exist")

@app.get("/settings")
async def get_settings():
    cfg = Config.load()
    return {
        "outputs_dir": cfg.outputs_dir,
        "temp_dir": cfg.temp_dir,
        "deepseek_key": cfg.deepseek_api_key,
        "telegram_token": cfg.telegram.get("bot_token", ""),
        "chat_id": cfg.telegram.get("chat_id", ""),
    }

@app.post("/settings")
async def update_settings(
    outputs_dir: str = Form(None),
    deepseek_key: str = Form(None)
):
    cfg_path = Path("config.yaml")
    with open(cfg_path, "r") as f:
        data = yaml.safe_load(f)
    
    if outputs_dir:
        data["paths"]["outputs_dir"] = outputs_dir
    
    with open(cfg_path, "w") as f:
        yaml.dump(data, f)
        
    return {"status": "ok", "message": "Settings updated"}

@app.post("/save-config")
async def save_config(
    deepseek_key: str = Form(...),
    telegram_token: str = Form(...),
    chat_id: str = Form(...),
    drive_enabled: bool = Form(False)
):
    try:
        # Update .env
        env_path = Path(".env")
        with open(env_path, "w") as f:
            f.write(f"DEEPSEEK_API_KEY={deepseek_key}\n")
            f.write(f"TELEGRAM_BOT_TOKEN={telegram_token}\n")
        
        # Update config.yaml
        cfg_path = Path("config.yaml")
        with open(cfg_path, "r") as f:
            data = yaml.safe_load(f)
        
        data["telegram"]["chat_id"] = chat_id
        data["drive"]["enabled"] = drive_enabled
        
        with open(cfg_path, "w") as f:
            yaml.dump(data, f)
            
        return {"status": "ok", "message": "Configuration saved successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
