package com.agi.platform.core.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface MessageDao {
    @Insert
    suspend fun insertMessage(message: MessageEntity)

    @Query("SELECT * FROM messages WHERE agentId = :agentId ORDER BY timestamp ASC")
    suspend fun getMessages(agentId: String): List<MessageEntity>

    @Query("DELETE FROM messages WHERE agentId = :agentId")
    suspend fun clearMessages(agentId: String)
}
