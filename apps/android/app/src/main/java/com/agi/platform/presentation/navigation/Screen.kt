package com.agi.platform.presentation.navigation

sealed class Screen(val route: String) {
    data object Onboarding : Screen("onboarding")
    data object Login : Screen("login")
    data object Agents : Screen("agents")
    data object Chat : Screen("chat/{agentId}") {
        fun createRoute(agentId: String) = "chat/$agentId"
    }
}