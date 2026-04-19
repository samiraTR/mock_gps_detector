# Mock GPS Detector

A Flutter application that detects mock GPS services and apps on Android devices.

## Features

- Detects installed mock GPS applications
- Identifies running mock GPS services
- Checks Android developer settings for mock location permission
- Verifies if current location is from a mock provider
- Provides risk assessment (Low, Medium, High)
- Allows pausing/resuming detected mock services
- Can open mock GPS apps for manual control

## Getting Started

1. Ensure you have Flutter installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app on a connected device

## Permissions

The app requires the following Android permissions:
- `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` for location access
- `QUERY_ALL_PACKAGES` for checking installed applications (Android 11+)

## Platform Support

Currently supports Android only. iOS support is not implemented.

## Contributing

Feel free to submit issues and pull requests.
