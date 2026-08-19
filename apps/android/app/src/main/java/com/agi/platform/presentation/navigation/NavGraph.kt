package com.agi.platform.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.agi.platform.presentation.screens.AgentsScreen
import com.agi.platform.presentation.screens.ChatScreen
import com.agi.platform.presentation.screens.LoginScreen
import com.agi.platform.presentation.screens.OnboardingScreen
import com.agi.platform.presentation.viewmodel.AgentsViewModel
import com.agi.platform.presentation.viewmodel.ChatViewModel

@Composable
fun NavGraph(
    navController: NavHostController = rememberNavController()
) {
    var isLoggedIn by remember { mutableStateOf(false) }
    var hasAcceptedPrivacy by remember { mutableStateOf(false) }

    NavHost(
        navController = navController,
        startDestination = if (hasAcceptedPrivacy) "login" else "privacy"
    ) {
        composable("privacy") {
            OnboardingScreen(
                onStart = {
                    hasAcceptedPrivacy = true
                    navController.navigate("login") {
                        popUpTo("privacy") { inclusive = true }
                    }
                }
            )
        }

        composable("login") {
            LoginScreen(
                onGuestLogin = {
                    isLoggedIn = true
                    navController.navigate("agents") {
                        popUpTo("login") { inclusive = true }
                    }
                },
                onGosuslugiLogin = { }
            )
        }

        composable("agents") {
            val viewModel: AgentsViewModel = hiltViewModel()
            val state by viewModel.uiState.collectAsStateWithLifecycle()

            AgentsScreen(
                state = state,
                onAgentClick = { agentId ->
                    navController.navigate("chat/$agentId")
                }
            )
        }

        composable(
            route = "chat/{agentId}",
            arguments = listOf(
                navArgument("agentId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val agentId = backStackEntry.arguments?.getString("agentId") ?: ""
            val viewModel: ChatViewModel = hiltViewModel()
            val state by viewModel.uiState.collectAsStateWithLifecycle()

            ChatScreen(
                agentId = agentId,
                state = state,
                onSendMessage = { message ->
                    viewModel.sendMessage("token", agentId, message)
                },
                onBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
