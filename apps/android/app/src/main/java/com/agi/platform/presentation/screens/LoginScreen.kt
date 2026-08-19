package com.agi.platform.presentation.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun LoginScreen(onGuestLogin: () -> Unit, onGosuslugiLogin: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(colors = listOf(MaterialTheme.colorScheme.background, MaterialTheme.colorScheme.surfaceVariant)))
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("👋 Добро пожаловать!", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text("Выберите способ входа", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(48.dp))
            Button(onClick = onGosuslugiLogin, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(16.dp), colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Text("🏛️"); Text("Войти через Госуслуги", fontWeight = FontWeight.Medium) }
            }
            Spacer(Modifier.height(12.dp))
            OutlinedButton(onClick = onGuestLogin, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(16.dp)) {
                Text("Продолжить без входа", fontWeight = FontWeight.Medium)
            }
            Spacer(Modifier.height(32.dp))
            Text("🤖 Ответы генерируются искусственным интеллектом", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
        }
    }
}