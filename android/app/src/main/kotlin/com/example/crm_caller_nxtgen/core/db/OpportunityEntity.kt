package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "opportunities")
data class OpportunityEntity(
    @PrimaryKey val id: String,           // local UUID
    val frappeDocname: String = "",       // filled after network sync
    val leadId: String,                   // local lead UUID
    val leadDocname: String = "",         // Frappe lead docname — needed for API call
    val dealValue: Double,
    val stage: String,
    val note: String = "",
    val isSynced: Boolean,
)
