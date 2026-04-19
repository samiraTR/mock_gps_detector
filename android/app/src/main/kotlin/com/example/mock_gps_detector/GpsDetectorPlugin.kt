package com.example.mock_gps_detector

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * GpsDetectorPlugin
 *
 * Methods exposed to Flutter:
 *   detectMockGPS        → Map  — full scan (dynamic + known-list combined)
 *   pauseMockServices    → Bool — broadcasts pause intent to detected services
 *   resumeMockServices   → Bool — broadcasts resume intent
 *   stopMockService      → Bool — attempts to stop a single service
 *   openApp              → void — launches a package by name
 *   openDeveloperOptions → void — opens Android Developer Options
 *   getRealLocation      → Map  — returns real GPS lat/lng after mock check
 */
class GpsDetectorPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    // ── Fallback known mock-GPS packages (used as secondary cross-check) ─────
    private val knownMockPackages = setOf(
        "com.lexa.fakegps",
        "com.incorporateapps.fakegps.fre",
        "com.incorporateapps.fakegps",
        "com.blogspot.newapphorizons.fakegps",
        "com.fake.gps.location",
        "com.fakeGPS.spoofer",
        "com.rosteam.gpsemulator",
        "com.onyxbits.remotecontrol",
        "com.theappninjas.gpsjoystick",
        "com.theappninjas.fakegpsjoystick",
        "org.hhuang.locspoof",
        "com.location.changer",
        "com.gps.emulator",
        "com.fakegps.mock",
        "net.marlove.fakegps",
        "com.appunwrapper.unlocator"
    )

    // ── Fallback known mock-GPS service class names ──────────────────────────
    private val knownMockServiceClasses = setOf(
        "com.lexa.fakegps.FakeLocationService",
        "com.incorporateapps.fakegps.services.FakeLocationService",
        "com.blogspot.newapphorizons.fakegps.FakeGPSService",
        "com.fake.gps.location.FakingService",
        "com.fakeGPS.spoofer.GPSSpoofService",
        "com.rosteam.gpsemulator.MockLocationService",
        "com.theappninjas.gpsjoystick.LocationService"
    )

    // ── Keywords used for dynamic service detection ──────────────────────────
    private val locationKeywords = listOf(
        "location", "gps", "mock", "fake", "spoof",
        "position", "coordinate", "nmea", "provider"
    )

    // ── FlutterPlugin ────────────────────────────────────────────────────────

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

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "detectMockGPS" -> result.success(detectMockGPS())

            "pauseMockServices" -> {
                val services = call.argument<List<String>>("services") ?: emptyList()
                result.success(pauseMockServices(services))
            }

            "resumeMockServices" -> {
                val services = call.argument<List<String>>("services") ?: emptyList()
                result.success(resumeMockServices(services))
            }

            "stopMockService" -> {
                val svcClass = call.argument<String>("serviceClass") ?: ""
                result.success(stopMockService(svcClass))
            }

            "openApp" -> {
                val pkg = call.argument<String>("packageName") ?: ""
                openApp(pkg)
                result.success(null)
            }

            "openDeveloperOptions" -> {
                openDeveloperOptions()
                result.success(null)
            }

            "getRealLocation" -> {
                val location = getRealLocation()
                if (location != null) {
                    result.success(
                        mapOf("lat" to location.latitude, "lng" to location.longitude)
                    )
                } else {
                    result.error("UNAVAILABLE", "Real location could not be determined", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // =========================================================================
    // DETECTION — Layer 1 (permission) + Layer 2 (service name) + Layer 3 (known list)
    // =========================================================================

    /**
     * Master scan combining all three detection layers.
     *
     * Layer 1 — Dynamic permission check:
     *   Any non-system app holding ACCESS_MOCK_LOCATION permission.
     *   Catches unknown/new mock apps that aren't in our list.
     *
     * Layer 2 — Dynamic running service scan:
     *   Any running service whose class name contains GPS/location keywords.
     *   Works regardless of package name.
     *
     * Layer 3 — Known list fallback:
     *   Cross-checks against hardcoded known package + service class names.
     *   Catches apps that don't expose obvious service names.
     */
    private fun detectMockGPS(): Map<String, Any> {
        val isMockEnabled      = isMockLocationEnabled()
        val isFromMock         = isCurrentLocationFromMockProvider()

        // Layer 1
        val appsWithMockPerm   = findAppsWithMockPermission()

        // Layer 2
        val dynamicServices    = findLocationRelatedServices()

        // Layer 3
        val knownApps          = findInstalledKnownMockApps()
        val knownServices      = findKnownRunningMockServices()

        // Merge + de-duplicate across all layers
        val allDetectedApps    = (appsWithMockPerm + knownApps).distinct()
        val allRunningServices = (dynamicServices.map { it.service.className } + knownServices).distinct()

        // Resolve which package is actively spoofing right now
        val activePackageName  = resolveActivePackage(dynamicServices, appsWithMockPerm)

        val hasActiveSvc       = allRunningServices.isNotEmpty() || isFromMock

        val riskLevel = when {
            isFromMock || allRunningServices.isNotEmpty() -> "HIGH"
            isMockEnabled || allDetectedApps.isNotEmpty() -> "MEDIUM"
            else                                           -> "LOW"
        }

        return mapOf(
            "isMockLocationEnabled" to isMockEnabled,
            "hasActiveMockService"  to hasActiveSvc,
            "isFromMockProvider"    to isFromMock,
            "activePackageName"     to (activePackageName ?: ""),
            "detectedMockApps"      to allDetectedApps,
            "runningMockServices"   to allRunningServices,
            "riskLevel"             to riskLevel,
            "message"               to buildSummaryMessage(
                isMockEnabled, allDetectedApps, allRunningServices, isFromMock
            )
        )
    }

    // ── Layer 1: Permission-based dynamic detection ──────────────────────────

    /**
     * Returns package names of all non-system apps that hold
     * ACCESS_MOCK_LOCATION permission — the ground truth on Android.
     * Android only grants this to the app explicitly chosen in Developer Options.
     */
    private fun findAppsWithMockPermission(): List<String> {
        val pm = context.packageManager
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter { appInfo ->
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                if (isSystemApp) return@filter false
                pm.checkPermission(
                    "android.permission.ACCESS_MOCK_LOCATION",
                    appInfo.packageName
                ) == PackageManager.PERMISSION_GRANTED
            }
            .map { it.packageName }
    }

    // ── Layer 2: Running service keyword-based dynamic detection ─────────────

    /**
     * Returns all currently running services whose class name contains
     * any of the GPS/location-related keywords.
     * No package list needed — works for any mock GPS app.
     */
    @Suppress("DEPRECATION")
    private fun findLocationRelatedServices(): List<ActivityManager.RunningServiceInfo> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return (am.getRunningServices(Int.MAX_VALUE) ?: emptyList())
            .filter { svcInfo ->
                val name = svcInfo.service.className.lowercase()
                locationKeywords.any { name.contains(it) }
            }
    }

    /**
     * Cross-matches running services with permission-holding apps.
     * Priority: service that belongs to a permission-holding package.
     * Fallback: first location-related service found.
     */
    private fun resolveActivePackage(
        dynamicServices: List<ActivityManager.RunningServiceInfo>,
        permissionApps: List<String>
    ): String? {
        return dynamicServices
            .firstOrNull { it.service.packageName in permissionApps }
            ?.service?.packageName
            ?: dynamicServices.firstOrNull()?.service?.packageName
    }

    // ── Layer 3: Known-list fallback ─────────────────────────────────────────

    private fun findInstalledKnownMockApps(): List<String> {
        val pm = context.packageManager
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .map { it.packageName }
            .filter { it in knownMockPackages }
    }

    @Suppress("DEPRECATION")
    private fun findKnownRunningMockServices(): List<String> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val running = am.getRunningServices(Int.MAX_VALUE) ?: return emptyList()
        return running
            .map { it.service.className }
            .filter { className ->
                knownMockServiceClasses.any { className.contains(it) } ||
                knownMockPackages.any { className.startsWith(it) }
            }
    }

    // ── Mock location setting check ──────────────────────────────────────────

    /**
     * On API 23+: tries to register a test provider.
     *   - SecurityException  → mock location NOT allowed for our app
     *   - IllegalArgument    → another app already registered this provider (actively spoofing)
     *   - Success            → developer options mock is on but no app is using it yet
     */
    private fun isMockLocationEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            try {
                lm.addTestProvider(
                    LocationManager.GPS_PROVIDER,
                    false, false, false, false,
                    false, true, true, 0, 5
                )
                lm.removeTestProvider(LocationManager.GPS_PROVIDER)
                true
            } catch (e: SecurityException) {
                false
            } catch (e: IllegalArgumentException) {
                true // Provider already taken by a mock app
            }
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ALLOW_MOCK_LOCATION, 0
            ) != 0
        }
    }

    /**
     * Checks if the last known location from any active provider
     * is flagged as coming from a mock provider.
     */
    private fun isCurrentLocationFromMockProvider(): Boolean {
        return try {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            lm.getProviders(true).any { provider ->
                @Suppress("MissingPermission")
                val loc: Location? = lm.getLastKnownLocation(provider)
                loc != null && isLocationMocked(loc)
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isLocationMocked(location: Location): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }
    }

    // =========================================================================
    // REAL LOCATION — only returned when confirmed NOT mocked
    // =========================================================================

    /**
     * Tries GPS provider first, then Network provider.
     * Only returns a location that passes the mock check.
     * Flutter calls this after the user stops the mock service.
     */
    private fun getRealLocation(): Location? {
        return try {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER
            )
            for (provider in providers) {
                if (!lm.isProviderEnabled(provider)) continue
                @Suppress("MissingPermission")
                val loc = lm.getLastKnownLocation(provider) ?: continue
                if (!isLocationMocked(loc)) return loc
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    // =========================================================================
    // SERVICE CONTROL
    // =========================================================================

    /**
     * Broadcasts a standard pause intent to each service's package.
     * Apps that honor this will pause their mock injection.
     * Always follow up with openApp() as a fallback.
     */
    private fun pauseMockServices(services: List<String>): Boolean {
        return try {
            services.forEach { svcClass ->
                val pkg = svcClass.substringBeforeLast(".")
                context.sendBroadcast(
                    Intent("com.fakegps.ACTION_PAUSE").apply { setPackage(pkg) }
                )
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun resumeMockServices(services: List<String>): Boolean {
        return try {
            services.forEach { svcClass ->
                val pkg = svcClass.substringBeforeLast(".")
                context.sendBroadcast(
                    Intent("com.fakegps.ACTION_RESUME").apply { setPackage(pkg) }
                )
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Attempts stopService() on the given service class.
     * Reliably works only for same-process services on API 26+.
     * For foreign processes: guide the user via openApp().
     */
    private fun stopMockService(serviceClass: String): Boolean {
        return try {
            val pkg = serviceClass.substringBeforeLast(".")
            context.stopService(
                Intent().apply { setClassName(pkg, serviceClass) }
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    // =========================================================================
    // NAVIGATION HELPERS
    // =========================================================================

    /**
     * Opens the mock app so the user can manually stop the service.
     * Falls back to App Info screen if no launch intent exists.
     */
    private fun openApp(packageName: String) {
        if (packageName.isEmpty()) return
        val pm = context.packageManager
        val intent = pm.getLaunchIntentForPackage(packageName)
            ?: Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun openDeveloperOptions() {
        try {
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private fun buildSummaryMessage(
        mockEnabled: Boolean,
        apps: List<String>,
        services: List<String>,
        fromMock: Boolean
    ): String {
        val parts = mutableListOf<String>()
        if (fromMock)              parts.add("Current location is from a mock provider")
        if (services.isNotEmpty()) parts.add("${services.size} mock service(s) actively running")
        if (apps.isNotEmpty())     parts.add("${apps.size} mock app(s) installed")
        if (mockEnabled)           parts.add("Mock location setting is enabled in Developer Options")
        return if (parts.isEmpty()) "No mock GPS activity detected"
               else parts.joinToString("; ")
    }
}