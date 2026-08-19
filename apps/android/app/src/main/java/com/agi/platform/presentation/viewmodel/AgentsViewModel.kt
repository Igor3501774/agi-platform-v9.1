package com.agi.platform.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.agi.platform.domain.model.Agent
import com.agi.platform.domain.usecase.GetAgentsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class AgentsUiState {
    object Loading : AgentsUiState()
    data class Success(val agents: List<Agent>) : AgentsUiState()
    data class Error(val message: String) : AgentsUiState()
    object Empty : AgentsUiState()
}

@HiltViewModel
class AgentsViewModel @Inject constructor(
    private val getAgentsUseCase: GetAgentsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow<AgentsUiState>(AgentsUiState.Loading)
    val uiState: StateFlow<AgentsUiState> = _uiState.asStateFlow()

    fun loadAgents(token: String) {
        viewModelScope.launch {
            _uiState.value = AgentsUiState.Loading
            try {
                val agents = getAgentsUseCase(token)
                _uiState.value = if (agents.isEmpty()) {
                    AgentsUiState.Empty
                } else {
                    AgentsUiState.Success(agents)
                }
            } catch (e: Exception) {
                _uiState.value = AgentsUiState.Error(e.message ?: "Unknown error")
            }
        }
    }
}
