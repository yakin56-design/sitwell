import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    final greenPaint = Paint()
      ..color = const Color(0xFF43A047)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final redPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double s = size.width / 160;
    double gx = 50 * s, gy = 15 * s;
    canvas.drawCircle(Offset(gx, gy + 10 * s), 9 * s,
        Paint()..color = const Color(0xFF43A047)..style = PaintingStyle.fill);
    canvas.drawLine(Offset(gx, gy + 19 * s), Offset(gx, gy + 55 * s), greenPaint);
    canvas.drawLine(Offset(gx - 18 * s, gy + 55 * s), Offset(gx + 18 * s, gy + 55 * s), greenPaint);
    canvas.drawLine(Offset(gx - 10 * s, gy + 55 * s), Offset(gx - 10 * s, gy + 80 * s), greenPaint);
    canvas.drawLine(Offset(gx + 10 * s, gy + 55 * s), Offset(gx + 10 * s, gy + 80 * s), greenPaint);
    canvas.drawLine(Offset(gx, gy + 30 * s), Offset(gx - 18 * s, gy + 48 * s), greenPaint);
    canvas.drawLine(Offset(gx, gy + 30 * s), Offset(gx + 18 * s, gy + 48 * s), greenPaint);

    double rx = 105 * s, ry = 15 * s;
    canvas.drawCircle(Offset(rx + 14 * s, ry + 18 * s), 9 * s,
        Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill);
    canvas.drawLine(Offset(rx, ry + 19 * s), Offset(rx + 14 * s, ry + 55 * s), redPaint);
    canvas.drawLine(Offset(rx - 12 * s, ry + 58 * s), Offset(rx + 22 * s, ry + 58 * s), redPaint);
    canvas.drawLine(Offset(rx - 4 * s, ry + 58 * s), Offset(rx - 4 * s, ry + 80 * s), redPaint);
    canvas.drawLine(Offset(rx + 14 * s, ry + 58 * s), Offset(rx + 14 * s, ry + 80 * s), redPaint);
    canvas.drawLine(Offset(rx + 6 * s, ry + 30 * s), Offset(rx + 30 * s, ry + 38 * s), redPaint);
    canvas.drawLine(Offset(rx + 6 * s, ry + 30 * s), Offset(rx + 12 * s, ry + 52 * s), redPaint);
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              SizedBox(
                width: 160, height: 110,
                child: CustomPaint(painter: PostureIconPainter()),
              ),
              const SizedBox(height: 40),
              const Text(
                'Improve Your\nPosture Every Day',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
              ),
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
                      Center(
                        child: Text(
                          _slideValue > 0.3 ? 'เลื่อนต่อไป →' : 'เลื่อนเพื่อเริ่มต้น →',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                        ),
                      ),
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
            ],
          ),
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

  Future<List<DiscoveredDevice>> scanForDevices() async {
    List<DiscoveredDevice> found = [];
    _scanSub?.cancel();
    _scanSub = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name.contains('SitWell') &&
          !found.any((d) => d.id == device.id)) {
        found.add(device);
      }
    });
    await Future.delayed(const Duration(seconds: 5));
    _scanSub?.cancel();
    return found;
  }

  Future<bool> connect(DiscoveredDevice device) async {
    final completer = Completer<bool>();
    _connectSub?.cancel();
    _connectSub = _ble.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((state) async {
      if (state.connectionState == DeviceConnectionState.connected) {
        _deviceId = device.id;
        final notifyChar = QualifiedCharacteristic(
          serviceId: Uuid.parse(_serviceUuid),
          characteristicId: Uuid.parse(_notifyUuid),
          deviceId: device.id,
        );
        _notifySub?.cancel();
        _notifySub = _ble.subscribeToCharacteristic(notifyChar).listen((data) {
          _dataController.add(String.fromCharCodes(data));
        });
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
    final writeChar = QualifiedCharacteristic(
      serviceId: Uuid.parse(_serviceUuid),
      characteristicId: Uuid.parse(_writeUuid),
      deviceId: _deviceId!,
    );
    await _ble.writeCharacteristicWithResponse(writeChar, value: [49]);
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connectSub?.cancel();
    _scanSub?.cancel();
    _deviceId = null;
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
  int _batteryLevel = 0;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      MonitorPage(ble: _ble, bleConnected: _bleConnected, batteryLevel: _batteryLevel),
      const StatsPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(children: [
          SizedBox(width: 36, height: 26,
              child: CustomPaint(painter: PostureIconPainter())),
          const SizedBox(width: 8),
          const Text('SitWell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          GestureDetector(
            onTap: () => _showBleSheet(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Icon(Icons.bluetooth,
                    color: _bleConnected ? const Color(0xFF43A047) : Colors.white38, size: 24),
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
      body: pages[_currentIndex],
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
  const BleConnectSheet({super.key, required this.ble, required this.onConnected, required this.onDisconnected});
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
        _status = results.isEmpty ? 'ไม่พบอุปกรณ์ SitWell — ตรวจสอบว่าเปิดอุปกรณ์แล้ว' : 'พบ ${results.length} อุปกรณ์';
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
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('เชื่อมต่ออุปกรณ์ SitWell',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, color: Colors.white),
            label: Text(_scanning ? 'กำลังสแกน...' : 'สแกนหาอุปกรณ์',
                style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 12),
          ..._results.map((r) => ListTile(
            leading: const Icon(Icons.devices_other, color: Color(0xFF43A047)),
            title: Text(r.name.isEmpty ? 'SitWell' : r.name,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text('สัญญาณ: ${r.rssi} dBm',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: () => _connect(r),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047),
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
  final int batteryLevel;
  const MonitorPage({super.key, required this.ble, required this.bleConnected, required this.batteryLevel});
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  bool _isActive = false;
  bool _useDevice = false;
  int _sessionMinutes = 0;
  int _badPostureCount = 0;
  Timer? _timer;
  StreamSubscription? _dataSub;
  StreamSubscription? _sensorSub;

  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _tiltAngle = 0;
  String _postureStatus = 'กดเริ่มเพื่อเริ่มตรวจจับ';
  Color _postureColor = Colors.white54;
  double _tiltThreshold = 30.0;

  @override
  void initState() {
    super.initState();
    _dataSub = widget.ble.dataStream.listen(_onBleData);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dataSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }

  void _onBleData(String raw) {
    try {
      final parts = raw.split(',');
      double x = double.parse(parts[0].split(':')[1]);
      double y = double.parse(parts[1].split(':')[1]);
      double z = double.parse(parts[2].split(':')[1]);
      double tilt = (asin(x.clamp(-1.0, 1.0)) * 180 / pi).abs();
      if (!mounted) return;
      setState(() {
        _accelX = x; _accelY = y; _accelZ = z; _tiltAngle = tilt;
        _checkPosture(tilt);
      });
    } catch (_) {}
  }

  void _checkPosture(double tilt) {
    if (!_isActive) return;
    if (tilt > _tiltThreshold) {
      _postureStatus = 'เอียงผิดท่า!';
      _postureColor = const Color(0xFFE53935);
      _badPostureCount++;
      widget.ble.sendAlert();
      HapticFeedback.vibrate();
    } else {
      _postureStatus = 'ท่านั่งดี ✓';
      _postureColor = const Color(0xFF43A047);
    }
  }

  void _startPhoneSensor() {
    _sensorSub?.cancel();
    _sensorSub = accelerometerEventStream().listen((event) {
      double tilt = (asin((event.x / 9.8).clamp(-1.0, 1.0)) * 180 / pi).abs();
      if (!mounted) return;
      setState(() {
        _accelX = event.x / 9.8;
        _accelY = event.y / 9.8;
        _accelZ = event.z / 9.8;
        _tiltAngle = tilt;
        _checkPosture(tilt);
      });
    });
  }

  void _toggleMonitoring() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _postureStatus = 'กำลังตรวจจับ...';
        _postureColor = const Color(0xFF43A047);
        _sessionMinutes = 0;
        _badPostureCount = 0;
        _timer = Timer.periodic(const Duration(seconds: 60), (_) {
          setState(() => _sessionMinutes++);
        });
        if (!_useDevice) _startPhoneSensor();
        _startForegroundTask();
      } else {
        _postureStatus = 'หยุดตรวจจับแล้ว';
        _postureColor = Colors.white54;
        _timer?.cancel();
        _sensorSub?.cancel();
        FlutterForegroundTask.stopService();
      }
    });
  }

  void _startForegroundTask() async {
    
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SitWell กำลังทำงาน',
      notificationText: 'กำลังตรวจจับท่านั่งของคุณ',
    );
  }

  IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 70) return Icons.battery_6_bar;
    if (level >= 50) return Icons.battery_4_bar;
    if (level >= 30) return Icons.battery_3_bar;
    if (level >= 15) return Icons.battery_1_bar;
    return Icons.battery_alert;
  }

  Color _batteryColor(int level) {
    if (level >= 50) return const Color(0xFF43A047);
    if (level >= 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('เลือกโหมดตรวจจับ',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _modeButton(Icons.smartphone, 'เซ็นเซอร์\nมือถือ', !_useDevice,
                  () => setState(() { _useDevice = false; if (_isActive) _startPhoneSensor(); }))),
              const SizedBox(width: 12),
              Expanded(child: _modeButton(Icons.devices_other, 'อุปกรณ์\nSitWell', _useDevice,
                  () => setState(() { _useDevice = true; _sensorSub?.cancel(); }))),
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
                        const Icon(Icons.bluetooth_connected, color: Color(0xFF43A047), size: 20),
                        const SizedBox(width: 8),
                        const Text('SitWell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(_batteryIcon(widget.batteryLevel),
                            color: _batteryColor(widget.batteryLevel), size: 20),
                        const SizedBox(width: 4),
                        Text('${widget.batteryLevel}%',
                            style: TextStyle(color: _batteryColor(widget.batteryLevel), fontWeight: FontWeight.bold)),
                      ])
                    : const Row(children: [
                        Icon(Icons.bluetooth_disabled, color: Colors.white38, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('ยังไม่ได้เชื่อมต่อ — กดไอคอนบลูทูธด้านบน',
                            style: TextStyle(color: Colors.white38, fontSize: 12))),
                      ]),
              ),
              if (widget.bleConnected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12)),
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
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('องศา', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
            border: Border.all(color: _isActive ? _postureColor : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            SizedBox(width: 100, height: 70,
                child: CustomPaint(painter: PostureIconPainter())),
            const SizedBox(height: 16),
            Text(_postureStatus, style: TextStyle(color: _postureColor, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _toggleMonitoring,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isActive ? const Color(0xFFE53935) : const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: Text(_isActive ? 'หยุด' : 'เริ่มตรวจจับ',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _statCard('เวลาในเซสชัน', '$_sessionMinutes นาที', Icons.timer, Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('เอียงผิดท่า', '$_badPostureCount ครั้ง', Icons.warning_amber,
              _badPostureCount > 0 ? const Color(0xFFE53935) : Colors.white)),
        ]),
      ]),
    );
  }

  Widget _sensorVal(String label, double val) {
    return Column(children: [
      Text(val.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.bold)),
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
  final List<double> _dayData = [0, 0, 0, 0, 0, 0, 0];
  final List<int> _badData = [0, 0, 0, 0, 0, 0, 0];
  final List<String> _labels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: ['วัน', 'อาทิตย์', 'เดือน'].asMap().entries.map((e) {
              bool sel = _tabIndex == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tabIndex = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF2E7D32) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(e.value, textAlign: TextAlign.center,
                        style: TextStyle(color: sel ? Colors.white : Colors.white54,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _summaryCard('ชั่วโมงอ่าน', '0 ชม.', Icons.menu_book, const Color(0xFF43A047))),
          const SizedBox(width: 12),
          Expanded(child: _summaryCard('เอียงผิดท่า', '0 ครั้ง', Icons.warning_amber, const Color(0xFFE53935))),
        ]),
        const SizedBox(height: 16),
        _barChart('ชั่วโมงการอ่านหนังสือ', _dayData, _labels, const Color(0xFF43A047), true),
        const SizedBox(height: 16),
        _barChart('จำนวนครั้งที่นั่งเอียงผิดท่า',
            _badData.map((e) => e.toDouble()).toList(), _labels, const Color(0xFFE53935), false),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _barChart(String title, List<double> data, List<String> labels, Color color, bool showVal) {
    double maxVal = data.reduce(max);
    if (maxVal == 0) maxVal = 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(data.length, (i) {
              double ratio = data[i] / maxVal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (showVal) Text(data[i].toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 4),
                    Container(height: ratio > 0 ? 110 * ratio : 2,
                        decoration: BoxDecoration(color: color.withOpacity(ratio > 0 ? 1 : 0.2),
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Text(labels[i], style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _alertMode = 0;
  double _tiltThreshold = 30.0;
  bool _goodPostureSaved = false;
  bool _badPostureSaved = false;
  final _delayCtrl = TextEditingController(text: '5');
  final _maxReadCtrl = TextEditingController(text: '60');
  bool _soundAlert = true;
  bool _vibrationAlert = true;
  bool _deviceLedAlert = true;

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
        _label('ดีเลย์การแจ้งเตือน'),
        _inputCard(Icons.hourglass_bottom, 'ดีเลย์ก่อนแจ้งเตือน (วินาที)', _delayCtrl, 'วิ'),
        const SizedBox(height: 16),
        _label('จำกัดเวลาอ่านต่อครั้ง'),
        _inputCard(Icons.timer_off, 'เวลาอ่านสูงสุดต่อครั้ง (นาที)', _maxReadCtrl, 'นาที'),
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
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
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
        onTap: () => setState(() => _alertMode = index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? Colors.white : Colors.white54),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _modeACard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('องศาที่แจ้งเตือน', style: TextStyle(color: Colors.white, fontSize: 16)),
          Text('${_tiltThreshold.round()}°',
              style: const TextStyle(color: Color(0xFF43A047), fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: _tiltThreshold, min: 5, max: 60, divisions: 55,
          activeColor: const Color(0xFF43A047), inactiveColor: Colors.white24,
          onChanged: (v) => setState(() => _tiltThreshold = v),
        ),
        const Text('ถ้าเอียงเกินองศานี้จะมีการแจ้งเตือน',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _modeBCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('บันทึกท่านั่ง 2 แบบเพื่อเปรียบเทียบ',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('ระบบจะแจ้งเตือนเมื่อเอียงเกินท่าที่ 2',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 16),
        _postureRecordTile(true),
        const SizedBox(height: 12),
        _postureRecordTile(false),
        if (_goodPostureSaved && _badPostureSaved) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF43A047).withOpacity(0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF43A047), size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('พร้อมตรวจจับแล้ว!',
                  style: TextStyle(color: Color(0xFF81C784), fontSize: 12))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _postureRecordTile(bool isGood) {
    bool saved = isGood ? _goodPostureSaved : _badPostureSaved;
    Color color = isGood ? const Color(0xFF43A047) : const Color(0xFFE53935);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: saved ? color.withOpacity(0.1) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: saved ? color : Colors.white12),
      ),
      child: Row(children: [
        isGood
            ? Icon(Icons.accessibility_new, color: saved ? color : Colors.white38, size: 32)
            : Transform.rotate(angle: 0.3,
                child: Icon(Icons.accessibility_new, color: saved ? color : Colors.white38, size: 32)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isGood ? '① ท่านั่งดี (ตรง)' : '② ท่านั่งไม่ดี (เอียง)',
              style: TextStyle(color: saved ? color : Colors.white, fontWeight: FontWeight.bold)),
          Text(saved ? '✓ บันทึกแล้ว' : (isGood ? 'นั่งตรงที่สุด แล้วกดบันทึก' : 'นั่งเอียงที่สุด แล้วกดบันทึก'),
              style: TextStyle(color: saved ? color.withOpacity(0.7) : Colors.white54, fontSize: 12)),
        ])),
        ElevatedButton(
          onPressed: () {
            setState(() => isGood ? _goodPostureSaved = true : _badPostureSaved = true);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isGood ? '✓ บันทึกท่านั่งดีแล้ว' : '✓ บันทึกท่านั่งไม่ดีแล้ว'),
              backgroundColor: color, duration: const Duration(seconds: 2),
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Text(saved ? 'บันทึกใหม่' : 'บันทึก',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _inputCard(IconData icon, String label, TextEditingController ctrl, String suffix) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
        SizedBox(
          width: 90,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              filled: true, fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              suffix: Text(suffix, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _alertToggles() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _toggle(Icons.volume_up, 'เสียงแจ้งเตือน', _soundAlert, (v) => setState(() => _soundAlert = v)),
        _toggle(Icons.vibration, 'การสั่น', _vibrationAlert, (v) => setState(() => _vibrationAlert = v)),
        _toggle(Icons.lightbulb_outline, 'ไฟ LED ที่อุปกรณ์ SitWell', _deviceLedAlert,
            (v) => setState(() => _deviceLedAlert = v)),
      ]),
    );
  }

  Widget _toggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.white54),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value, onChanged: onChanged,
      activeColor: const Color(0xFF43A047),
    );
  }
}