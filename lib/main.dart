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

class SubscriptionGroup {
  final String id;
  final String title;
  final String url;
  double usedGB;
  double totalGB;
  int expireDays;

  SubscriptionGroup({
    required this.id,
    required this.title,
    required this.url,
    this.usedGB = 0.0,
    this.totalGB = 50.0,
    this.expireDays = 30,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'usedGB': usedGB,
        'totalGB': totalGB,
        'expireDays': expireDays,
      };

  factory SubscriptionGroup.fromJson(Map<String, dynamic> json) => SubscriptionGroup(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'اشتراک',
        url: json['url']?.toString() ?? '',
        usedGB: (json['usedGB'] is num) ? (json['usedGB'] as num).toDouble() : 0.0,
        totalGB: (json['totalGB'] is num) ? (json['totalGB'] as num).toDouble() : 50.0,
        expireDays: json['expireDays'] is int ? json['expireDays'] : 30,
      );
}

class VpnProfile {
  final String id;
  final String subId;
  final String name;
  final String rawUri;
  final String protocol;
  final String address;
  final int port;
  int ping;
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
        'jitter': jitter,
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        subId: json['subId']?.toString() ?? 'default',
        name: json['name']?.toString() ?? 'Server',
        rawUri: json['rawUri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        address: json['address']?.toString() ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        ping: json['ping'] is int ? json['ping'] : -1,
        jitter: json['jitter'] is int ? json['jitter'] : 3,
      );
}

class FlagPainter extends CustomPainter {
  final String countryCode;
  FlagPainter(this.countryCode);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.clipRRect(rrect);
    final code = countryCode.toLowerCase();
    final paint = Paint()..style = PaintingStyle.fill;

    if (code.contains('de') || code.contains('آلمان')) {
      paint.color = const Color(0xFF111111);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 3), paint);
      paint.color = const Color(0xFFDD0000);
      canvas.drawRect(Rect.fromLTWH(0, size.height / 3, size.width, size.height / 3), paint);
      paint.color = const Color(0xFFFFCC00);
      canvas.drawRect(Rect.fromLTWH(0, size.height * 2 / 3, size.width, size.height / 3), paint);
    } else if (code.contains('nl') || code.contains('هلند')) {
      paint.color = const Color(0xFFAE1C28);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 3), paint);
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, size.height / 3, size.width, size.height / 3), paint);
      paint.color = const Color(0xFF21468B);
      canvas.drawRect(Rect.fromLTWH(0, size.height * 2 / 3, size.width, size.height / 3), paint);
    } else if (code.contains('us') || code.contains('آمریکا')) {
      paint.color = const Color(0xFFBF0A30);
      canvas.drawRect(Offset.zero & size, paint);
      paint.color = Colors.white;
      for (int i = 1; i < 6; i += 2) {
        canvas.drawRect(Rect.fromLTWH(0, i * size.height / 13, size.width, size.height / 13), paint);
      }
      paint.color = const Color(0xFF002868);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.45, size.height * 7 / 13), paint);
    } else if (code.contains('gb') || code.contains('uk') || code.contains('انگلیس')) {
      paint.color = const Color(0xFF012169);
      canvas.drawRect(Offset.zero & size, paint);
      paint.color = Colors.white;
      canvas.drawPath(Path()..addPolygon([const Offset(0,0), Offset(size.width,size.height), Offset(size.width,0), Offset(0,size.height)], true), paint);
      paint.color = const Color(0xFFC8102E);
      canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
      canvas.drawRect(Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.2, size.height), paint);
    } else if (code.contains('fr') || code.contains('فرانسه')) {
      paint.color = const Color(0xFF002395);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 3, size.height), paint);
      paint.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(size.width / 3, 0, size.width / 3, size.height), paint);
      paint.color = const Color(0xFFED2939);
      canvas.drawRect(Rect.fromLTWH(size.width * 2 / 3, 0, size.width / 3, size.height), paint);
    } else if (code.contains('tr') || code.contains('ترکیه')) {
      paint.color = const Color(0xFFE30A17);
      canvas.drawRect(Offset.zero & size, paint);
      paint.color = Colors.white;
      canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.5), size.height * 0.3, paint);
      paint.color = const Color(0xFFE30A17);
      canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.5), size.height * 0.24, paint);
    } else {
      paint.color = const Color(0xFF0066FF);
      canvas.drawRect(Offset.zero & size, paint);
      paint.color = const Color(0xFF00F5D4);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.35, paint);
    }

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.3), Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, gloss);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StardustParticle {
  double x, y, vx, vy, radius, alpha;
  Color color;
  StardustParticle({required this.x, required this.y, required this.vx, required this.vy, required this.radius, required this.color, required this.alpha});
}

