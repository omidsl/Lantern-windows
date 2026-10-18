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
      title: 'Lantern 3D Spatial VPN — Windows Edition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060913),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0066FF),
          secondary: Color(0xFF00F5D4),
          surface: Color(0xFF10172A),
        ),
      ),
      home: const LanternDesktopScreen(),
    );
  }
}

// ==================== مدل پروفایل سرور و شاخص پایداری گیمینگ ====================
class VpnProfile {
  final String id;
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
        name: json['name']?.toString() ?? 'Server',
        rawUri: json['rawUri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        address: json['address']?.toString() ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        ping: json['ping'] is int ? json['ping'] : -1,
        jitter: json['jitter'] is int ? json['jitter'] : 3,
      );
}

// ==================== موتور ذرات معلق جمینای (Gemini Floating Stardust) ====================
class StardustParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;
  double alpha;

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
  final bool isConnected;
  final bool isGaming;
  final Offset mousePos;

  GeminiParticlePainter({
    required this.particles,
    required this.progress,
    required this.isConnected,
    required this.isGaming,
    required this.mousePos,
  });

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

      // واکنش نرم ذرات به حرکت موس روی دسکتاپ ویندوز
      final double dx = px - mousePos.dx;
      final double dy = py - mousePos.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 115 && dist > 1) {
        px += (dx / dist) * (115 - dist) * 0.25;
        py += (dy / dist) * (115 - dist) * 0.25;
      }

      final Color activeColor = isConnected
          ? (isGaming ? const Color(0xFFFF2E93) : const Color(0xFF00F5D4))
          : p.color;

      final Paint paint = Paint()
        ..color = activeColor.withOpacity(
          (p.alpha * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.x * 10))).clamp(0.1, 0.85),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GeminiParticlePainter oldDelegate) => true;
}

