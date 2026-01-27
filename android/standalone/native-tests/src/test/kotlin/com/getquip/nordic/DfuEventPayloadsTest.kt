package com.getquip.nordic

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DfuEventPayloadsTest {
    @Test
    fun statePayloadIncludesStateAndDevice() {
        val payload = DfuEventPayloads.statePayload("CONNECTING", "AA:BB:CC:DD")

        assertEquals("CONNECTING", payload["state"])
        assertEquals("AA:BB:CC:DD", payload["deviceAddress"])
        assertEquals(2, payload.size)
    }

    @Test
    fun progressPayloadIncludesAllFields() {
        val payload = DfuEventPayloads.progressPayload(
            deviceAddress = "11:22:33:44",
            percent = 42,
            speed = 100.5f,
            avgSpeed = 90.25f,
            currentPart = 2,
            totalParts = 3
        )

        assertEquals("11:22:33:44", payload["deviceAddress"])
        assertEquals(42, payload["percent"])
        assertEquals(100.5f, payload["speed"])
        assertEquals(90.25f, payload["avgSpeed"])
        assertEquals(2, payload["currentPart"])
        assertEquals(3, payload["totalParts"])
        assertEquals(6, payload.size)
    }

    @Test
    fun progressPayloadPreservesZeroValues() {
        val payload = DfuEventPayloads.progressPayload(
            deviceAddress = "00:00:00:00",
            percent = 0,
            speed = 0f,
            avgSpeed = 0f,
            currentPart = 0,
            totalParts = 0
        )

        assertEquals(0, payload["percent"])
        assertEquals(0f, payload["speed"])
        assertEquals(0f, payload["avgSpeed"])
        assertEquals(0, payload["currentPart"])
        assertEquals(0, payload["totalParts"])
    }

    @Test
    fun statePayloadAllowsEmptyDeviceAddress() {
        val payload = DfuEventPayloads.statePayload("UNKNOWN_STATE", "")

        assertEquals("UNKNOWN_STATE", payload["state"])
        assertEquals("", payload["deviceAddress"])
    }
}
