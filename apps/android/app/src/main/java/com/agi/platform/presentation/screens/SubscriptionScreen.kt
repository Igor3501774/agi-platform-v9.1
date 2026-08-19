package com.agi.platform.presentation.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun SubscriptionScreen(
    onPlanSelected: (String) -> Unit,
    onBack: () -> Unit
) {
    val plans = listOf(
        Plan("Бесплатный", "0 ₽", "3 запроса/день", false),
        Plan("Pro", "299 ₽/мес", "Безлимит + Память", true),
        Plan("Business", "999 ₽/мес", "Безлимит + API доступ", true)
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "💎 Выберите тариф",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(plans) { plan ->
                PlanCard(
                    plan = plan,
                    onSelect = { onPlanSelected(plan.name) }
                )
            }
        }

        Button(
            onClick = onBack,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp)
        ) {
            Text("Назад")
        }
    }
}

data class Plan(
    val name: String,
    val price: String,
    val features: String,
    val isPremium: Boolean
)

@Composable
fun PlanCard(
    plan: Plan,
    onSelect: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = plan.name,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                if (plan.isPremium) {
                    Text(
                        text = "⭐",
                        fontSize = 24.sp
                    )
                }
            }

            Text(
                text = plan.price,
                fontSize = 18.sp,
                color = MaterialTheme.colorScheme.primary
            )

            Text(
                text = plan.features,
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 4.dp)
            )

            Button(
                onClick = onSelect,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            ) {
                Text(if (plan.name == "Бесплатный") "Выбрать" else "Подписаться")
            }
        }
    }
}
