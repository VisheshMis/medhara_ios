package com.medha.companion

import android.app.Application
import com.medha.companion.data.sync.MedhaSyncWorker

class MedhaCompanionApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Register periodic background delta synchronization (every 15 min on network connection)
        MedhaSyncWorker.enqueuePeriodicSync(this)
    }
}
