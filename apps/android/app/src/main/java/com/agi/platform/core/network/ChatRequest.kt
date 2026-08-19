package com.agi.platform.core.network

data class ChatRequest(
    val agent_id: String,
    val message: String,
    val user_id: String = "android_user"
)
