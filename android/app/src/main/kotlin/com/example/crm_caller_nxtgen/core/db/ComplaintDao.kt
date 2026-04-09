package com.example.crm_caller_nxtgen.core.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface ComplaintDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertComplaint(complaint: ComplaintEntity)

    @Update
    suspend fun updateComplaint(complaint: ComplaintEntity)

    @Query("SELECT * FROM complaints WHERE phoneNumber = :phoneNumber")
    fun getComplaintsForPhoneFlow(phoneNumber: String): Flow<List<ComplaintEntity>>

    @Query("SELECT * FROM complaints WHERE isSynced = 0")
    suspend fun getUnsyncedComplaints(): List<ComplaintEntity>
}
