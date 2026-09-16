package com.example.expenses

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_SMS = "com.vault.cashflow/sms"
        const val CHANNEL_GET_QUEUE = "com.vault.cashflow/get_native_queue"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val PREFS_NAME = "pending_native_sms"
        private const val TAG = "MainActivity"
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SMS)
        val queueChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_GET_QUEUE)

        val methodHandler = MethodChannel.MethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }

        smsChannel.setMethodCallHandler(methodHandler)
        queueChannel.setMethodCallHandler(methodHandler)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "get_native_queue", "getNativePendingSms" -> {
                try {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val allEntries = prefs.all
                    val list = ArrayList<Map<String, Any>>()

                    for ((key, value) in allEntries) {
                        if (value is String) {
                            try {
                                val obj = JSONObject(value)
                                val map = HashMap<String, Any>()
                                map["id"] = obj.optString("id", key)
                                map["referenceCode"] = obj.optString("referenceCode", "")
                                map["amount"] = obj.optDouble("amount", 0.0)
                                map["isIncome"] = obj.optBoolean("isIncome", false)
                                map["description"] = obj.optString("description", "M-Pesa Transaction")
                                map["date"] = obj.optString("date", "")
                                map["rawMessage"] = obj.optString("rawMessage", "")
                                map["timestamp"] = obj.optLong("timestamp", System.currentTimeMillis())
                                list.add(map)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error parsing stored native transaction: $value", e)
                            }
                        }
                    }

                    // Clear SharedPreferences queue file after transferring to Flutter
                    prefs.edit().clear().commit()
                    Log.d(TAG, "Transferred and cleared ${list.size} transactions from '$PREFS_NAME'")
                    result.success(list)
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing get_native_queue", e)
                    result.success(ArrayList<Map<String, Any>>())
                }
            }

            "clearNativePendingSms", "clear_native_queue" -> {
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().clear().commit()
                result.success(true)
            }

            "checkSmsPermissions" -> {
                val receiveGranted = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.RECEIVE_SMS
                ) == PackageManager.PERMISSION_GRANTED
                val readGranted = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.READ_SMS
                ) == PackageManager.PERMISSION_GRANTED
                val notifGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }
                result.success(receiveGranted && readGranted && notifGranted)
            }

            "requestSmsPermissions" -> {
                val neededPermissions = mutableListOf<String>()
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    neededPermissions.add(Manifest.permission.RECEIVE_SMS)
                }
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    neededPermissions.add(Manifest.permission.READ_SMS)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        neededPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
                    }
                }

                if (neededPermissions.isEmpty()) {
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        this,
                        neededPermissions.toTypedArray(),
                        PERMISSION_REQUEST_CODE
                    )
                }
            }

            "isBatteryOptimizationIgnored" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnored = powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                    result.success(isIgnored)
                } else {
                    result.success(true)
                }
            }

            "requestIgnoreBatteryOptimization" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "Direct ignore battery optimization request failed, trying settings overview", e)
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            Log.e(TAG, "Failed to launch battery settings", e2)
                            result.success(false)
                        }
                    }
                } else {
                    result.success(true)
                }
            }

            "openBatterySettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open app settings", e)
                    result.success(false)
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val receiveGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECEIVE_SMS
            ) == PackageManager.PERMISSION_GRANTED
            val readGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
            val notifGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
            val allGranted = receiveGranted && readGranted && notifGranted
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }
}
