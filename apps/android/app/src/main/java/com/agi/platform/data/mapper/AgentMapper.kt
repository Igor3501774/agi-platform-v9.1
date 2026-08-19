package com.agi.platform.data.mapper

import com.agi.platform.data.dto.AgentDto
import com.agi.platform.domain.model.Agent

fun AgentDto.toDomain(): Agent {
    return Agent(
        id = id,
        name = name,
        description = description ?: "",
        specialty = specialty ?: "",
        category = category ?: "",
        isPremium = is_premium,
        isSafe = is_safe,
        icon = icon
    )
}
