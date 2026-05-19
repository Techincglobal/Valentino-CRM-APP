package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

// ─────────────────────────────────────────────────────────────────────────────
// Frappe API configuration
// Reads the SAME keys that the Flutter app writes via StorageService:
//   crm_base_url  → the server base URL
//   crm_sid       → the Frappe session cookie (set by login)
// flutter_shared_preferences stores every key with "flutter." prefix.
// ─────────────────────────────────────────────────────────────────────────────

data class FrappeConfig(
    val serverUrl: String,     // e.g. "https://crm.mycompany.com"
    val sid: String,           // Frappe session id cookie
    val csrfToken: String,     // X-Frappe-CSRF-Token — required for POST/PUT/DELETE
) {
    val isValid: Boolean get() = serverUrl.isNotBlank() && sid.isNotBlank()
    val cookieHeader: String get() = "sid=$sid"
}

// ─────────────────────────────────────────────────────────────────────────────
// Frappe API response wrappers
// ─────────────────────────────────────────────────────────────────────────────

data class FrappeLeadResult(
    val docname: String,
    val leadName: String,
    val companyName: String,
    val email: String,
    val mobileNo: String,
    val status: String,
    val latestNote: String = "",
)

data class FrappeOpportunityResult(val docname: String)
data class FrappeComplaintResult(val docname: String)
data class FrappeQuotationResult(val docname: String)
data class FrappeCallLogResult(val docname: String)

// ─────────────────────────────────────────────────────────────────────────────
// FrappeApiService
// All network calls are suspend functions. Each throws on HTTP error so the
// repository can catch and decide (retry / offline fallback).
// ─────────────────────────────────────────────────────────────────────────────

class FrappeApiService(private val context: Context) {

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private val httpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(8, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .writeTimeout(15, TimeUnit.SECONDS)
            .build()
    }

    private val JSON = "application/json; charset=utf-8".toMediaType()