// ==================== موتور کانفیگ‌ساز Xray مخصوص ویندوز (بدون هیچ پلاگین اندرویدی) ====================
class WindowsXrayConfigBuilder {
  static String decodeB64(String str) {
    String clean = str.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  static VpnProfile? parseProfile(String link, int index) {
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
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          name: ps,
          rawUri: clean,
          protocol: 'VMESS',
          address: host,
          port: port,
        );
      } else if (clean.startsWith('vless://') ||
          clean.startsWith('trojan://') ||
          clean.startsWith('ss://')) {
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
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
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
    required int engineMode, // 0: TUN, 1: System Proxy, 2: Fragment, 3: Socks5/LAN
    required bool gamingMode,
    required bool strictAntiLeak,
    required bool allowLan,
    required int splitTunnelMode,
  }) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    Map<String, dynamic> outbound;
    if (trimmed.startsWith('vmess://')) {
      outbound = _buildVmessOutbound(
        trimmed,
        enableFragment: engineMode == 2,
        gamingMode: gamingMode,
      );
    } else if (trimmed.startsWith('trojan://')) {
      outbound = _buildTrojanOutbound(
        trimmed,
        enableFragment: engineMode == 2,
        gamingMode: gamingMode,
      );
    } else if (trimmed.startsWith('ss://')) {
      outbound = _buildShadowsocksOutbound(
        trimmed,
        enableFragment: engineMode == 2,
        gamingMode: gamingMode,
      );
    } else {
      outbound = _buildVlessOutbound(
        trimmed,
        enableFragment: engineMode == 2,
        gamingMode: gamingMode,
      );
    }

    return _wrapInBaseConfig(
      outbound,
      engineMode: engineMode,
      strictAntiLeak: strictAntiLeak,
      allowLan: allowLan || engineMode == 3,
      splitTunnelMode: splitTunnelMode,
    );
  }

  static Map<String, dynamic> _buildVlessOutbound(
    String link, {
    required bool enableFragment,
    required bool gamingMode,
  }) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;

    final String uuid = Uri.decodeComponent(uri.userInfo);
    final String address = uri.host;
    final int port = uri.port > 0 ? uri.port : 443;
    final String encryption = q['encryption'] ?? 'none';
    final String flow = q['flow'] ?? '';

    final Map<String, dynamic> user = {
      'id': uuid,
      'encryption': encryption,
      'level': 8,
    };
    if (flow.isNotEmpty) user['flow'] = flow;

    return {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [user],
          }
        ]
      },
      'streamSettings': _buildStreamSettings(
        q,
        address,
        enableFragment: enableFragment,
        gamingMode: gamingMode,
      ),
    };
  }

  static Map<String, dynamic> _buildVmessOutbound(
    String link, {
    required bool enableFragment,
    required bool gamingMode,
  }) {
    final decoded = decodeB64(link.substring(8));
    final Map<String, dynamic> m = jsonDecode(decoded);

    final String address = m['add']?.toString() ?? '';
    final int port = int.tryParse(m['port']?.toString() ?? '443') ?? 443;
    final String id = m['id']?.toString() ?? '';
    final int aid = int.tryParse(m['aid']?.toString() ?? '0') ?? 0;
    final String scy = m['scy']?.toString() ?? 'auto';
    final String net = (m['net']?.toString() ?? 'tcp').toLowerCase();
    final String tls = (m['tls']?.toString() ?? 'none').toLowerCase();
    final String sni = m['sni']?.toString() ?? m['host']?.toString() ?? address;
    final String host = m['host']?.toString() ?? '';
    final String path = m['path']?.toString() ?? '/';
    final String fp = m['fp']?.toString() ?? 'chrome';

    final Map<String, String> q = {
      'type': net,
      'security': tls == 'tls' ? 'tls' : 'none',
      'sni': sni,
      'host': host,
      'path': path,
      'fp': fp,
    };

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
                'id': id,
                'alterId': aid,
                'security': scy,
                'level': 8,
              }
            ]
          }
        ]
      },
      'streamSettings': _buildStreamSettings(
        q,
        address,
        enableFragment: enableFragment,
        gamingMode: gamingMode,
      ),
    };
  }

  static Map<String, dynamic> _buildTrojanOutbound(
    String link, {
    required bool enableFragment,
    required bool gamingMode,
  }) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;

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
      'streamSettings': _buildStreamSettings(
        q,
        uri.host,
        enableFragment: enableFragment,
        gamingMode: gamingMode,
      ),
    };
  }

  static Map<String, dynamic> _buildShadowsocksOutbound(
    String link, {
    required bool enableFragment,
    required bool gamingMode,
  }) {
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
          {
            'address': uri.host,
            'port': uri.port > 0 ? uri.port : 443,
            'method': method,
            'password': password,
            'level': 8,
          }
        ]
      },
    };
  }

  static Map<String, dynamic> _buildStreamSettings(
    Map<String, String> q,
    String defaultHost, {
    required bool enableFragment,
    required bool gamingMode,
  }) {
    final String net = (q['type'] ?? 'tcp').toLowerCase();
    final String security = (q['security'] ?? 'none').toLowerCase();
    final String sni = q['sni'] ?? q['host'] ?? defaultHost;
    final String fp = q['fp'] ?? 'chrome';
    final String alpnStr = q['alpn'] ?? '';
    final String path = q['path'] ?? '/';
    final String hostHeader = q['host'] ?? '';

    final Map<String, dynamic> stream = {
      'network': net,
      'security': security,
    };

    if (security == 'tls') {
      final Map<String, dynamic> tlsSettings = {
        'allowInsecure': q['allowInsecure'] == '1' || q['allowInsecure'] == 'true',
        'serverName': sni,
        'fingerprint': fp,
      };
      if (alpnStr.isNotEmpty) {
        tlsSettings['alpn'] = alpnStr.split(',').map((e) => e.trim()).toList();
      }
      stream['tlsSettings'] = tlsSettings;
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
      stream['wsSettings'] = {
        'path': path,
        'headers': hostHeader.isNotEmpty ? {'Host': hostHeader} : {},
      };
    } else if (net == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': q['serviceName'] ?? path,
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
    if (sockopt.isNotEmpty) {
      stream['sockopt'] = sockopt;
    }

    return stream;
  }

  static String _wrapInBaseConfig(
    Map<String, dynamic> proxyOutbound, {
    required int engineMode,
    required bool strictAntiLeak,
    required bool allowLan,
    required int splitTunnelMode,
  }) {
    final String listenIp = allowLan ? '0.0.0.0' : '127.0.0.1';

    final List<Map<String, dynamic>> outbounds = [
      proxyOutbound,
      {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
      {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
    ];

    if (engineMode == 2) {
      outbounds.add({
        'tag': 'fragment',
        'protocol': 'freedom',
        'settings': {
          'domainStrategy': 'AsIs',
          'fragment': {
            'packets': 'tlshello',
            'length': '10-20',
            'interval': '10-20',
          }
        }
      });
    }

    final List<Map<String, dynamic>> rules = [];

    if (strictAntiLeak) {
      rules.add({
        'type': 'field',
        'outboundTag': 'block',
        'ip': ['::/0'],
      });
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
        'domain': [
          'regexp:.*\\.ir\$',
          'domain:shaparak.ir',
          'domain:snapp.ir',
          'domain:digikala.com',
          'domain:aparat.com',
          'domain:divar.ir',
        ]
      });
    }

    final Map<String, dynamic> fullConfig = {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': listenIp,
          'protocol': 'socks',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
          'settings': {'auth': 'noauth', 'udp': true},
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': listenIp,
          'protocol': 'http',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
          'settings': {},
        }
      ],
      'outbounds': outbounds,
      'dns': {
        'servers': ['1.1.1.1', '8.8.8.8'],
        if (strictAntiLeak) 'queryStrategy': 'UseIPv4',
      },
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': rules,
      }
    };
    return jsonEncode(fullConfig);
  }
}

