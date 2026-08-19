package com.agi.platform.di

import android.content.Context
import com.agi.platform.core.database.AppDatabase
import com.agi.platform.core.database.MessageDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideAppDatabase(@ApplicationContext context: Context): AppDatabase {
        return AppDatabase.getInstance(context)
    }

    @Provides
    fun provideMessageDao(database: AppDatabase): MessageDao {
        return database.messageDao()
    }
}
