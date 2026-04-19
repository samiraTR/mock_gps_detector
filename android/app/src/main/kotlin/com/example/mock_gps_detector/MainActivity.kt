package com.example.mock_gps_detector

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.mock_gps_detector.GpsDetectorPlugin

class MainActivity : FlutterActivity(){
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the GPS detector plugin with the engine
        flutterEngine.plugins.add(GpsDetectorPlugin())
    }
}
