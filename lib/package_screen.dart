// // import 'package:detect_fake_location/detect_fake_location.dart';
// import 'dart:io';

// import 'package:flutter/material.dart';

// import 'package:safe_device/safe_device.dart';
// // import 'package:trust_location/trust_location.dart';

// class PackageScreen extends StatefulWidget {
//   const PackageScreen({super.key});

//   @override
//   State<PackageScreen> createState() => _PackageScreenState();
// }

// class _PackageScreenState extends State<PackageScreen> {
//   bool isJailBroken = false;
//   bool isJailBrokenCustom = false;
//   bool isMockLocation = false;
//   bool isRealDevice = false;
//   bool isOnExternalStorage = false;
//   bool isSafeDevice = false;
//   bool isDevelopmentModeEnable = false;
//   Map<String, dynamic> jailbreakDetails = {};
//   Map<String, dynamic> rootDetectionDetails = {};

//   @override
//   void initState() {
//     super.initState();
//     initPlatformState();
//     // requestLocationPermission();
//     // input seconds into parameter for getting location with repeating by timer.
//     // this example set to 5 seconds.
//     // TrustLocation.start(5);
//     // getLocation();
//   }

//   Future<void> initPlatformState() async {
//     if (!mounted) return;

//     setState(() {
//       isJailBroken = false;
//       isJailBrokenCustom = false;
//       isMockLocation = false;
//       isRealDevice = false;
//       isOnExternalStorage = false;
//       isSafeDevice = false;
//       isDevelopmentModeEnable = false;
//       jailbreakDetails = {};
//       rootDetectionDetails = {};
//     });

//     isJailBroken = await SafeDevice.isJailBroken;
//     isMockLocation = await SafeDevice.isMockLocation;
//     isRealDevice = await SafeDevice.isRealDevice;
//     isOnExternalStorage = await SafeDevice.isOnExternalStorage;
//     isSafeDevice = await SafeDevice.isSafeDevice;
//     isDevelopmentModeEnable = await SafeDevice.isDevelopmentModeEnable;

//     // iOS-specific enhanced jailbreak detection
//     if (Platform.isIOS) {
//       isJailBrokenCustom = await SafeDevice.isJailBrokenCustom;
//       jailbreakDetails = await SafeDevice.jailbreakDetails;
//     }

//     // Android-specific enhanced root detection debugging
//     if (Platform.isAndroid) {
//       rootDetectionDetails = await SafeDevice.rootDetectionDetails;
//     }

//     setState(() {
//       this.isJailBroken = isJailBroken;
//       this.isJailBrokenCustom = isJailBrokenCustom;
//       this.isMockLocation = isMockLocation;
//       this.isRealDevice = isRealDevice;
//       this.isOnExternalStorage = isOnExternalStorage;
//       this.isSafeDevice = isSafeDevice;
//       this.isDevelopmentModeEnable = isDevelopmentModeEnable;
//       this.jailbreakDetails = jailbreakDetails;
//       this.rootDetectionDetails = rootDetectionDetails;
//     });
//   }

//   /// get location method, use a try/catch PlatformException.
//   // Future<void> getLocation() async {
//   //   try {
//   //     TrustLocation.onChange.listen((values) => setState(() {
//   //           _latitude = values.latitude;
//   //           _longitude = values.longitude;
//   //           _isMockLocation = values.isMockLocation;
//   //         }));
//   //   } on PlatformException catch (e) {
//   //     print('PlatformException $e');
//   //   }
//   // }

//   /// request location permission at runtime.
//   // void requestLocationPermission() async {
//   //   PermissionStatus permission =
//   //       await LocationPermissions().requestPermissions();
//   //   print('permissions: $permission');
//   // }

