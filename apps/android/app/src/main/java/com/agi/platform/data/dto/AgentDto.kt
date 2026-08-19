package com.agi.platform.data.dto

data class AgentDto(
    val id: String,
    val name: String,
    val description: String,
    val specialty: String,
    val category: String,
    val is_premium: Boolean = false,
    val is_safe: Boolean = false,
    val icon: String? = null,
    val prompt_template: String? = null
)
