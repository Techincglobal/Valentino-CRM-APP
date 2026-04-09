package com.example.crm_caller_nxtgen.core.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface OpportunityDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOpportunity(opp: OpportunityEntity)

    @Update
    suspend fun updateOpportunity(opp: OpportunityEntity)

    @Query("SELECT * FROM opportunities WHERE leadId = :leadId")
    fun getOpportunitiesForLeadFlow(leadId: String): Flow<List<OpportunityEntity>>

    @Query("SELECT * FROM opportunities WHERE isSynced = 0")
    suspend fun getUnsyncedOpportunities(): List<OpportunityEntity>
}
