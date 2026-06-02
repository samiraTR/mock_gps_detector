import 'package:flutter/material.dart';
import 'package:mock_gps_detector/mock_gps_detector.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mock GPS Detector Example',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MockGpsDetector _detector = const MockGpsDetector();
  Map<String, dynamic>? _status;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _error = null;
    });
    try {
      final status = await _detector.getDeveloperOptionsStatus();
      setState(() {
        _status = status;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mock GPS Detector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: _scan,
              child: const Text('Check Status'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_status != null) ...[
              Text('Developer options: ${_status!['developerOptionsEnabled']}'),
              Text(
                  'Mock app: ${_status!['selectedMockLocationApp'] ?? 'none'}'),
            ],
          ],
        ),
      ),
    );
  }
}
