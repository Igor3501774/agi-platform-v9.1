package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.repository.ChatRepository

class SendMessage(
    private val repository: ChatRepository
) {
    suspend operator fun invoke(token: String, agentId: String, message: String): ChatMessage {
        return repository.sendMessage(token, agentId, message)
    }
}
