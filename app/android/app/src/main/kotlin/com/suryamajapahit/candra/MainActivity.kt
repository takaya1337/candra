package com.suryamajapahit.candra

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.ContentValues
import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.location.LocationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Where the top of the phone points, from magnetic north, while
        // Light's compass is on.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/heading")
            .setStreamHandler(HeadingStream(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/gallery")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                savePng(call.argument<ByteArray>("bytes")!!, call.argument<String>("name")!!, result)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "share" -> share(call.argument<String>("path")!!, result)
                    "saveAs" -> saveAs(
                        call.argument<String>("path")!!,
                        call.argument<String>("name")!!,
                        result,
                    )
                    "pick" -> pick(result)
                    else -> result.notImplemented()
                }
            }

        // A practice under way, standing in the notification shade with
        // its clock running: what the Dynamic Island is on an iPhone.
        val island = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/island")
        practiceChannel = island
        island.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    showPractice(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("detail") ?: "",
                        (call.argument<Number>("color") ?: 0xFFFFFFFF).toInt(),
                        (call.argument<Number>("start") ?: 0).toLong(),
                        call.argument<Number>("end")?.toLong(),
                    )
                    result.success(null)
                }
                "end" -> {
                    notifications().cancel(PRACTICE_NOTIFICATION)
                    result.success(null)
                }
                // Whether it was a tap on that notification that opened
                // the app.
                "launched" -> {
                    result.success(openedByPractice)
                    openedByPractice = false
                }
                else -> result.notImplemented()
            }
        }

        // The zone the phone's clock is set to, by its tz database name.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/clock")
            .setMethodCallHandler { call, result ->
                if (call.method == "zone") result.success(java.util.TimeZone.getDefault().id)
                else result.notImplemented()
            }

        // The app's own version, and handing a link or an address to
        // whatever on the phone opens it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/app")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        result.success("${info.versionName}+${info.longVersionCode}")
                    }
                    "open" -> try {
                        startActivity(
                            android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                android.net.Uri.parse(call.argument<String>("url")!!),
                            )
                        )
                        result.success(true)
                    } catch (e: android.content.ActivityNotFoundException) {
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candra/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "current" -> current(result)
                    // Whether the app may already read where the phone is:
                    // asks nothing.
                    "allowed" -> result.success(
                        allowed(Manifest.permission.ACCESS_FINE_LOCATION) ||
                            allowed(Manifest.permission.ACCESS_COARSE_LOCATION),
                    )
                    "cancel" -> {
                        located(null, "cancelled")
                        result.success(null)
                    }
                    "open" -> openInMaps(
                        call.argument<Double>("latitude")!!,
                        call.argument<Double>("longitude")!!,
                        call.argument<String>("label") ?: "",
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private var practiceChannel: MethodChannel? = null
    private var openedByPractice = false

    private fun notifications() =
        getSystemService(NOTIFICATION_SERVICE) as NotificationManager

    // The practice's notification: it cannot be swiped away while the
    // practice runs, makes no sound, and its clock is kept turning by the
    // phone itself, up for a stopwatch and down for a countdown, with the
    // app closed. A tap opens the practice.
    private fun showPractice(title: String, detail: String, color: Int, start: Long, end: Long?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications().createNotificationChannel(
                NotificationChannel(
                    PRACTICE_CHANNEL,
                    "Practice",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "A practice under way, with its clock" },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            PRACTICE_NOTIFICATION,
            Intent(this, MainActivity::class.java)
                .setAction(OPEN_PRACTICE)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, PRACTICE_CHANNEL)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
        builder
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(title)
            .setContentText(detail)
            .setColor(color)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setWhen(end ?: start)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setContentIntent(open)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setChronometerCountDown(end != null)
        }
        notifications().notify(PRACTICE_NOTIFICATION, builder.build())
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == OPEN_PRACTICE) openedByPractice = true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == OPEN_PRACTICE) {
            practiceChannel?.invokeMethod("opened", null)
        }
    }

    // The answer owed to Dart while the phone is being asked where it is.
    private var locating: MethodChannel.Result? = null
    private var locatingCancel: CancellationSignal? = null
    private val handler = Handler(Looper.getMainLooper())

    private fun allowed(permission: String) =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    // Where the phone is now. Only ever called when the user presses the
    // geotag button; the permission is asked for then, the first time.
    private fun current(result: MethodChannel.Result) {
        if (locating != null) {
            result.error("unavailable", "Already looking", null)
            return
        }
        locating = result
        if (allowed(Manifest.permission.ACCESS_FINE_LOCATION) ||
            allowed(Manifest.permission.ACCESS_COARSE_LOCATION)
        ) {
            locate()
        } else {
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                REQUEST_LOCATION,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_LOCATION) return
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            locate()
        } else {
            located(null, "denied")
        }
    }

    // Asks every source the phone has switched on, takes the first answer,
    // and after a while settles for the last place the phone knew.
    @Suppress("MissingPermission")
    private fun locate() {
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        if (!LocationManagerCompat.isLocationEnabled(manager)) {
            located(null, "off")
            return
        }
        val fine = allowed(Manifest.permission.ACCESS_FINE_LOCATION)
        val sources = manager.getProviders(true).filter {
            it != LocationManager.PASSIVE_PROVIDER && (fine || it != LocationManager.GPS_PROVIDER)
        }
        if (sources.isEmpty()) {
            located(null, "unavailable")
            return
        }
        // With Wi-Fi and network positioning off the phone has only its
        // satellites to go by, and those need open sky: said, if it fails.
        val gaveUp =
            if (sources.contains(LocationManager.NETWORK_PROVIDER)) "timeout" else "sky"
        val cancel = CancellationSignal()
        locatingCancel = cancel
        var waitingFor = sources.size
        for (source in sources) {
            LocationManagerCompat.getCurrentLocation(
                manager,
                source,
                cancel,
                ContextCompat.getMainExecutor(this),
            ) { location ->
                waitingFor--
                if (location != null) {
                    located(location, null)
                } else if (waitingFor == 0) {
                    located(lastKnown(manager, sources), gaveUp)
                }
            }
        }
        handler.postDelayed({ located(lastKnown(manager, sources), gaveUp) }, LOCATE_FOR)
    }

    // The freshest place the phone remembers, if it is recent enough to be
    // where the user still is.
    @Suppress("MissingPermission")
    private fun lastKnown(manager: LocationManager, sources: List<String>): Location? =
        sources.mapNotNull { manager.getLastKnownLocation(it) }
            .filter { System.currentTimeMillis() - it.time < 10 * 60 * 1000 }
            .maxByOrNull { it.time }

    private fun located(location: Location?, problem: String?) {
        val result = locating ?: return
        locating = null
        locatingCancel?.cancel()
        locatingCancel = null
        handler.removeCallbacksAndMessages(null)
        if (location != null) {
            result.success(
                mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                ),
            )
        } else {
            result.error(problem ?: "unavailable", null, null)
        }
    }

    // Hands a place to whatever maps app the phone has.
    private fun openInMaps(
        latitude: Double,
        longitude: Double,
        label: String,
        result: MethodChannel.Result,
    ) {
        val pin = if (label.isEmpty()) "$latitude,$longitude" else "$latitude,$longitude(${Uri.encode(label)})"
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:$latitude,$longitude?q=$pin")))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    // The answer owed to Dart while the system's file screen is up.
    private var waiting: MethodChannel.Result? = null
    private var source: File? = null

    // Hands a file in the exports folder to whichever app the user picks.
    // That app is lent the one file, for reading.
    private fun share(path: String, result: MethodChannel.Result) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, null))
        result.success(null)
    }

    // Lets the user choose where on the device a copy goes. The system's
    // own file screen does the choosing, so no storage permission is needed.
    private fun saveAs(path: String, name: String, result: MethodChannel.Result) {
        if (waiting != null) {
            result.error("busy", "Another file screen is open", null)
            return
        }
        waiting = result
        source = File(path)
        startActivityForResult(
            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
                putExtra(Intent.EXTRA_TITLE, name)
            },
            REQUEST_SAVE,
        )
    }

    // Lets the user choose a file to import; it is copied into the app's
    // cache and the copy's path given back.
    private fun pick(result: MethodChannel.Result) {
        if (waiting != null) {
            result.error("busy", "Another file screen is open", null)
            return
        }
        waiting = result
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf(
                        "application/zip",
                        "application/x-zip-compressed",
                        "application/octet-stream",
                    ),
                )
            },
            REQUEST_PICK,
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_PICK) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = waiting ?: return
        waiting = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // Backed out of: not an error.
            result.success(null)
            return
        }
        try {
            if (requestCode == REQUEST_SAVE) {
                contentResolver.openOutputStream(uri)!!.use { out ->
                    source!!.inputStream().use { it.copyTo(out) }
                }
                result.success(true)
            } else {
                val copy = File(File(cacheDir, "imports").apply { mkdirs() }, "picked.zip")
                contentResolver.openInputStream(uri)!!.use { input ->
                    copy.outputStream().use { input.copyTo(it) }
                }
                result.success(copy.path)
            }
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
    }

    companion object {
        private const val REQUEST_SAVE = 4101
        private const val REQUEST_PICK = 4102
        private const val REQUEST_LOCATION = 4103
        private const val PRACTICE_NOTIFICATION = 4201
        private const val PRACTICE_CHANNEL = "practice"
        private const val OPEN_PRACTICE = "com.suryamajapahit.candra.OPEN_PRACTICE"
        // A satellite fix from cold can take most of a minute.
        private const val LOCATE_FOR = 45_000L
    }

    // Writes into the shared Pictures collection through MediaStore, which
    // needs no storage permission from Android 10 on. Older versions would
    // need one, so they are refused rather than prompted.
    private fun savePng(bytes: ByteArray, name: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("unsupported", "Saving images needs Android 10 or later", null)
            return
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Candra")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("io", "Could not create the image", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            result.success(null)
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            result.error("io", e.message, null)
        }
    }
}

/// The phone's heading from magnetic north, in degrees, from the fused
/// rotation-vector sensor, with how much the sensor trusts itself
/// (0 to 3); the screen's turning allowed for.
class HeadingStream(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var accuracy = 0
    private val matrix = FloatArray(9)
    private val angles = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (sensor == null) {
            events?.error("none", "no rotation sensor", null)
            return
        }
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, value: Int) {
        accuracy = value
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(matrix, event.values)
        SensorManager.getOrientation(matrix, angles)
        @Suppress("DEPRECATION")
        val turned = when (activity.windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
        val heading = (Math.toDegrees(angles[0].toDouble()) + turned + 360) % 360
        sink?.success(mapOf("heading" to heading, "accuracy" to accuracy))
    }
}
