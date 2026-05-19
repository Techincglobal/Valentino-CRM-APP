package com.example.crm_caller_nxtgen.core.db

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface CallLogDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(log: CallLogEntity)

    @Update
    suspend fun update(log: CallLogEntity)

    @Query("SELECT * FROM call_logs ORDER BY createdAt DESC LIMIT 200")
    fun observeAll(): Flow<List<CallLogEntity>>

    @Query("SELECT * FROM call_logs WHERE isSynced = 0")
    suspend fun getUnsynced(): List<CallLogEntity>
}
