package com.agi.platform.di

import com.agi.platform.data.repository.AgentRepositoryImpl
import com.agi.platform.data.repository.ChatRepositoryImpl
import com.agi.platform.domain.repository.AgentsRepository
import com.agi.platform.domain.repository.ChatRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object RepositoryModule {
    @Provides
    @Singleton
    fun provideAgentsRepository(impl: AgentRepositoryImpl): AgentsRepository {
        return impl
    }

    @Provides
    @Singleton
    fun provideChatRepository(impl: ChatRepositoryImpl): ChatRepository {
        return impl
    }
}
