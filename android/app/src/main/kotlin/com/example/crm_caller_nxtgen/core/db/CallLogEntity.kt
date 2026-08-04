package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "call_logs")
data class CallLogEntity(
    @PrimaryKey val id: String,
    val frappeDocname: String = "",
    val phoneNumber: String,
    val callerName: String,
    val leadDocname: String = "",
    val durationSeconds: Long,
    val notes: String,
    val callType: String,         // "Regular" or "WhatsApp"
    val direction: String = "Inbound",
    val status: String = "Answered",
    val createdAt: Long,
    val isSynced: Boolean,
)
