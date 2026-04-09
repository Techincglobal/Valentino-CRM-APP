package com.example.crm_caller_nxtgen.core.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface ContactDao {
    @Query("SELECT * FROM crm_contacts WHERE phoneNumber = :phoneNumber LIMIT 1")
    suspend fun getContact(phoneNumber: String): ContactEntity?

    @Query("SELECT * FROM crm_contacts WHERE phoneNumber LIKE '%' || :partialNumber LIMIT 1")
    suspend fun getContactByPartial(partialNumber: String): ContactEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertContacts(contacts: List<ContactEntity>)

    @Query("DELETE FROM crm_contacts")
    suspend fun clearAll()
}
