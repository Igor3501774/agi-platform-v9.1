package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

class ObserveMessagesUseCase @Inject constructor(
    private val repository: ChatRepository
) {
    operator fun invoke(agentId: String): Flow<List<ChatMessage>> {
        return repository.observeMessages(agentId)
    }
}