//   Widget buildInfoRow(String key, bool value) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Row(
//         children: <Widget>[
//           Expanded(
//             child: Text(
//               key,
//               style: const TextStyle(fontSize: 16),
//             ),
//           ),
//           Text(
//             value.toString(),
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: value ? Colors.red : Colors.green,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildJailbreakDetailsSection() {
//     if (jailbreakDetails.isEmpty) return Container();

//     return Column(
//       children: [
//         const Divider(),
//         const Text(
//           'Jailbreak Detection Details (iOS)',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 8),
//         if (jailbreakDetails.containsKey('isSimulator'))
//           Card(
//             color: jailbreakDetails['isSimulator'] == true
//                 ? Colors.blue.shade50
//                 : null,
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: buildInfoRow(
//                   'isSimulator', jailbreakDetails['isSimulator'] ?? false),
//             ),
//           ),
//         ...jailbreakDetails.entries
//             .where((entry) => entry.key != 'isSimulator')
//             .map((entry) => buildInfoRow(
//                 '${entry.key}', entry.value is bool ? entry.value : false))
//             .toList(),
//       ],
//     );
//   }

//   Widget buildRootDetectionDetailsSection() {
//     if (rootDetectionDetails.isEmpty) return Container();

//     return Column(
//       children: [
//         const Divider(),
//         const Text(
//           'Root Detection Details (Android)',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 8),
//         // Device information
//         if (rootDetectionDetails.containsKey('brand'))
//           Card(
//             color: Colors.blue.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Device Info:',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('Brand: ${rootDetectionDetails['brand']}'),
//                   Text('Model: ${rootDetectionDetails['model']}'),
//                   Text('API Level: ${rootDetectionDetails['apiLevel']}'),
//                   Text('Build Type: ${rootDetectionDetails['buildType']}'),
//                   Text('Build Tags: ${rootDetectionDetails['buildTags']}'),
//                 ],
//               ),
//             ),
//           ),
//         const SizedBox(height: 8),
//         // Detection results
//         ...rootDetectionDetails.entries
//             .where((entry) => entry.value is bool)
//             .map((entry) => buildInfoRow('${entry.key}', entry.value))
//             .toList(),
//         // System properties
//         if (rootDetectionDetails.containsKey('ro.debuggable'))
//           Card(
//             color: Colors.orange.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('System Properties:',
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text(
//                       'ro.debuggable: ${rootDetectionDetails['ro.debuggable']}'),
//                   Text('ro.secure: ${rootDetectionDetails['ro.secure']}'),
//                   Text(
//                       'service.adb.root: ${rootDetectionDetails['service.adb.root']}'),
//                   Text(
//                       'ro.build.type: ${rootDetectionDetails['ro.build.type']}'),
//                   Text(
//                       'ro.build.tags: ${rootDetectionDetails['ro.build.tags']}'),
//                 ],
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text('Device Safe Check'),
//         ),
//         body: SingleChildScrollView(
//           child: Center(
//             child: Card(
//               margin: const EdgeInsets.all(16.0),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   mainAxisSize: MainAxisSize.min,
//                   children: <Widget>[
//                     // buildInfoRow('isJailBroken()', isJailBroken),
//                     // if (Platform.isIOS) ...[
//                     //   buildInfoRow('isJailBrokenCustom()', isJailBrokenCustom),
//                     // ],
//                     const SizedBox(height: 8),
//                     buildInfoRow('isMockLocation()', isMockLocation),
//                     const SizedBox(height: 8),
//                     buildInfoRow('isRealDevice()', isRealDevice),
//                     // SizedBox(height: 8),
//                     // buildInfoRow('isOnExternalStorage()', isOnExternalStorage),
//                     const SizedBox(height: 8),
//                     buildInfoRow('isSafeDevice()', isSafeDevice),
//                     const SizedBox(height: 8),
//                     buildInfoRow(
//                         'isDevelopmentModeEnable()', isDevelopmentModeEnable),
//                     if (Platform.isIOS) buildJailbreakDetailsSection(),
//                     // if (Platform.isAndroid) buildRootDetectionDetailsSection(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
// //   void _showResult(String title, bool isFakeLocation, String mode) {
// //     showDialog(
// //       context: context,
// //       builder: (BuildContext context) {
// //         return AlertDialog(
// //           title: Text(title),
// //           content: Text(
// //               'Mode: $mode\nThe user is${isFakeLocation ? '' : ' not'} using a fake location.'),
// //           actions: <Widget>[
// //             TextButton(
// //               child: Text('OK'),
// //               onPressed: () {
// //                 Navigator.of(context).pop();
// //               },
// //             ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text('Fake Location Detection Demo'),
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Text(
// //               'Configure Detection Settings',
// //               style: Theme.of(context).textTheme.headlineSmall,
// //             ),
// //             SizedBox(height: 20),
// //             SwitchListTile(
// //               title: Text('Ignore External Accessory'),
// //               subtitle: Text(
// //                 'When enabled, external accessories (like CarPlay) won\'t trigger fake location detection',
// //               ),
// //               value: _ignoreExternalAccessory,
// //               onChanged: (bool value) {
// //                 setState(() {
// //                   _ignoreExternalAccessory = value;
// //                 });
// //               },
// //             ),
// //             SizedBox(height: 30),
// //             ElevatedButton(
// //               child: Text('Detect Fake Location'),
// //               onPressed: () async {
// //                 bool isFakeLocation = await DetectFakeLocation()
// //                     .detectFakeLocation(
// //                         ignoreExternalAccessory: _ignoreExternalAccessory);
// //                 _showResult(
// //                   'Fake Location Detection Result',
// //                   isFakeLocation,
// //                   _ignoreExternalAccessory
// //                       ? 'Ignoring External Accessory'
// //                       : 'Checking All Sources',
// //                 );
// //               },
// //             ),
// //             SizedBox(height: 20),
// //             Text(
// //               'Test Both Modes:',
// //               style: Theme.of(context).textTheme.titleMedium,
// //             ),
// //             SizedBox(height: 10),
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //               children: [
// //                 ElevatedButton(
// //                   child: Text('Standard Mode'),
// //                   onPressed: () async {
// //                     bool isFakeLocation = await DetectFakeLocation()
// //                         .detectFakeLocation(ignoreExternalAccessory: false);
// //                     _showResult(
// //                       'Standard Mode Result',
// //                       isFakeLocation,
// //                       'Checking All Sources',
// //                     );
// //                   },
// //                 ),
// //                 ElevatedButton(
// //                   child: Text('Ignore Accessory'),
// //                   onPressed: () async {
// //                     bool isFakeLocation = await DetectFakeLocation()
// //                         .detectFakeLocation(ignoreExternalAccessory: true);
// //                     _showResult(
// //                       'Ignore Accessory Mode Result',
// //                       isFakeLocation,
// //                       'Ignoring External Accessory',
// //                     );
// //                   },
// //                 ),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
