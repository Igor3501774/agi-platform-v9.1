package com.agi.platform.domain.repository

import com.agi.platform.domain.model.Agent
import kotlinx.coroutines.flow.Flow

interface AgentRepository {
    suspend fun getAgents(token: String): List<Agent>
    fun observeAgents(): Flow<List<Agent>>
}
