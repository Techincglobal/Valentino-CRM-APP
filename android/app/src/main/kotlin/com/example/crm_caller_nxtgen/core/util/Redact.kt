package com.example.crm_caller_nxtgen.core.util

/**
 * Masks a phone number for logging, keeping only the last 3 digits.
 *
 * Debug-level logging is stripped from release builds by proguard
 * (-assumenosideeffects on Log.d/v/i), but Log.w/Log.e are deliberately kept so
 * production failures stay diagnosable. Any of those that reference a caller's
 * number must route it through here first: a phone number in logcat is customer
 * PII readable by anything holding READ_LOGS, or by anyone with adb access.
 *
 * The tail is preserved because it's enough to correlate a failure with a
 * specific call while debugging, without identifying the person.
 */
internal fun redactPhone(phone: String?): String {
    if (phone.isNullOrBlank()) return "(none)"
    // Placeholder for "the OS wouldn't give us a number" — not PII, keep it readable.
    if (phone == "Hidden") return phone
    if (phone.length <= 3) return "*".repeat(phone.length)
    return "*".repeat(phone.length - 3) + phone.takeLast(3)
}
