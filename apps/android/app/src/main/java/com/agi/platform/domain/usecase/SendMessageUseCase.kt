package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.repository.ChatRepository
import javax.inject.Inject

class SendMessageUseCase @Inject constructor(
    private val repository: ChatRepository
) {
    suspend operator fun invoke(token: String, agentId: String, text: String): ChatMessage {
        return repository.sendMessage(token, agentId, text)
    }
}
