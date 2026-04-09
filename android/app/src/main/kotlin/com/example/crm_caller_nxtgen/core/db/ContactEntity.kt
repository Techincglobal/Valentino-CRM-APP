package com.example.crm_caller_nxtgen.core.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "crm_contacts")
data class ContactEntity(
    @PrimaryKey
    val phoneNumber: String,
    val name: String,
    val type: String,
    val docname: String,
    val lastUpdated: Long
)
