package com.agi.platform.domain.repository

import com.agi.platform.domain.model.Agent

interface AgentsRepository {
    suspend fun getAgents(token: String): List<Agent>
    suspend fun getCategories(token: String): List<String>
}