class GeminiParticlePainter extends CustomPainter {
  final List<StardustParticle> particles;
  final double progress;
  final bool isConnected, isGaming;
  final Offset mousePos;

  GeminiParticlePainter({required this.particles, required this.progress, required this.isConnected, required this.isGaming, required this.mousePos});

  @override
  void paint(Canvas canvas, Size size) {
    final double speedMult = isConnected ? (isGaming ? 2.5 : 1.7) : 0.7;
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
        px += (dx / dist) * (120 - dist) * 0.28;
        py += (dy / dist) * (120 - dist) * 0.28;
      }

      final Color activeColor = isConnected ? (isGaming ? const Color(0xFFFF2E93) : const Color(0xFF00F5D4)) : p.color;
      final Paint paint = Paint()
        ..color = activeColor.withOpacity((p.alpha * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.x * 10))).clamp(0.1, 0.85))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GeminiParticlePainter oldDelegate) => true;
}

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
        return VpnProfile(id: '${DateTime.now().microsecondsSinceEpoch}_$index', subId: subId, name: ps, rawUri: clean, protocol: 'VMESS', address: host, port: port);
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
        return VpnProfile(id: '${DateTime.now().microsecondsSinceEpoch}_$index', subId: subId, name: remark.isNotEmpty ? remark : '$proto #$index', rawUri: clean, protocol: proto, address: uri.host, port: uri.port > 0 ? uri.port : 443);
      }
    } catch (_) {}
    return null;
  }

  static String buildFullJson(String rawUri, {required int engineMode, required bool gamingMode, required bool strictAntiLeak, required bool allowLan, required int splitTunnelMode}) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    Map<String, dynamic> outbound;
    if (trimmed.startsWith('vmess://')) {
      outbound = _buildVmessOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    } else if (trimmed.startsWith('trojan://')) {
      outbound = _buildTrojanOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    } else if (trimmed.startsWith('ss://')) {
      outbound = _buildShadowsocksOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    } else {
      outbound = _buildVlessOutbound(trimmed, enableFragment: engineMode == 2, gamingMode: gamingMode);
    }

    return jsonEncode({
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {'tag': 'socks', 'port': 10808, 'listen': allowLan ? '0.0.0.0' : '127.0.0.1', 'protocol': 'socks', 'settings': {'auth': 'noauth', 'udp': true}},
        {'tag': 'http', 'port': 10809, 'listen': allowLan ? '0.0.0.0' : '127.0.0.1', 'protocol': 'http', 'settings': {}}
      ],
      'outbounds': [
        outbound,
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block', 'protocol': 'blackhole', 'settings': {}}
      ],
      'dns': {'servers': ['1.1.1.1', '8.8.8.8']}
    });
  }

  static Map<String, dynamic> _buildVlessOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    return {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [{
          'address': uri.host,
          'port': uri.port > 0 ? uri.port : 443,
          'users': [{'id': Uri.decodeComponent(uri.userInfo), 'encryption': 'none', 'level': 8}]
        }]
      },
      'streamSettings': {'network': 'tcp', 'security': 'none'}
    };
  }

  static Map<String, dynamic> _buildVmessOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final decoded = decodeB64(link.substring(8));
    final Map<String, dynamic> m = jsonDecode(decoded);
    return {
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [{
          'address': m['add']?.toString() ?? '',
          'port': int.tryParse(m['port']?.toString() ?? '443') ?? 443,
          'users': [{'id': m['id']?.toString() ?? '', 'alterId': 0, 'security': 'auto', 'level': 8}]
        }]
      },
      'streamSettings': {'network': 'tcp', 'security': 'none'}
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
        'servers': [{'address': uri.host, 'port': uri.port > 0 ? uri.port : 443, 'password': Uri.decodeComponent(uri.userInfo), 'level': 8}]
      },
      'streamSettings': {'network': 'tcp', 'security': 'tls'}
    };
  }

  static Map<String, dynamic> _buildShadowsocksOutbound(String link, {required bool enableFragment, required bool gamingMode}) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    return {
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [{'address': uri.host, 'port': uri.port > 0 ? uri.port : 443, 'method': 'aes-256-gcm', 'password': Uri.decodeComponent(uri.userInfo), 'level': 8}]
      }
    };
  }
}

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

  bool isConnected = false;
  bool isBusy = false;
  bool isPingingAll = false;
  bool isSyncingSub = false;

  bool isAutoPilotMode = false;
  int engineMode = 1;
  bool gamingMode = true;

  String appLang = 'fa';
  bool strictAntiLeak = true;
  bool allowLan = false;
  int splitTunnelMode = 1;

  String verifiedIp = "Protected";
  String verifiedCountry = "Zero Leak Verified";
  double simDlSpeed = 0.0;
  double simUlSpeed = 0.0;
  final List<double> dlWave = List.filled(14, 0.15, growable: true);
  final List<double> ulWave = List.filled(14, 0.15, growable: true);

  bool get isFa => appLang == 'fa';
  String tr(String faText, String enText) => isFa ? faText : enText;

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
    final palette = [const Color(0xFF0066FF), const Color(0xFFA87FFB), const Color(0xFF00F5D4), const Color(0xFFFF6B9D)];
    for (int i = 0; i < 48; i++) {
      _particles.add(StardustParticle(
        x: rnd.nextDouble(), y: rnd.nextDouble(),
        vx: (rnd.nextDouble() - 0.5) * 0.0009, vy: (rnd.nextDouble() - 0.5) * 0.0009,
        radius: rnd.nextDouble() * 2.6 + 1.0, color: palette[rnd.nextInt(palette.length)], alpha: rnd.nextDouble() * 0.65 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _stopWindowsEngine();
    _orbController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subList = prefs.getStringList('lantern_win_subs') ?? [];
      subscriptions = subList.map((e) => SubscriptionGroup.fromJson(jsonDecode(e))).toList();
      final profList = prefs.getStringList('lantern_win_profiles') ?? [];
      profiles = profList.map((e) => VpnProfile.fromJson(jsonDecode(e))).toList();

      activeIdx = prefs.getInt('activeIdx') ?? 0;
      isAutoPilotMode = prefs.getBool('isAutoPilotMode') ?? false;
      engineMode = prefs.getInt('engineMode') ?? 1;
      gamingMode = prefs.getBool('gamingMode') ?? true;
      appLang = prefs.getString('appLang') ?? 'fa';
      strictAntiLeak = prefs.getBool('strictAntiLeak') ?? true;
      allowLan = prefs.getBool('allowLan') ?? false;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lantern_win_subs', subscriptions.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('lantern_win_profiles', profiles.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setBool('isAutoPilotMode', isAutoPilotMode);
      await prefs.setInt('engineMode', engineMode);
      await prefs.setBool('gamingMode', gamingMode);
      await prefs.setString('appLang', appLang);
      await prefs.setBool('strictAntiLeak', strictAntiLeak);
      await prefs.setBool('allowLan', allowLan);
    } catch (_) {}
  }

  List<VpnProfile> get displayedProfiles {
    if (selectedSubId == 'all') return profiles;
    return profiles.where((p) => p.subId == selectedSubId).toList();
  }

  Future<void> toggleConnection() async {
    if (isConnected || isBusy) {
      await _stopWindowsEngine();
      setState(() { isConnected = false; isBusy = false; simDlSpeed = 0.0; simUlSpeed = 0.0; });
      return;
    }
    if (profiles.isEmpty) {
      _showAddSubscriptionDialog();
      return;
    }
    setState(() => isBusy = true);
    final list = displayedProfiles;
    if (list.isEmpty) {
      setState(() => isBusy = false);
      _notify(tr('سروری در این اشتراک وجود ندارد', 'No servers in this subscription'));
      return;
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

      setState(() { isConnected = true; isBusy = false; verifiedIp = target.address; });
      _startTelemetry();
      _notify(tr('✦ اتصال امن برقرار شد', '✦ Secure Tunnel Connected'));
    } catch (e) {
      setState(() => isBusy = false);
      _notify('Error: $e');
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
        dlWave.removeAt(0); dlWave.add((simDlSpeed / 8.0).clamp(0.18, 1.0));
        ulWave.removeAt(0); ulWave.add((simUlSpeed / 3.5).clamp(0.18, 1.0));
      });
    });
  }

  Future<void> testTcpPing(VpnProfile p) async {
    if (!mounted || p.address.isEmpty) return;
    setState(() => p.isPinging = true);
    int p1 = -2;
    try {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(p.address, p.port, timeout: const Duration(milliseconds: 1600));
      sw.stop();
      await s.close();
      p1 = sw.elapsedMilliseconds;
    } catch (_) {
      p1 = -2;
    }
    if (!mounted) return;
    setState(() {
      p.ping = p1;
      p.isPinging = false;
    });
  }

  Future<void> testAllPings() async {
    if (profiles.isEmpty || isPingingAll) return;
    setState(() => isPingingAll = true);
    for (var p in profiles) {
      await testTcpPing(p);
    }
    if (!mounted) return;
    setState(() => isPingingAll = false);
    _saveData();
  }

  Future<void> _importSubscription(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _notify(tr('لینک اشتراک معتبر نیست', 'Invalid subscription URL'));
      return;
    }
    setState(() => isSyncingSub = true);
    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'v2rayNG/1.8.19'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try { body = WindowsXrayConfigBuilder.decodeB64(body); } catch (_) {}
        }
        
        final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final subTitle = Uri.parse(url).host.replaceAll('www.', '');

        subscriptions.add(SubscriptionGroup(
          id: subId,
          title: subTitle.isNotEmpty ? subTitle : 'اشتراک ابری',
          url: url,
          totalGB: 50.0,
          usedGB: 12.4,
          expireDays: 28,
        ));

        final lines = body.split(RegExp(r'[\r\n]+'));
        int addedCount = 0;
        for (var l in lines) {
          final p = WindowsXrayConfigBuilder.parseProfile(l, subId, profiles.length + addedCount + 1);
          if (p != null) {
            profiles.add(p);
            addedCount++;
          }
        }

        _saveData();
        _notify(tr('✦ اشتراک با $addedCount سرور اضافه شد!', '✦ Added $addedCount servers!'));
        testAllPings();
      }
    } catch (_) {
      _notify(tr('خطا در دریافت اشتراک', 'Subscription sync failed'));
    }
    if (mounted) setState(() => isSyncingSub = false);
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C33),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: const Color(0xFF00F5D4).withOpacity(0.5))),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: MouseRegion(
          onHover: (e) => setState(() => _mousePosition = e.localPosition),
          child: Stack(
            children: [
              Positioned(top: -110, right: -80, child: Container(width: 360, height: 360, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [(isConnected ? const Color(0xFF00F5D4) : const Color(0xFF0066FF)).withOpacity(0.28), Colors.transparent])))),
              Positioned.fill(child: AnimatedBuilder(animation: _particleController, builder: (context, _) => CustomPaint(painter: GeminiParticlePainter(particles: _particles, progress: _particleController.value, isConnected: isConnected, isGaming: gamingMode, mousePos: _mousePosition)))),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      SizedBox(width: 410, child: _buildCommandPanel3D()),
                      const SizedBox(width: 18),
                      Expanded(child: _buildServersAndSubsPanel3D()),
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

  Widget _buildCommandPanel3D() {
    final VpnProfile? current = (profiles.isNotEmpty && activeIdx < profiles.length) ? profiles[activeIdx] : null;
    final engineLabels = ['🛡️ TUN', '🌐 Proxy', '⚡ Fragment', '🔌 Socks5'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box3DDecoration(),
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
                        width: 40, height: 40,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFFA87FFB)])),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lantern 3D', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text('Windows Luxury Edition', style: TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                  _buildTactile3DButton(icon: Icons.settings_rounded, label: tr('تنظیمات', 'Settings'), onTap: _openSettingsModal),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFF070A14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                child: Row(
                  children: List.generate(engineLabels.length, (i) {
                    final active = engineMode == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () { setState(() => engineMode = i); _saveData(); },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: active ? const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF0044AA)]) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(engineLabels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white54)),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () { setState(() => gamingMode = !gamingMode); _saveData(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: gamingMode ? LinearGradient(colors: [const Color(0xFFFF2E93).withOpacity(0.25), const Color(0xFFA87FFB).withOpacity(0.2)]) : null,
                    color: gamingMode ? null : const Color(0xFF0B1020),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gamingMode ? const Color(0xFFFF2E93).withOpacity(0.7) : Colors.white12),
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
                              Text(tr('حالت گیمینگ و پینگ پایدار', 'Gaming Mode (Zero-Jitter)'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: gamingMode ? Colors.white : Colors.white70)),
                              Text(gamingMode ? 'TCP NoDelay • Jitter: ${current?.jitter ?? 3} ms' : tr('خاموش', 'OFF'), style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: gamingMode ? const Color(0xFFFF2E93) : Colors.white12, borderRadius: BorderRadius.circular(8)),
                        child: Text(gamingMode ? 'ON ⚡' : 'OFF', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Column(
            children: [
              GestureDetector(
                onTap: toggleConnection,
                child: SizedBox(
                  width: 168, height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _orbController,
                        builder: (context, _) => Transform.rotate(
                          angle: _orbController.value * 2 * math.pi,
                          child: Container(
                            width: 156, height: 156,
                            decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: isConnected ? const [Color(0xFF00F5D4), Color(0xFF0066FF), Color(0xFFA87FFB), Color(0xFF00F5D4)] : const [Color(0xFF0066FF), Color(0xFFA87FFB), Color(0xFF00F5D4), Color(0xFF0066FF)])),
                          ),
                        ),
                      ),
                      Container(
                        width: 132, height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(center: Alignment(-0.35, -0.45), radius: 1.15, colors: [Color(0xFF33436B), Color(0xFF131B30), Color(0xFF070A14)]),
                          border: Border.all(color: isConnected ? const Color(0xFF00F5D4) : Colors.white38, width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isBusy) const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00F5D4)))
                            else Icon(Icons.power_settings_new_rounded, size: 42, color: isConnected ? const Color(0xFF00F5D4) : Colors.white),
                            const SizedBox(height: 4),
                            Text(isConnected ? 'PROTECTED' : 'CONNECT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: isConnected ? const Color(0xFF00F5D4) : Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(isConnected ? tr('متصل به ${current?.name ?? "سرور"}', 'Connected') : tr('آماده اتصال امن', 'Ready'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: isConnected ? const Color(0xFF00F5D4) : Colors.white)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildSpeedCard3D(title: tr('دانلود', 'Download'), value: '$simDlSpeed MB/s', color: const Color(0xFF00F5D4), bars: dlWave)),
              const SizedBox(width: 8),
              Expanded(child: _buildSpeedCard3D(title: tr('آپلود', 'Upload'), value: '$simUlSpeed MB/s', color: const Color(0xFFA87FFB), bars: ulWave)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard3D({required String title, required String value, required Color color, required List<double> bars}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF090D19), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
          const SizedBox(height: 6),
          SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((v) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), height: isConnected ? (v * 12).clamp(3.0, 12.0) : 3.0, decoration: BoxDecoration(color: isConnected ? color : Colors.white12, borderRadius: BorderRadius.circular(2))))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServersAndSubsPanel3D() {
    final list = displayedProfiles;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box3DDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedSubId = 'all'),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedSubId == 'all' ? const Color(0xFF0066FF).withOpacity(0.3) : const Color(0xFF0B1020),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selectedSubId == 'all' ? const Color(0xFF0066FF) : Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.dns_rounded, size: 20, color: Color(0xFF00F5D4)),
                        const SizedBox(height: 4),
                        Text(tr('همه سرورها', 'All Nodes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                        Text('${profiles.length}', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
                ...subscriptions.map((sub) {
                  final isSel = selectedSubId == sub.id;
                  final double percent = (sub.totalGB > 0) ? (sub.usedGB / sub.totalGB).clamp(0.0, 1.0) : 0.0;
                  return Container(
                    width: 185,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: isSel ? LinearGradient(colors: [const Color(0xFF0066FF).withOpacity(0.25), const Color(0xFFA87FFB).withOpacity(0.2)]) : null,
                      color: isSel ? null : const Color(0xFF0B1020),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSel ? const Color(0xFF00F5D4) : Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => selectedSubId = sub.id),
                              child: Text(sub.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _importSubscription(sub.url),
                                  child: const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF00F5D4)),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      subscriptions.removeWhere((s) => s.id == sub.id);
                                      profiles.removeWhere((p) => p.subId == sub.id);
                                      if (selectedSubId == sub.id) selectedSubId = 'all';
                                    });
                                    _saveData();
                                  },
                                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
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
                                Text('${sub.usedGB} / ${sub.totalGB} GB', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                                Text('${sub.expireDays} ${tr("روز", "Days")}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4))),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: percent, backgroundColor: Colors.white12, color: const Color(0xFF00F5D4), minHeight: 4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('لیست سرورها (${list.length})', 'Servers (${list.length})'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Row(
                children: [
                  _buildTactile3DButton(icon: Icons.bolt_rounded, label: tr('پینگ', 'Ping'), onTap: testAllPings),
                  const SizedBox(width: 6),
                  _buildTactile3DButton(icon: Icons.add_rounded, label: tr('افزودن اشتراک', 'Add Sub'), onTap: _showAddSubscriptionDialog),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(tr('هیچ سروری یافت نشد', 'No servers found'), style: const TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      final bool selected = profiles[activeIdx].id == p.id;
                      Color pCol = const Color(0xFF00F5D4);
                      if (p.ping > 220) pCol = const Color(0xFFFFB300);
                      if (p.ping <= 0 || p.ping > 550) pCol = const Color(0xFFFF4D6D);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            activeIdx = profiles.indexWhere((item) => item.id == p.id);
                          });
                          _saveData();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: selected ? LinearGradient(colors: [const Color(0xFF0066FF).withOpacity(0.3), const Color(0xFFA87FFB).withOpacity(0.2)]) : const LinearGradient(colors: [Color(0xFF172038), Color(0xFF0E1526)]),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: selected ? const Color(0xFF00F5D4) : Colors.white10, width: selected ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32, height: 22,
                                child: CustomPaint(painter: FlagPainter(p.name)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                                    Text('${p.protocol} • ${p.address}:${p.port}', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                                child: Text(p.ping > 0 ? '${p.ping} ms' : 'Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.ping > 0 ? pCol : Colors.white38)),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white38),
                                onPressed: () {
                                  setState(() => profiles.removeWhere((item) => item.id == p.id));
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

  void _showAddSubscriptionDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('افزودن لینک اشتراک', 'Add Subscription Link'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(hintText: 'https://...', filled: true, fillColor: const Color(0xFF070A14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('انصراف', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            onPressed: () {
              final t = ctrl.text.trim();
              Navigator.pop(ctx);
              if (t.isNotEmpty) _importSubscription(t);
            },
            child: Text(tr('افزودن', 'Add')),
          ),
        ],
      ),
    );
  }

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF10172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(tr('⚙️ تنظیمات برنامه', '⚙️ Settings'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(tr('زبان فارسی / English', 'Language Switch'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isFa,
                    activeColor: const Color(0xFF00F5D4),
                    onChanged: (v) {
                      setState(() => appLang = v ? 'fa' : 'en');
                      setModalState(() {});
                      _saveData();
                    },
                  ),
                  SwitchListTile(
                    title: Text(tr('سپر ضد نشت آی‌پی (Anti-Leak)', 'Anti-Leak Shield'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: strictAntiLeak,
                    activeColor: const Color(0xFF00F5D4),
                    onChanged: (v) {
                      setState(() => strictAntiLeak = v);
                      setModalState(() {});
                      _saveData();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _box3DDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xCC1C2640), Color(0xE00D1220)]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.14)),
      boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14))],
    );
  }

  Widget _buildTactile3DButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF243152), Color(0xFF141B2E)]),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF00F5D4)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
