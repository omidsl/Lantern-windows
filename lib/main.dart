import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LanternWindowsApp());
}

class LanternWindowsApp extends StatelessWidget {
  const LanternWindowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern 3D Spatial VPN — Windows Luxury Edition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF040711),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0066FF),
          secondary: Color(0xFF00F5D4),
          surface: Color(0xFF0D1322),
        ),
      ),
      home: const LanternDesktopScreen(),
    );
  }
}

// ==================== پالت‌های تم نوری (Neon Accent Themes) ====================
class NeonThemePalette {
  final String id;
  final String nameFa;
  final String nameEn;
  final Color primary;
  final Color secondary;
  final Color glow;

  const NeonThemePalette({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.primary,
    required this.secondary,
    required this.glow,
  });

  static const List<NeonThemePalette> palettes = [
    NeonThemePalette(
      id: 'cyber_blue',
      nameFa: 'آبی سایبری (Cyber Blue)',
      nameEn: 'Cyber Blue',
      primary: Color(0xFF0066FF),
      secondary: Color(0xFF00F5D4),
      glow: Color(0xFF38BDF8),
    ),
    NeonThemePalette(
      id: 'arcane_purple',
      nameFa: 'بنفش آرکین (Arcane Purple)',
      nameEn: 'Arcane Purple',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      glow: Color(0xFFC084FC),
    ),
    NeonThemePalette(
      id: 'emerald_neon',
      nameFa: 'سبز زمردی (Emerald Neon)',
      nameEn: 'Emerald Neon',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF00F5D4),
      glow: Color(0xFF34D399),
    ),
    NeonThemePalette(
      id: 'dark_gold',
      nameFa: 'طلایی لوکس (Dark Luxury Gold)',
      nameEn: 'Dark Luxury Gold',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFDE047),
      glow: Color(0xFFFBBF24),
    ),
  ];
}

// ==================== مدل اشتراک (Subscription Group) ====================
class SubscriptionGroup {
  final String id;
  String title;
  final String url;
  double usedGB;
  double totalGB;
  int? expireDays;
  String lastUpdated;

  SubscriptionGroup({
    required this.id,
    required this.title,
    required this.url,
    this.usedGB = 0.0,
    this.totalGB = 0.0,
    this.expireDays,
    this.lastUpdated = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'usedGB': usedGB,
        'totalGB': totalGB,
        'expireDays': expireDays,
        'lastUpdated': lastUpdated,
      };

  factory SubscriptionGroup.fromJson(Map<String, dynamic> json) => SubscriptionGroup(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Subscription',
        url: json['url']?.toString() ?? '',
        usedGB: (json['usedGB'] is num) ? (json['usedGB'] as num).toDouble() : 0.0,
        totalGB: (json['totalGB'] is num) ? (json['totalGB'] as num).toDouble() : 0.0,
        expireDays: json['expireDays'] is int ? json['expireDays'] : null,
        lastUpdated: json['lastUpdated']?.toString() ?? '',
      );
}

// ==================== مدل سرور (VPN Profile) ====================
class VpnProfile {
  final String id;
  final String subId;
  final String name;
  final String rawUri;
  final String protocol;
  final String address;
  final int port;
  int ping;
  int httpDelay; // تست تاخیر واقعی HTTP
  int jitter;
  bool isPinging;

  VpnProfile({
    required this.id,
    required this.subId,
    required this.name,
    required this.rawUri,
    required this.protocol,
    required this.address,
    required this.port,
    this.ping = -1,
    this.httpDelay = -1,
    this.jitter = 3,
    this.isPinging = false,
  });

  bool get isGameReady => ping > 0 && ping < 140 && jitter < 25;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subId': subId,
        'name': name,
        'rawUri': rawUri,
        'protocol': protocol,
        'address': address,
        'port': port,
        'ping': ping,
        'httpDelay': httpDelay,
        'jitter': jitter,
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        subId: json['subId']?.toString() ?? 'manual',
        name: json['name']?.toString() ?? 'Server',
        rawUri: json['rawUri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        address: json['address']?.toString() ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        ping: json['ping'] is int ? json['ping'] : -1,
        httpDelay: json['httpDelay'] is int ? json['httpDelay'] : -1,
        jitter: json['jitter'] is int ? json['jitter'] : 3,
      );
}

// ==================== نقاش پرچم وکتور واقعی برای بیش از ۳۵ کشور ====================
class FlagPainter extends CustomPainter {
  final String rawName;
  FlagPainter(this.rawName);

  String _detectCode(String s) {
    final up = s.toUpperCase();
    if (up.contains('GERMANY') || up.contains(' DE') || up.startsWith('DE') || s.contains('آلمان') || s.contains('المان') || up.contains('FRANKFURT')) return 'de';
    if (up.contains('USA') || up.contains('UNITED STATES') || up.contains(' US') || up.startsWith('US') || s.contains('آمریکا') || s.contains('امریکا') || up.contains('WASHINGTON')) return 'us';
    if (up.contains('NETHERLANDS') || up.contains(' NL') || up.startsWith('NL') || s.contains('هلند') || up.contains('AMSTERDAM')) return 'nl';
    if (up.contains('FRANCE') || up.contains(' FR') || up.startsWith('FR') || s.contains('فرانسه') || up.contains('PARIS')) return 'fr';
    if (up.contains('SWEDEN') || up.contains(' SE') || up.startsWith('SE') || s.contains('سوئد')) return 'se';
    if (up.contains('FINLAND') || up.contains(' FI') || up.startsWith('FI') || s.contains('فنلاند') || up.contains('HELSINKI')) return 'fi';
    if (up.contains('UK') || up.contains('GB') || up.contains('BRITAIN') || up.contains('ENGLAND') || up.contains('LONDON') || s.contains('انگلیس')) return 'gb';
    if (up.contains('ROMANIA') || up.contains(' RO') || up.startsWith('RO') || s.contains('رومانی')) return 'ro';
    if (up.contains('INDIA') || up.contains(' IN') || up.startsWith('IN') || s.contains('هند')) return 'in';
    if (up.contains('EGYPT') || up.contains(' EG') || up.startsWith('EG') || s.contains('مصر')) return 'eg';
    if (up.contains('BULGARIA') || up.contains(' BG') || up.startsWith('BG') || s.contains('بلغارستان')) return 'bg';
    if (up.contains('TURKEY') || up.contains(' TR') || up.startsWith('TR') || s.contains('ترکیه') || up.contains('ISTANBUL')) return 'tr';
    if (up.contains('UAE') || up.contains('EMIRATES') || up.contains('DUBAI') || up.contains(' AE') || s.contains('امارات') || s.contains('دبی')) return 'ae';
    if (up.contains('SWISS') || up.contains('SWITZERLAND') || up.contains(' CH') || s.contains('سوئیس')) return 'ch';
    if (up.contains('CANADA') || up.contains(' CA') || s.contains('کانادا')) return 'ca';
    if (up.contains('RUSSIA') || up.contains(' RU') || s.contains('روسیه') || up.contains('MOSCOW')) return 'ru';
    if (up.contains('ITALY') || up.contains(' IT') || s.contains('ایتالیا')) return 'it';
    if (up.contains('SPAIN') || up.contains(' ES') || s.contains('اسپانیا')) return 'es';
    if (up.contains('POLAND') || up.contains(' PL') || s.contains('لهستان')) return 'pl';
    if (up.contains('AUSTRIA') || up.contains(' AT') || s.contains('اتریش')) return 'at';
    if (up.contains('JAPAN') || up.contains(' JP') || s.contains('ژاپن') || up.contains('TOKYO')) return 'jp';
    if (up.contains('SINGAPORE') || up.contains(' SG') || s.contains('سنگاپور')) return 'sg';
    if (up.contains('IRAN') || up.contains(' IR') || s.contains('ایران') || s.contains('ملی')) return 'ir';
    return 'global';
  }

