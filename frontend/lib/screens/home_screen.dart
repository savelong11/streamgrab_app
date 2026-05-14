import 'package:flutter/material.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _jobId;
  String _status = "Sẵn sàng";
  String? _errorMessage;
  final List<String> _logs = [];
  String _outputsDir = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    try {
      final settings = await ApiService.getSettings();
      setState(() {
        _outputsDir = settings['outputs_dir'];
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, "${DateTime.now().toString().split('.').first.split(' ').last}: $message");
      if (_logs.length > 5) _logs.removeLast();
    });
  }

  String _cleanUrl(String url) {
    url = url.trim();
    // Example: Clean YouTube shorts or long parameters
    if (url.contains("youtube.com/watch?v=")) {
      final id = url.split("v=")[1].split("&")[0];
      return "https://www.youtube.com/watch?v=$id";
    }
    return url;
  }

  bool _validateUrl(String url) {
    if (url.isEmpty) return false;
    
    final youtubeRegex = RegExp(r"^(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+$");
    final facebookRegex = RegExp(r"^(https?://)?(www\.)?facebook\.com/.+$");
    final tiktokRegex = RegExp(r"^(https?://)?(www\.|vt\.)?tiktok\.com/.+$");
    final douyinRegex = RegExp(r"^(https?://)?(www\.|v\.)?douyin\.com/.+$");

    // Check for profile links
    if (url.contains("profile.php") || url.contains("/profile/") || (url.contains("facebook.com") && !url.contains("/videos/") && !url.contains("/reel/") && !url.contains("/posts/"))) {
       if (url.contains("facebook.com")) {
         setState(() {
           _errorMessage = "Đây là link trang cá nhân Facebook. Vui lòng dán link VIDEO hoặc REEL cụ thể.";
         });
         return false;
       }
    }

    if (youtubeRegex.hasMatch(url) || facebookRegex.hasMatch(url) || tiktokRegex.hasMatch(url) || douyinRegex.hasMatch(url)) {
      return true;
    }
    
    setState(() {
      _errorMessage = "Đường dẫn không hợp lệ. Hãy đảm bảo đây là link video (YouTube, TikTok, Douyin hoặc Facebook).";
    });
    return false;
  }

  void _handleAnalyze() async {
    String url = _cleanUrl(_urlController.text);
    if (!_validateUrl(url)) return;

    setState(() {
      _isLoading = true;
      _status = "Đang phân tích...";
      _errorMessage = null;
      _jobId = null;
    });
    _addLog("Bắt đầu phân tích: $url");

    try {
      final res = await ApiService.startDownload(url);
      setState(() {
        _jobId = res['job_id'];
        _status = "Đang tải xuống...";
      });
      _addLog("Máy chủ đã nhận việc. Mã công việc: $_jobId");
      _startStatusPolling();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = "Lỗi";
        _errorMessage = "Không thể kết nối với máy chủ. Vui lòng kiểm tra lại backend.log.";
      });
      _addLog("❌ LỖI KẾT NỐI: $e");
    }
  }

  void _showSettings() {
    final TextEditingController dirController = TextEditingController(text: _outputsDir);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Cài đặt", style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Thư mục lưu video:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: dirController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Hướng dẫn"),
                    content: const Text("1. Dán link video vào ô nhập liệu.\n2. Bấm PHÂN TÍCH & TẢI VỀ.\n3. Đợi tiến trình hoàn tất và bấm MỞ THƯ MỤC."),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng"))],
                  ),
                );
              },
              child: Text("Xem hướng dẫn sử dụng", style: GoogleFonts.inter(color: Colors.blueAccent, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              await ApiService.updateSettings(dirController.text);
              setState(() => _outputsDir = dirController.text);
              Navigator.pop(context);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  void _startStatusPolling() async {
    if (_jobId == null) return;

    while (_isLoading) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final res = await ApiService.getStatus(_jobId!);
        setState(() {
          _status = res['status'];
          if (_status == "completed") {
            _isLoading = false;
            _addLog("✅ Tải video thành công: ${res['filename'] ?? ''}");
          } else if (_status == "failed") {
            _isLoading = false;
            _errorMessage = res['message'] ?? "Tải xuống thất bại.";
            _addLog("❌ Tải xuống thất bại: $_errorMessage");
          }
        });
      } catch (e) {
        _addLog("⚠️ Đang kiểm tra lại trạng thái...");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.15),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .move(begin: const Offset(0, 0), end: const Offset(-20, 30), duration: 5.seconds),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.1),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .move(begin: const Offset(0, 0), end: const Offset(30, -20), duration: 7.seconds),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                      IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings, color: Colors.white70)),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  Text(
                    "StreamGrab",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    "Tải video đa nền tảng cực nhanh.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 10),

                  // Platforms
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPlatformIcon(Icons.video_library, "YT", Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      _buildPlatformIcon(Icons.tiktok, "TT", Colors.cyanAccent, size: 16),
                      const SizedBox(width: 8),
                      _buildPlatformIcon(Icons.music_video, "DY", Colors.pinkAccent, size: 16),
                      const SizedBox(width: 8),
                      _buildPlatformIcon(Icons.facebook, "FB", Colors.blueAccent, size: 16),
                    ],
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 30),

                  // STATUS & LOGS (COMPACT)
                  if (_jobId != null) _buildStatusCard().animate().fadeIn(),
                  
                  if (_logs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("TIẾN TRÌNH", style: GoogleFonts.outfit(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: _logs.join("\n")));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã sao chép")));
                                  },
                                  child: Text("SAO CHÉP", style: GoogleFonts.outfit(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ..._logs.take(3).map((log) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SelectableText(log, style: GoogleFonts.inter(fontSize: 10, color: log.contains("❌") ? Colors.redAccent : Colors.white70)),
                            )),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(),

                  // Input Section
                  GlassContainer(
                    blur: 25,
                    opacity: 0.08,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _urlController,
                            onChanged: (_) => setState(() => _errorMessage = null),
                            decoration: InputDecoration(
                              hintText: "Dán link video tại đây...",
                              hintStyle: GoogleFonts.inter(color: Colors.white24),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.link_rounded, color: Colors.blueAccent),
                            ),
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),

                          InkWell(
                            onTap: _isLoading ? null : _handleAnalyze,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFA855F7)]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.indigo.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "PHÂN TÍCH & TẢI VỀ",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 100), // Extra space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformIcon(IconData icon, String label, Color color, {double size = 24}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(size / 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: size),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 8, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return GlassContainer(
      blur: 15,
      opacity: 0.05,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mã công việc: $_jobId",
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _status == "completed" ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                  if (_status == "completed")
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InkWell(
                        onTap: () => ApiService.openFolder(_jobId!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.folder_open, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 8),
                              Text("MỞ THƯ MỤC", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
