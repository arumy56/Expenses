package com.example.expenses

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Pure Native Android BroadcastReceiver listening to SMS_RECEIVED intent events.
 * 1. Safely parses SMS PDUs across diverse Android OEM configurations.
 * 2. Uses PowerManager.WakeLock to prevent CPU sleeping during background Doze.
 * 3. Natively parses M-Pesa SMS bodies using Kotlin Regex (amount, isIncome, description, date).
 * 4. Displays high-priority heads-up notification card directly in native OS layer on channel 'vault_alerts'.
 * 5. Synchronously persists parsed transaction payloads into SharedPreferences 'pending_native_sms'
 *    with unique UUID/transaction sub-keys so no events are ever lost.
 * 6. Completely decoupled from Flutter engine during background runtime.
 */
class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val CHANNEL_ID = "vault_alerts"
        private const val CHANNEL_NAME = "Vault Alerts"
        private const val PREFS_NAME = "pending_native_sms"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null) return

        val action = intent?.action ?: return
        Log.d(TAG, "SmsReceiver triggered with action: $action")

        // Handle device reboot / package update to ensure receiver readiness
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            Log.d(TAG, "SmsReceiver initialized following system boot/update event.")
            return
        }

        if (action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        // Acquire a partial WakeLock so the CPU remains awake during background execution & Doze
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Vault:SmsReceiverWakeLock"
        )?.apply {
            setReferenceCounted(false)
            acquire(15000) // 15 seconds safety timeout
        }

        try {
            var messages: Array<SmsMessage?>? = null
            try {
                messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Telephony.Sms.Intents.getMessagesFromIntent failed, attempting fallback", e)
            }

            // Fallback PDU extraction if Telephony helper returned null
            if (messages.isNullOrEmpty()) {
                val bundle = intent.extras
                if (bundle != null && bundle.containsKey("pdus")) {
                    val pdus = bundle.get("pdus") as? Array<*>
                    val format = bundle.getString("format")
                    if (pdus != null) {
                        val list = mutableListOf<SmsMessage>()
                        for (pdu in pdus) {
                            val bytes = pdu as? ByteArray ?: continue
                            val msg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && format != null) {
                                SmsMessage.createFromPdu(bytes, format)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsMessage.createFromPdu(bytes)
                            }
                            if (msg != null) list.add(msg)
                        }
                        messages = list.toTypedArray()
                    }
                }
            }

            if (messages.isNullOrEmpty()) return

            val fullBody = StringBuilder()
            var sender = ""

            for (sms in messages) {
                if (sms != null) {
                    fullBody.append(sms.displayMessageBody ?: sms.messageBody ?: "")
                    if (sender.isEmpty()) {
                        sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: ""
                    }
                }
            }

            val messageBody = fullBody.toString().trim()
            if (messageBody.isEmpty()) return

            // Native parsing of M-Pesa SMS
            val parsedTx = parseMpesaSmsNative(messageBody, sender)
            if (parsedTx != null) {
                Log.d(TAG, "Valid M-Pesa transaction resolved natively: $parsedTx")

                // 1. Synchronously persist into SharedPreferences 'pending_native_sms'
                saveToNativeQueue(context, parsedTx)

                // 2. Immediately trigger native heads-up notification card on 'vault_alerts'
                showNativeNotification(context, parsedTx)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing incoming SMS", e)
        } finally {
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing wakeLock", e)
            }
        }
    }

    /**
     * Full Native Kotlin Parser for Safaricom M-Pesa SMS confirmations.
     * Extracts amount (Double), isIncome (Boolean), clean description, referenceCode, date, id.
     */
    private fun parseMpesaSmsNative(messageBody: String, sender: String): Map<String, Any>? {
        val upper = messageBody.uppercase()
        val upperSender = sender.uppercase()

        val isMpesaKeyword = upperSender.contains("MPESA") ||
                upperSender.contains("M-PESA") ||
                upperSender.contains("SAFARICOM") ||
                upper.contains("M-PESA") ||
                upper.contains("MPESA") ||
                upper.contains("CONFIRMED") ||
                ((upper.contains("SENT") || upper.contains("PAID") || upper.contains("RECEIVED") || upper.contains("BOUGHT")) &&
                        (upper.contains("KSH") || upper.contains("KES")))

        if (!isMpesaKeyword) {
            return null
        }

        // 1. Extract Amount (Double)
        val amountRegex = Regex("""(?:Ksh|KES|KSh)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)""", RegexOption.IGNORE_CASE)
        val amountMatch = amountRegex.find(messageBody) ?: return null
        val rawAmountStr = amountMatch.groupValues[1].replace(",", "")
        val amount = rawAmountStr.toDoubleOrNull() ?: return null
        if (amount <= 0.0) return null

        // 2. Extract Reference Code
        val codeRegex = Regex("""\b([A-Z0-9]{8,12})\s+(?:Confirmed|confirmed)""", RegexOption.IGNORE_CASE)
        val codeMatch = codeRegex.find(messageBody)
        val referenceCode = codeMatch?.groupValues?.get(1)?.uppercase() ?: ""

        val id = if (referenceCode.isNotEmpty()) {
            "mpesa_$referenceCode"
        } else {
            "sms_${UUID.randomUUID().toString().substring(0, 8)}"
        }

        // 3. Determine Inflow vs Outflow
        val lower = messageBody.lowercase()
        val isIncome = lower.contains("received") ||
                lower.contains("give you") ||
                lower.contains("transferred from") ||
                lower.contains("deposited")

        // 4. Extract Description
        var description = ""
        if (isIncome) {
            val receivedRegex = Regex("""from\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)""", RegexOption.IGNORE_CASE)
            val match = receivedRegex.find(messageBody)
            val senderName = match?.groupValues?.get(1)?.trim() ?: ""
            description = if (senderName.isNotEmpty()) senderName else "Received Funds"
        } else {
            if (lower.contains("paid")) {
                val paidRegex = Regex("""(?:paid\s+to|paid\s+(?:Ksh|KES|KSh)?\.?\s*[\d,\.]+\s+to)\s+([^.]+?)(?:\s+for\s+account|\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)""", RegexOption.IGNORE_CASE)
                val match = paidRegex.find(messageBody)
                val merchant = match?.groupValues?.get(1)?.trim() ?: ""
                description = if (merchant.isNotEmpty()) merchant else "Merchant Payment"
            } else if (lower.contains("sent to") || lower.contains("transferred to") || lower.contains("sent")) {
                val sentRegex = Regex("""(?:sent\s+to|transferred\s+to|sent\s+(?:Ksh|KES|KSh)?\.?\s*[\d,\.]+\s+to)\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)""", RegexOption.IGNORE_CASE)
                val match = sentRegex.find(messageBody)
                val recipient = match?.groupValues?.get(1)?.trim() ?: ""
                description = if (recipient.isNotEmpty()) recipient else "Sent Money"
            } else if (lower.contains("withdrawn")) {
                val withdrawRegex = Regex("""withdrawn from\s+([^.]+?)(?:\s+on\s+\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\.\s*New|\.|$)""", RegexOption.IGNORE_CASE)
                val match = withdrawRegex.find(messageBody)
                val agent = match?.groupValues?.get(1)?.trim() ?: ""
                description = if (agent.isNotEmpty()) "ATM/Agent: $agent" else "Cash Withdrawal"
            } else if (lower.contains("bought") || lower.contains("airtime")) {
                description = "Airtime Purchase"
            } else if (lower.contains("fuliza")) {
                description = "Fuliza M-Pesa"
            } else {
                description = "Sent Money"
            }
        }

        description = description.replace(Regex("""\s+"""), " ").trim()
        if (description.endsWith(".")) {
            description = description.substring(0, description.length - 1).trim()
        }

        // 5. Extract Date
        val dateRegex = Regex("""on\s+(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})""", RegexOption.IGNORE_CASE)
        val dateMatch = dateRegex.find(messageBody)
        val formattedDate = if (dateMatch != null) {
            val dayStr = dateMatch.groupValues[1].padStart(2, '0')
            val monthStr = dateMatch.groupValues[2].padStart(2, '0')
            var yearStr = dateMatch.groupValues[3]
            if (yearStr.length == 2) yearStr = "20$yearStr"
            "$yearStr-$monthStr-$dayStr"
        } else {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        }

        return mapOf(
            "id" to id,
            "referenceCode" to referenceCode,
            "amount" to amount,
            "isIncome" to isIncome,
            "description" to description,
            "date" to formattedDate,
            "rawMessage" to messageBody,
            "timestamp" to System.currentTimeMillis()
        )
    }

    /**
     * Saves parsed transaction directly into Android SharedPreferences 'pending_native_sms'
     * using the transaction code or unique UUID as sub-key.
     */
    private fun saveToNativeQueue(context: Context, tx: Map<String, Any>) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val subKey = (tx["referenceCode"] as? String)?.takeIf { it.isNotEmpty() }
                ?: (tx["id"] as? String)
                ?: UUID.randomUUID().toString()

            val jsonObject = JSONObject().apply {
                put("id", tx["id"])
                put("referenceCode", tx["referenceCode"])
                put("amount", tx["amount"])
                put("isIncome", tx["isIncome"])
                put("description", tx["description"])
                put("date", tx["date"])
                put("rawMessage", tx["rawMessage"])
                put("timestamp", tx["timestamp"])
            }

            prefs.edit().putString(subKey, jsonObject.toString()).commit()
            Log.d(TAG, "Natively saved transaction subKey: $subKey into '$PREFS_NAME'")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving transaction to native SharedPreferences", e)
        }
    }

    /**
     * Immediately constructs and displays the high-priority heads-up notification card on 'vault_alerts'.
     */
    private fun showNativeNotification(context: Context, tx: Map<String, Any>) {
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            // Register notification channel for Android O (API 26) and above
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Instant M-Pesa transaction alerts and review reminders"
                    enableLights(true)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 250, 100, 250)
                    setSound(defaultSoundUri, audioAttributes)
                    setShowBadge(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val isIncome = tx["isIncome"] as? Boolean ?: false
            val amount = (tx["amount"] as? Double) ?: 0.0
            val description = tx["description"] as? String ?: "M-Pesa Transaction"
            val rawMessage = tx["rawMessage"] as? String ?: ""
            val formattedAmount = String.format(Locale.US, "%,.2f", amount)

            val title = if (isIncome) {
                "📥 Inflow: KSh $formattedAmount"
            } else {
                "💸 Outflow: KSh $formattedAmount"
            }

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle(title)
                .setContentText("$description • Tap to review & categorize")
                .setStyle(NotificationCompat.BigTextStyle().bigText(rawMessage))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setSound(defaultSoundUri)
                .setVibrate(longArrayOf(0, 250, 100, 250))
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .build()

            val notificationId = (System.currentTimeMillis() % 100000).toInt()
            notificationManager.notify(notificationId, notification)
            Log.d(TAG, "Dispatched native heads-up notification for ID: $notificationId ($title)")
        } catch (e: Exception) {
            Log.e(TAG, "Error displaying native notification", e)
        }
    }
}
