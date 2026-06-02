import 'package:flutter_test/flutter_test.dart';
import 'package:mock_gps_detector/mock_gps_detector.dart';

void main() {
  test('constructs detector', () {
    const detector = MockGpsDetector();
    expect(detector, isA<MockGpsDetector>());
  });
}