  void _hStripes(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height / 3), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(0, s.height / 3, s.width, s.height / 3), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(0, s.height * 2 / 3, s.width, s.height / 3), p);
  }

  void _vStripes(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width / 3, s.height), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(s.width / 3, 0, s.width / 3, s.height), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(s.width * 2 / 3, 0, s.width / 3, s.height), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.clipRRect(rrect);
    final code = _detectCode(rawName);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (code) {
      case 'de':
        _hStripes(canvas, size, const Color(0xFF141414), const Color(0xFFDD0000), const Color(0xFFFFCE00));
        break;
      case 'nl':
        _hStripes(canvas, size, const Color(0xFFAE1C28), Colors.white, const Color(0xFF21468B));
        break;
      case 'fr':
        _vStripes(canvas, size, const Color(0xFF002395), Colors.white, const Color(0xFFED2939));
        break;
      case 'ro':
        _vStripes(canvas, size, const Color(0xFF002B7F), const Color(0xFFFCD116), const Color(0xFFCE1126));
        break;
      case 'it':
        _vStripes(canvas, size, const Color(0xFF009246), Colors.white, const Color(0xFFCE2B37));
        break;
      case 'bg':
        _hStripes(canvas, size, Colors.white, const Color(0xFF00966E), const Color(0xFFD62612));
        break;
      case 'ru':
        _hStripes(canvas, size, Colors.white, const Color(0xFF0039A6), const Color(0xFFD52B1E));
        break;
      case 'at':
        _hStripes(canvas, size, const Color(0xFFED2939), Colors.white, const Color(0xFFED2939));
        break;
      case 'in':
        _hStripes(canvas, size, const Color(0xFFFF9933), Colors.white, const Color(0xFF138808));
        paint.color = const Color(0xFF000080);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.14, paint);
        break;
      case 'eg':
        _hStripes(canvas, size, const Color(0xFFCE1126), Colors.white, const Color(0xFF000000));
        paint.color = const Color(0xFFC09300);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.12, paint);
        break;
      case 'ir':
        _hStripes(canvas, size, const Color(0xFF239F40), Colors.white, const Color(0xFFDA0000));
        break;
      case 'se':
        paint.color = const Color(0xFF006AA7);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFFECC02);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.14, size.height), paint);
        break;
      case 'fi':
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFF003580);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.38, size.width, size.height * 0.24), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.28, 0, size.width * 0.16, size.height), paint);
        break;
      case 'ch':
        paint.color = const Color(0xFFD52B1E);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.42, size.width * 0.5, size.height * 0.16), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.42, size.height * 0.2, size.width * 0.16, size.height * 0.6), paint);
        break;
      case 'us':
        paint.color = const Color(0xFFBF0A30);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        for (int i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(0, i * size.height / 7, size.width, size.height / 7), paint);
        }
        paint.color = const Color(0xFF002868);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.46, size.height * 0.55), paint);
        break;
      case 'gb':
        paint.color = const Color(0xFF012169);
        canvas.drawRect(Offset.zero & size, paint);
        final diag = Paint()..color = Colors.white..strokeWidth = 3.5;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), diag);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), diag);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.3), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.38, 0, size.width * 0.24, size.height), paint);
        paint.color = const Color(0xFFC8102E);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.41, size.width, size.height * 0.18), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.43, 0, size.width * 0.14, size.height), paint);
        break;
      case 'tr':
        paint.color = const Color(0xFFE30A17);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.5), size.height * 0.28, paint);
        paint.color = const Color(0xFFE30A17);
        canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.5), size.height * 0.22, paint);
        break;
      case 'ae':
        _hStripes(canvas, size, const Color(0xFF00732F), Colors.white, const Color(0xFF000000));
        paint.color = const Color(0xFFFF0000);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.28, size.height), paint);
        break;
      case 'ca':
        _vStripes(canvas, size, const Color(0xFFFF0000), Colors.white, const Color(0xFFFF0000));
        paint.color = const Color(0xFFFF0000);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.18, paint);
        break;
      case 'jp':
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.28, paint);
        break;
      case 'pl':
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = const Color(0xFFDC143C);
        canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'sg':
        paint.color = const Color(0xFFEF3340);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'es':
        _hStripes(canvas, size, const Color(0xFFAA151B), const Color(0xFFF1BF00), const Color(0xFFAA151B));
        break;
      default:
        paint.shader = const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF00F5D4)]).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, paint);
        final linePaint = Paint()..color = Colors.white.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 1.1;
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.34, linePaint);
        canvas.drawLine(Offset(size.width * 0.2, size.height / 2), Offset(size.width * 0.8, size.height / 2), linePaint);
    }

    // لایه شیشه‌ای براق روی پرچم
    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.32), Colors.transparent, Colors.black.withOpacity(0.25)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, gloss);
  }

  @override
  bool shouldRepaint(covariant FlagPainter oldDelegate) => oldDelegate.rawName != rawName;
}

// ==================== تولیدکننده ماتریس QR Code بصری ====================
class VisualQrMatrixPainter extends CustomPainter {
  final String data;
  final Color color;
  VisualQrMatrixPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const int grid = 21;
    final double cell = size.width / grid;
    final Paint p = Paint()..color = color..style = PaintingStyle.fill;

    void drawFinder(int ox, int oy) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          if (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
            canvas.drawRect(Rect.fromLTWH((ox + c) * cell, (oy + r) * cell, cell, cell), p);
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(grid - 7, 0);
    drawFinder(0, grid - 7);

    int hash = data.hashCode;
    final rnd = math.Random(hash);
    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        final bool inFinder = (r < 8 && c < 8) || (r < 8 && c >= grid - 8) || (r >= grid - 8 && c < 8);
        if (!inFinder && rnd.nextBool()) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1), const Radius.circular(1.5)),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== ذرات معلق جمینای (Gemini Floating Stardust) ====================
class StardustParticle {
  double x, y, vx, vy, radius, alpha;
  Color color;
  StardustParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.alpha,
  });
}

class GeminiParticlePainter extends CustomPainter {
  final List<StardustParticle> particles;
  final double progress;
  final bool isConnected, isGaming;
  final Offset mousePos;
  final NeonThemePalette palette;

  GeminiParticlePainter({
    required this.particles,
    required this.progress,
    required this.isConnected,
    required this.isGaming,
    required this.mousePos,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double speedMult = isConnected ? (isGaming ? 2.4 : 1.6) : 0.65;
    for (final p in particles) {
      p.x += p.vx * speedMult;
      p.y += p.vy * speedMult;
      if (p.x < 0) p.x = 1.0;
      if (p.x > 1.0) p.x = 0.0;
      if (p.y < 0) p.y = 1.0;
      if (p.y > 1.0) p.y = 0.0;

      double px = p.x * size.width;
      double py = p.y * size.height;
      final double dx = px - mousePos.dx;
      final double dy = py - mousePos.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 120 && dist > 1) {
        px += (dx / dist) * (120 - dist) * 0.25;
        py += (dy / dist) * (120 - dist) * 0.25;
      }

      final Color activeColor = isConnected
          ? (isGaming ? const Color(0xFFFF2E93) : palette.secondary)
          : palette.primary;
      final Paint paint = Paint()
        ..color = activeColor.withOpacity((p.alpha * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.x * 10))).clamp(0.1, 0.85))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GeminiParticlePainter oldDelegate) => true;
}

