package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.example.crm_caller_nxtgen.overlay.domain.ItemSearchResult
import com.example.crm_caller_nxtgen.overlay.domain.QuoteLineItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
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
    val isValid: Boolean get() = serverUrl.isNotBlank() && sid.isNotBlank() && csrfToken.isNotBlank()
    // Only requires a logged-in session, NOT the csrf token — used to gate
    // refreshCsrfToken() itself. If this required csrfToken too, a session
    // that never had a csrf token (e.g. Frappe didn't hand one back on the
    // login POST) could NEVER bootstrap one: refresh would refuse to even
    // try, and every create/update call would permanently fail with
    // "Frappe not configured" despite the server/session being fine.
    val hasSession: Boolean get() = serverUrl.isNotBlank() && sid.isNotBlank()
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
    val latestQuoteSubject: String = "",
    val latestQuoteAmount: Double = 0.0,
    val latestQuoteStatus: String = "",
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
        if (!config.hasSession) return@withContext false
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
    // Central POST executor — refreshes CSRF and retries once on 403
    // ─────────────────────────────────────────────────────────────────────────

    private suspend fun executePost(request: Request): okhttp3.Response {
        var response = httpClient.newCall(request).execute()
        if (response.code == 403) {
            // CSRF expired — refresh token and retry with updated config
            refreshCsrfToken()
            val newConfig = getConfig()
            val retryRequest = request.newBuilder()
                .apply {
                    if (newConfig.csrfToken.isNotBlank())
                        header("X-Frappe-CSRF-Token", newConfig.csrfToken)
                }
                .build()
            response.close()
            response = httpClient.newCall(retryRequest).execute()
        }
        return response
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

            val docname = msg.optString("docname")

            // Fetch the latest quotation for this lead (best-effort, non-blocking)
            val quote = if (docname.isNotBlank()) fetchLatestQuote(config, docname) else null

            FrappeLeadResult(
                docname            = docname,
                leadName           = msg.optString("name"),
                companyName        = "",
                email              = msg.optString("email_id"),
                mobileNo           = msg.optString("mobile_no").ifBlank { msg.optString("phone") },
                status             = "Lead",
                latestNote         = msg.optString("latest_note"),
                latestQuoteSubject = quote?.optString("title") ?: quote?.optString("name") ?: "",
                latestQuoteAmount  = quote?.optDouble("grand_total", 0.0) ?: 0.0,
                latestQuoteStatus  = quote?.optString("status") ?: "",
            )
        } catch (_: Exception) { null }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FETCH LATEST QUOTATION for a lead/party (best-effort)
    // ─────────────────────────────────────────────────────────────────────────

    private fun fetchLatestQuote(config: FrappeConfig, partyDocname: String): JSONObject? {
        return try {
            val fields = "%5B%22name%22%2C%22title%22%2C%22grand_total%22%2C%22status%22%2C%22currency%22%5D"
            val filters = "%5B%5B%22party_name%22%2C%22%3D%22%2C%22${partyDocname.encodeUrl()}%22%5D%5D"
            val url = "${config.serverUrl}/api/resource/Quotation" +
                "?fields=$fields&filters=$filters&limit=1&order_by=modified%20desc"
            val resp = httpClient.newCall(
                Request.Builder()
                    .url(url)
                    .header("Cookie", config.cookieHeader)
                    .header("Content-Type", "application/json")
                    .get()
                    .build()
            ).execute()
            if (!resp.isSuccessful) return null
            val body = resp.body?.string() ?: return null
            val arr = JSONObject(body).optJSONArray("data") ?: return null
            if (arr.length() == 0) null else arr.getJSONObject(0)
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

        val response = executePost(request)
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

        val response = executePost(request)
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

        val response = executePost(request)
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
        items: List<QuoteLineItem>,
        note: String,
        currency: String = "",
        validTill: String = "",
    ): FrappeQuotationResult = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val itemsJson = JSONArray().apply {
            items.forEach { item ->
                put(JSONObject().apply {
                    put("item_code", item.itemCode)
                    put("item_name", item.itemName)
                    put("qty",       item.qty)
                    put("rate",      item.rate)
                })
            }
        }

        val body = JSONObject().apply {
            put("lead_docname", leadDocname)
            put("party_type",   partyType)
            put("subject",      subject)
            put("items",        itemsJson)
            put("note",         note)
            if (currency.isNotBlank())  put("currency",   currency)
            if (validTill.isNotBlank()) put("valid_till",  validTill)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.create_quotation")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = executePost(request)
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val data = JSONObject(response.body?.string() ?: "{}")
        val msg  = data.optJSONObject("message") ?: data
        FrappeQuotationResult(docname = msg.optString("name", ""))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SEARCH ITEMS — GET /api/method/nxtgen_crm_mobile.api.search_items
    // Powers the item-code autocomplete in the quotation form.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun searchItems(query: String): List<ItemSearchResult> = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) return@withContext emptyList()

        val url = "${config.serverUrl}/api/method/nxtgen_crm_mobile.api.search_items" +
            "?query=${query.encodeUrl()}&limit=20"

        val request = Request.Builder()
            .url(url)
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .get()
            .build()

        return@withContext try {
            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) return@withContext emptyList()
            val bodyStr = response.body?.string() ?: return@withContext emptyList()
            val arr = JSONObject(bodyStr).optJSONArray("message") ?: return@withContext emptyList()
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                ItemSearchResult(
                    itemCode = obj.optString("name"),
                    itemName = obj.optString("item_name").ifBlank { obj.optString("name") },
                    rate     = obj.optDouble("standard_rate", 0.0),
                )
            }
        } catch (_: Exception) { emptyList() }
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

        val response = executePost(request)
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }

        val msg = JSONObject(response.body?.string() ?: "{}").optJSONObject("message")
            ?: throw RuntimeException("Invalid response")
        FrappeCallLogResult(docname = msg.optString("name"))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UPDATE CALL LOG  →  nxtgen_crm_mobile.api.update_call_log
    // Patches an already-created Mobile Call Log with notes entered after the
    // fact — the log itself is created the instant the call ends so every call
    // is captured even if the user never opens the "add a note" popup.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun updateCallLog(
        name: String,
        notes: String,
    ): Unit = withContext(Dispatchers.IO) {
        val config = getConfig()
        if (!config.isValid) throw IllegalStateException("Frappe not configured")

        val body = JSONObject().apply {
            put("name",  name)
            put("notes", notes)
        }

        val request = Request.Builder()
            .url("${config.serverUrl}/api/method/nxtgen_crm_mobile.api.update_call_log")
            .header("Cookie", config.cookieHeader)
            .header("Content-Type", "application/json")
            .apply { if (config.csrfToken.isNotBlank()) header("X-Frappe-CSRF-Token", config.csrfToken) }
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = executePost(request)
        if (!response.isSuccessful) {
            throw RuntimeException("Frappe error ${response.code}: ${response.body?.string()}")
        }
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

        executePost(request).close()
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

    companion object {
        private const val TAG = "FrappeApi"
    }
}
