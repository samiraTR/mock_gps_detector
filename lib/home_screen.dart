import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mock_gps_detector/package_screen.dart';

class MockGPSDetectionResult {
  final bool isMockLocationEnabled;
  final bool hasActiveMockService;
  final bool isFromMockProvider;
  final List<String> detectedMockApps;
  final List<String> runningMockServices;
  final String riskLevel; // LOW, MEDIUM, HIGH
  final String message;

  MockGPSDetectionResult({
    required this.isMockLocationEnabled,
    required this.hasActiveMockService,
    required this.isFromMockProvider,
    required this.detectedMockApps,
    required this.runningMockServices,
    required this.riskLevel,
    required this.message,
  });

  factory MockGPSDetectionResult.fromMap(Map<dynamic, dynamic> map) {
    return MockGPSDetectionResult(
      isMockLocationEnabled: map['isMockLocationEnabled'] ?? false,
      hasActiveMockService: map['hasActiveMockService'] ?? false,
      isFromMockProvider: map['isFromMockProvider'] ?? false,
      detectedMockApps: List<String>.from(map['detectedMockApps'] ?? []),
      runningMockServices: List<String>.from(map['runningMockServices'] ?? []),
      riskLevel: map['riskLevel'] ?? 'LOW',
      message: map['message'] ?? '',
    );
  }
}

class GPSDetectorScreen extends StatefulWidget {
  const GPSDetectorScreen({super.key});

  @override
  State<GPSDetectorScreen> createState() => _GPSDetectorScreenState();
}

