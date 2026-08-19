package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow

class ObserveMessages(
    private val repository: ChatRepository
) {
    operator fun invoke(agentId: String): Flow<List<ChatMessage>> {
        return repository.observeMessages(agentId)
    }
}
