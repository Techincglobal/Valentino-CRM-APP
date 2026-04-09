package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "notes")
data class NoteEntity(
    @PrimaryKey val id: String,
    val phoneNumber: String,
    val content: String,
    val entityType: String, // LEAD, OPPORTUNITY, COMPLAINT, CALL_LOG
    val timestamp: Long,
    val isSynced: Boolean
)
