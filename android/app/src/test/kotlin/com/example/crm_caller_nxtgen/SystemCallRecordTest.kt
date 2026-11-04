package com.example.crm_caller_nxtgen

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class SystemCallRecordTest {

    @Test
    fun testSystemCallRecordProperties() {
        val record = SystemCallRecord(
            phone = "0722084691",
            direction = "Inbound",
            status = "Answered",
            durationSeconds = 45L,
            timestamp = 1730628000000L,
        )

        assertEquals("0722084691", record.phone)
        assertEquals("Inbound", record.direction)
        assertEquals("Answered", record.status)
        assertEquals(45L, record.durationSeconds)
        assertEquals(1730628000000L, record.timestamp)
    }

    @Test
    fun testOutboundCallOutcomeMapping() {
        val recordAnswered = SystemCallRecord(
            phone = "+94712345678",
            direction = "Outbound",
            status = "Answered",
            durationSeconds = 120L,
            timestamp = System.currentTimeMillis(),
        )
        assertEquals("Outbound", recordAnswered.direction)
        assertEquals("Answered", recordAnswered.status)

        val recordNoAnswer = SystemCallRecord(
            phone = "+94712345678",
            direction = "Outbound",
            status = "No Answer",
            durationSeconds = 0L,
            timestamp = System.currentTimeMillis(),
        )
        assertEquals("Outbound", recordNoAnswer.direction)
        assertEquals("No Answer", recordNoAnswer.status)
    }

    @Test
    fun testPhoneNormalizationAndDeduplicationMatching() {
        fun isSamePhoneNumber(a: String?, b: String?): Boolean {
            if (a.isNullOrBlank() || b.isNullOrBlank()) return true
            val da = a.filter { it.isDigit() }
            val db = b.filter { it.isDigit() }
            if (da == db) return true
            if (da.length >= 8 && db.length >= 8 && da.takeLast(8) == db.takeLast(8)) return true
            return false
        }

        // Test matching variations of the same phone number (international prefix vs local 0-prefix)
        org.junit.Assert.assertTrue(isSamePhoneNumber("0722084691", "+94722084691"))
        org.junit.Assert.assertTrue(isSamePhoneNumber("+94722084691", "0722084691"))
        org.junit.Assert.assertTrue(isSamePhoneNumber("072-208-4691", "+94 72 208 4691"))
        org.junit.Assert.assertTrue(isSamePhoneNumber("0722084691", "0722084691"))
        org.junit.Assert.assertTrue(isSamePhoneNumber("", "0722084691"))
        org.junit.Assert.assertTrue(isSamePhoneNumber("0722084691", null))

        // Different numbers must NOT match
        org.junit.Assert.assertFalse(isSamePhoneNumber("0711111111", "0722222222"))
        org.junit.Assert.assertFalse(isSamePhoneNumber("+94711111111", "+94722222222"))
    }
}

