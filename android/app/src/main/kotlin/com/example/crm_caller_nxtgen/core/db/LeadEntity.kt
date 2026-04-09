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
)
