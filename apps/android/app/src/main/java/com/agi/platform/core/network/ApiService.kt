package com.agi.platform.core.network

import retrofit2.http.*
import com.agi.platform.data.dto.*

interface ApiService {
    // Auth
    @POST("auth/token")
    suspend fun login(@Body request: LoginRequest): TokenResponse

    // Agents
    @GET("api/agents/")
    suspend fun getAgents(@Header("Authorization") auth: String): AgentsResponse

    @GET("api/agents/categories/")
    suspend fun getCategories(@Header("Authorization") auth: String): CategoriesResponse

    @GET("api/agents/stats/")
    suspend fun getStats(@Header("Authorization") auth: String): StatsResponse

    // Chat
    @POST("api/chat/send")
    suspend fun sendMessage(
        @Header("Authorization") auth: String,
        @Body request: ChatRequest
    ): ChatResponse

    // Embeddings
    @POST("api/embed/")
    suspend fun getEmbedding(
        @Header("Authorization") auth: String,
        @Body request: EmbeddingRequest
    ): EmbeddingResponse

    // Memory
    @POST("api/v1/memory/save")
    suspend fun saveMemory(
        @Header("Authorization") auth: String,
        @Body request: MemorySaveRequest
    ): MemorySaveResponse

    @POST("api/v1/memory/search")
    suspend fun searchMemory(
        @Header("Authorization") auth: String,
        @Body request: MemorySearchRequest
    ): MemorySearchResponse
}

// Data classes
data class LoginRequest(val username: String, val password: String)
data class TokenResponse(val access_token: String, val token_type: String)

data class AgentsResponse(val agents: List<AgentDto>, val total: Int)
data class CategoriesResponse(val categories: List<String>)
data class StatsResponse(
    val total: Int,
    val premium: Int,
    val free: Int,
    val safe: Int,
    val categories: Map<String, Int>
)

data class ChatResponse(val response: String, val agent_id: String)

data class EmbeddingRequest(val texts: List<String>)
data class EmbeddingResponse(val embeddings: List<List<Double>>)

data class MemorySaveRequest(
    val agent_id: String,
    val text: String,
    val metadata: Map<String, Any>
)
data class MemorySaveResponse(val status: String, val memory_id: String, val agent_id: String)

data class MemorySearchRequest(
    val agent_id: String,
    val query: String,
    val limit: Int = 5
)
data class MemorySearchResponse(val results: List<MemoryItem>, val total: Int)
data class MemoryItem(val text: String, val score: Double)
