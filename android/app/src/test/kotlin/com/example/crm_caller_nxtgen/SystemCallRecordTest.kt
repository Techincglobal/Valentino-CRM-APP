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
}
