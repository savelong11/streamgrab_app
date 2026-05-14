# 🚀 StreamGrab - Multi-Platform Video Downloader

**StreamGrab** là một ứng dụng tải video cao cấp, hỗ trợ đa nền tảng (YouTube, TikTok, Douyin, Facebook) với giao diện hiện đại, tốc độ vượt trội và tích hợp các tính năng tự động hóa thông minh.

![StreamGrab Preview](https://raw.githubusercontent.com/savelong11/streamgrab_app/main/frontend/assets/preview.png) *(Lưu ý: Thay bằng link ảnh thật của bạn)*

## ✨ Tính năng nổi bật

-   **Hỗ trợ đa nền tảng:** Tải video từ YouTube, TikTok, Douyin và Facebook chỉ với một cú click.
-   **Giao diện Glassmorphism:** Thiết kế hiện đại, sang trọng với các hiệu ứng làm mờ và chuyển động mượt mà.
-   **Quản lý thông minh:**
    *   Tự động đặt tên file theo ID định danh của video.
    *   Tùy chỉnh thư mục lưu trữ video ngay trong ứng dụng.
-   **Tự động hóa:** Tích hợp đẩy video lên Google Drive và thông báo qua Telegram.
-   **Nhận diện link thông minh:** Tự động lọc link rác và cảnh báo nếu người dùng dán sai định dạng link (như link trang cá nhân).
-   **Siêu gọn nhẹ:** Giao diện được tối ưu để hiển thị vừa vặn trên màn hình, không tốn diện tích.

## 🛠 Công nghệ sử dụng

-   **Frontend:** Flutter (với các hiệu ứng Glassmorphism & Animations).
-   **Backend:** FastAPI (Python 3.13) - Xử lý API tốc độ cao.
-   **Công cụ tải:** `yt-dlp` & `ffmpeg` - Đảm bảo chất lượng video tốt nhất (4K/HD).
-   **Lưu trữ & Thông báo:** Google Drive API & Telegram Bot API.

## 🚀 Hướng dẫn cài đặt & Chạy nhanh

### 1. Yêu cầu hệ thống
-   macOS (M1/M2/M3 hoặc Intel).
-   Python 3.12+ và Flutter SDK.
-   FFmpeg (Cài qua Homebrew: `brew install ffmpeg`).

### 2. Khởi chạy ứng dụng
Dự án đã được tự động hóa hoàn toàn. Bạn chỉ cần mở Terminal tại thư mục dự án và chạy:

```bash
./run_all.sh
```

Lệnh này sẽ tự động:
1.  Thiết lập môi trường ảo Python.
2.  Cài đặt các thư viện cần thiết.
3.  Khởi chạy Backend (Cổng 8000).
4.  Mở ứng dụng Flutter trên máy Mac của bạn.

## ⚙️ Cài đặt cấu hình
Bạn có thể điều chỉnh các thông số chuyên sâu (Token Telegram, Google Drive) trong file `config.yaml` hoặc thông qua bảng **Cài đặt** trực tiếp trên ứng dụng.

---

## 🤝 Đóng góp
Mọi ý kiến đóng góp hoặc báo lỗi vui lòng mở **Issue** trên GitHub của dự án.

**Phát triển bởi [savelong11](https://github.com/savelong11)**