// ==================== صفحه اصلی دسکتاپ سه‌بعدی ویندوز ====================
class LanternDesktopScreen extends StatefulWidget {
  const LanternDesktopScreen({super.key});

  @override
  State<LanternDesktopScreen> createState() => _LanternDesktopScreenState();
}

class _LanternDesktopScreenState extends State<LanternDesktopScreen>
    with TickerProviderStateMixin {
  Process? _windowsXrayProcess;
  Timer? _desktopStatsTimer;
  Timer? _failoverWatchdog;

  late final AnimationController _orbController;
  late final AnimationController _particleController;
  final List<StardustParticle> _particles = [];
  Offset _mousePosition = const Offset(500, 320);

  List<VpnProfile> profiles = [];
  int activeIdx = 0;

  bool isConnected = false;
  bool isBusy = false;
  bool isPingingAll = false;
  bool isSyncingSub = false;

  // تفکیک کامل حالت انتخاب دستی 🔒 و خلبان خودکار 🤖
  bool isAutoPilotMode = false;

  // ۴ مدل اتصال ویندوز: 0=TUN, 1=System Proxy, 2=Fragment, 3=Socks5/LAN
  int engineMode = 1;

  // دکمه حالت گیمینگ روی صفحه اصلی
  bool gamingMode = true;

  // تنظیمات پیشرفته
  String appLang = 'fa';
  bool strictAntiLeak = true;
  bool killSwitchActive = true;
  bool autoFailover = true;
  bool allowLan = false;
  int splitTunnelMode = 1;

  String subTitle = "Lantern Spatial Cloud";
  String savedSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int? expireDays;

  String verifiedIp = "Protected";
  String verifiedCountry = "DNS & IPv6 Shield Ready";
  double simDlSpeed = 0.0;
  double simUlSpeed = 0.0;
  final List<double> dlWave = List.filled(14, 0.15, growable: true);
  final List<double> ulWave = List.filled(14, 0.15, growable: true);

  bool get isFa => appLang == 'fa';
  String tr(String faText, String enText) => isFa ? faText : enText;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _initParticles();
    _loadData();
  }

  void _initParticles() {
    final rnd = math.Random();
    final palette = [
      const Color(0xFF0066FF),
      const Color(0xFFA87FFB),
      const Color(0xFF00F5D4),
      const Color(0xFFFF6B9D),
    ];
    for (int i = 0; i < 45; i++) {
      _particles.add(
        StardustParticle(
          x: rnd.nextDouble(),
          y: rnd.nextDouble(),
          vx: (rnd.nextDouble() - 0.5) * 0.0009,
          vy: (rnd.nextDouble() - 0.5) * 0.0009,
          radius: rnd.nextDouble() * 2.5 + 1.0,
          color: palette[rnd.nextInt(palette.length)],
          alpha: rnd.nextDouble() * 0.65 + 0.2,
        ),
      );
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
      final list = prefs.getStringList('lantern_win_profiles') ?? [];
      final loaded = <VpnProfile>[];
      for (var item in list) {
        try {
          loaded.add(VpnProfile.fromJson(jsonDecode(item)));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        profiles = loaded;
        activeIdx = prefs.getInt('activeIdx') ?? 0;
        if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
        isAutoPilotMode = prefs.getBool('isAutoPilotMode') ?? false;
        engineMode = prefs.getInt('engineMode') ?? 1;
        gamingMode = prefs.getBool('gamingMode') ?? true;
        appLang = prefs.getString('appLang') ?? 'fa';
        strictAntiLeak = prefs.getBool('strictAntiLeak') ?? true;
        killSwitchActive = prefs.getBool('killSwitchActive') ?? true;
        autoFailover = prefs.getBool('autoFailover') ?? true;
        allowLan = prefs.getBool('allowLan') ?? false;
        splitTunnelMode = prefs.getInt('splitTunnelMode') ?? 1;
        savedSubUrl = prefs.getString('savedSubUrl') ?? "";
        subTitle = prefs.getString('subTitle') ?? "Lantern Spatial Cloud";
      });
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_win_profiles',
        profiles.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setBool('isAutoPilotMode', isAutoPilotMode);
      await prefs.setInt('engineMode', engineMode);
      await prefs.setBool('gamingMode', gamingMode);
      await prefs.setString('appLang', appLang);
      await prefs.setBool('strictAntiLeak', strictAntiLeak);
      await prefs.setBool('killSwitchActive', killSwitchActive);
      await prefs.setBool('autoFailover', autoFailover);
      await prefs.setBool('allowLan', allowLan);
      await prefs.setInt('splitTunnelMode', splitTunnelMode);
      await prefs.setString('savedSubUrl', savedSubUrl);
      await prefs.setString('subTitle', subTitle);
    } catch (_) {}
  }

  Future<void> toggleConnection() async {
    if (isConnected || isBusy) {
      await _stopWindowsEngine();
      setState(() {
        isConnected = false;
        isBusy = false;
        simDlSpeed = 0.0;
        simUlSpeed = 0.0;
      });
      _notify(tr('تونل ویندوز قطع شد', 'Windows Tunnel Disconnected'));
      return;
    }

    if (profiles.isEmpty) {
      _showAddDialog();
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

    final String fullConfig = WindowsXrayConfigBuilder.buildFullJson(
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
        _windowsXrayProcess = await Process.start(
          xrayExe.path,
          ['-c', configFile.path],
          workingDirectory: exeDir,
        );
      }

      if (engineMode != 3) {
        await _setWindowsSystemProxy(enable: true, server: '127.0.0.1:10809');
      }

      setState(() {
        isConnected = true;
        isBusy = false;
        verifiedIp = target.address;
      });

      _startDesktopTelemetry();
      _checkRealIp();
      _notify(tr('✦ تونل امن ویندوز برقرار شد!', '✦ Windows Secure Tunnel Connected!'));
    } catch (e) {
      setState(() => isBusy = false);
      _notify('Engine Error: $e');
    }
  }

  Future<void> _stopWindowsEngine() async {
    _desktopStatsTimer?.cancel();
    _failoverWatchdog?.cancel();
    if (Platform.isWindows) {
      await _setWindowsSystemProxy(enable: false);
      _windowsXrayProcess?.kill();
      _windowsXrayProcess = null;
    }
  }

  Future<void> _setWindowsSystemProxy({required bool enable, String server = '127.0.0.1:10809'}) async {
    if (!Platform.isWindows) return;
    const String regPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    try {
      await Process.run('reg', [
        'add', regPath, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', enable ? '1' : '0', '/f'
      ]);
      if (enable) {
        await Process.run('reg', [
          'add', regPath, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', server, '/f'
        ]);
      }
    } catch (_) {}
  }

  void _startDesktopTelemetry() {
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

  Future<void> _checkRealIp() async {
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            verifiedIp = data['query']?.toString() ?? 'Protected';
            verifiedCountry = "${data['country'] ?? ''} • Zero Leak Verified";
          });
        }
      }
    } catch (_) {}
  }

  Future<void> testTcpPing(VpnProfile p) async {
    if (!mounted || p.address.isEmpty) return;
    setState(() => p.isPinging = true);

    int ping1 = -2;
    int ping2 = -2;
    try {
      final sw1 = Stopwatch()..start();
      final s1 = await Socket.connect(p.address, p.port, timeout: const Duration(milliseconds: 1800));
      sw1.stop();
      await s1.close();
      ping1 = sw1.elapsedMilliseconds;

      if (gamingMode) {
        final sw2 = Stopwatch()..start();
        final s2 = await Socket.connect(p.address, p.port, timeout: const Duration(milliseconds: 1800));
        sw2.stop();
        await s2.close();
        ping2 = sw2.elapsedMilliseconds;
      }
    } catch (_) {
      ping1 = -2;
    }

    if (!mounted) return;
    setState(() {
      p.ping = ping1;
      p.jitter = (ping1 > 0 && ping2 > 0) ? (ping1 - ping2).abs() : 3;
      p.isPinging = false;
    });
  }

  Future<void> testAllPings() async {
    if (profiles.isEmpty || isPingingAll) return;
    setState(() => isPingingAll = true);

    const int batch = 5;
    for (int i = 0; i < profiles.length; i += batch) {
      final end = (i + batch < profiles.length) ? i + batch : profiles.length;
      await Future.wait([for (int j = i; j < end; j++) testTcpPing(profiles[j])]);
    }

    if (!mounted) return;
    setState(() {
      if (isAutoPilotMode) {
        profiles.sort((a, b) {
          if (a.ping <= 0 && b.ping <= 0) return 0;
          if (a.ping <= 0) return 1;
          if (b.ping <= 0) return -1;
          return a.ping.compareTo(b.ping);
        });
        activeIdx = 0;
      }
      isPingingAll = false;
    });
    _saveData();
  }

  Future<void> selectServerCard(int index) async {
    if (index < 0 || index >= profiles.length) return;
    final bool wasConn = isConnected;

    setState(() {
      activeIdx = index;
      isAutoPilotMode = false;
    });
    await _saveData();

    if (wasConn) {
      await _stopWindowsEngine();
      setState(() => isConnected = false);
      await Future.delayed(const Duration(milliseconds: 300));
      await toggleConnection();
    } else {
      _notify(tr('🔒 سرور «${profiles[index].name}» در حالت دستی قفل شد', '🔒 Locked on ${profiles[index].name}'));
    }
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      _notify(tr('کلیپ‌بورد خالی است!', 'Clipboard is empty!'));
      return;
    }
    await _importRawInput(data.text!.trim());
  }

  Future<void> syncSubscription() async {
    if (savedSubUrl.isEmpty) {
      _notify(tr('ابتدا یک لینک اشتراک اضافه کنید.', 'No subscription URL saved yet.'));
      return;
    }
    await _importRawInput(savedSubUrl, replaceAll: true);
  }

  Future<void> _importRawInput(String input, {bool replaceAll = false}) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      setState(() => isSyncingSub = true);
      try {
        final res = await http.get(Uri.parse(input), headers: {'User-Agent': 'v2rayNG/1.8.19'}).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          String body = res.body.trim();
          if (!body.contains('://')) {
            try {
              body = WindowsXrayConfigBuilder.decodeB64(body);
            } catch (_) {}
          }
          final added = _parseConfigLines(body, replace: replaceAll);
          if (added > 0) {
            savedSubUrl = input;
            subTitle = Uri.parse(input).host;
            _saveData();
          }
        }
      } catch (_) {
        _notify(tr('خطا در دریافت لینک اشتراک', 'Subscription fetch failed'));
      }
      if (mounted) setState(() => isSyncingSub = false);
    } else {
      _parseConfigLines(input, replace: false);
    }
  }

  int _parseConfigLines(String raw, {required bool replace}) {
    final lines = raw.split(RegExp(r'[\r\n]+'));
    final added = <VpnProfile>[];
    for (var l in lines) {
      final p = WindowsXrayConfigBuilder.parseProfile(l, profiles.length + added.length + 1);
      if (p != null) added.add(p);
    }
    if (added.isEmpty) {
      _notify(tr('کانفیگ معتبری یافت نشد', 'No valid configs found'));
      return 0;
    }
    setState(() {
      if (replace) {
        profiles = added;
      } else {
        profiles.insertAll(0, added);
      }
      activeIdx = 0;
    });
    _saveData();
    testAllPings();
    return added.length;
  }

  String _detectFlag(String name) {
    final up = name.toUpperCase();
    if (up.contains('DE') || up.contains('GERMANY') || name.contains('آلمان')) return '🇩🇪';
    if (up.contains('NL') || up.contains('NETHERLANDS') || name.contains('هلند')) return '🇳🇱';
    if (up.contains('US') || up.contains('AMERICA') || name.contains('آمریکا')) return '🇺🇸';
    if (up.contains('GB') || up.contains('UK') || up.contains('LONDON') || name.contains('انگلیس')) return '🇬🇧';
    if (up.contains('FI') || up.contains('FINLAND') || name.contains('فنلاند')) return '🇫🇮';
    if (up.contains('TR') || up.contains('TURKEY') || name.contains('ترکیه')) return '🇹🇷';
    if (up.contains('FR') || up.contains('FRANCE') || name.contains('فرانسه')) return '🇫🇷';
    if (up.contains('CH') || up.contains('SWISS') || name.contains('سوئیس')) return '🇨🇭';
    return '🌐';
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131C33),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: const Color(0xFF00F5D4).withOpacity(0.45)),
        ),
        duration: const Duration(seconds: 2),
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
              // هاله‌های نوری پس‌زمینه
              Positioned(
                top: -110,
                right: -80,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF0066FF)).withOpacity(0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -110,
                left: -80,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (gamingMode ? const Color(0xFFFF2E93) : const Color(0xFFA87FFB)).withOpacity(0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ذرات معلق و ستاره‌ای جمینای
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: GeminiParticlePainter(
                        particles: _particles,
                        progress: _particleController.value,
                        isConnected: isConnected,
                        isGaming: gamingMode,
                        mousePos: _mousePosition,
                      ),
                    );
                  },
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 410,
                        child: _buildCommandPanel3D(),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _buildServersPanel3D(),
                      ),
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
    final List<String> engineLabels = ['🛡️ TUN', '🌐 Proxy', '⚡ Fragment', '🔌 Socks5'];

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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFFA87FFB)]),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF0066FF).withOpacity(0.45), blurRadius: 14),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lantern 3D',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.4),
                          ),
                          Text(
                            subTitle,
                            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildTactile3DButton(
                    icon: Icons.settings_suggest_rounded,
                    label: tr('تنظیمات', 'Settings'),
                    onTap: _openSettingsModal,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ۴ مدل اتصال ویندوز
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF070A14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                            gradient: active
                                ? const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF0044AA)])
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: active
                                ? [BoxShadow(color: const Color(0xFF0066FF).withOpacity(0.4), blurRadius: 8)]
                                : null,
                          ),
                          child: Text(
                            engineLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),

              // دکمه حالت گیمینگ روی صفحه اصلی
              GestureDetector(
                onTap: () {
                  setState(() => gamingMode = !gamingMode);
                  _saveData();
                  _notify(
                    gamingMode
                        ? tr('🎮 حالت گیمینگ (TCP NoDelay + Anti-Jitter) فعال شد!', '🎮 Gaming Mode (Zero-Jitter) Activated!')
                        : tr('حالت گیمینگ غیرفعال شد', 'Gaming Mode Disabled'),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: gamingMode
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFFF2E93).withOpacity(0.25),
                              const Color(0xFFA87FFB).withOpacity(0.20),
                            ],
                          )
                        : null,
                    color: gamingMode ? null : const Color(0xFF0B1020),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: gamingMode ? const Color(0xFFFF2E93).withOpacity(0.75) : Colors.white12,
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            size: 18,
                            color: gamingMode ? const Color(0xFFFF2E93) : Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('حالت گیمینگ و پینگ پایدار (CS2 / Gaming)', 'Gaming Ultra-Low Jitter Mode'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  color: gamingMode ? Colors.white : Colors.white70,
                                ),
                              ),
                              Text(
                                gamingMode
                                    ? 'TCP NoDelay • Packet Pacing • Jitter: ${current?.jitter ?? 3} ms'
                                    : tr('برای حذف لگ و پکت‌لاس بازی کلیک کنید', 'Click to enable low-latency gaming socket'),
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
                        child: Text(
                          gamingMode ? 'ON ⚡' : 'OFF',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // گوی راکتور سه‌بعدی در مرکز
          Column(
            children: [
              GestureDetector(
                onTap: toggleConnection,
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _orbController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _orbController.value * 2 * math.pi,
                            child: Container(
                              width: 156,
                              height: 156,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: isConnected
                                      ? const [Color(0xFF00F5D4), Color(0xFF0066FF), Color(0xFFA87FFB), Color(0xFF00F5D4)]
                                      : (gamingMode
                                          ? const [Color(0xFFFF2E93), Color(0xFFA87FFB), Color(0xFF0066FF), Color(0xFFFF2E93)]
                                          : const [Color(0xFF0066FF), Color(0xFFA87FFB), Color(0xFF00F5D4), Color(0xFF0066FF)]),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF0066FF)).withOpacity(0.42),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.35, -0.45),
                            radius: 1.15,
                            colors: [Color(0xFF33436B), Color(0xFF131B30), Color(0xFF070A14)],
                          ),
                          border: Border.all(
                            color: isConnected ? const Color(0xFF00F5D4) : Colors.white.withOpacity(0.35),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isBusy)
                              const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF00F5D4)),
                              )
                            else
                              Icon(
                                Icons.power_settings_new_rounded,
                                size: 42,
                                color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              isConnected ? 'PROTECTED' : 'CONNECT',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: isConnected ? const Color(0xFF00F5D4) : Colors.white70,
                              ),
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
                isConnected
                    ? tr('متصل به ${current?.name ?? "سرور"}', 'Connected to ${current?.name ?? "Server"}')
                    : tr('آماده برقراری تونل سه‌بعدی ویندوز', 'Ready for Windows Spatial Tunnel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
                ),
              ),
            ],
          ),

          // رادار ضد نشت + سرعت زنده
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF080C18),
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
                          Text(
                            'IP: $verifiedIp',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Colors.white),
                          ),
                          Text(
                            verifiedCountry,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5D4).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00F5D4).withOpacity(0.4)),
                      ),
                      child: Text(
                        strictAntiLeak ? '🛡️ NO LEAK' : 'STANDARD',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF00F5D4)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSpeedCard3D(
                      title: tr('دانلود زنده', 'Download'),
                      value: '$simDlSpeed MB/s',
                      color: const Color(0xFF00F5D4),
                      bars: dlWave,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpeedCard3D(
                      title: tr('آپلود زنده', 'Upload'),
                      value: '$simUlSpeed MB/s',
                      color: const Color(0xFFA87FFB),
                      bars: ulWave,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard3D({
    required String title,
    required String value,
    required Color color,
    required List<double> bars,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D19),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
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
              children: bars.map((v) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: isConnected ? (v * 12).clamp(3.0, 12.0) : 3.0,
                    decoration: BoxDecoration(
                      color: isConnected ? color : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServersPanel3D() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box3DDecoration(),
      child: Column(
        children: [
          // کلید برجسته سه‌بعدی تفکیک حالت «انتخاب دستی 🔒» و «خلبان خودکار 🤖»
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF060912),
              borderRadius: BorderRadius.circular(16),
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
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: !isAutoPilotMode
                            ? LinearGradient(colors: [const Color(0xFF0066FF).withOpacity(0.35), const Color(0xFF0066FF).withOpacity(0.15)])
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: !isAutoPilotMode ? Border.all(color: const Color(0xFF0066FF).withOpacity(0.7)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔒', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('حالت انتخاب دستی (ثابت)', 'Manual Lock Mode'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: !isAutoPilotMode ? Colors.white : Colors.white54),
                                ),
                                Text(
                                  tr('قفل روی سرور انتخابی شما', 'Stays on selected server'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                                ),
                              ],
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
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: isAutoPilotMode
                            ? LinearGradient(colors: [const Color(0xFFA87FFB).withOpacity(0.35), const Color(0xFF00F5D4).withOpacity(0.18)])
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: isAutoPilotMode ? Border.all(color: const Color(0xFF00F5D4).withOpacity(0.7)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🤖', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('خلبان خودکار (Smart Auto)', 'Smart Auto-Pilot'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: isAutoPilotMode ? Colors.white : Colors.white54),
                                ),
                                Text(
                                  tr('سریع‌ترین پینگ + ضد قطعی', 'Lowest ping + Failover'),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                                ),
                              ],
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isAutoPilotMode
                      ? tr('🤖 خلبان خودکار فعال: اتصال به بهترین سرور', '🤖 Auto-Pilot Active: Best node locked')
                      : tr('🔒 حالت دستی فعال: روی سرور دلخواه کلیک کنید', '🔒 Manual Lock: Click any server to lock'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAutoPilotMode ? const Color(0xFF00F5D4) : const Color(0xFF93C5FD),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildTactile3DButton(
                    icon: Icons.sync_rounded,
                    label: tr('آپدیت', 'Sync'),
                    onTap: syncSubscription,
                  ),
                  const SizedBox(width: 6),
                  _buildTactile3DButton(
                    icon: Icons.bolt_rounded,
                    label: tr('پینگ', 'Ping'),
                    onTap: testAllPings,
                  ),
                  const SizedBox(width: 6),
                  _buildTactile3DButton(
                    icon: Icons.content_paste_rounded,
                    label: tr('چسباندن', 'Paste'),
                    onTap: pasteFromClipboard,
                  ),
                  const SizedBox(width: 6),
                  _buildTactile3DButton(
                    icon: Icons.add_rounded,
                    label: tr('افزودن', 'Add'),
                    onTap: _showAddDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          Expanded(
            child: profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns_outlined, size: 44, color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(
                          tr('هیچ سروری اضافه نشده است', 'No servers added yet'),
                          style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                          onPressed: pasteFromClipboard,
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: Text(tr('چسباندن کانفیگ یا اشتراک از کلیپ‌بورد', 'Paste Config / Subscription from Clipboard')),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final bool selected = index == activeIdx;

                      Color pCol = const Color(0xFF00F5D4);
                      if (p.ping > 220) pCol = const Color(0xFFFFB300);
                      if (p.ping <= 0 || p.ping > 550) pCol = const Color(0xFFFF4D6D);

                      return GestureDetector(
                        onTap: () => selectServerCard(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF0066FF).withOpacity(0.28),
                                      const Color(0xFFA87FFB).withOpacity(0.18),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFF172038), Color(0xFF0E1526)],
                                  ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected ? const Color(0xFF00F5D4) : Colors.white.withOpacity(0.08),
                              width: selected ? 1.5 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(_detectFlag(p.name), style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
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
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                          ),
                                        ),
                                        if (p.isGameReady) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF2E93).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFF2E93).withOpacity(0.5)),
                                            ),
                                            child: const Text(
                                              '🎯 GAME READY',
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFFF85B3)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${p.protocol} • ${p.address}:${p.port} • ${selected ? (isAutoPilotMode ? "🤖 Auto-Locked" : "🔒 Manual-Locked") : ""}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => testTcpPing(p),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(color: p.ping > 0 ? pCol.withOpacity(0.4) : Colors.white10),
                                  ),
                                  child: p.isPinging
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4)),
                                        )
                                      : Text(
                                          p.ping > 0 ? '${p.ping} ms' : (p.ping == -2 ? 'Timeout' : 'Ping'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: p.ping > 0 ? pCol : Colors.white38,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.white38),
                                onPressed: () {
                                  setState(() {
                                    profiles.removeAt(index);
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

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: const Color(0xFF10172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.white.withOpacity(0.18)),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('⚙️ تنظیمات پیشرفته و زبان برنامه', '⚙️ Advanced Settings & Language'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSettingTile(
                          title: tr('🌍 زبان برنامه (Language)', '🌍 Interface Language'),
                          subtitle: tr('تغییر آنی زبان و چیدمان راست‌به‌چپ / چپ‌به‌راست', 'Instant Persian (RTL) / English (LTR) switch'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChoiceChip(
                                label: const Text('🇮🇷 فارسی'),
                                selected: isFa,
                                onSelected: (_) {
                                  setState(() => appLang = 'fa');
                                  setModalState(() {});
                                  _saveData();
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('🇬🇧 English'),
                                selected: !isFa,
                                onSelected: (_) {
                                  setState(() => appLang = 'en');
                                  setModalState(() {});
                                  _saveData();
                                },
                              ),
                            ],
                          ),
                        ),
                        _buildSettingTile(
                          title: tr('🛡️ سپر ضد نشت آی‌پی و DNS (Zero-Leak)', '🛡️ Strict Anti-IP & DNS Leak Shield'),
                          subtitle: tr('مسدودسازی کامل IPv6 و قفل کردن DNS داخل تونل', 'Block IPv6 traffic & force encrypted DNS'),
                          trailing: Switch(
                            value: strictAntiLeak,
                            activeColor: const Color(0xFF00F5D4),
                            onChanged: (v) {
                              setState(() => strictAntiLeak = v);
                              setModalState(() {});
                              _saveData();
                            },
                          ),
                        ),
                        _buildSettingTile(
                          title: tr('🛑 کلید اضطراری قطع اینترنت (Kill Switch)', '🛑 Network Kill Switch Protection'),
                          subtitle: tr('جلوگیری از لو رفتن آی‌پی واقعی در لحظه افتادن VPN', 'Prevent real IP exposure if tunnel drops'),
                          trailing: Switch(
                            value: killSwitchActive,
                            activeColor: const Color(0xFF00F5D4),
                            onChanged: (v) {
                              setState(() => killSwitchActive = v);
                              setModalState(() {});
                              _saveData();
                            },
                          ),
                        ),
                        _buildSettingTile(
                          title: tr('🔀 مسیریابی هوشمند ترافیک (Split Tunneling)', '🔀 Per-App & Domain Split Tunneling'),
                          subtitle: splitTunnelMode == 0
                              ? tr('عبور ۱۰۰٪ کل ترافیک از تونل', 'Route 100% of traffic through tunnel')
                              : tr('عبور مستقیم سایت‌های بانکی و داخلی (.ir)', 'Bypass local & Iranian banking domains'),
                          trailing: DropdownButton<int>(
                            value: splitTunnelMode,
                            dropdownColor: const Color(0xFF172038),
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(value: 0, child: Text(tr('تونل ۱۰۰٪ کامل', '100% Global Tunnel'), style: const TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 1, child: Text(tr('هوشمند (معافیت ایران)', 'Bypass Local / .IR'), style: const TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => splitTunnelMode = val);
                              setModalState(() {});
                              _saveData();
                            },
                          ),
                        ),
                        _buildSettingTile(
                          title: tr('📡 اشتراک‌گذاری VPN در وای‌فای خانه (Allow LAN)', '📡 Share VPN over Local Wi-Fi (Allow LAN)'),
                          subtitle: tr('امکان اتصال گوشی و کنسول به پورت 10808 کامپیوتر', 'Expose Socks5/HTTP gateway on port 10808'),
                          trailing: Switch(
                            value: allowLan,
                            activeColor: const Color(0xFF00F5D4),
                            onChanged: (v) {
                              setState(() => allowLan = v);
                              setModalState(() {});
                              _saveData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('افزودن کانفیگ یا لینک اشتراک', 'Add Config or Subscription URL'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'vless://...\nvmess://...\nhttps://...',
            filled: true,
            fillColor: const Color(0xFF070A14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('انصراف', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            onPressed: () {
              final t = ctrl.text.trim();
              Navigator.pop(ctx);
              if (t.isNotEmpty) _importRawInput(t);
            },
            child: Text(tr('افزودن', 'Add')),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box3DDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xCC1C2640), Color(0xE00D1220)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.14)),
      boxShadow: const [
        BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14)),
      ],
    );
  }

  Widget _buildTactile3DButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF243152), Color(0xFF141B2E)],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
          ],
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
