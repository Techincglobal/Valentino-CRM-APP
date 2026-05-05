package com.example.crm_caller_nxtgen.core.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface LeadDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLead(lead: LeadEntity)

    @Update
    suspend fun updateLead(lead: LeadEntity)

    @Query("SELECT * FROM leads WHERE phoneNumber = :phoneNumber LIMIT 1")
    fun getLeadByPhoneFlow(phoneNumber: String): Flow<LeadEntity?>

    @Query("SELECT * FROM leads WHERE phoneNumber = :phoneNumber LIMIT 1")
    suspend fun getLeadByPhone(phoneNumber: String): LeadEntity?

    @Query("SELECT * FROM leads WHERE id = :id LIMIT 1")
    suspend fun getLeadById(id: String): LeadEntity?

    @Query("SELECT * FROM leads WHERE isSynced = 0")
    suspend fun getUnsyncedLeads(): List<LeadEntity>

    @Query("DELETE FROM leads WHERE phoneNumber = :phoneNumber OR phoneNumber = :phoneShort")
    suspend fun deleteLeadByPhone(phoneNumber: String, phoneShort: String)

    @Query("DELETE FROM leads")
    suspend fun deleteAllLeads()
}
