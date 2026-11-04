package com.example.crm_caller_nxtgen

import com.example.crm_caller_nxtgen.core.db.CallLogEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class FrappeRepositoryDeduplicationTest {

    private fun isDuplicate(
        newPhone: String,
        newTimestamp: Long,
        recentLogs: List<CallLogEntity>,
        cutoffWindowMs: Long = 15000L
    ): CallLogEntity? {
        val cutoff = newTimestamp - cutoffWindowMs
        val filteredByTime = recentLogs.filter { it.createdAt >= cutoff }
        val phoneDigits = newPhone.filter { it.isDigit() }.takeLast(8)

        return filteredByTime.firstOrNull { r ->
            val rDigits = r.phoneNumber.filter { it.isDigit() }.takeLast(8)
            (phoneDigits.isNotBlank() && rDigits == phoneDigits) ||
            (phoneDigits.isBlank() && r.phoneNumber == newPhone)
        }
    }

    @Test
    fun testDeduplicationWithin15SecondWindow() {
        val now = System.currentTimeMillis()
        val existingLog = CallLogEntity(
            id = UUID.randomUUID().toString(),
            phoneNumber = "0722084691",
            callerName = "Unknown",
            leadDocname = "",
            durationSeconds = 45L,
            notes = "",
            callType = "Regular",
            direction = "Inbound",
            status = "Answered",
            createdAt = now - 5000L, // 5 seconds ago
            isSynced = true,
        )

        val recentList = listOf(existingLog)

        // Incoming duplicate with international prefix 7 seconds later
        val dup = isDuplicate("+94722084691", now + 2000L, recentList)
        assertNotNull("Should detect duplicate for same phone within 15s window", dup)
        assertEquals(existingLog.id, dup?.id)
    }

    @Test
    fun testCallsAfterCutoffWindowAreNotDeduplicated() {
        val now = System.currentTimeMillis()
        val oldLog = CallLogEntity(
            id = UUID.randomUUID().toString(),
            phoneNumber = "0722084691",
            callerName = "Unknown",
            leadDocname = "",
            durationSeconds = 30L,
            notes = "",
            callType = "Regular",
            direction = "Inbound",
            status = "Answered",
            createdAt = now - 25000L, // 25 seconds ago (outside 15s cutoff)
            isSynced = true,
        )

        val recentList = listOf(oldLog)

        // A new call after 25s should NOT be blocked as a duplicate
        val dup = isDuplicate("0722084691", now, recentList)
        assertEquals("New call after 15s window should NOT be deduplicated", null, dup)
    }

    @Test
    fun testDifferentPhoneNumbersAreNotDeduplicated() {
        val now = System.currentTimeMillis()
        val logA = CallLogEntity(
            id = UUID.randomUUID().toString(),
            phoneNumber = "0711111111",
            callerName = "A",
            leadDocname = "",
            durationSeconds = 20L,
            notes = "",
            callType = "Regular",
            direction = "Inbound",
            status = "Answered",
            createdAt = now - 2000L,
            isSynced = false,
        )

        val recentList = listOf(logA)

        val dup = isDuplicate("0722222222", now, recentList)
        assertEquals("Different phone numbers must not be treated as duplicates", null, dup)
    }

    @Test
    fun testCallLogEntityPropertiesAndDefaults() {
        val entity = CallLogEntity(
            id = "uuid-123",
            phoneNumber = "0722084691",
            callerName = "Amila",
            leadDocname = "LEAD-001",
            durationSeconds = 60L,
            notes = "Test notes",
            callType = "Regular",
            direction = "Inbound",
            status = "Declined",
            createdAt = 1730628000000L,
            isSynced = false,
            frappeDocname = "",
        )

        assertEquals("uuid-123", entity.id)
        assertEquals("0722084691", entity.phoneNumber)
        assertEquals("Declined", entity.status)
        assertFalse(entity.isSynced)
        assertEquals("", entity.frappeDocname)
    }
}
