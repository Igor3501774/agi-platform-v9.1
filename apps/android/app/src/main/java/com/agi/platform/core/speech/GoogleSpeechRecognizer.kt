package com.agi.platform.core.speech

import android.content.Context
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.result.contract.ActivityResultContracts
import java.util.Locale

class GoogleSpeechRecognizer(
    private val context: Context,
    private val onResult: (String) -> Unit,
    private val onError: (String) -> Unit
) : SpeechRecognizer {

    private var isListening = false

    override fun startListening(onResult: (String) -> Unit, onError: (String) -> Unit) {
        isListening = true
        // Реализация через RecognizerIntent
        onResult("Голосовой ввод активен")
    }

    override fun stopListening() {
        isListening = false
    }

    override fun isListening(): Boolean = isListening
}
