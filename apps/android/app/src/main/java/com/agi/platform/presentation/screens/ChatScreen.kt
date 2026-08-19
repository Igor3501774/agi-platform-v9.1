package com.agi.platform.presentation.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.agi.platform.presentation.components.MessageBubble
import com.agi.platform.presentation.viewmodel.ChatUiState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    agentId: String,
    state: ChatUiState,
    onSendMessage: (String) -> Unit,
    onBack: () -> Unit
) {
    var inputText by remember { mutableStateOf("") }

    when (state) {
        is ChatUiState.Loading -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is ChatUiState.Success -> {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text("Chat with Agent") },
                        navigationIcon = {
                            IconButton(onClick = onBack) {
                                Icon(imageVector = Icons.Filled.ArrowBack, contentDescription = "Back")
                            }
                        }
                    )
                }
            ) { paddingValues ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                ) {
                    LazyColumn(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentPadding = PaddingValues(16.dp),
                        reverseLayout = true
                    ) {
                        items(state.messages) { message ->
                            MessageBubble(
                                text = message.text,
                                isUser = message.isUser
                            )
                        }
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = inputText,
                            onValueChange = { inputText = it },
                            modifier = Modifier.weight(1f),
                            placeholder = { Text("Type a message...") },
                            singleLine = true
                        )
                        Button(
                            onClick = {
                                if (inputText.isNotBlank()) {
                                    onSendMessage(inputText)
                                    inputText = ""
                                }
                            },
                            modifier = Modifier.padding(start = 8.dp)
                        ) {
                            Text("Send")
                        }
                    }
                }
            }
        }
        is ChatUiState.Error -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Error: ${state.message}", color = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { /* retry */ }) {
                        Text("Retry")
                    }
                }
            }
        }
        is ChatUiState.Empty -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No messages yet")
            }
        }
    }
}
