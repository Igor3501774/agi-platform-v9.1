package com.agi.platform.presentation.components

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.Toast

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    text: String,
    isUser: Boolean
) {
    val context = LocalContext.current
    var showCopied by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 4.dp),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        Card(
            colors = CardDefaults.cardColors(
                containerColor = if (isUser)
                    MaterialTheme.colorScheme.primaryContainer
                else
                    MaterialTheme.colorScheme.secondaryContainer
            ),
            modifier = Modifier
                .widthIn(max = 280.dp)
                .combinedClickable(
                    onClick = { },
                    onLongClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("AGI Platform", text)
                        clipboard.setPrimaryClip(clip)
                        showCopied = true
                        Toast.makeText(context, "Скопировано!", Toast.LENGTH_SHORT).show()
                    }
                )
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodyMedium
                )
                if (!isUser) {
                    Text(
                        text = "🤖 Сгенерировано ИИ",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
        if (showCopied) {
            Text(
                text = "Скопировано!",
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}