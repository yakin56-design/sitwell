import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
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
                width: 160, height: 160,
                child: Stack(alignment: Alignment.center, children: [
                  Transform.rotate(
                    angle: 0.3,
                    child: const Icon(Icons.accessibility_new, size: 100, color: Color(0xFFE53935)),
                  ),
                  const Positioned(
                    left: 20,
                    child: Icon(Icons.accessibility_new, size: 100, color: Color(0xFF43A047)),
                  ),
                ]),
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
                      const Center(
                        child: Text('เลื่อนเพื่อเริ่มต้น',
                            style: TextStyle(color: Colors.white60, fontSize: 16)),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MonitorPage(),
      const StatsPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(children: [
          const Icon(Icons.accessibility_new, color: Color(0xFF43A047), size: 28),
          const SizedBox(width: 8),
          const Text('SitWell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
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
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  bool _isActive = false;
  int _sessionMinutes = 0;
  int _badPostureCount = 0;
  Timer? _timer;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _toggleMonitoring() {
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _timer = Timer.periodic(const Duration(seconds: 60), (_) {
          setState(() => _sessionMinutes++);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _isActive ? const Color(0xFF43A047) : Colors.transparent, width: 2),
          ),
          child: Column(children: [
            Icon(_isActive ? Icons.accessibility_new : Icons.accessibility_new_outlined,
                size: 80, color: _isActive ? const Color(0xFF43A047) : Colors.white30),
            const SizedBox(height: 16),
            Text(_isActive ? 'กำลังตรวจจับ...' : 'กดเริ่มเพื่อเริ่มตรวจจับ',
                style: TextStyle(
                    color: _isActive ? const Color(0xFF43A047) : Colors.white54, fontSize: 18)),
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
          Expanded(child: _statCard('เวลา', '$_sessionMinutes นาที', Icons.timer)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('เอียงผิดท่า', '$_badPostureCount ครั้ง', Icons.warning_amber)),
        ]),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('หน้าสถิติ', style: TextStyle(color: Colors.white, fontSize: 24)),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('หน้าตั้งค่า', style: TextStyle(color: Colors.white, fontSize: 24)),
    );
  }
}