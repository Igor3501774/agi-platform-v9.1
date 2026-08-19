package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.Agent
import com.agi.platform.domain.repository.AgentRepository
import kotlinx.coroutines.flow.Flow

class GetAgents(
    private val repository: AgentRepository
) {
    suspend operator fun invoke(token: String): List<Agent> = repository.getAgents(token)
    fun observe(): Flow<List<Agent>> = repository.observeAgents()
}
