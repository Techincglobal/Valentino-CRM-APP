package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "complaints")
data class ComplaintEntity(
    @PrimaryKey val id: String,           // local UUID
    val frappeDocname: String = "",       // filled after network sync
    val phoneNumber: String,
    val leadDocname: String = "",         // Frappe lead docname for linkage
    val category: String,
    val description: String,
    val priority: String,                 // "Low", "Medium", "High"
    val isSynced: Boolean,
)
