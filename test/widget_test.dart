// This is a basic Flutter widget test for the Mock GPS Detector app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter_test/flutter_test.dart';

import 'package:mock_gps_detector/main.dart';

void main() {
  testWidgets('App starts and shows GPS detector screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the GPS detector screen is shown
    expect(find.text('GPS SPOOF DETECTOR'), findsOneWidget);
    expect(find.text('Tap SCAN to detect mock GPS services'), findsOneWidget);
  });
}
