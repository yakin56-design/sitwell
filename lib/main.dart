import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SitWellApp());
}

class SitWellApp extends StatelessWidget {
  const SitWellApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SitWell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ===== POSTURE ICON PAINTER =====
class PostureIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double s = size.width / 120;
    _drawSidePerson(canvas, s, 30 * s, 8 * s, const Color(0xFF43A047), false);
    _drawSidePerson(canvas, s, 75 * s, 8 * s, const Color(0xFFE53935), true);
  }

  void _drawSidePerson(Canvas canvas, double s, double cx, double cy,
      Color color, bool leaning) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    double headR = 7 * s;
    double headX = leaning ? cx + 10 * s : cx;
    double headY = cy + headR;
    canvas.drawCircle(Offset(headX, headY), headR,
        Paint()..color = color..style = PaintingStyle.fill);
    double hipX = leaning ? cx - 5 * s : cx;
    double hipY = cy + 45 * s;
    canvas.drawLine(Offset(headX, headY + headR), Offset(hipX, hipY), paint);
    double kneeX = hipX + 22 * s;
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, hipY), paint);
    canvas.drawLine(Offset(kneeX, hipY), Offset(kneeX, hipY + 22 * s), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== SPLASH SCREEN =====
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _slideValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const Spacer(),
            SizedBox(width: 160, height: 100,
                child: CustomPaint(painter: PostureIconPainter())),
            const SizedBox(height: 40),
            const Text('Improve Your\nPosture Every Day',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                  color: Colors.white, height: 1.3)),
            const SizedBox(height: 16),
            const Text('ช่วยให้คุณนั่งอ่านหนังสือถูกท่าทาง',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white30),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(child: Text(
                      _slideValue > 0.3 ? 'เลื่อนต่อไป →' : 'เลื่อนเพื่อเริ่มต้น →',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16))),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 50),
                      left: _slideValue * (MediaQuery.of(context).size.width - 80 - 56),
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) {
                          setState(() {
                            double maxW = MediaQuery.of(context).size.width - 80 - 56;
                            _slideValue = ((_slideValue * maxW + d.delta.dx) / maxW).clamp(0.0, 1.0);
                          });
                        },
                        onHorizontalDragEnd: (_) {
                          if (_slideValue > 0.8) {
                            Navigator.pushReplacement(context,
                                MaterialPageRoute(builder: (_) => const HomeScreen()));
                          } else {
                            setState(() => _slideValue = 0.0);
                          }
                        },
                        child: Container(
                          width: 56, height: 56,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF43A047),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(Icons.arrow_forward, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }
}

