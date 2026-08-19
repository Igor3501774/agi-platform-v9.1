package com.agi.platform.data.dto

data class PhotoRequestDto(
    val agent_id: String,
    val photo_base64: String,
    val question: String,
    val user_id: String = "android_user"
)