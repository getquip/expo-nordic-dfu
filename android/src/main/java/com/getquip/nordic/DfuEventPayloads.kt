package com.getquip.nordic

object DfuEventPayloads {
    fun statePayload(state: String, deviceAddress: String): Map<String, String> {
        return mapOf(
            "state" to state,
            "deviceAddress" to deviceAddress
        )
    }

    fun progressPayload(
        deviceAddress: String,
        percent: Int,
        speed: Float,
        avgSpeed: Float,
        currentPart: Int,
        totalParts: Int
    ): Map<String, Any> {
        return mapOf(
            "deviceAddress" to deviceAddress,
            "percent" to percent,
            "speed" to speed,
            "avgSpeed" to avgSpeed,
            "currentPart" to currentPart,
            "totalParts" to totalParts
        )
    }
}
