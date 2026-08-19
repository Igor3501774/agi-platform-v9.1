package com.agi.platform.data.dto

data class ChatRequest(
    val agent_id: String,
    val message: String,
    val user_id: String = "android_user",
    val history: List<Map<String, Any>> = emptyList()
)
