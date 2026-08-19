package com.agi.platform.core.speech

interface SpeechRecognizer {
    fun startListening(onResult: (String) -> Unit, onError: (String) -> Unit)
    fun stopListening()
    fun isListening(): Boolean
}