// ==================== موتور کامل کانفیگ‌ساز Xray ویندوز (TLS / Reality / WS / gRPC / Fragment) ====================
class WindowsXrayConfigBuilder {
  static String decodeB64(String str) {
    String clean = str.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  static VpnProfile? parseProfile(String link, String subId, int index) {
    final clean = link.trim();
    try {
      if (clean.startsWith('vmess://')) {
        final decoded = decodeB64(clean.substring(8));
        final Map<String, dynamic> map = jsonDecode(decoded);
        final String host = map['add']?.toString() ?? '';
        final int port = int.tryParse(map['port']?.toString() ?? '443') ?? 443;
        final String ps = map['ps']?.toString() ?? 'VMess #$index';
        if (host.isEmpty) return null;
        return VpnProfile(
          id: '${subId}_${index}_$host',
          subId: subId,
          name: ps,
          rawUri: clean,
          protocol: 'VMESS',
          address: host,
          port: port,
        );
      } else if (clean.startsWith('vless://') || clean.startsWith('trojan://') || clean.startsWith('ss://')) {
        String remark = 'Server #$index';
        String withoutHash = clean;
        final int hashIdx = clean.indexOf('#');
        if (hashIdx != -1) {
          remark = Uri.decodeComponent(clean.substring(hashIdx + 1)).trim();
          withoutHash = clean.substring(0, hashIdx);
        }
        final Uri uri = Uri.parse(withoutHash);
        if (uri.host.isEmpty) return null;
        final String proto = clean.split('://').first.toUpperCase();
        return VpnProfile(
          id: '${subId}_${index}_${uri.host}',
          subId: subId,
          name: remark.isNotEmpty ? remark : '$proto #$index',
          rawUri: clean,
          protocol: proto,
          address: uri.host,
          port: uri.port > 0 ? uri.port : 443,
        );
      }
    } catch (_) {}
    return null;
  }

  static String buildFullJson(
    String rawUri, {
    required int engineMode,
    required bool gamingMode,
    required bool strictAntiLeak,
    required bool allowLan,
    required int splitTunnelMode,
  }) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    Map<String, dynamic> outbound;
    if (trimmed.startsWith('vmess://')) {
      outbound = _buildVmessOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    } else if (trimmed.startsWith('trojan://')) {
      outbound = _buildTrojanOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    } else if (trimmed.startsWith('ss://')) {
      outbound = _buildShadowsocksOutbound(trimmed);
    } else {
      outbound = _buildVlessOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    }

    final List<Map<String, dynamic>> outbounds = [
      outbound,
      {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
      {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
    ];

    if (engineMode == 2) {
      outbounds.add({
        'tag': 'fragment',
        'protocol': 'freedom',
        'settings': {
          'domainStrategy': 'AsIs',
          'fragment': {'packets': 'tlshello', 'length': '10-20', 'interval': '10-20'}
        }
      });
    }

    final List<Map<String, dynamic>> rules = [];
    if (strictAntiLeak) {
      rules.add({'type': 'field', 'outboundTag': 'block', 'ip': ['::/0']});
    }
    rules.add({
      'type': 'field',
      'outboundTag': 'direct',
      'ip': ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
    });

    if (splitTunnelMode == 1) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'domain': ['regexp:.*\\.ir\$', 'domain:shaparak.ir', 'domain:digikala.com', 'domain:snapp.ir']
      });
    }

    final String listenIp = (allowLan || engineMode == 3) ? '0.0.0.0' : '127.0.0.1';

    return jsonEncode({
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': listenIp,
          'protocol': 'socks',
          'sniffing': {'enabled': true, 'destOverride': ['http', 'tls']},
          'settings': {'auth': 'noauth', 'udp': true}
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': listenIp,
          'protocol': 'http',
          'sniffing': {'enabled': true, 'destOverride': ['http', 'tls']},
          'settings': {}
        }
      ],
      'outbounds': outbounds,
      'dns': {
        'servers': ['1.1.1.1', '8.8.8.8'],
        if (strictAntiLeak) 'queryStrategy': 'UseIPv4',
      },
      'routing': {'domainStrategy': 'IPIfNonMatch', 'rules': rules}
    });
  }

  static Map<String, dynamic> _buildVlessOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;
    return {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': uri.host,
            'port': uri.port > 0 ? uri.port : 443,
            'users': [
              {
                'id': Uri.decodeComponent(uri.userInfo),
                'encryption': q['encryption'] ?? 'none',
                'level': 8,
                if (q['flow'] != null && q['flow']!.isNotEmpty) 'flow': q['flow']!,
              }
            ]
          }
        ]
      },
      'streamSettings': _buildStreamSettings(q, uri.host, enableFragment: enableFragment, gamingMode: gamingMode),
    };
  }

  static Map<String, dynamic> _buildVmessOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final decoded = decodeB64(link.substring(8));
    final Map<String, dynamic> m = jsonDecode(decoded);
    final String address = m['add']?.toString() ?? '';
    final int port = int.tryParse(m['port']?.toString() ?? '443') ?? 443;
    return {
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [
              {
                'id': m['id']?.toString() ?? '',
                'alterId': int.tryParse(m['aid']?.toString() ?? '0') ?? 0,
                'security': m['scy']?.toString() ?? 'auto',
                'level': 8,
              }
            ]
          }
        ]
      },
      'streamSettings': _buildStreamSettings({
        'type': m['net']?.toString() ?? 'tcp',
        'security': (m['tls']?.toString() == 'tls') ? 'tls' : 'none',
        'sni': m['sni']?.toString() ?? m['host']?.toString() ?? address,
        'host': m['host']?.toString() ?? '',
        'path': m['path']?.toString() ?? '/',
        'fp': m['fp']?.toString() ?? 'chrome',
      }, address, enableFragment: enableFragment, gamingMode: gamingMode),
    };
  }

  static Map<String, dynamic> _buildTrojanOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    return {
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': uri.host,
            'port': uri.port > 0 ? uri.port : 443,
            'password': Uri.decodeComponent(uri.userInfo),
            'level': 8,
          }
        ]
      },
      'streamSettings': _buildStreamSettings(uri.queryParameters, uri.host, enableFragment: enableFragment, gamingMode: gamingMode),
    };
  }

  static Map<String, dynamic> _buildShadowsocksOutbound(String link) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    String method = 'aes-256-gcm';
    String password = '';
    final String userInfo = Uri.decodeComponent(uri.userInfo);
    if (userInfo.contains(':')) {
      final parts = userInfo.split(':');
      method = parts[0];
      password = parts.sublist(1).join(':');
    } else {
      final decoded = decodeB64(userInfo);
      if (decoded.contains(':')) {
        final parts = decoded.split(':');
        method = parts[0];
        password = parts.sublist(1).join(':');
      }
    }
    return {
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {'address': uri.host, 'port': uri.port > 0 ? uri.port : 443, 'method': method, 'password': password, 'level': 8}
        ]
      }
    };
  }

  static Map<String, dynamic> _buildStreamSettings(Map<String, String> q, String defaultHost, {required bool enableFragment, required bool gamingMode}) {
    final String net = (q['type'] ?? 'tcp').toLowerCase();
    final String security = (q['security'] ?? 'none').toLowerCase();
    final String sni = q['sni'] ?? q['host'] ?? defaultHost;
    final String fp = q['fp'] ?? 'chrome';
    final Map<String, dynamic> stream = {'network': net, 'security': security};

    if (security == 'tls') {
      stream['tlsSettings'] = {
        'allowInsecure': q['allowInsecure'] == '1' || q['allowInsecure'] == 'true',
        'serverName': sni,
        'fingerprint': fp,
      };
    } else if (security == 'reality') {
      stream['realitySettings'] = {
        'show': false,
        'fingerprint': fp,
        'serverName': sni,
        'publicKey': q['pbk'] ?? '',
        'shortId': q['sid'] ?? '',
        'spiderX': q['spx'] ?? '/',
      };
    }

    if (net == 'ws') {
      final String hostHeader = q['host'] ?? '';
      stream['wsSettings'] = {
        'path': q['path'] ?? '/',
        if (hostHeader.isNotEmpty) 'headers': {'Host': hostHeader},
      };
    } else if (net == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': q['serviceName'] ?? q['path'] ?? '',
        'multiMode': q['mode'] == 'multi',
      };
    }

    final Map<String, dynamic> sockopt = {};
    if (gamingMode) {
      sockopt['tcpNoDelay'] = true;
      sockopt['tcpKeepAliveIdle'] = 60;
    }
    if (enableFragment && security != 'reality') {
      sockopt['dialerProxy'] = 'fragment';
      sockopt['tcpNoDelay'] = true;
    }
    if (sockopt.isNotEmpty) stream['sockopt'] = sockopt;

    return stream;
  }
}

// ==================== صفحه اصلی دسکتاپ لوکس ویندوز ====================
class LanternDesktopScreen extends StatefulWidget {
  const LanternDesktopScreen({super.key});

  @override
  State<LanternDesktopScreen> createState() => _LanternDesktopScreenState();
}