// ===== BLE SERVICE =====
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  final _ble = FlutterReactiveBle();
  StreamSubscription? _scanSub;
  StreamSubscription? _connectSub;
  StreamSubscription? _notifySub;
  String? _deviceId;
  bool get isConnected => _deviceId != null;

  final _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  static const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const _writeUuid   = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const _notifyUuid  = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<List<DiscoveredDevice>> scanForDevices() async {
    await requestPermissions();
    List<DiscoveredDevice> found = [];
    _scanSub?.cancel();
    _scanSub = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.isNotEmpty && !found.any((d) => d.id == device.id)) {
        found.add(device);
      }
    });
    await Future.delayed(const Duration(seconds: 5));
    _scanSub?.cancel();
    return found.where((d) => d.name.toLowerCase().contains('sitwell')).toList();
  }

  Future<bool> connect(DiscoveredDevice device) async {
    final completer = Completer<bool>();
    _connectSub?.cancel();
    _connectSub = _ble.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 15),
    ).listen((state) async {
      if (state.connectionState == DeviceConnectionState.connected) {
        _deviceId = device.id;
        try {
          final notifyChar = QualifiedCharacteristic(
            serviceId: Uuid.parse(_serviceUuid),
            characteristicId: Uuid.parse(_notifyUuid),
            deviceId: device.id,
          );
          _notifySub?.cancel();
          _notifySub = _ble.subscribeToCharacteristic(notifyChar).listen((data) {
            _dataController.add(String.fromCharCodes(data));
          });
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(true);
      } else if (state.connectionState == DeviceConnectionState.disconnected) {
        _deviceId = null;
        if (!completer.isCompleted) completer.complete(false);
      }
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future;
  }

  Future<void> sendAlert() async {
    if (_deviceId == null) return;
    try {
      final writeChar = QualifiedCharacteristic(
        serviceId: Uuid.parse(_serviceUuid),
        characteristicId: Uuid.parse(_writeUuid),
        deviceId: _deviceId!,
      );
      await _ble.writeCharacteristicWithResponse(writeChar, value: [49]);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connectSub?.cancel();
    _scanSub?.cancel();
    _deviceId = null;
  }
}

// ===== STATS SERVICE =====
class StatsService {
  // key format: "stats_YYYY-MM-DD_HH" สำหรับรายชั่วโมง
  static String _dayKey(DateTime dt, int hour) =>
      'stats_${DateFormat('yyyy-MM-dd').format(dt)}_$hour';
  static String _dateKey(DateTime dt) =>
      'stats_${DateFormat('yyyy-MM-dd').format(dt)}';

  static Future<void> addSession(int minutes, int badCount) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final hour = now.hour;

    // บันทึกรายชั่วโมง
    String hKey = _dayKey(now, hour);
    double prevMin = prefs.getDouble('${hKey}_min') ?? 0;
    int prevBad = prefs.getInt('${hKey}_bad') ?? 0;
    await prefs.setDouble('${hKey}_min', prevMin + minutes / 60);
    await prefs.setInt('${hKey}_bad', prevBad + badCount);

    // บันทึกรายวัน
    String dKey = _dateKey(now);
    double prevDayMin = prefs.getDouble('${dKey}_min') ?? 0;
    int prevDayBad = prefs.getInt('${dKey}_bad') ?? 0;
    await prefs.setDouble('${dKey}_min', prevDayMin + minutes / 60);
    await prefs.setInt('${dKey}_bad', prevDayBad + badCount);
  }

  // ดึงข้อมูลรายชั่วโมงของวันนี้ (24 ชั่วโมง)
  static Future<Map<String, List<double>>> getTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    List<double> hours = [], bads = [];
    for (int h = 0; h < 24; h++) {
      String key = _dayKey(now, h);
      hours.add(prefs.getDouble('${key}_min') ?? 0);
      bads.add((prefs.getInt('${key}_bad') ?? 0).toDouble());
    }
    return {'hours': hours, 'bads': bads};
  }

  // ดึงข้อมูลรายวันของสัปดาห์นี้ (จันทร์-อาทิตย์)
  static Future<Map<String, List<double>>> getWeekData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // หาวันจันทร์ของสัปดาห์นี้
    final monday = now.subtract(Duration(days: now.weekday - 1));
    List<double> hours = [], bads = [];
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      String key = _dateKey(day);
      hours.add(prefs.getDouble('${key}_min') ?? 0);
      bads.add((prefs.getInt('${key}_bad') ?? 0).toDouble());
    }
    return {'hours': hours, 'bads': bads};
  }

  // ดึงข้อมูลรายเดือนของปีนี้ (ม.ค.-ธ.ค.)
  static Future<Map<String, List<double>>> getYearData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    List<double> hours = [], bads = [];
    for (int m = 1; m <= 12; m++) {
      double totalHours = 0, totalBads = 0;
      int daysInMonth = DateUtils.getDaysInMonth(now.year, m);
      for (int d = 1; d <= daysInMonth; d++) {
        final day = DateTime(now.year, m, d);
        String key = _dateKey(day);
        totalHours += prefs.getDouble('${key}_min') ?? 0;
        totalBads += prefs.getInt('${key}_bad') ?? 0;
      }
      hours.add(totalHours);
      bads.add(totalBads);
    }
    return {'hours': hours, 'bads': bads};
  }

  static Future<Map<String, int>> getTotals() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalMinutes': prefs.getInt('totalMinutes') ?? 0,
      'totalBadPosture': prefs.getInt('totalBadPosture') ?? 0,
    };
  }

  static Future<void> addTotals(int minutes, int badCount) async {
    final prefs = await SharedPreferences.getInstance();
    int prev = prefs.getInt('totalMinutes') ?? 0;
    int prevBad = prefs.getInt('totalBadPosture') ?? 0;
    await prefs.setInt('totalMinutes', prev + minutes);
    await prefs.setInt('totalBadPosture', prevBad + badCount);
  }
}

// ===== SETTINGS SERVICE =====
class SettingsService {
  static Future<void> save({
    required double tiltThreshold,
    required int delaySeconds,
    required bool vibrationAlert,
    required bool deviceLedAlert,
    required bool soundAlert,
    required int alertMode,
    required double goodPostureAngle,
    required double badPostureAngle,
    required double goodPostureAnglePhone,
    required double badPostureAnglePhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tiltThreshold', tiltThreshold);
    await prefs.setInt('delaySeconds', delaySeconds);
    await prefs.setBool('vibrationAlert', vibrationAlert);
    await prefs.setBool('deviceLedAlert', deviceLedAlert);
    await prefs.setBool('soundAlert', soundAlert);
    await prefs.setInt('alertMode', alertMode);
    await prefs.setDouble('goodPostureAngle', goodPostureAngle);
    await prefs.setDouble('badPostureAngle', badPostureAngle);
    await prefs.setDouble('goodPostureAnglePhone', goodPostureAnglePhone);
    await prefs.setDouble('badPostureAnglePhone', badPostureAnglePhone);
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tiltThreshold': prefs.getDouble('tiltThreshold') ?? 30.0,
      'delaySeconds': prefs.getInt('delaySeconds') ?? 5,
      'vibrationAlert': prefs.getBool('vibrationAlert') ?? true,
      'deviceLedAlert': prefs.getBool('deviceLedAlert') ?? true,
      'soundAlert': prefs.getBool('soundAlert') ?? true,
      'alertMode': prefs.getInt('alertMode') ?? 0,
      'goodPostureAngle': prefs.getDouble('goodPostureAngle') ?? -1,
      'badPostureAngle': prefs.getDouble('badPostureAngle') ?? -1,
      'goodPostureAnglePhone': prefs.getDouble('goodPostureAnglePhone') ?? -1,
      'badPostureAnglePhone': prefs.getDouble('badPostureAnglePhone') ?? -1,
    };
  }
}

