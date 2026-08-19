package com.agi.platform.domain.repository

import com.agi.platform.domain.model.ChatMessage
import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    suspend fun sendMessage(token: String, agentId: String, text: String): ChatMessage
    fun observeMessages(agentId: String): Flow<List<ChatMessage>>
    suspend fun clearHistory(agentId: String)
}
