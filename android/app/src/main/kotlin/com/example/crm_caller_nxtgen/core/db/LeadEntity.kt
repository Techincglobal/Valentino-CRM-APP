package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "leads")
data class LeadEntity(
    @PrimaryKey val id: String,           // local UUID
    val frappeDocname: String = "",       // "CRM-LEAD-2024-00042" — empty until synced
    val phoneNumber: String,
    val name: String?,
    val email: String? = null,
    val company: String? = null,
    val status: String,                   // "New", "Lead", "Interested", "Converted"
    val isSynced: Boolean,
    val cachedAt: Long = 0L,             // epoch-ms when last refreshed from server
    val latestNote: String = "",          // most recent note from Frappe — shown on call
    val latestQuoteSubject: String = "",  // most recent quotation subject/title
    val latestQuoteAmount: Double = 0.0,  // most recent quotation grand total
    val latestQuoteStatus: String = "",   // "Draft", "Submitted", "Cancelled", etc.
)
