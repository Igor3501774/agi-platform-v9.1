package com.agi.platform.data.dto

data class ChatResponseDto(
    val response: String,
    val agent_id: String,
    val source: String,
    val cost: Double,
    val latency_ms: Int
)