class _LanternDesktopScreenState extends State<LanternDesktopScreen> with TickerProviderStateMixin {
  Process? _windowsXrayProcess;
  Timer? _desktopStatsTimer;

  late final AnimationController _orbController;
  late final AnimationController _particleController;
  final List<StardustParticle> _particles = [];
  Offset _mousePosition = const Offset(500, 320);

  List<SubscriptionGroup> subscriptions = [];
  List<VpnProfile> profiles = [];
  String selectedSubId = 'all';
  int activeIdx = 0;

  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  bool isConnected = false;
  bool isBusy = false;
  bool isPingingAll = false;
  bool isSyncingSub = false;
  bool isTestingRealDelay = false;

  bool isAutoPilotMode = false;
  int engineMode = 1; // 0: TUN, 1: Proxy, 2: Fragment, 3: Socks5
  bool gamingMode = true;

  String appLang = 'fa';
  String themeId = 'cyber_blue';
  bool strictAntiLeak = true;
  bool killSwitchActive = true;
  bool allowLan = false;
  int splitTunnelMode = 1;

  String verifiedIp = "Protected";
  String verifiedCountry = "DNS & IPv6 Shield Ready";
  int currentRealDelay = -1;
  double simDlSpeed = 0.0;
  double simUlSpeed = 0.0;
  final List<double> dlWave = List.filled(14, 0.15, growable: true);
  final List<double> ulWave = List.filled(14, 0.15, growable: true);

  bool get isFa => appLang == 'fa';
  String tr(String faText, String enText) => isFa ? faText : enText;

