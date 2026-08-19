package com.agi.platform.data.repository

import com.agi.platform.core.database.MessageDao
import com.agi.platform.core.database.MessageEntity
import com.agi.platform.core.network.ApiService
import com.agi.platform.core.network.ChatRequest
import com.agi.platform.data.mapper.toDomain
import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.repository.ChatRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatRepositoryImpl @Inject constructor(
    private val apiService: ApiService,
    private val messageDao: MessageDao
) : ChatRepository {

    override suspend fun sendMessage(token: String, agentId: String, text: String): ChatMessage {
        val request = ChatRequest(
            agent_id = agentId,
            message = text,
            user_id = "android_user"
        )
        val response = apiService.sendMessage("Bearer $token", request)

        val userMsg = MessageEntity(agentId = agentId, text = text, isUser = true)
        messageDao.insertMessage(userMsg)

        val aiMsg = MessageEntity(agentId = agentId, text = response.response, isUser = false)
        messageDao.insertMessage(aiMsg)

        return ChatMessage(
            id = aiMsg.id.toString(),
            agentId = agentId,
            text = response.response,
            isUser = false,
            timestamp = aiMsg.timestamp
        )
    }

    override fun observeMessages(agentId: String): Flow<List<ChatMessage>> {
        return flow {
            while (true) {
                val entities = messageDao.getMessages(agentId)
                emit(entities.map { it.toDomain() })
                kotlinx.coroutines.delay(500)
            }
        }
    }

    override suspend fun clearHistory(agentId: String) {
        messageDao.clearMessages(agentId)
    }
}
