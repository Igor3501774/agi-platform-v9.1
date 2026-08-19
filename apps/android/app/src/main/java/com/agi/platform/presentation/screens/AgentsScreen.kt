package com.agi.platform.presentation.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.agi.platform.domain.model.Agent
import com.agi.platform.presentation.components.AgentCard
import com.agi.platform.presentation.viewmodel.AgentsUiState

@Composable
fun AgentsScreen(
    state: AgentsUiState,
    onAgentClick: (String) -> Unit
) {
    when (state) {
        is AgentsUiState.Loading -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is AgentsUiState.Success -> {
            Column(modifier = Modifier.fillMaxSize()) {
                Text(
                    text = "Choose an Agent",
                    style = MaterialTheme.typography.headlineMedium,
                    modifier = Modifier.padding(16.dp)
                )
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    items(state.agents) { agent ->
                        AgentCard(agent = agent, onClick = { onAgentClick(agent.id) })
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
        is AgentsUiState.Error -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Error: ${state.message}", color = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { /* reload */ }) {
                        Text("Retry")
                    }
                }
            }
        }
        is AgentsUiState.Empty -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No agents available")
            }
        }
    }
}