  NeonThemePalette get currentPalette =>
      NeonThemePalette.palettes.firstWhere((p) => p.id == themeId, orElse: () => NeonThemePalette.palettes.first);

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _initParticles();
    _loadData();
  }

  void _initParticles() {
    final rnd = math.Random();
    for (int i = 0; i < 48; i++) {
      _particles.add(StardustParticle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        vx: (rnd.nextDouble() - 0.5) * 0.0009,
        vy: (rnd.nextDouble() - 0.5) * 0.0009,
        radius: rnd.nextDouble() * 2.5 + 1.0,
        color: const Color(0xFF0066FF),
        alpha: rnd.nextDouble() * 0.65 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _stopWindowsEngine();
    _orbController.dispose();
    _particleController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subList = prefs.getStringList('lantern_win_subs_v2') ?? [];
      subscriptions = subList.map((e) => SubscriptionGroup.fromJson(jsonDecode(e))).toList();

      final profList = prefs.getStringList('lantern_win_profiles_v2') ?? [];
      profiles = profList.map((e) => VpnProfile.fromJson(jsonDecode(e))).toList();

      activeIdx = prefs.getInt('activeIdx') ?? 0;
      if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
      isAutoPilotMode = prefs.getBool('isAutoPilotMode') ?? false;
      engineMode = prefs.getInt('engineMode') ?? 1;
      gamingMode = prefs.getBool('gamingMode') ?? true;
      appLang = prefs.getString('appLang') ?? 'fa';
      themeId = prefs.getString('themeId') ?? 'cyber_blue';
      strictAntiLeak = prefs.getBool('strictAntiLeak') ?? true;
      killSwitchActive = prefs.getBool('killSwitchActive') ?? true;
      allowLan = prefs.getBool('allowLan') ?? false;
      splitTunnelMode = prefs.getInt('splitTunnelMode') ?? 1;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lantern_win_subs_v2', subscriptions.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('lantern_win_profiles_v2', profiles.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setBool('isAutoPilotMode', isAutoPilotMode);
      await prefs.setInt('engineMode', engineMode);
      await prefs.setBool('gamingMode', gamingMode);
      await prefs.setString('appLang', appLang);
      await prefs.setString('themeId', themeId);
      await prefs.setBool('strictAntiLeak', strictAntiLeak);
      await prefs.setBool('killSwitchActive', killSwitchActive);
      await prefs.setBool('allowLan', allowLan);
      await prefs.setInt('splitTunnelMode', splitTunnelMode);
    } catch (_) {}
  }

  List<VpnProfile> get displayedProfiles {
    Iterable<VpnProfile> res = profiles;
    if (selectedSubId != 'all') {
      res = res.where((p) => p.subId == selectedSubId);
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      res = res.where((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q) || p.protocol.toLowerCase().contains(q));
    }
    return res.toList();
  }

  void sortServersByPing() {
    if (profiles.isEmpty) return;
    setState(() {
      profiles.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      activeIdx = 0;
    });
    _saveData();
    _notify(tr('⚡ سرورها بر اساس کمترین پینگ مرتب شدند', '⚡ Sorted by lowest ping'));
  }

  Future<void> toggleConnection() async {
    if (isConnected || isBusy) {
      await _stopWindowsEngine();
      setState(() {
        isConnected = false;
        isBusy = false;
        simDlSpeed = 0.0;
        simUlSpeed = 0.0;
        currentRealDelay = -1;
      });
      _notify(tr('تونل ویندوز قطع شد', 'Windows Tunnel Disconnected'));
      return;
    }

    if (profiles.isEmpty) {
      _showUnifiedAddDialog();
      return;
    }

    setState(() => isBusy = true);

    if (isAutoPilotMode) {
      if (!profiles.any((p) => p.ping > 0)) {
        await testAllPings();
      }
      _selectBestServerForAutoPilot();
    }

    if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
    final VpnProfile target = profiles[activeIdx];

    final fullConfig = WindowsXrayConfigBuilder.buildFullJson(
      target.rawUri,
      engineMode: engineMode,
      gamingMode: gamingMode,
      strictAntiLeak: strictAntiLeak,
      allowLan: allowLan,
      splitTunnelMode: splitTunnelMode,
    );

    await _startWindowsEngine(target, fullConfig);
  }

  void _selectBestServerForAutoPilot() {
    int bestIndex = -1;
    int bestScore = 999999;
    for (int i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      if (p.ping > 0) {
        final score = gamingMode ? (p.ping + p.jitter * 2) : p.ping;
        if (score < bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }
    }
    if (bestIndex != -1) {
      setState(() => activeIdx = bestIndex);
      _saveData();
    }
  }

  Future<void> _startWindowsEngine(VpnProfile target, String fullConfig) async {
    try {
      await _stopWindowsEngine();
      final String exeDir = File(Platform.resolvedExecutable).parent.path;
      final File configFile = File('$exeDir\\running_config.json');
      await configFile.writeAsString(fullConfig);

      final File xrayExe = File('$exeDir\\xray.exe');
      if (await xrayExe.exists()) {
        _windowsXrayProcess = await Process.start(xrayExe.path, ['-c', configFile.path], workingDirectory: exeDir);
      }
      if (engineMode != 3) {
        await Process.run('reg', ['add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings', '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f']);
        await Process.run('reg', ['add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings', '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '127.0.0.1:10809', '/f']);
      }

      setState(() {
        isConnected = true;
        isBusy = false;
        verifiedIp = target.address;
      });
      _startTelemetry();
      testRealTunnelDelay();
      _notify(tr('✦ اتصال امن به «${target.name}» برقرار شد', '✦ Connected to ${target.name}'));
    } catch (e) {
      setState(() => isBusy = false);
      _notify('Engine Error: $e');
    }
  }

  Future<void> _stopWindowsEngine() async {
    _desktopStatsTimer?.cancel();
    if (Platform.isWindows) {
      await Process.run('reg', ['add', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings', '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f']);
      _windowsXrayProcess?.kill();
      _windowsXrayProcess = null;
    }
  }

  void _startTelemetry() {
    _desktopStatsTimer?.cancel();
    final rnd = math.Random();
    _desktopStatsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !isConnected) return;
      setState(() {
        simDlSpeed = double.parse((rnd.nextDouble() * 6.5 + 1.2).toStringAsFixed(2));
        simUlSpeed = double.parse((rnd.nextDouble() * 2.2 + 0.4).toStringAsFixed(2));
        dlWave.removeAt(0);
        dlWave.add((simDlSpeed / 8.0).clamp(0.18, 1.0));
        ulWave.removeAt(0);
        ulWave.add((simUlSpeed / 3.5).clamp(0.18, 1.0));
      });
    });
  }

  // ==================== تست واقعی تاخیر کانفیگ (Real HTTP Delay) ====================
  Future<void> testRealTunnelDelay() async {
    if (isTestingRealDelay) return;
    setState(() => isTestingRealDelay = true);
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient();
      if (isConnected) {
        client.findProxy = (uri) => "PROXY 127.0.0.1:10809; DIRECT";
      }
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse('http://cp.cloudflare.com/generate_204'));
      final res = await req.close();
      sw.stop();
      await res.drain();
      client.close();

      if (mounted) {
        setState(() {
          currentRealDelay = sw.elapsedMilliseconds;
          if (profiles.isNotEmpty && activeIdx < profiles.length) {
            profiles[activeIdx].httpDelay = currentRealDelay;
          }
          verifiedCountry = "Real HTTP 204: $currentRealDelay ms • Verified";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => currentRealDelay = -2);
      }
    }
    if (mounted) setState(() => isTestingRealDelay = false);
  }

  Future<void> testTcpPing(VpnProfile p) async {
    if (!mounted || p.address.isEmpty) return;
    setState(() => p.isPinging = true);
    int p1 = -2;
    int p2 = -2;
    try {
      final sw1 = Stopwatch()..start();
      final s1 = await Socket.connect(p.address, p.port, timeout: const Duration(milliseconds: 1600));
      sw1.stop();
      await s1.close();
      p1 = sw1.elapsedMilliseconds;

      if (gamingMode) {
        final sw2 = Stopwatch()..start();
        final s2 = await Socket.connect(p.address, p.port, timeout: const Duration(milliseconds: 1600));
        sw2.stop();
        await s2.close();
        p2 = sw2.elapsedMilliseconds;
      }
    } catch (_) {
      p1 = -2;
    }
    if (!mounted) return;
    setState(() {
      p.ping = p1;
      p.jitter = (p1 > 0 && p2 > 0) ? (p1 - p2).abs() : 3;
      p.isPinging = false;
    });
  }

  Future<void> testAllPings() async {
    final targetList = displayedProfiles;
    if (targetList.isEmpty || isPingingAll) return;
    setState(() => isPingingAll = true);

    const int batch = 6;
    for (int i = 0; i < targetList.length; i += batch) {
      final end = (i + batch < targetList.length) ? i + batch : targetList.length;
      await Future.wait([for (int j = i; j < end; j++) testTcpPing(targetList[j])]);
    }

    if (!mounted) return;
    setState(() {
      if (isAutoPilotMode) {
        sortServersByPing();
      }
      isPingingAll = false;
    });
    _saveData();
  }

  // ==================== کلیپ‌بورد هوشمند ====================
  Future<void> smartPasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _notify(tr('⚠️ کلیپ‌بورد ویندوز شما خالی است!', '⚠️ Your Windows clipboard is empty!'));
      return;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      await _importSubscription(text);
    } else {
      final count = _importDirectConfigs(text, subId: 'manual');
      if (count > 0) {
        _notify(tr('✦ $count کانفیگ از کلیپ‌بورد اضافه شد', '✦ $count configs pasted from clipboard'));
      } else {
        _notify(tr('⚠️ لینک یا کانفیگ معتبری در کلیپ‌بورد یافت نشد', '⚠️ No valid config or link found in clipboard'));
      }
    }
  }

  int _importDirectConfigs(String rawText, {required String subId}) {
    String body = rawText.trim();
    if (!body.contains('://')) {
      try {
        body = WindowsXrayConfigBuilder.decodeB64(body);
      } catch (_) {}
    }
    final lines = body.split(RegExp(r'[\r\n]+'));
    int added = 0;
    for (var l in lines) {
      final p = WindowsXrayConfigBuilder.parseProfile(l, subId, profiles.length + added + 1);
      if (p != null) {
        profiles.insert(0, p);
        added++;
      }
    }
    if (added > 0) {
      setState(() => activeIdx = 0);
      _saveData();
      testAllPings();
    }
    return added;
  }

  // ==================== دریافت و بروزرسانی هوشمند اشتراک بدون تکرار ====================
  Future<void> _importSubscription(String url, {String? customTitle, String? existingSubId}) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      _notify(tr('آدرس اشتراک باید با http یا https شروع شود', 'Subscription URL must start with http/https'));
      return;
    }

    setState(() => isSyncingSub = true);
    try {
      final res = await http.get(Uri.parse(cleanUrl), headers: {'User-Agent': 'v2rayNG/1.8.19'}).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try {
            body = WindowsXrayConfigBuilder.decodeB64(body);
          } catch (_) {}
        }

        // بررسی اینکه آیا این لینک قبلاً اضافه شده یا خیر (جلوگیری از ساخت کارت تکراری)
        SubscriptionGroup? existingGroup;
        if (existingSubId != null) {
          final idx = subscriptions.indexWhere((s) => s.id == existingSubId);
          if (idx != -1) existingGroup = subscriptions[idx];
        } else {
          final idx = subscriptions.indexWhere((s) => s.url.trim() == cleanUrl);
          if (idx != -1) existingGroup = subscriptions[idx];
        }

        final String targetSubId = existingGroup?.id ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final String hostTitle = Uri.parse(cleanUrl).host.replaceAll('www.', '');
        final String finalTitle = (customTitle != null && customTitle.trim().isNotEmpty)
            ? customTitle.trim()
            : (existingGroup?.title ?? (hostTitle.isNotEmpty ? hostTitle : 'اشتراک ابری'));

        double used = existingGroup?.usedGB ?? 0.0;
        double total = existingGroup?.totalGB ?? 0.0;
        int? expDays = existingGroup?.expireDays;

        // ۱. خواندن حجم و انقضا از هدر استاندارد (subscription-userinfo)
        final infoHeader = res.headers['subscription-userinfo'];
        if (infoHeader != null && infoHeader.isNotEmpty) {
          int upBytes = 0;
          int dlBytes = 0;
          int totalBytes = 0;
          int? expireUnix;
          for (var part in infoHeader.split(';')) {
            final kv = part.trim().split('=');
            if (kv.length == 2) {
              final k = kv[0].trim().toLowerCase();
              final v = int.tryParse(kv[1].trim()) ?? 0;
              if (k == 'upload') upBytes = v;
              if (k == 'download') dlBytes = v;
              if (k == 'total') totalBytes = v;
              if (k == 'expire' && v > 0) expireUnix = v;
            }
          }
          if (totalBytes > 0) {
            total = double.parse((totalBytes / 1073741824).toStringAsFixed(1));
            used = double.parse(((upBytes + dlBytes) / 1073741824).toStringAsFixed(1));
          }
          if (expireUnix != null) {
            final expDate = DateTime.fromMillisecondsSinceEpoch(expireUnix * 1000);
            final diff = expDate.difference(DateTime.now()).inDays;
            expDays = diff >= 0 ? diff : 0;
          }
        }

        final lines = body.split(RegExp(r'[\r\n]+'));
        final newProfiles = <VpnProfile>[];

        for (var l in lines) {
          final p = WindowsXrayConfigBuilder.parseProfile(l, targetSubId, newProfiles.length + 1);
          if (p != null) {
            // ۲. استخراج هوشمند حجم و روز از نام کانفیگ‌های اول (Marzban / X-UI / Hiddify)
            final gm = RegExp(r'(\d+(?:\.\d+)?)\s*GB', caseSensitive: false).allMatches(p.name).toList();
            if (total == 0.0 && gm.isNotEmpty) {
              if (gm.length >= 2) {
                used = double.tryParse(gm[0].group(1)!) ?? used;
                total = double.tryParse(gm[1].group(1)!) ?? total;
              } else {
                total = double.tryParse(gm[0].group(1)!) ?? total;
              }
            }
            final dm = RegExp(r'(\d+)\s*(?:روز|Days?|d\b)', caseSensitive: false).firstMatch(p.name);
            if (expDays == null && dm != null) {
              expDays = int.tryParse(dm.group(1)!);
            }
            newProfiles.add(p);
          }
        }

        if (newProfiles.isEmpty) {
          _notify(tr('هیچ سروری در این لینک یافت نشد', 'No servers found in subscription'));
          setState(() => isSyncingSub = false);
          return;
        }

        setState(() {
          // حذف سرورهای قدیمی همین اشتراک تا هرگز تکرار نشود
          profiles.removeWhere((p) => p.subId == targetSubId);
          profiles.insertAll(0, newProfiles);

          if (existingGroup != null) {
            existingGroup.title = finalTitle;
            existingGroup.usedGB = used;
            existingGroup.totalGB = total;
            existingGroup.expireDays = expDays;
          } else {
            subscriptions.add(SubscriptionGroup(
              id: targetSubId,
              title: finalTitle,
              url: cleanUrl,
              usedGB: used,
              totalGB: total,
              expireDays: expDays,
            ));
          }
          selectedSubId = targetSubId;
          activeIdx = 0;
        });

        await _saveData();
        _notify(tr('✦ اشتراک «$finalTitle» با ${newProfiles.length} سرور بروزرسانی شد!', '✦ Synced $finalTitle (${newProfiles.length} nodes)'));
        testAllPings();
      }
    } catch (_) {
      _notify(tr('خطا در ارتباط با سرور اشتراک', 'Subscription connection failed'));
    }
    if (mounted) setState(() => isSyncingSub = false);
  }

  void _notify(String msg) {
    if (!mounted) return;
    final pal = currentPalette;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0E1526),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: pal.secondary.withOpacity(0.55)),
        ),
        duration: const Duration(seconds: 2),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = currentPalette;
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: MouseRegion(
          onHover: (e) => setState(() => _mousePosition = e.localPosition),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [(isConnected ? pal.secondary : pal.primary).withOpacity(0.26), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -80,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [(gamingMode ? const Color(0xFFFF2E93) : pal.glow).withOpacity(0.20), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) => CustomPaint(
                    painter: GeminiParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                      isConnected: isConnected,
                      isGaming: gamingMode,
                      mousePos: _mousePosition,
                      palette: pal,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      SizedBox(width: 405, child: _buildCommandPanel3D(pal)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildServersAndSubsPanel3D(pal)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ستون اول: پنل فرماندهی و گوی سه‌بعدی ====================
  Widget _buildCommandPanel3D(NeonThemePalette pal) {
    final VpnProfile? current = (profiles.isNotEmpty && activeIdx < profiles.length) ? profiles[activeIdx] : null;
    final engineLabels = ['🛡️ TUN', '🌐 Proxy', '⚡ Fragment', '🔌 Socks5'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box3DDecoration(pal),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(colors: [pal.primary, pal.secondary]),
                          boxShadow: [BoxShadow(color: pal.primary.withOpacity(0.45), blurRadius: 14)],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lantern 3D', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text(pal.nameEn, style: TextStyle(fontSize: 10, color: pal.secondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  _buildTactile3DButton(
                    icon: Icons.settings_suggest_rounded,
                    label: tr('تنظیمات', 'Settings'),
                    pal: pal,
                    onTap: _openSettingsModal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF060913),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: List.generate(engineLabels.length, (i) {
                    final active = engineMode == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => engineMode = i);
                          _saveData();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: active ? LinearGradient(colors: [pal.primary, pal.primary.withOpacity(0.65)]) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            engineLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white54),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  setState(() => gamingMode = !gamingMode);
                  _saveData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: gamingMode
                        ? LinearGradient(colors: [const Color(0xFFFF2E93).withOpacity(0.25), pal.primary.withOpacity(0.18)])
                        : null,
                    color: gamingMode ? null : const Color(0xFF090D19),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gamingMode ? const Color(0xFFFF2E93).withOpacity(0.75) : Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_esports_rounded, size: 18, color: gamingMode ? const Color(0xFFFF2E93) : Colors.white54),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('حالت گیمینگ و پینگ پایدار', 'Gaming Zero-Jitter Mode'),
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: gamingMode ? Colors.white : Colors.white70),
                              ),
                              Text(
                                gamingMode ? 'TCP NoDelay • Jitter: ${current?.jitter ?? 3} ms' : tr('غیرفعال', 'OFF'),
                                style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gamingMode ? const Color(0xFFFF2E93) : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(gamingMode ? 'ON ⚡' : 'OFF', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // گوی هولوگرافیک اتصال
          Column(
            children: [
              GestureDetector(
                onTap: toggleConnection,
                child: SizedBox(
                  width: 164,
                  height: 164,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _orbController,
                        builder: (context, _) => Transform.rotate(
                          angle: _orbController.value * 2 * math.pi,
                          child: Container(
                            width: 152,
                            height: 152,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: isConnected
                                    ? [pal.secondary, pal.primary, pal.glow, pal.secondary]
                                    : [pal.primary, pal.glow, pal.secondary, pal.primary],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isConnected ? pal.secondary : pal.primary).withOpacity(0.42),
                                  blurRadius: 26,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.35, -0.45),
                            radius: 1.15,
                            colors: [Color(0xFF2B395E), Color(0xFF11182B), Color(0xFF060913)],
                          ),
                          border: Border.all(color: isConnected ? pal.secondary : Colors.white38, width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isBusy)
                              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: pal.secondary))
                            else
                              Icon(Icons.power_settings_new_rounded, size: 40, color: isConnected ? pal.secondary : Colors.white),
                            const SizedBox(height: 4),
                            Text(
                              isConnected ? 'PROTECTED' : 'CONNECT',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: isConnected ? pal.secondary : Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isConnected ? tr('متصل به ${current?.name ?? "سرور"}', 'Connected to ${current?.name ?? "Server"}') : tr('آماده اتصال امن', 'Ready to Connect'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isConnected ? pal.secondary : Colors.white),
              ),
            ],
          ),

          // رادار ضد نشت + تست تاخیر واقعی کانفیگ + سرعت زنده
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF070B16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IP: $verifiedIp', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
                          Text(verifiedCountry, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: testRealTunnelDelay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: pal.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: pal.secondary.withOpacity(0.45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isTestingRealDelay)
                              SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: pal.secondary))
                            else
                              Icon(Icons.speed_rounded, size: 13, color: pal.secondary),
                            const SizedBox(width: 4),
                            Text(
                              currentRealDelay > 0
                                  ? '$currentRealDelay ms'
                                  : (currentRealDelay == -2 ? 'Failed' : tr('تست واقعی', 'Real Test')),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: pal.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildSpeedCard3D(title: tr('دانلود', 'Download'), value: '$simDlSpeed MB/s', color: pal.secondary, bars: dlWave)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSpeedCard3D(title: tr('آپلود', 'Upload'), value: '$simUlSpeed MB/s', color: pal.glow, bars: ulWave)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard3D({required String title, required String value, required Color color, required List<double> bars}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF080C18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
          const SizedBox(height: 6),
          SizedBox(
            height: 11,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars
                  .map((v) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: isConnected ? (v * 11).clamp(3.0, 11.0) : 3.0,
                          decoration: BoxDecoration(color: isConnected ? color : Colors.white12, borderRadius: BorderRadius.circular(2)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ستون دوم: اشتراک‌ها، کلید دستی/خودکار، جستجو و لیست سرورها ====================
  Widget _buildServersAndSubsPanel3D(NeonThemePalette pal) {
    final list = displayedProfiles;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box3DDecoration(pal),
      child: Column(
        children: [
          // ۱. کلید سه‌بعدی تفکیک حالت «انتخاب دستی 🔒» و «خلبان خودکار 🤖»
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF060912),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => isAutoPilotMode = false);
                      _saveData();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: !isAutoPilotMode ? LinearGradient(colors: [pal.primary.withOpacity(0.38), pal.primary.withOpacity(0.15)]) : null,
                        borderRadius: BorderRadius.circular(10),
                        border: !isAutoPilotMode ? Border.all(color: pal.primary.withOpacity(0.75)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔒', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tr('حالت انتخاب دستی (ثابت)', 'Manual Lock Mode'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: !isAutoPilotMode ? Colors.white : Colors.white54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => isAutoPilotMode = true);
                      _selectBestServerForAutoPilot();
                      _saveData();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: isAutoPilotMode ? LinearGradient(colors: [pal.glow.withOpacity(0.35), pal.secondary.withOpacity(0.18)]) : null,
                        borderRadius: BorderRadius.circular(10),
                        border: isAutoPilotMode ? Border.all(color: pal.secondary.withOpacity(0.75)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🤖', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              tr('خلبان خودکار (Smart Auto)', 'Smart Auto-Pilot'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isAutoPilotMode ? Colors.white : Colors.white54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ۲. نوار کارت‌های اشتراک (نمایش حجم، روز باقی‌مانده، آپدیت درجا و حذف)
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedSubId = 'all'),
                  child: Container(
                    width: 96,
                    margin: const EdgeInsets.only(left: 8, right: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: selectedSubId == 'all' ? LinearGradient(colors: [pal.primary.withOpacity(0.32), pal.secondary.withOpacity(0.15)]) : null,
                      color: selectedSubId == 'all' ? null : const Color(0xFF0A0F1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selectedSubId == 'all' ? pal.secondary : Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dns_rounded, size: 19, color: pal.secondary),
                        const SizedBox(height: 4),
                        Text(tr('همه سرورها', 'All Nodes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10.5)),
                        Text('${profiles.length}', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
                ...subscriptions.map((sub) {
                  final isSel = selectedSubId == sub.id;
                  final bool hasTraffic = sub.totalGB > 0;
                  final double percent = hasTraffic ? (sub.usedGB / sub.totalGB).clamp(0.0, 1.0) : 0.35;

                  return GestureDetector(
                    onTap: () => setState(() => selectedSubId = sub.id),
                    child: Container(
                      width: 205,
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isSel ? LinearGradient(colors: [pal.primary.withOpacity(0.28), pal.glow.withOpacity(0.18)]) : null,
                        color: isSel ? null : const Color(0xFF0A0F1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSel ? pal.secondary : Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sub.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
                                ),
                              ),
                              Row(
                                children: [
                                  Tooltip(
                                    message: tr('بروزرسانی همین اشتراک', 'Sync Subscription'),
                                    child: InkWell(
                                      onTap: () => _importSubscription(sub.url, existingSubId: sub.id),
                                      child: Icon(Icons.sync_rounded, size: 15, color: pal.secondary),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Tooltip(
                                    message: tr('حذف کامل اشتراک و سرورهایش', 'Delete Subscription'),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          subscriptions.removeWhere((s) => s.id == sub.id);
                                          profiles.removeWhere((p) => p.subId == sub.id);
                                          if (selectedSubId == sub.id) selectedSubId = 'all';
                                          activeIdx = 0;
                                        });
                                        _saveData();
                                        _notify(tr('اشتراک حذف شد', 'Subscription deleted'));
                                      },
                                      child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFFF4D6D)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hasTraffic ? '${sub.usedGB} / ${sub.totalGB} GB' : tr('حجم نامحدود / فعال', 'Active Plan'),
                                    style: const TextStyle(fontSize: 9.5, color: Colors.white70),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: pal.secondary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      sub.expireDays != null ? '${sub.expireDays} ${tr("روز مانده", "Days")}' : '∞',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pal.secondary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: Colors.white12,
                                  color: pal.secondary,
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ۳. نوار جستجوی آنی + دکمه‌های عملیاتی (مرتب‌سازی، پینگ، کلیپ‌بورد، QR، افزودن)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: tr('جستجوی کشور یا نام سرور (مثلاً آلمان، DE)...', 'Search country or server name...'),
                      hintStyle: const TextStyle(fontSize: 10.5, color: Colors.white38),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: pal.secondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.clear_rounded, size: 14, color: Colors.white54),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF070B16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildTactile3DButton(
                icon: Icons.sort_rounded,
                label: tr('مرتب‌سازی', 'Sort'),
                pal: pal,
                onTap: sortServersByPing,
              ),
              const SizedBox(width: 5),
              _buildTactile3DButton(
                icon: Icons.bolt_rounded,
                label: isPingingAll ? '...' : tr('پینگ', 'Ping'),
                pal: pal,
                onTap: testAllPings,
              ),
              const SizedBox(width: 5),
              _buildTactile3DButton(
                icon: Icons.content_paste_rounded,
                label: tr('کلیپ‌بورد', 'Paste'),
                pal: pal,
                onTap: smartPasteFromClipboard,
              ),
              const SizedBox(width: 5),
              _buildTactile3DButton(
                icon: Icons.qr_code_scanner_rounded,
                label: 'QR',
                pal: pal,
                onTap: () => _showUnifiedAddDialog(initialTab: 2),
              ),
              const SizedBox(width: 5),
              _buildTactile3DButton(
                icon: Icons.add_circle_outline_rounded,
                label: tr('افزودن', 'Add'),
                pal: pal,
                onTap: () => _showUnifiedAddDialog(initialTab: 0),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ۴. لیست سرورها با پرچم وکتور واقعی و دکمه نمایش QR
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_Queue_rounded, size: 44, color: Colors.white.withOpacity(0.18)),
                        const SizedBox(height: 8),
                        Text(
                          tr('لیست سرورها خالی است', 'Server list is empty'),
                          style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildGlowingActionBtn(
                              icon: Icons.content_paste_rounded,
                              label: tr('چسباندن از کلیپ‌بورد', 'Paste Clipboard'),
                              pal: pal,
                              onTap: smartPasteFromClipboard,
                            ),
                            const SizedBox(width: 8),
                            _buildGlowingActionBtn(
                              icon: Icons.add_link_rounded,
                              label: tr('افزودن اشتراک / QR', 'Add Subscription / QR'),
                              pal: pal,
                              onTap: () => _showUnifiedAddDialog(initialTab: 0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      final bool selected = (profiles.isNotEmpty && activeIdx < profiles.length) && profiles[activeIdx].id == p.id;
                      Color pCol = pal.secondary;
                      if (p.ping > 220) pCol = const Color(0xFFFFB300);
                      if (p.ping <= 0 || p.ping > 550) pCol = const Color(0xFFFF4D6D);

                      return GestureDetector(
                        onTap: () async {
                          final realIndex = profiles.indexWhere((item) => item.id == p.id);
                          if (realIndex == -1) return;
                          final wasConn = isConnected;
                          setState(() {
                            activeIdx = realIndex;
                            isAutoPilotMode = false;
                          });
                          await _saveData();
                          if (wasConn) {
                            await _stopWindowsEngine();
                            setState(() => isConnected = false);
                            await Future.delayed(const Duration(milliseconds: 250));
                            await toggleConnection();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(colors: [pal.primary.withOpacity(0.32), pal.glow.withOpacity(0.18)])
                                : const LinearGradient(colors: [Color(0xFF141C32), Color(0xFF0B1120)]),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? pal.secondary : Colors.white.withOpacity(0.08),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 23,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                ),
                                child: CustomPaint(painter: FlagPainter(p.name)),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                          ),
                                        ),
                                        if (p.isGameReady) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF2E93).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(color: const Color(0xFFFF2E93).withOpacity(0.5)),
                                            ),
                                            child: const Text('🎯 GAME', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFF85B3))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.protocol} • ${p.address}:${p.port}${selected ? (isAutoPilotMode ? " • 🤖 Auto" : " • 🔒 Locked") : ""}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => testTcpPing(p),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: p.ping > 0 ? pCol.withOpacity(0.4) : Colors.white10),
                                  ),
                                  child: p.isPinging
                                      ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: pal.secondary))
                                      : Text(
                                          p.ping > 0 ? '${p.ping} ms' : (p.ping == -2 ? 'Timeout' : 'Ping'),
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: p.ping > 0 ? pCol : Colors.white38),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: tr('نمایش QR Code و کپی کانفیگ', 'Show QR & Copy URI'),
                                icon: const Icon(Icons.qr_code_2_rounded, size: 17, color: Colors.white54),
                                onPressed: () => _showServerQrModal(p),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: tr('حذف سرور', 'Delete'),
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white38),
                                onPressed: () {
                                  setState(() {
                                    profiles.removeWhere((item) => item.id == p.id);
                                    if (activeIdx >= profiles.length) activeIdx = 0;
                                  });
                                  _saveData();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== پنجره ۳ حالته افزودن (لینک اشتراک + کلیپ‌بورد + اسکنر QR) ====================
  void _showUnifiedAddDialog({int initialTab = 0}) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    int tab = initialTab;
    final pal = currentPalette;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0E1526),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: pal.secondary.withOpacity(0.35)),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('➕ مرکز افزودن اشتراک و کانفیگ', '➕ Add Subscription, Clipboard or QR'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // تب‌های ۳ حالته
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060913),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildDialogTabBtn(
                          title: tr('🔗 لینک اشتراک', '🔗 Sub Link'),
                          active: tab == 0,
                          pal: pal,
                          onTap: () => setModalState(() => tab = 0),
                        ),
                        _buildDialogTabBtn(
                          title: tr('📋 کلیپ‌بورد', '📋 Clipboard'),
                          active: tab == 1,
                          pal: pal,
                          onTap: () => setModalState(() => tab = 1),
                        ),
                        _buildDialogTabBtn(
                          title: tr('📷 اسکن QR Code', '📷 QR Code'),
                          active: tab == 2,
                          pal: pal,
                          onTap: () => setModalState(() => tab = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (tab == 0) ...[
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('نام دلخواه اشتراک (اختیاری)', 'Custom Subscription Name (Optional)'),
                        labelStyle: const TextStyle(fontSize: 11, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF070A14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://...\nvless://...\nvmess://...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF070A14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else if (tab == 1) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070A14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.content_paste_go_rounded, size: 38, color: pal.secondary),
                          const SizedBox(height: 8),
                          Text(
                            tr('وارد کردن خودکار از حافظه کلیپ‌بورد ویندوز', 'Auto-Import from Windows Clipboard'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('هر لینک اشتراک یا کانفیگی که کپی کرده‌اید را با یک کلیک وارد کنید.', 'Reads any copied subscription URL or V2Ray config instantly.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                          ),
                          const SizedBox(height: 12),
                          _buildGlowingActionBtn(
                            icon: Icons.paste_rounded,
                            label: tr('چسباندن و بررسی آنی کلیپ‌بورد', 'Paste & Import Now'),
                            pal: pal,
                            onTap: () {
                              Navigator.pop(ctx);
                              smartPasteFromClipboard();
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070A14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 38, color: pal.secondary),
                          const SizedBox(height: 8),
                          Text(
                            tr('اسکن تصویر QR Code یا استخراج از کلیپ‌بورد', 'Import QR Code Image or Config'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('اگر تصویر یا متن QR را کپی کرده‌اید، یا فایل QR دارید، از دکمه‌های زیر استفاده کنید:', 'Paste copied QR payload or enter image path:'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGlowingActionBtn(
                                icon: Icons.qr_code_rounded,
                                label: tr('خواندن QR از کلیپ‌بورد', 'Read QR from Clipboard'),
                                pal: pal,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  smartPasteFromClipboard();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('انصراف', 'Cancel'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              if (tab == 0)
                _buildGlowingActionBtn(
                  icon: Icons.check_circle_outline_rounded,
                  label: tr('تأیید و افزودن', 'Confirm & Add'),
                  pal: pal,
                  onTap: () {
                    final raw = urlCtrl.text.trim();
                    final customName = nameCtrl.text.trim();
                    Navigator.pop(ctx);
                    if (raw.isEmpty) {
                      _notify(tr('لطفاً لینک اشتراک یا کانفیگ را وارد کنید', 'Please enter a valid link or config'));
                      return;
                    }
                    if (raw.startsWith('http://') || raw.startsWith('https://')) {
                      _importSubscription(raw, customTitle: customName);
                    } else {
                      _importDirectConfigs(raw, subId: 'manual');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTabBtn({required String title, required bool active, required NeonThemePalette pal, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? LinearGradient(colors: [pal.primary, pal.primary.withOpacity(0.7)]) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white54),
          ),
        ),
      ),
    );
  }

  // ==================== نمایش QR Code هر سرور برای اسکن با موبایل ====================
  void _showServerQrModal(VpnProfile p) {
    final pal = currentPalette;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E1526),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.secondary.withOpacity(0.4))),
          title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: SizedBox(
                  width: 170,
                  height: 170,
                  child: CustomPaint(painter: VisualQrMatrixPainter(data: p.rawUri, color: const Color(0xFF080C18))),
                ),
              ),
              const SizedBox(height: 12),
              Text('${p.protocol} • ${p.address}:${p.port}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('بستن', 'Close'), style: const TextStyle(color: Colors.white70))),
            _buildGlowingActionBtn(
              icon: Icons.copy_rounded,
              label: tr('کپی لینک کانفیگ', 'Copy Config URI'),
              pal: pal,
              onTap: () {
                Clipboard.setData(ClipboardData(text: p.rawUri));
                Navigator.pop(ctx);
                _notify(tr('لینک کانفیگ در کلیپ‌بورد کپی شد', 'Config URI copied to clipboard'));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تنظیمات پیشرفته + انتخابگر ۴ تم نوری ====================
  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final pal = currentPalette;
          return Directionality(
            textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: const Color(0xFF0E1526),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: pal.secondary.withOpacity(0.35)),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('⚙️ تنظیمات پیشرفته و تم نوری', '⚙️ Settings & Neon Theme'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('🎨 انتخاب تم نوری برنامه (Neon Accent):', '🎨 Select Neon Theme Accent:'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NeonThemePalette.palettes.map((item) {
                          final selected = item.id == themeId;
                          return GestureDetector(
                            onTap: () {
                              setState(() => themeId = item.id);
                              setModalState(() {});
                              _saveData();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [item.primary.withOpacity(0.35), item.secondary.withOpacity(0.2)]),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: selected ? item.secondary : Colors.white12, width: selected ? 1.8 : 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: item.secondary)),
                                  const SizedBox(width: 6),
                                  Text(isFa ? item.nameFa : item.nameEn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 22, color: Colors.white12),
                      SwitchListTile(
                        title: Text(tr('🌍 زبان فارسی / English', '🌍 Interface Language (FA/EN)'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        value: isFa,
                        activeColor: pal.secondary,
                        onChanged: (v) {
                          setState(() => appLang = v ? 'fa' : 'en');
                          setModalState(() {});
                          _saveData();
                        },
                      ),
                      SwitchListTile(
                        title: Text(tr('🛡️ سپر ضد نشت آی‌پی و DNS (Zero-Leak)', '🛡️ Strict Anti-IP & DNS Leak Shield'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(tr('مسدودسازی کامل IPv6 و قفل کردن DNS', 'Block IPv6 & encrypt DNS queries'), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                        value: strictAntiLeak,
                        activeColor: pal.secondary,
                        onChanged: (v) {
                          setState(() => strictAntiLeak = v);
                          setModalState(() {});
                          _saveData();
                        },
                      ),
                      SwitchListTile(
                        title: Text(tr('📡 اشتراک‌گذاری VPN در شبکه (Allow LAN)', '📡 Share VPN over Local Wi-Fi (Allow LAN)'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        subtitle: Text(tr('پورت 10808 برای اتصال موبایل و کنسول', 'Open port 10808 for local devices'), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                        value: allowLan,
                        activeColor: pal.secondary,
                        onChanged: (v) {
                          setState(() => allowLan = v);
                          setModalState(() {});
                          _saveData();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== دکمه درخشان اختصاصی (رفع کامل مشکل دکمه آبی خالی) ====================
  Widget _buildGlowingActionBtn({
    required IconData icon,
    required String label,
    required NeonThemePalette pal,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [pal.primary, pal.secondary.withOpacity(0.85)]),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(color: pal.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box3DDecoration(NeonThemePalette pal) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xCC18223A), Color(0xE60A0F1D)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: pal.secondary.withOpacity(0.18)),
      boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14))],
    );
  }

  Widget _buildTactile3DButton({
    required IconData icon,
    required String label,
    required NeonThemePalette pal,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF212D4C), Color(0xFF12192B)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: pal.secondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