class _GPSDetectorScreenState extends State<GPSDetectorScreen>
    with TickerProviderStateMixin {
  // ── Method Channel ──────────────────────────────────────────────────────────
  static const _channel =
      MethodChannel('com.example.mock_gps_detector/gps_detector');

  // ── State ────────────────────────────────────────────────────────────────────
  MockGPSDetectionResult? _result;
  bool _isScanning = false;
  String _statusMessage = 'Tap SCAN to detect mock GPS services';
  bool _servicesPaused = false;

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // ── Method Channel Calls ─────────────────────────────────────────────────────

  /// Scans the device for mock GPS apps, services, and system flags
  Future<void> _scanForMockGPS() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for mock GPS services…';
      _result = null;
    });
    _scanController.forward(from: 0);

    try {
      final Map<dynamic, dynamic> raw =
          await _channel.invokeMethod('detectMockGPS');

      final result = MockGPSDetectionResult.fromMap(raw);

      setState(() {
        _result = result;
        _isScanning = false;
        _statusMessage = result.hasActiveMockService
            ? '⚠️Active mock GPS service detected!'
            : '✅ No mock GPS detected';
      });
      //   _statusMessage = result.hasActiveMockService
      //       ? '⚠️ Active mock GPS service detected!'
      //       : result.isMockLocationEnabled
      //           ? '⚠️ Mock location setting is ON'
      //           : '✅ No mock GPS detected';
      // });
    } on PlatformException catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Error: ${e.message}';
      });
      _showSnackbar('Platform error: ${e.message}', isError: true);
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Unexpected error occurred';
      });
    }
  }

  /// Pauses / resumes all detected mock GPS background services
  Future<void> _toggleMockServices() async {
    if (_result == null || _result!.runningMockServices.isEmpty) return;

    try {
      final bool success = await _channel.invokeMethod(
        _servicesPaused ? 'resumeMockServices' : 'pauseMockServices',
        {'services': _result!.runningMockServices},
      );

      if (success) {
        setState(() => _servicesPaused = !_servicesPaused);
        _showSnackbar(
          _servicesPaused
              ? 'Mock services paused successfully'
              : 'Mock services resumed',
          isError: false,
        );
      }
    } on PlatformException catch (e) {
      _showSnackbar('Failed: ${e.message}', isError: true);
    }
  }

  /// Opens the specific mock GPS app so the user can stop it manually
  Future<void> _openMockApp(String packageName) async {
    try {
      await _channel.invokeMethod('openApp', {'packageName': packageName});
    } on PlatformException catch (e) {
      _showSnackbar('Cannot open app: ${e.message}', isError: true);
    }
  }

  /// Opens Android Developer Options → Mock Location setting
  Future<void> _openDeveloperOptions() async {
    try {
      await _channel.invokeMethod('openDeveloperOptions');
    } on PlatformException catch (e) {
      _showSnackbar('Cannot open settings: ${e.message}', isError: true);
    }
  }

  /// Force-stops a specific mock service by its class name
  Future<void> _stopService(String serviceClass) async {
    try {
      final bool stopped = await _channel.invokeMethod(
        'stopMockService',
        {'serviceClass': serviceClass},
      );
      if (stopped) {
        _showSnackbar('Service stopped', isError: false);
        await _scanForMockGPS(); // re-scan
      } else {
        _showSnackbar('Could not stop service — try manually', isError: true);
      }
    } on PlatformException catch (e) {
      _showSnackbar('Error: ${e.message}', isError: true);
    }
  }

  void _showSnackbar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
        backgroundColor:
            isError ? const Color(0xFFFF4444) : const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildRadarWidget(),
                    const SizedBox(height: 24),
                    _buildStatusCard(),
                    if (_result != null) ...[
                      const SizedBox(height: 16),
                      _buildResultCards(),
                      if (_result!.hasActiveMockService ||
                          _result!.runningMockServices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildServiceControlPanel(),
                      ],
                      if (_result!.detectedMockApps.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetectedAppsList(),
                      ],
                      if (_result!.runningMockServices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildRunningServicesList(),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _buildScanButton(),
                    _buildNavButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PackageScreen()),
        );
      },
      child: const Text('Go to Package Screen'),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2A3A), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF00FF88).withOpacity(0.4), width: 1),
            ),
            child:
                const Icon(Icons.gps_fixed, color: Color(0xFF00FF88), size: 18),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GPS SPOOF DETECTOR',
                  style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'monospace')),
              Text('Mock Location Scanner v1.0',
                  style: TextStyle(
                      color: Color(0xFF4A6080),
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadarWidget() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0D1420),
            border: Border.all(
              color: (_result?.hasActiveMockService ?? false)
                  ? const Color(0xFFFF4444).withOpacity(0.6)
                  : const Color(0xFF00FF88).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_result?.hasActiveMockService ?? false)
                    ? const Color(0xFFFF4444)
                        .withOpacity(0.2 * _pulseAnimation.value)
                    : const Color(0xFF00FF88)
                        .withOpacity(0.15 * _pulseAnimation.value),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric rings
              for (final size in [120.0, 90.0, 60.0])
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1E3050).withOpacity(0.8),
                      width: 1,
                    ),
                  ),
                ),
              if (_isScanning)
                RotationTransition(
                  turns: _scanController,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          const Color(0xFF00FF88).withOpacity(0),
                          const Color(0xFF00FF88).withOpacity(0.6),
                          const Color(0xFF00FF88).withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              Icon(
                _result?.hasActiveMockService ?? false
                    ? Icons.warning_rounded
                    : Icons.gps_fixed,
                color: _result?.hasActiveMockService ?? false
                    ? const Color(0xFFFF4444)
                    : const Color(0xFF00FF88),
                size: 32,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1420),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A), width: 1),
      ),
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _result?.hasActiveMockService ?? false
              ? const Color(0xFFFF4444)
              : _result?.isMockLocationEnabled ?? false
                  ? const Color(0xFFFFAA00)
                  : const Color(0xFF00FF88),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _infoTile(
                    'Mock Provider', r.isFromMockProvider, Icons.location_off)),
            const SizedBox(width: 10),
            Expanded(
                child: _infoTile(
                    'Setting ON', r.isMockLocationEnabled, Icons.settings)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _infoTile('Active Service', r.hasActiveMockService,
                    Icons.miscellaneous_services)),
            const SizedBox(width: 10),
            Expanded(child: _riskTile(r.riskLevel)),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(String label, bool isAlert, IconData icon) {
    final color = isAlert ? const Color(0xFFFF4444) : const Color(0xFF00FF88);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF4A6080),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  letterSpacing: 1)),
          Text(isAlert ? 'DETECTED' : 'CLEAR',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _riskTile(String level) {
    final color = level == 'HIGH'
        ? const Color(0xFFFF4444)
        : level == 'MEDIUM'
            ? const Color(0xFFFFAA00)
            : const Color(0xFF00FF88);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color, size: 18),
          const SizedBox(height: 8),
          const Text('RISK LEVEL',
              style: TextStyle(
                  color: Color(0xFF4A6080),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  letterSpacing: 1)),
          Text(level,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildServiceControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF4444), size: 16),
              SizedBox(width: 8),
              Text('ACTIVE MOCK SERVICE DETECTED',
                  style: TextStyle(
                      color: Color(0xFFFF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'A mock GPS background service is currently running.\nStop it to prevent fake location injection.',
            style: TextStyle(
                color: Color(0xFF8A9AB0),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: _servicesPaused ? 'RESUME' : 'PAUSE SERVICE',
                  icon:
                      _servicesPaused ? Icons.play_arrow : Icons.pause_rounded,
                  color: const Color(0xFFFFAA00),
                  onTap: _toggleMockServices,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: 'DEV OPTIONS',
                  icon: Icons.developer_mode,
                  color: const Color(0xFF4488FF),
                  onTap: _openDeveloperOptions,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedAppsList() {
    return _listSection(
      title: 'DETECTED MOCK APPS',
      icon: Icons.apps,
      color: const Color(0xFFFFAA00),
      items: _result!.detectedMockApps,
      itemBuilder: (pkg) => Row(
        children: [
          const Icon(Icons.android, color: Color(0xFFFFAA00), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pkg,
                style: const TextStyle(
                    color: Color(0xFFCCDDEE),
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ),
          GestureDetector(
            onTap: () => _openMockApp(pkg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAA00).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: const Color(0xFFFFAA00).withOpacity(0.4)),
              ),
              child: const Text('OPEN',
                  style: TextStyle(
                      color: Color(0xFFFFAA00),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningServicesList() {
    return _listSection(
      title: 'RUNNING MOCK SERVICES',
      icon: Icons.miscellaneous_services,
      color: const Color(0xFFFF4444),
      items: _result!.runningMockServices,
      itemBuilder: (svc) => Row(
        children: [
          const Icon(Icons.settings_applications,
              color: Color(0xFFFF4444), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              svc.split('.').last,
              style: const TextStyle(
                  color: Color(0xFFCCDDEE),
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          GestureDetector(
            onTap: () => _stopService(svc),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: const Color(0xFFFF4444).withOpacity(0.4)),
              ),
              child: const Text('STOP',
                  style: TextStyle(
                      color: Color(0xFFFF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection<T>({
    required String title,
    required IconData icon,
    required Color color,
    required List<T> items,
    required Widget Function(T) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1420),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${items.length}',
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E2A3A), height: 1),
          ...items.map((item) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: itemBuilder(item),
              )),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return GestureDetector(
      onTap: _isScanning ? null : _scanForMockGPS,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _isScanning
              ? const Color(0xFF00FF88).withOpacity(0.05)
              : const Color(0xFF00FF88).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isScanning
                ? const Color(0xFF00FF88).withOpacity(0.2)
                : const Color(0xFF00FF88).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF00FF88),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              const Text('SCANNING…',
                  style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2)),
            ] else ...[
              const Icon(Icons.radar, color: Color(0xFF00FF88), size: 20),
              const SizedBox(width: 10),
              const Text('SCAN FOR MOCK GPS',
                  style: TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2)),
            ],
          ],
        ),
      ),
    );
  }
}
