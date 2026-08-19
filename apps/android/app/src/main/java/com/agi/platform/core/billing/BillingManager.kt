package com.agi.platform.core.billing

import android.content.Context

interface BillingManager {
    fun startConnection()
    fun purchaseSubscription(planId: String)
    fun checkPurchases()
}

class RuStoreBillingManager(private val context: Context) : BillingManager {
    override fun startConnection() {
        // Инициализация RuStore SDK
    }

    override fun purchaseSubscription(planId: String) {
        // Покупка подписки
    }

    override fun checkPurchases() {
        // Проверка активных подписок
    }
}
