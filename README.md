# mock_gps_detector

Android Flutter plugin for detecting developer options state and selected mock location app.

## Installation

```yaml
dependencies:
  mock_gps_detector: ^1.0.0
```

## Usage

```dart
import 'package:mock_gps_detector/mock_gps_detector.dart';

final detector = MockGpsDetector();
final status = await detector.getDeveloperOptionsStatus();
```

Returned keys:
- `developerOptionsEnabled` (`bool`)
- `selectedMockLocationApp` (`String?`)
- `hasSelectedMockLocationApp` (`bool`)

## Platform support

- Android: supported
- iOS/macOS/web/windows/linux: not supported

## Example

See `example/lib/main.dart`.