    // Read config from SharedPreferences — matches what Flutter's StorageService writes
    fun getConfig(): FrappeConfig {
        // flutter_shared_preferences stores strings with "flutter." prefix
        val url  = prefs.getString("flutter.crm_base_url",    "") ?: ""
        val sid  = prefs.getString("flutter.crm_sid",         "") ?: ""
        val csrf = prefs.getString("flutter.crm_csrf_token",  "") ?: ""
        return FrappeConfig(url.trimEnd('/'), sid, csrf)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CSRF REFRESH
    // Frappe issues a fresh csrf_token cookie on every GET response.
    // Call this before any POST/PUT so the stored token is always current.
    // Writes the new value back to SharedPreferences so Flutter reads it too.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun refreshCsrfToken(): Boolean = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) return@withContext false
        return@withContext try {
            val request = Request.Builder()
                .url("${config.serverUrl}/api/method/frappe.auth.get_logged_user")
                .header("Cookie", config.cookieHeader)
                .header("Accept", "application/json")
                .get()
                .build()
            val response = httpClient.newCall(request).execute()
            // Frappe puts the fresh CSRF in the Set-Cookie response header
            val setCookie = response.headers("Set-Cookie").joinToString(";")
            val match = Regex("csrf_token=([^;,\\s]+)").find(setCookie)
            val newCsrf = match?.groupValues?.getOrNull(1)?.takeIf { it.isNotBlank() }
            if (newCsrf != null) {
                prefs.edit().putString("flutter.crm_csrf_token", newCsrf).apply()
                Log.d(TAG, "CSRF token refreshed")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "CSRF refresh failed: ${e.message}")
            false
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Parse a Frappe error body into a short human-readable message
    // ─────────────────────────────────────────────────────────────────────────

    private fun parseFrappeError(body: String, httpCode: Int): String {
        return try {
            val json = JSONObject(body)
            // Frappe wraps errors in _server_messages (JSON-encoded list of JSON strings)
            val serverMsgs = json.optString("_server_messages")
            if (serverMsgs.isNotBlank()) {
                val arr = org.json.JSONArray(serverMsgs)
                if (arr.length() > 0) {
                    val inner = JSONObject(arr.getString(0))
                    val msg = inner.optString("message").trim()
                    if (msg.isNotBlank()) return msg
                }
            }
            // Plain exception string
            val exc = json.optString("exception")
            if (exc.isNotBlank()) {
                // "frappe.exceptions.SomeError: actual message" → "actual message"
                return exc.substringAfter(": ").ifBlank { exc }
            }
            "Server error ($httpCode)"
        } catch (_: Exception) {
            "Server error ($httpCode)"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LOOKUP: find lead by phone number via get_caller_details API
    // Returns null when not found.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun lookupLeadByPhone(phone: String): FrappeLeadResult? = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) return@withContext null

        val url = "${config.serverUrl}/api/method/nxtgen_crm_mobile.api.get_caller_details" +
            "?caller_number=${normalisePhone(phone).encodeUrl()}"

        val request = Request.Builder()
            .url(url)
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .get()
            .build()

        return@withContext try {
            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) return@withContext null

            val bodyStr = response.body?.string() ?: return@withContext null
            val root = JSONObject(bodyStr)
            val msg  = root.optJSONObject("message") ?: return@withContext null

            if (!msg.optBoolean("found", false)) return@withContext null

            FrappeLeadResult(
                docname     = msg.optString("docname"),
                leadName    = msg.optString("name"),
                companyName = "",
                email       = msg.optString("email_id"),
                mobileNo    = msg.optString("mobile_no").ifBlank { msg.optString("phone") },
                status      = "Lead",
                latestNote  = msg.optString("latest_note"),
            )
        } catch (_: Exception) { null }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE LEAD via create_lead_with_note API
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createLead(
        name: String,
        email: String,
        company: String,
        phone: String,
        note: String,
    ): FrappeLeadResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("first_name", name)
            if (email.isNotBlank()) put("email_id", email)
            put("mobile_no",  normalisePhone(phone))
            if (note.isNotBlank()) put("note_content", note)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_lead_with_note")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val requestBodyStr = body.toString()
        Log.d(TAG, "╔══ CREATE LEAD REQUEST ══════════════════════════════════")
        Log.d(TAG, "║  URL  : ${request.url}")
        Log.d(TAG, "║  Body : $requestBodyStr")
        Log.d(TAG, "╚════════════════════════════════════════════════════════")

        val response = httpClient.newCall(request).execute()
        val rawBody = response.body?.string() ?: ""

        val statusLine = "${response.code} ${response.message}"
        if (response.isSuccessful) {
            Log.d(TAG, "╔══ CREATE LEAD RESPONSE ✅ ══════════════════════════════")
            Log.d(TAG, "║  Status : $statusLine")
            Log.d(TAG, "║  Body   : $rawBody")
            Log.d(TAG, "╚════════════════════════════════════════════════════════")
        } else {
            Log.e(TAG, "╔══ CREATE LEAD ERROR ❌ ═════════════════════════════════")
            Log.e(TAG, "║  Status : $statusLine")
            Log.e(TAG, "║  Body   : $rawBody")
            Log.e(TAG, "╚════════════════════════════════════════════════════════")
        }

        writeApiLog(
            label = "CREATE LEAD",
            url = request.url.toString(),
            requestBody = requestBodyStr,
            statusCode = response.code,
            responseBody = rawBody,
            isError = !response.isSuccessful,
        )

        if (!response.isSuccessful) {
            throw RuntimeException(parseFrappeError(rawBody, response.code))
        }

        val msg = JSONObject(rawBody).optJSONObject("message")
            ?: throw RuntimeException("Unexpected response from server")

        FrappeLeadResult(
            docname     = msg.optString("lead_name"),
            leadName    = name,
            companyName = company,
            email       = email,
            mobileNo    = normalisePhone(phone),
            status      = "Lead",
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE OPPORTUNITY
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createOpportunity(
        leadDocname: String,
        expectedValue: Double,
        stage: String,
        note: String,
    ): FrappeOpportunityResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("lead_docname",       leadDocname)
            put("opportunity_amount", expectedValue)
            put("stage",              stage)
            if (note.isNotBlank()) put("note", note)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_opportunity")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val msg = JSONObject(response.body?.string() ?: "{}").optJSONObject("message")
            ?: throw RuntimeException("Invalid response")
        FrappeOpportunityResult(docname = msg.optString("name"))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE COMPLAINT (maps to Frappe CRM Issue / custom complaint doctype)
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createComplaint(
        leadDocname: String?,
        category: String,
        details: String,
        priority: String,
        callerName: String,
        phone: String,
    ): FrappeComplaintResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("category",    category)
            put("details",     details)
            put("priority",    priority)
            put("caller_name", callerName)
            put("phone",       normalisePhone(phone))
            if (!leadDocname.isNullOrBlank()) put("lead_docname", leadDocname)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_complaint")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val msg = JSONObject(response.body?.string() ?: "{}").optJSONObject("message")
            ?: throw RuntimeException("Invalid response")
        FrappeComplaintResult(docname = msg.optString("name"))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE QUOTATION
    // POST /api/method/nxtgen_crm_mobile.api.create_quotation
    // Links a new Frappe Quotation to an existing Lead or Customer docname.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createQuotation(
        leadDocname: String,
        partyType: String,    // "Lead" or "Customer"
        subject: String,
        amount: Double,
        note: String,
    ): FrappeQuotationResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("lead_docname", leadDocname)
            put("party_type",   partyType)
            put("subject",      subject)
            put("amount",       amount)
            put("note",         note)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_quotation")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val data = JSONObject(response.body?.string() ?: "{}")
        val msg  = data.optJSONObject("message") ?: data
        FrappeQuotationResult(docname = msg.optString("name", ""))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE CALL LOG  →  nxtgen_crm_mobile.api.create_call_log
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createCallLog(
        phone: String,
        callerName: String,
        leadDocname: String?,
        durationSeconds: Long,
        notes: String,
        callType: String,
        direction: String,
    ): FrappeCallLogResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("phone",        normalisePhone(phone))
            put("caller_name",  callerName)
            put("duration",     durationSeconds)
            put("notes",        notes)
            put("call_type",    callType)
            put("direction",    direction)
            if (!leadDocname.isNullOrBlank()) put("lead_docname", leadDocname)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_call_log")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val msg = JSONObject(response.body?.string() ?: "{}").optJSONObject("message")
            ?: throw RuntimeException("Invalid response")
        FrappeCallLogResult(docname = msg.optString("name"))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ADD NOTE  →  nxtgen_crm_mobile.api.add_call_note
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun addNote(doctype: String, docname: String, noteContent: String) = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) return@withContext

        val body = JSONObject().apply {
            put("doctype",      doctype)
            put("docname",      docname)
            put("note_content", noteContent)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.add_call_note")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        httpClient.newCall(request).execute().close()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /** Strip non-digits except leading +. Returns last 10 digits for fuzzy match. */
    private fun normalisePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() || it == '+' }
        return digits.ifBlank { phone }
    }

    private fun String.encodeUrl(): String =
        java.net.URLEncoder.encode(this, "UTF-8")

    // ─────────────────────────────────────────────────────────────────────────
    // API log writer — appends each call to crm_api_log.md in app files dir
    // Read via:  adb shell run-as com.example.crm_caller_nxtgen cat files/crm_api_log.md
    // Or pull:   adb pull /data/data/com.example.crm_caller_nxtgen/files/crm_api_log.md
    // ─────────────────────────────────────────────────────────────────────────

    private fun writeApiLog(
        label: String,
        url: String,
        requestBody: String,
        statusCode: Int,
        responseBody: String,
        isError: Boolean,
    ) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
            val icon = if (isError) "❌" else "✅"
            val entry = buildString {
                appendLine()
                appendLine("## $icon $label — $ts")
                appendLine()
                appendLine("**URL:** `$url`")
                appendLine()
                appendLine("**Request Body:**")
                appendLine("```json")
                appendLine(try { JSONObject(requestBody).toString(2) } catch (_: Exception) { requestBody })
                appendLine("```")
                appendLine()
                appendLine("**Response — HTTP $statusCode:**")
                appendLine("```json")
                appendLine(try { JSONObject(responseBody).toString(2) } catch (_: Exception) { responseBody })
                appendLine("```")
                appendLine()
                appendLine("---")
            }

            val logFile = File(context.filesDir, "crm_api_log.md")
            // Prepend header on first write
            if (!logFile.exists()) {
                logFile.writeText("# CRM API Log\n\n")
            }
            logFile.appendText(entry)
            Log.d(TAG, "API log written → ${logFile.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to write API log file: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "FrappeApi"
    }
}