// ===== HOME SCREEN =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final BleService _ble = BleService();
  bool _bleConnected = false;
  bool _loaded = false;
  bool _useDevice = false;

  double _tiltThreshold = 30.0;
  int _delaySeconds = 5;
  bool _soundAlert = true;
  bool _vibrationAlert = true;
  bool _deviceLedAlert = true;
  int _alertMode = 0; // 0=Mode A, 1=Mode B
  double _goodPostureAngle = -1;
  double _badPostureAngle = -1;
  double _goodPostureAnglePhone = -1;
  double _badPostureAnglePhone = -1;

  // ค่าเซ็นเซอร์ปัจจุบันสำหรับ Mode B
  double _currentTiltAngle = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initForegroundTask();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.load();
    setState(() {
      _tiltThreshold = settings['tiltThreshold'];
      _delaySeconds = settings['delaySeconds'];
      _vibrationAlert = settings['vibrationAlert'];
      _deviceLedAlert = settings['deviceLedAlert'];
      _soundAlert = settings['soundAlert'];
      _alertMode = settings['alertMode'];
      _goodPostureAngle = settings['goodPostureAngle'];
      _badPostureAngle = settings['badPostureAngle'];
      _goodPostureAnglePhone = settings['goodPostureAnglePhone'];
      _badPostureAnglePhone = settings['badPostureAnglePhone'];
      _loaded = true;
    });
  }

  void _onSessionEnd(int minutes, int badCount) async {
    await StatsService.addSession(minutes, badCount);
    await StatsService.addTotals(minutes, badCount);
  }

  void _onSettingsChanged(Map<String, dynamic> settings) async {
    setState(() {
      _tiltThreshold = settings['tiltThreshold'];
      _delaySeconds = settings['delaySeconds'];
      _soundAlert = settings['soundAlert'];
      _vibrationAlert = settings['vibrationAlert'];
      _deviceLedAlert = settings['deviceLedAlert'];
      _alertMode = settings['alertMode'];
      _goodPostureAngle = settings['goodPostureAngle'];
      _badPostureAngle = settings['badPostureAngle'];
      _goodPostureAnglePhone = settings['goodPostureAnglePhone'];
      _badPostureAnglePhone = settings['badPostureAnglePhone'];
    });
    await SettingsService.save(
      tiltThreshold: _tiltThreshold,
      delaySeconds: _delaySeconds,
      vibrationAlert: _vibrationAlert,
      deviceLedAlert: _deviceLedAlert,
      soundAlert: _soundAlert,
      alertMode: _alertMode,
      goodPostureAngle: _goodPostureAngle,
      badPostureAngle: _badPostureAngle,
      goodPostureAnglePhone: _goodPostureAnglePhone,
      badPostureAnglePhone: _badPostureAnglePhone,
    );
  }

  void _onUseDeviceChanged(bool useDevice) {
    setState(() => _useDevice = useDevice);
  }

  void _onTiltAngleChanged(double angle) {
    setState(() => _currentTiltAngle = angle);
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sitwell_channel',
        channelName: 'SitWell Monitor',
        channelDescription: 'กำลังตรวจจับท่านั่ง',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  // คำนวณ threshold จาก Mode B
  double _getEffectiveThreshold() {
    if (_alertMode == 1) {
      if (_useDevice && _goodPostureAngle >= 0 && _badPostureAngle >= 0) {
        return (_badPostureAngle - _goodPostureAngle).abs() / 2;
      } else if (!_useDevice && _goodPostureAnglePhone >= 0 && _badPostureAnglePhone >= 0) {
        return (_badPostureAnglePhone - _goodPostureAnglePhone).abs() / 2;
      }
    }
    return _tiltThreshold;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF43A047))),
      );
    }

    final pages = [
      MonitorPage(
        ble: _ble,
        bleConnected: _bleConnected,
        tiltThreshold: _getEffectiveThreshold(),
        delaySeconds: _delaySeconds,
        soundAlert: _soundAlert,
        vibrationAlert: _vibrationAlert,
        deviceLedAlert: _deviceLedAlert,
        onSessionEnd: _onSessionEnd,
        onUseDeviceChanged: _onUseDeviceChanged,
        onTiltAngleChanged: _onTiltAngleChanged,
      ),
      const StatsPage(),
      SettingsPage(
        tiltThreshold: _tiltThreshold,
        delaySeconds: _delaySeconds,
        soundAlert: _soundAlert,
        vibrationAlert: _vibrationAlert,
        deviceLedAlert: _deviceLedAlert,
        alertMode: _alertMode,
        goodPostureAngle: _goodPostureAngle,
        badPostureAngle: _badPostureAngle,
        goodPostureAnglePhone: _goodPostureAnglePhone,
        badPostureAnglePhone: _badPostureAnglePhone,
        currentTiltAngle: _currentTiltAngle,
        useDevice: _useDevice,
        onChanged: _onSettingsChanged,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(children: [
          SizedBox(width: 50, height: 35,
              child: CustomPaint(painter: PostureIconPainter())),
          const SizedBox(width: 8),
          const Text('SitWell',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          GestureDetector(
            onTap: () => _showBleSheet(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.bluetooth,
                    color: _bleConnected ? const Color(0xFF43A047) : Colors.white38,
                    size: 24),
                if (_bleConnected) ...[
                  const SizedBox(width: 4),
                  const Text('เชื่อมต่อแล้ว',
                      style: TextStyle(color: Color(0xFF43A047), fontSize: 12)),
                ],
              ]),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart, color: Color(0xFF43A047)),
            label: 'ตรวจจับ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF43A047)),
            label: 'สถิติ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF43A047)),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }

  void _showBleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => BleConnectSheet(
        ble: _ble,
        onConnected: () => setState(() => _bleConnected = true),
        onDisconnected: () => setState(() => _bleConnected = false),
      ),
    );
  }
}

