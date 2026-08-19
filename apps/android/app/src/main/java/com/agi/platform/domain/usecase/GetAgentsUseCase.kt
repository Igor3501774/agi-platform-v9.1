package com.agi.platform.domain.usecase

import com.agi.platform.domain.model.Agent
import com.agi.platform.domain.repository.AgentsRepository
import javax.inject.Inject

class GetAgentsUseCase @Inject constructor(
    private val repository: AgentsRepository
) {
    suspend operator fun invoke(token: String): List<Agent> {
        return repository.getAgents(token)
    }
}
