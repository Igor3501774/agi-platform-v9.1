package com.agi.platform.data.mapper

import com.agi.platform.core.database.MessageEntity
import com.agi.platform.domain.model.ChatMessage

fun MessageEntity.toDomain(): ChatMessage {
    return ChatMessage(
        id = id.toString(),
        agentId = agentId,
        text = text,
        isUser = isUser,
        timestamp = timestamp
    )
}