// ===== BLE CONNECT SHEET =====
class BleConnectSheet extends StatefulWidget {
  final BleService ble;
  final VoidCallback onConnected;
  final VoidCallback onDisconnected;
  const BleConnectSheet({super.key, required this.ble,
      required this.onConnected, required this.onDisconnected});
  @override
  State<BleConnectSheet> createState() => _BleConnectSheetState();
}

class _BleConnectSheetState extends State<BleConnectSheet> {
  bool _scanning = false;
  List<DiscoveredDevice> _results = [];
  String _status = 'กดสแกนเพื่อค้นหาอุปกรณ์ SitWell';

  void _scan() async {
    setState(() { _scanning = true; _status = 'กำลังสแกน...'; _results = []; });
    try {
      final results = await widget.ble.scanForDevices();
      setState(() {
        _results = results;
        _scanning = false;
        _status = results.isEmpty
            ? 'ไม่พบอุปกรณ์ SitWell — ตรวจสอบว่าเปิดอุปกรณ์แล้ว'
            : 'พบ ${results.length} อุปกรณ์';
      });
    } catch (e) {
      setState(() { _scanning = false; _status = 'เกิดข้อผิดพลาด: $e'; });
    }
  }

  void _connect(DiscoveredDevice device) async {
    setState(() => _status = 'กำลังเชื่อมต่อ...');
    final ok = await widget.ble.connect(device);
    if (ok && mounted) {
      widget.onConnected();
      Navigator.pop(context);
    } else {
      setState(() => _status = 'เชื่อมต่อไม่สำเร็จ ลองใหม่');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('เชื่อมต่ออุปกรณ์ SitWell',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (widget.ble.isConnected)
          ElevatedButton.icon(
            onPressed: () async {
              await widget.ble.disconnect();
              widget.onDisconnected();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
            label: const Text('ตัดการเชื่อมต่อ', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, color: Colors.white),
            label: Text(_scanning ? 'กำลังสแกน...' : 'สแกนหาอุปกรณ์',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 12),
          ..._results.map((r) => ListTile(
            leading: const Icon(Icons.devices_other, color: Color(0xFF43A047)),
            title: Text(r.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('สัญญาณ: ${r.rssi} dBm',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: () => _connect(r),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('เชื่อมต่อ', style: TextStyle(color: Colors.white)),
            ),
          )),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ===== MONITOR PAGE =====
class MonitorPage extends StatefulWidget {
  final BleService ble;
  final bool bleConnected;
  final double tiltThreshold;
  final int delaySeconds;
  final bool soundAlert;
  final bool vibrationAlert;
  final bool deviceLedAlert;
  final Function(int minutes, int badCount) onSessionEnd;
  final Function(bool useDevice) onUseDeviceChanged;
  final Function(double angle) onTiltAngleChanged;

  const MonitorPage({
    super.key,
    required this.ble,
    required this.bleConnected,
    required this.tiltThreshold,
    required this.delaySeconds,
    required this.soundAlert,
    required this.vibrationAlert,
    required this.deviceLedAlert,
    required this.onSessionEnd,
    required this.onUseDeviceChanged,
    required this.onTiltAngleChanged,
  });
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  bool _isActive = false;
  bool _useDevice = false;
  int _sessionMinutes = 0;
  int _badPostureCount = 0;
  Timer? _timer;
  Timer? _delayTimer;
  Timer? _repeatAlertTimer;
  StreamSubscription? _dataSub;
  StreamSubscription? _sensorSub;

  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _tiltAngle = 0;
  String _postureStatus = 'กดเริ่มเพื่อเริ่มตรวจจับ';
  Color _postureColor = Colors.white54;

  bool _isBadPosture = false;
  bool _waitingDelay = false;
  bool _alertedThisEvent = false;

  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('th-TH');
    _tts.setSpeechRate(0.5);
    _dataSub = widget.ble.dataStream.listen(_onBleData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _delayTimer?.cancel();
    _repeatAlertTimer?.cancel();
    _dataSub?.cancel();
    _sensorSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _onBleData(String raw) {
    try {
      final parts = raw.split(',');
      double x = double.parse(parts[0].split(':')[1]);
      double y = double.parse(parts[1].split(':')[1]);
      double z = double.parse(parts[2].split(':')[1]);

      double tiltX = (asin(x.clamp(-1.0, 1.0)) * 180 / pi).abs();
      double tiltY = (asin(y.clamp(-1.0, 1.0)) * 180 / pi).abs();
      double adjustedY = (tiltY - 90).abs();
      double tilt = max(tiltX, adjustedY);

      if (!mounted) return;
      setState(() {
        _accelX = x; _accelY = y; _accelZ = z;
        _tiltAngle = tilt;
      });
      widget.onTiltAngleChanged(tilt);
      if (_isActive && _useDevice) _processPosture(tilt);
    } catch (_) {}
  }

  void _processPosture(double tilt) {
    bool badNow = tilt > widget.tiltThreshold;

    if (badNow && !_isBadPosture) {
      _isBadPosture = true;
      _alertedThisEvent = false;
      _waitingDelay = true;
      setState(() {
        _postureStatus = 'กำลังตรวจสอบ... (${tilt.toStringAsFixed(0)}°)';
        _postureColor = Colors.orange;
      });
      _delayTimer?.cancel();
      _delayTimer = Timer(Duration(seconds: widget.delaySeconds), () {
        if (_isBadPosture && !_alertedThisEvent && mounted) {
          _alertedThisEvent = true;
          setState(() {
            _badPostureCount++;
            _postureStatus = 'เอียงผิดท่า! (${_tiltAngle.toStringAsFixed(0)}°)';
            _postureColor = const Color(0xFFE53935);
          });
          _triggerAlert();
          _repeatAlertTimer?.cancel();
          _repeatAlertTimer = Timer.periodic(const Duration(seconds: 10), (_) {
            if (_isBadPosture && mounted) {
              _triggerAlert();
            } else {
              _repeatAlertTimer?.cancel();
            }
          });
        }
        _waitingDelay = false;
      });
    } else if (!badNow && _isBadPosture) {
      _isBadPosture = false;
      _alertedThisEvent = false;
      _waitingDelay = false;
      _delayTimer?.cancel();
      _repeatAlertTimer?.cancel();
      setState(() {
        _postureStatus = 'ท่านั่งดี ✓';
        _postureColor = const Color(0xFF43A047);
      });
    } else if (badNow && _alertedThisEvent) {
      setState(() {
        _postureStatus = 'เอียงผิดท่า! (${tilt.toStringAsFixed(0)}°)';
        _postureColor = const Color(0xFFE53935);
      });
    }
  }

  void _triggerAlert() {
    if (widget.vibrationAlert) HapticFeedback.heavyImpact();
    if (widget.deviceLedAlert) widget.ble.sendAlert();
    if (widget.soundAlert) _tts.speak('ปรับท่านั่ง');
  }

  void _startPhoneSensor() {
    _sensorSub?.cancel();
    _sensorSub = accelerometerEventStream().listen((event) {
      double tiltX = (asin((event.x / 9.8).clamp(-1.0, 1.0)) * 180 / pi).abs();
      double rawY = (asin((event.y / 9.8).clamp(-1.0, 1.0)) * 180 / pi).abs();
      double adjustedY = (rawY - 90).abs();
      double tilt = max(tiltX, adjustedY);

      if (!mounted) return;
      setState(() {
        _accelX = event.x / 9.8;
        _accelY = event.y / 9.8;
        _accelZ = event.z / 9.8;
        _tiltAngle = tilt;
      });
      widget.onTiltAngleChanged(tilt);
      if (_isActive && !_useDevice) _processPosture(tilt);
    });
  }

  void _toggleMonitoring() {
    if (_isActive) {
      widget.onSessionEnd(_sessionMinutes, _badPostureCount);
      setState(() {
        _isActive = false;
        _postureStatus = 'หยุดตรวจจับแล้ว';
        _postureColor = Colors.white54;
        _isBadPosture = false;
        _waitingDelay = false;
      });
      _timer?.cancel();
      _delayTimer?.cancel();
      _repeatAlertTimer?.cancel();
      _sensorSub?.cancel();
      _tts.stop();
      FlutterForegroundTask.stopService();
    } else {
      setState(() {
        _isActive = true;
        _sessionMinutes = 0;
        _badPostureCount = 0;
        _postureStatus = 'กำลังตรวจจับ...';
        _postureColor = const Color(0xFF43A047);
        _isBadPosture = false;
        _waitingDelay = false;
        _alertedThisEvent = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        setState(() => _sessionMinutes++);
      });
      if (!_useDevice) _startPhoneSensor();
      _startForegroundTask();
    }
  }

  void _startForegroundTask() async {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SitWell กำลังทำงาน',
      notificationText: 'กำลังตรวจจับท่านั่งของคุณ',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('เลือกโหมดตรวจจับ',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _modeButton(Icons.smartphone, 'เซ็นเซอร์\nมือถือ',
                  !_useDevice, () => setState(() {
                    _useDevice = false;
                    widget.onUseDeviceChanged(false);
                    if (_isActive) _startPhoneSensor();
                  }))),
              const SizedBox(width: 12),
              Expanded(child: _modeButton(Icons.devices_other, 'อุปกรณ์\nSitWell',
                  _useDevice, () => setState(() {
                    _useDevice = true;
                    widget.onUseDeviceChanged(true);
                    _sensorSub?.cancel();
                  }))),
            ]),
            if (_useDevice) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.bleConnected
                      ? const Color(0xFF43A047).withOpacity(0.5) : Colors.white12),
                ),
                child: widget.bleConnected
                    ? Row(children: [
                        const Icon(Icons.bluetooth_connected,
                            color: Color(0xFF43A047), size: 20),
                        const SizedBox(width: 8),
                        const Text('SitWell',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Icon(Icons.check_circle,
                            color: Color(0xFF43A047), size: 18),
                      ])
                    : const Row(children: [
                        Icon(Icons.bluetooth_disabled, color: Colors.white38, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                            'ยังไม่ได้เชื่อมต่อ — กดไอคอนบลูทูธด้านบน',
                            style: TextStyle(color: Colors.white38, fontSize: 12))),
                      ]),
              ),
              if (widget.bleConnected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ค่าเซ็นเซอร์ real-time',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _sensorVal('X', _accelX),
                      _sensorVal('Y', _accelY),
                      _sensorVal('Z', _accelZ),
                      Column(children: [
                        Text('${_tiltAngle.toStringAsFixed(1)}°',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('องศา',
                            style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ]),
                    ]),
                  ]),
                ),
              ],
            ],
          ]),
        ),

        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _isActive ? _postureColor : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            SizedBox(width: 120, height: 80,
                child: CustomPaint(painter: PostureIconPainter())),
            const SizedBox(height: 16),
            Text(_postureStatus,
                style: TextStyle(color: _postureColor, fontSize: 18)),
            const SizedBox(height: 8),
            Text('ดีเลย์: ${widget.delaySeconds} วิ | องศา: ${widget.tiltThreshold.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _toggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActive
                    ? const Color(0xFFE53935) : const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: Text(_isActive ? 'หยุด' : 'เริ่มตรวจจับ',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _statCard('เวลาในเซสชัน',
              '$_sessionMinutes นาที', Icons.timer, Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('เอียงผิดท่า',
              '$_badPostureCount ครั้ง', Icons.warning_amber,
              _badPostureCount > 0 ? const Color(0xFFE53935) : Colors.white)),
        ]),
      ]),
    );
  }

  Widget _sensorVal(String label, double val) {
    return Column(children: [
      Text(val.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }

  Widget _modeButton(IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF43A047) : Colors.transparent),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? Colors.white : Colors.white54, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: valueColor, fontSize: 22,
            fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ===== STATS PAGE =====
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _tabIndex = 0;
  bool _loading = true;
  List<double> _hoursData = List.filled(24, 0);
  List<double> _badsData = List.filled(24, 0);
  int _totalMinutes = 0;
  int _totalBadPosture = 0;

  final List<String> _monthLabels = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];
  final List<String> _dayLabels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final totals = await StatsService.getTotals();
    Map<String, List<double>> data;

    if (_tabIndex == 0) {
      data = await StatsService.getTodayData();
    } else if (_tabIndex == 1) {
      data = await StatsService.getWeekData();
    } else {
      data = await StatsService.getYearData();
    }

    setState(() {
      _hoursData = data['hours']!;
      _badsData = data['bads']!;
      _totalMinutes = totals['totalMinutes']!;
      _totalBadPosture = totals['totalBadPosture']!;
      _loading = false;
    });
  }

  List<String> _getLabels() {
    if (_tabIndex == 0) {
      // รายชั่วโมง 0-23
      return List.generate(24, (i) => i % 4 == 0 ? '$i' : '');
    } else if (_tabIndex == 1) {
      return _dayLabels;
    } else {
      return _monthLabels;
    }
  }

  String _getTitle() {
    final now = DateTime.now();
    if (_tabIndex == 0) {
      return 'วันที่ ${DateFormat('d MMM yyyy', 'th').format(now)}';
    } else if (_tabIndex == 1) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return '${DateFormat('d MMM', 'th').format(monday)} - ${DateFormat('d MMM yyyy', 'th').format(sunday)}';
    } else {
      return 'ปี ${now.year + 543}';
    }
  }

  @override
  Widget build(BuildContext context) {
    String hours = ((_totalMinutes) / 60).toStringAsFixed(1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Tab selector
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: ['วัน', 'อาทิตย์', 'เดือน'].asMap().entries.map((e) {
              bool sel = _tabIndex == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _tabIndex = e.key);
                    _loadData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF2E7D32) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(e.value, textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.white54,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // แสดงช่วงเวลา
        Center(
          child: Text(_getTitle(),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),

        const SizedBox(height: 16),

        // Summary cards
        Row(children: [
          Expanded(child: _summaryCard('ชั่วโมงอ่าน', '$hours ชม.',
              Icons.menu_book, const Color(0xFF43A047))),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('เอียงผิดท่า',
              '$_totalBadPosture ครั้ง',
              Icons.warning_amber, const Color(0xFFE53935))),
        ]),

        const SizedBox(height: 16),

        if (_loading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)))
        else ...[
          _barChart(
            _tabIndex == 0 ? 'ชั่วโมงการอ่านรายชั่วโมง'
                : _tabIndex == 1 ? 'ชั่วโมงการอ่านรายวัน'
                : 'ชั่วโมงการอ่านรายเดือน',
            _hoursData, _getLabels(), const Color(0xFF43A047), true),
          const SizedBox(height: 16),
          _barChart(
            _tabIndex == 0 ? 'ครั้งที่เอียงผิดท่ารายชั่วโมง'
                : _tabIndex == 1 ? 'ครั้งที่เอียงผิดท่ารายวัน'
                : 'ครั้งที่เอียงผิดท่ารายเดือน',
            _badsData, _getLabels(), const Color(0xFFE53935), false),
        ],
      ]),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _barChart(String title, List<double> data, List<String> labels,
      Color color, bool showVal) {
    double maxVal = data.isEmpty ? 1 : data.reduce(max);
    if (maxVal == 0) maxVal = 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white,
            fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (i) {
              double ratio = data[i] / maxVal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (showVal && data[i] > 0)
                      Text(data[i].toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white54, fontSize: 8)),
                    const SizedBox(height: 2),
                    Container(
                      height: ratio > 0 ? 110 * ratio : 2,
                      decoration: BoxDecoration(
                          color: color.withOpacity(ratio > 0 ? 1 : 0.15),
                          borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(height: 4),
                    Text(i < labels.length ? labels[i] : '',
                        style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ===== SETTINGS PAGE =====
class SettingsPage extends StatefulWidget {
  final double tiltThreshold;
  final int delaySeconds;
  final bool soundAlert;
  final bool vibrationAlert;
  final bool deviceLedAlert;
  final int alertMode;
  final double goodPostureAngle;
  final double badPostureAngle;
  final double goodPostureAnglePhone;
  final double badPostureAnglePhone;
  final double currentTiltAngle;
  final bool useDevice;
  final Function(Map<String, dynamic>) onChanged;

  const SettingsPage({
    super.key,
    required this.tiltThreshold,
    required this.delaySeconds,
    required this.soundAlert,
    required this.vibrationAlert,
    required this.deviceLedAlert,
    required this.alertMode,
    required this.goodPostureAngle,
    required this.badPostureAngle,
    required this.goodPostureAnglePhone,
    required this.badPostureAnglePhone,
    required this.currentTiltAngle,
    required this.useDevice,
    required this.onChanged,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _alertMode;
  late double _tiltThreshold;
  late int _delaySeconds;
  late bool _soundAlert;
  late bool _vibrationAlert;
  late bool _deviceLedAlert;
  late double _goodPostureAngle;
  late double _badPostureAngle;
  late double _goodPostureAnglePhone;
  late double _badPostureAnglePhone;

  @override
  void initState() {
    super.initState();
    _alertMode = widget.alertMode;
    _tiltThreshold = widget.tiltThreshold;
    _delaySeconds = widget.delaySeconds;
    _soundAlert = widget.soundAlert;
    _vibrationAlert = widget.vibrationAlert;
    _deviceLedAlert = widget.deviceLedAlert;
    _goodPostureAngle = widget.goodPostureAngle;
    _badPostureAngle = widget.badPostureAngle;
    _goodPostureAnglePhone = widget.goodPostureAnglePhone;
    _badPostureAnglePhone = widget.badPostureAnglePhone;
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goodPostureAngle != widget.goodPostureAngle) {
      _goodPostureAngle = widget.goodPostureAngle;
    }
    if (oldWidget.badPostureAngle != widget.badPostureAngle) {
      _badPostureAngle = widget.badPostureAngle;
    }
    if (oldWidget.goodPostureAnglePhone != widget.goodPostureAnglePhone) {
      _goodPostureAnglePhone = widget.goodPostureAnglePhone;
    }
    if (oldWidget.badPostureAnglePhone != widget.badPostureAnglePhone) {
      _badPostureAnglePhone = widget.badPostureAnglePhone;
    }
  }

  void _save() {
    widget.onChanged({
      'tiltThreshold': _tiltThreshold,
      'delaySeconds': _delaySeconds,
      'soundAlert': _soundAlert,
      'vibrationAlert': _vibrationAlert,
      'deviceLedAlert': _deviceLedAlert,
      'alertMode': _alertMode,
      'goodPostureAngle': _goodPostureAngle,
      'badPostureAngle': _badPostureAngle,
      'goodPostureAnglePhone': _goodPostureAnglePhone,
      'badPostureAnglePhone': _badPostureAnglePhone,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('โหมดตั้งค่าการแจ้งเตือน'),
        _modeSelector(),
        const SizedBox(height: 16),
        if (_alertMode == 0) _modeACard(),
        if (_alertMode == 1) _modeBCard(),
        const SizedBox(height: 16),
        _label('ดีเลย์ก่อนแจ้งเตือน'),
        _delayCard(),
        const SizedBox(height: 16),
        _label('วิธีแจ้งเตือน'),
        _alertToggles(),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
  );

  Widget _modeSelector() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _modeTab(0, Icons.tune, 'กำหนดองศา'),
        _modeTab(1, Icons.model_training, 'บันทึกท่านั่ง'),
      ]),
    );
  }

  Widget _modeTab(int index, IconData icon, String label) {
    bool sel = _alertMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _alertMode = index); _save(); },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? Colors.white : Colors.white54),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: sel ? Colors.white : Colors.white54, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _modeACard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('องศาที่แจ้งเตือน',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          Text('${_tiltThreshold.round()}°',
              style: const TextStyle(color: Color(0xFF43A047),
                  fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: _tiltThreshold, min: 5, max: 60, divisions: 55,
          activeColor: const Color(0xFF43A047), inactiveColor: Colors.white24,
          onChanged: (v) { setState(() => _tiltThreshold = v); _save(); },
        ),
        const Text('ถ้าเอียงเกินองศานี้จะมีการแจ้งเตือน',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _modeBCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('บันทึกท่านั่ง 2 แบบ',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),

        // แสดงองศาปัจจุบัน
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.straighten, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text('องศาปัจจุบัน: ${widget.currentTiltAngle.toStringAsFixed(1)}°',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ),

        const SizedBox(height: 4),
        Text('ใช้: ${widget.useDevice ? "อุปกรณ์ SitWell" : "เซ็นเซอร์มือถือ"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),

        const SizedBox(height: 16),

        // ท่าดี
        _postureRecordTile(
          isGood: true,
          saved: widget.useDevice ? _goodPostureAngle >= 0 : _goodPostureAnglePhone >= 0,
          savedAngle: widget.useDevice ? _goodPostureAngle : _goodPostureAnglePhone,
          onSave: () {
            setState(() {
              if (widget.useDevice) {
                _goodPostureAngle = widget.currentTiltAngle;
              } else {
                _goodPostureAnglePhone = widget.currentTiltAngle;
              }
            });
            _save();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✓ บันทึกท่านั่งดีแล้ว'),
              backgroundColor: Color(0xFF43A047),
              duration: Duration(seconds: 2),
            ));
          },
        ),

        const SizedBox(height: 12),

        // ท่าไม่ดี
        _postureRecordTile(
          isGood: false,
          saved: widget.useDevice ? _badPostureAngle >= 0 : _badPostureAnglePhone >= 0,
          savedAngle: widget.useDevice ? _badPostureAngle : _badPostureAnglePhone,
          onSave: () {
            setState(() {
              if (widget.useDevice) {
                _badPostureAngle = widget.currentTiltAngle;
              } else {
                _badPostureAnglePhone = widget.currentTiltAngle;
              }
            });
            _save();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✓ บันทึกท่านั่งไม่ดีแล้ว'),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 2),
            ));
          },
        ),

        // แสดงสถานะพร้อมใช้
        if ((widget.useDevice && _goodPostureAngle >= 0 && _badPostureAngle >= 0) ||
            (!widget.useDevice && _goodPostureAnglePhone >= 0 && _badPostureAnglePhone >= 0)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF43A047).withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  'พร้อมตรวจจับแล้ว! ท่าดี: ${widget.useDevice ? _goodPostureAngle.toStringAsFixed(0) : _goodPostureAnglePhone.toStringAsFixed(0)}° | '
                  'ท่าไม่ดี: ${widget.useDevice ? _badPostureAngle.toStringAsFixed(0) : _badPostureAnglePhone.toStringAsFixed(0)}°',
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 11))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _postureRecordTile({
    required bool isGood,
    required bool saved,
    required double savedAngle,
    required VoidCallback onSave,
  }) {
    Color color = isGood ? const Color(0xFF43A047) : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saved ? color.withOpacity(0.1) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: saved ? color : Colors.white12),
      ),
      child: Row(children: [
        SizedBox(width: 40, height: 30,
            child: CustomPaint(painter: PostureIconPainter())),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isGood ? '① ท่านั่งดี (ตรง)' : '② ท่านั่งไม่ดี (เอียง)',
              style: TextStyle(color: saved ? color : Colors.white,
                  fontWeight: FontWeight.bold)),
          Text(saved
              ? '✓ บันทึกแล้ว (${savedAngle.toStringAsFixed(0)}°)'
              : (isGood ? 'นั่งตรงที่สุด แล้วกดบันทึก'
                  : 'นั่งเอียงที่สุด แล้วกดบันทึก'),
              style: TextStyle(
                  color: saved ? color.withOpacity(0.7) : Colors.white54,
                  fontSize: 12)),
        ])),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Text(saved ? 'บันทึกใหม่' : 'บันทึก',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _delayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('ดีเลย์ก่อนแจ้งเตือน',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          Text('$_delaySeconds วิ',
              style: const TextStyle(color: Color(0xFF43A047),
                  fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: _delaySeconds.toDouble(), min: 1, max: 30, divisions: 29,
          activeColor: const Color(0xFF43A047), inactiveColor: Colors.white24,
          onChanged: (v) { setState(() => _delaySeconds = v.round()); _save(); },
        ),
        const Text('ต้องเอียงนานกว่านี้ถึงจะนับและแจ้งเตือน',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _alertToggles() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _toggle(Icons.volume_up, 'เสียงแจ้งเตือน (พูดว่า "ปรับท่านั่ง")',
            _soundAlert, (v) { setState(() => _soundAlert = v); _save(); }),
        _toggle(Icons.vibration, 'การสั่น', _vibrationAlert,
            (v) { setState(() => _vibrationAlert = v); _save(); }),
        _toggle(Icons.lightbulb_outline, 'ไฟ LED ที่อุปกรณ์ SitWell',
            _deviceLedAlert,
            (v) { setState(() => _deviceLedAlert = v); _save(); }),
      ]),
    );
  }

  Widget _toggle(IconData icon, String label, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.white54),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value, onChanged: onChanged,
      activeColor: const Color(0xFF43A047),
    );
  }
}