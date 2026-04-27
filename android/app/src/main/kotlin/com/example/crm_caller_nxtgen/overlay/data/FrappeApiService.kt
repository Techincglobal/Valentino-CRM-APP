package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
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
)

data class FrappeOpportunityResult(val docname: String)
data class FrappeComplaintResult(val docname: String)
data class FrappeQuotationResult(val docname: String)

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
        // flutter_shared_preferences stores strings as "flutter.<key>"
        val url = prefs.getString("flutter.crm_base_url", "") ?: ""
        val sid = prefs.getString("flutter.crm_sid", "") ?: ""
        return FrappeConfig(url.trimEnd('/'), sid)
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
            .post(body.toString().toRequestBody(JSON))
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            val errBody = response.body?.string() ?: ""
            throw RuntimeException("Frappe error ${response.code}: $errBody")
        }

        val responseBody = response.body?.string() ?: throw RuntimeException("Empty response")
        val msg = JSONObject(responseBody).optJSONObject("message")
            ?: throw RuntimeException("Invalid response")

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
    // Utilities
    // ─────────────────────────────────────────────────────────────────────────

    /** Strip non-digits except leading +. Returns last 10 digits for fuzzy match. */
    private fun normalisePhone(phone: String): String {
        val digits = phone.filter { it.isDigit() || it == '+' }
        return digits.ifBlank { phone }
    }

    private fun String.encodeUrl(): String =
        java.net.URLEncoder.encode(this, "UTF-8")
}
