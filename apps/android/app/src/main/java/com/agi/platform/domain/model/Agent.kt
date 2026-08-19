package com.agi.platform.domain.model

data class Agent(
    val id: String,
    val name: String,
    val description: String,
    val specialty: String,
    val category: String,
    val isPremium: Boolean = false,
    val isSafe: Boolean = false,
    val icon: String? = null
)

data class ChatMessage(
    val id: String,
    val agentId: String,
    val text: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis()
)
