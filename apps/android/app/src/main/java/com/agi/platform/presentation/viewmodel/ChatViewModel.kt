package com.agi.platform.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agi.platform.domain.model.ChatMessage
import com.agi.platform.domain.usecase.ObserveMessagesUseCase
import com.agi.platform.domain.usecase.SendMessageUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class ChatUiState {
    object Loading : ChatUiState()
    data class Success(val messages: List<ChatMessage>) : ChatUiState()
    data class Error(val message: String) : ChatUiState()
    object Empty : ChatUiState()
}

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val sendMessageUseCase: SendMessageUseCase,
    private val observeMessagesUseCase: ObserveMessagesUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<ChatUiState>(ChatUiState.Loading)
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    fun loadMessages(agentId: String) {
        viewModelScope.launch {
            observeMessagesUseCase(agentId).collect { messages ->
                _uiState.value = if (messages.isEmpty()) {
                    ChatUiState.Empty
                } else {
                    ChatUiState.Success(messages)
                }
            }
        }
    }

    fun sendMessage(token: String, agentId: String, text: String) {
        viewModelScope.launch {
            try {
                val message = sendMessageUseCase(token, agentId, text)
                val currentState = _uiState.value
                val updatedMessages = if (currentState is ChatUiState.Success) {
                    currentState.messages + message
                } else {
                    listOf(message)
                }
                _uiState.value = ChatUiState.Success(updatedMessages)
            } catch (e: Exception) {
                _uiState.value = ChatUiState.Error(e.message ?: "Unknown error")
            }
        }
    }
}
