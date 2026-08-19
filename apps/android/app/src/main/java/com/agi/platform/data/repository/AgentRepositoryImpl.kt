package com.agi.platform.data.repository

import com.agi.platform.core.network.ApiService
import com.agi.platform.data.mapper.toDomain
import com.agi.platform.domain.model.Agent
import com.agi.platform.domain.repository.AgentsRepository
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AgentRepositoryImpl @Inject constructor(
    private val apiService: ApiService
) : AgentsRepository {

    override suspend fun getAgents(token: String): List<Agent> {
        val response = apiService.getAgents("Bearer $token")
        return response.agents.map { it.toDomain() }
    }

    override suspend fun getCategories(token: String): List<String> {
        val response = apiService.getCategories("Bearer $token")
        return response.categories
    }
}
