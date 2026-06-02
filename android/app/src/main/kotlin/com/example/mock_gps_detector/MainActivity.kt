package com.example.mock_gps_detector


import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(){

     private val CHANNEL = "com.example.mock_gps_detector/gps_detector"

    private val SYSTEM_DEFAULT_MOCK_APPS = setOf(
        "com.android.shell", "null", "none", "", "0"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine) 

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getDeveloperOptionsStatus" -> {
                        val isDevMode = isDeveloperOptionsEnabled()
                        val mockApp = getSelectedMockLocationApp()
                        result.success(
                            mapOf(
                                "developerOptionsEnabled" to isDevMode,
                                "selectedMockLocationApp" to mockApp,
                                "hasSelectedMockLocationApp" to (mockApp != null)
                            )
                        )
                    }

                    "isDeveloperOptionsEnabled" -> {
                        result.success(isDeveloperOptionsEnabled())
                    }

                    "getSelectedMockLocationApp" -> {
                        result.success(getSelectedMockLocationApp())
                    }

                    "isMockLocationAppSelected" -> {
                        result.success(getSelectedMockLocationApp() != null)
                    }

                    "openDeveloperOptions" -> {
                        openDeveloperOptions()
                        result.success(null)
                    }

                    "diagnoseMockApps" -> {
                        try {
                            val pm = packageManager
                            val flags = PackageManager.GET_PERMISSIONS
                            val packages = if (android.os.Build.VERSION.SDK_INT >= 33) {
                                pm.getInstalledPackages(
                                    PackageManager.PackageInfoFlags.of(flags.toLong())
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                pm.getInstalledPackages(flags)
                            }

                            val mockApps = mutableListOf<Map<String, Any?>>()
                            for (packageInfo in packages) {
                                val hasMockPermission = packageInfo.requestedPermissions
                                    ?.contains("android.permission.ACCESS_MOCK_LOCATION") == true
                                if (hasMockPermission) {
                                    mockApps.add(
                                        mapOf(
                                            "package" to packageInfo.packageName,
                                            "permissionsFlags" to
                                                packageInfo.requestedPermissionsFlags?.toList()
                                        )
                                    )
                                }
                            }

                            result.success(
                                mapOf(
                                    "total_packages_scanned" to packages.size,
                                    "mock_apps_found" to mockApps,
                                    "manufacturer" to android.os.Build.MANUFACTURER,
                                    "sdk" to android.os.Build.VERSION.SDK_INT
                                )
                            )
                        } catch (e: Exception) {
                            result.success(mapOf("error" to e.message))
                        }
                    }

                    "diagnoseMockLocation" -> {
                        try {
                            val secureKeys = listOf(
                                "mock_location_app",
                                "allowed_mock_location_app",
                                "mock_location",
                                "allow_mock_location",
                                "selected_mock_location_app",
                                "mock_gps_apps",
                                "fake_location_app",
                                "mock_location_package",
                                "enabled_mock_location_app",
                                "oppo_mock_location_app",
                                "mock_location_provider_app"
                            )
                            val results = mutableMapOf<String, String?>()
                            for (key in secureKeys) {
                                results["secure:$key"] = try {
                                    Settings.Secure.getString(contentResolver, key)
                                } catch (e: Exception) {
                                    "ERROR: ${e.message}"
                                }
                            }
                            results["manufacturer"] = android.os.Build.MANUFACTURER
                            results["android_sdk"] = android.os.Build.VERSION.SDK_INT.toString()
                            result.success(results)
                        } catch (e: Exception) {
                            result.success(mapOf("error" to e.message))
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isDeveloperOptionsEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) == 1
        } catch (e: Exception) {
            false
        }
    }

    private fun getSelectedMockLocationApp(): String? {
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        val sdkInt = android.os.Build.VERSION.SDK_INT

        return try {
            // ── 1. Standard Android 6+ ──
            val modernApp = Settings.Secure.getString(contentResolver, "mock_location_app")
            if (!isInvalidMockApp(modernApp)) return modernApp

            // ── 2. Xiaomi / Redmi ──
            if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
                val a = Settings.Secure.getString(contentResolver, "mock_location_package")
                if (!isInvalidMockApp(a)) return a
                val b = Settings.Secure.getString(contentResolver, "enabled_mock_location_app")
                if (!isInvalidMockApp(b)) return b
            }

            // ── 3. Oppo / Realme / OnePlus ──
            if (manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus")
            ) {
                val a = Settings.Secure.getString(contentResolver, "oppo_mock_location_app")
                if (!isInvalidMockApp(a)) return a
                val b = Settings.Secure.getString(contentResolver, "mock_location_provider_app")
                if (!isInvalidMockApp(b)) return b
            }

            // ── 4. Vivo / Legacy fallback: integer flag ──
            if (manufacturer.contains("vivo")) {
                val flag = Settings.Secure.getInt(contentResolver, "mock_location", 0)
                if (flag == 1) return "mock_location_enabled"
            }

            // ── 5. Legacy Android < 6 ──
            if (sdkInt < 23) {
                val flag = Settings.Secure.getInt(contentResolver, "allow_mock_location", 0)
                if (flag == 1) return "mock_location_enabled"
            }

            // ── 6. Generic key fallback ──
            val fallbackKeys = listOf(
                "allowed_mock_location_app",
                "mock_location_provider_app",
                "mock_location_package",
                "selected_mock_location_app"
            )
            for (key in fallbackKeys) {
                val value = try {
                    Settings.Secure.getString(contentResolver, key)
                } catch (e: Exception) { null }
                if (!isInvalidMockApp(value)) return value
            }

            // ── 7. Last resort: permission scan ──
            getAppWithMockLocationPermission()

        } catch (e: Exception) {
            null
        }
    }

    private fun getAppWithMockLocationPermission(): String? {
        return try {
            val pm = packageManager
            val flags = PackageManager.GET_PERMISSIONS
            val packages = if (android.os.Build.VERSION.SDK_INT >= 33) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(flags)
            }

            val systemPrefixes = listOf(
                "com.android", "com.google", "android",
                "com.samsung.android", "com.miui", "com.vivo",
                "com.oppo", "com.realme", "com.oneplus"
            )

            packages.firstOrNull { info ->
                val isNotSystem = systemPrefixes.none { info.packageName.startsWith(it) }
                val hasMock = info.requestedPermissions
                    ?.contains("android.permission.ACCESS_MOCK_LOCATION") == true
                isNotSystem && hasMock
            }?.packageName
        } catch (e: Exception) {
            null
        }
    }

    private fun isInvalidMockApp(app: String?): Boolean {
        if (app == null) return true
        return app.trim().lowercase() in SYSTEM_DEFAULT_MOCK_APPS
    }

    private fun openDeveloperOptions() {
        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            )
        } catch (e: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            } catch (e2: Exception) { /* ignore */ }
        }
    }
    
}
