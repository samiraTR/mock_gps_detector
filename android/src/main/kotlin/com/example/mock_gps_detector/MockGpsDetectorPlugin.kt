package com.example.mock_gps_detector

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MockGpsDetectorPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private val systemDefaultMockApps = setOf(
        "com.android.shell", "null", "none", "", "0"
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "com.example.mock_gps_detector/gps_detector"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
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

            "isDeveloperOptionsEnabled" -> result.success(isDeveloperOptionsEnabled())
            "getSelectedMockLocationApp" -> result.success(getSelectedMockLocationApp())
            "isMockLocationAppSelected" -> result.success(getSelectedMockLocationApp() != null)
            "openDeveloperOptions" -> {
                openDeveloperOptions()
                result.success(null)
            }

            "diagnoseMockApps" -> result.success(diagnoseMockApps())
            "diagnoseMockLocation" -> result.success(diagnoseMockLocation())
            else -> result.notImplemented()
        }
    }

    private fun isDeveloperOptionsEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0
            ) == 1
        } catch (_: Exception) {
            false
        }
    }

    private fun getSelectedMockLocationApp(): String? {
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        val sdkInt = android.os.Build.VERSION.SDK_INT

        return try {
            val modernApp = Settings.Secure.getString(context.contentResolver, "mock_location_app")
            if (!isInvalidMockApp(modernApp)) return modernApp

            if (manufacturer.contains("xiaomi") || manufacturer.contains("redmi")) {
                val a = Settings.Secure.getString(context.contentResolver, "mock_location_package")
                if (!isInvalidMockApp(a)) return a
                val b = Settings.Secure.getString(context.contentResolver, "enabled_mock_location_app")
                if (!isInvalidMockApp(b)) return b
            }

            if (
                manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus")
            ) {
                val a = Settings.Secure.getString(context.contentResolver, "oppo_mock_location_app")
                if (!isInvalidMockApp(a)) return a
                val b = Settings.Secure.getString(context.contentResolver, "mock_location_provider_app")
                if (!isInvalidMockApp(b)) return b
            }

            if (manufacturer.contains("vivo")) {
                val flag = Settings.Secure.getInt(context.contentResolver, "mock_location", 0)
                if (flag == 1) return "mock_location_enabled"
            }

            if (sdkInt < 23) {
                val flag = Settings.Secure.getInt(context.contentResolver, "allow_mock_location", 0)
                if (flag == 1) return "mock_location_enabled"
            }

            val fallbackKeys = listOf(
                "allowed_mock_location_app",
                "mock_location_provider_app",
                "mock_location_package",
                "selected_mock_location_app"
            )
            for (key in fallbackKeys) {
                val value = try {
                    Settings.Secure.getString(context.contentResolver, key)
                } catch (_: Exception) {
                    null
                }
                if (!isInvalidMockApp(value)) return value
            }

            getAppWithMockLocationPermission()
        } catch (_: Exception) {
            null
        }
    }

    private fun diagnoseMockApps(): Map<String, Any?> {
        return try {
            val pm = context.packageManager
            val flags = PackageManager.GET_PERMISSIONS
            val packages = if (android.os.Build.VERSION.SDK_INT >= 33) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags.toLong()))
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
                            "permissionsFlags" to packageInfo.requestedPermissionsFlags?.toList()
                        )
                    )
                }
            }

            mapOf(
                "total_packages_scanned" to packages.size,
                "mock_apps_found" to mockApps,
                "manufacturer" to android.os.Build.MANUFACTURER,
                "sdk" to android.os.Build.VERSION.SDK_INT
            )
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    private fun diagnoseMockLocation(): Map<String, String?> {
        return try {
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
                    Settings.Secure.getString(context.contentResolver, key)
                } catch (e: Exception) {
                    "ERROR: ${e.message}"
                }
            }
            results["manufacturer"] = android.os.Build.MANUFACTURER
            results["android_sdk"] = android.os.Build.VERSION.SDK_INT.toString()
            results
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    private fun getAppWithMockLocationPermission(): String? {
        return try {
            val pm = context.packageManager
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
        } catch (_: Exception) {
            null
        }
    }

    private fun isInvalidMockApp(app: String?): Boolean {
        if (app == null) return true
        return app.trim().lowercase() in systemDefaultMockApps
    }

    private fun openDeveloperOptions() {
        try {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            )
        } catch (_: Exception) {
            try {
                context.startActivity(
                    Intent(Settings.ACTION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            } catch (_: Exception) {
                // no-op
            }
        }
    }
}
